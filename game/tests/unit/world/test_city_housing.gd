extends GdUnitTestSuite

const _City = preload("res://scripts/world/City.gd")
const _Defs = preload("res://scripts/data/BuildingDefs.gd")
const _Chain = preload("res://scripts/economy/ProductionChain.gd")
const _Assignment = preload("res://scripts/world/WorkerAssignment.gd")
const _DemoProc = preload("res://scripts/demographics/DemographicTurnProcessor.gd")
const _Registry = preload("res://scripts/demographics/CharacterRegistry.gd")

var city: Variant
var center := Vector2i(5, 5)

func before_test() -> void:
	city = _City.new()
	city.uid = 7
	city.center = center
	city.stronghold_level = 1
	city.add_followers(10)
	city.storage[&"industry"] = 200.0

func _chain_def(id: StringName, workers: int) -> Variant:
	var d := UniqueBuilding.Def.new()
	d.id = id
	d.display_name = String(id)
	var req := UniqueBuilding.LevelReq.new()
	req.industry = 10.0
	d.levels = [req]
	var c := _Chain.new()
	c.id = id + "_chain"
	c.required_workers = workers
	c.outputs[&"grain"] = 2.0
	d.production_chain = c
	return d

func test_no_housing_base() -> void:
	assert_that(city.housing_total()).is_equal(0)
	assert_that(city.pop_cap()).is_equal(GameNumbers.POP_CAP_BY_STRONGHOLD[0])
	assert_that(city.free_housing(PopUnit.State.WORKER)).is_equal(GameNumbers.BASE_SETTLEMENT_HOUSING)
	assert_that(city.free_housing(PopUnit.State.SCHOLAR)).is_equal(0)
	assert_that(city.immigrant_state()).is_equal(PopUnit.State.WORKER)

func test_shack_extends_cap_and_housing() -> void:
	var cap_before: int = city.pop_cap()
	var shack_cell := HexUtils.get_neighbor(center, 0)
	var bld: Variant = city.build_building(_Defs.shack(), shack_cell)
	assert_that(bld).is_not_null()
	assert_that(city.pop_cap()).is_equal(cap_before + 10)
	assert_that(city.housing_capacity(PopUnit.State.WORKER)).is_equal(10)
	assert_that(city.housing_total()).is_equal(10)
	assert_that(city.free_housing(PopUnit.State.WORKER)).is_equal(10 + 10 - city.count_state(PopUnit.State.WORKER))

func test_manor_and_barracks_housing() -> void:
	var b1: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 1))
	assert_that(b1).is_not_null()
	var b2: Variant = city.build_building(_Defs.barracks(), HexUtils.get_neighbor(center, 3))
	assert_that(b2).is_not_null()
	assert_that(city.housing_capacity(PopUnit.State.SCHOLAR)).is_equal(2)
	assert_that(city.housing_capacity(PopUnit.State.MILITIA)).is_equal(5)

func test_immigrant_state_priority() -> void:
	var b1: Variant = city.build_building(_Defs.barracks(), HexUtils.get_neighbor(center, 0))
	var b2: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 2))
	assert_that(b1).is_not_null()
	assert_that(b2).is_not_null()
	assert_that(city.immigrant_state()).is_equal(PopUnit.State.WORKER)
	for i in 10:
		city.add_migrant(PopUnit.State.WORKER)
	assert_that(city.immigrant_state()).is_equal(PopUnit.State.MILITIA)
	for i in 5:
		city.add_migrant(PopUnit.State.MILITIA)
	assert_that(city.immigrant_state()).is_equal(PopUnit.State.SCHOLAR)
	for i in 2:
		city.add_migrant(PopUnit.State.SCHOLAR)
	assert_that(city.immigrant_state()).is_equal(-1)

func test_assignment_fills_buildings() -> void:
	var d: Variant = _chain_def(&"farm_a", 2)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_that(bld).is_not_null()
	for i in 12:
		city.add_migrant(PopUnit.State.WORKER)
	var n: int = _Assignment.rebalance(city)
	assert_that(n).is_equal(2)
	assert_that(int(bld.assigned_workers)).is_equal(2)
	var assigned_count := 0
	for u in city.pop:
		if u.assigned_to == bld.uid:
			assigned_count += 1
	assert_that(assigned_count).is_equal(2)
	assert_that(_Assignment.rebalance(city)).is_equal(0)

func test_assignment_never_overfills() -> void:
	var d: Variant = _chain_def(&"mine_a", 4)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_that(bld).is_not_null()
	for i in 3:
		city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_that(int(bld.assigned_workers)).is_equal(3)
	city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_that(int(bld.assigned_workers)).is_equal(4)
	city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_that(int(bld.assigned_workers)).is_equal(4)

func test_release_building_frees_workers() -> void:
	var d: Variant = _chain_def(&"mill_a", 2)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_that(bld).is_not_null()
	for i in 4:
		city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_that(int(bld.assigned_workers)).is_equal(2)
	var freed: int = _Assignment.release_building(city, bld.uid)
	assert_that(freed).is_equal(2)
	var free_workers := 0
	for u in city.pop:
		if u.state == PopUnit.State.WORKER and u.assigned_to == -1:
			free_workers += 1
	assert_that(free_workers).is_equal(4)

func test_orphans_released_on_rebalance() -> void:
	var d: Variant = _chain_def(&"bakery_a", 1)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_that(bld).is_not_null()
	for i in 2:
		city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	city.pop[1].assigned_to = 999
	bld.assigned_workers = 0
	var n: int = _Assignment.rebalance(city)
	assert_bool(n >= 1).is_true()
	var orphan := 0
	for u in city.pop:
		if u.assigned_to == 999:
			orphan += 1
	assert_that(orphan).is_equal(0)

func test_building_def_applies_chain_upkeep_zone() -> void:
	var d: Variant = _chain_def(&"smithy_a", 2)
	d.default_upkeep[&"wood"] = 2.0
	d.default_zone = 2
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_that(bld).is_not_null()
	assert_that(bld.get_production_chain()).is_not_null()
	assert_bool(bld.get_production_chain() != d.production_chain).is_true()
	assert_that(int(bld.get_production_chain().required_workers)).is_equal(2)
	assert_bool(absf(float(bld.get_upkeep()[&"wood"]) - 2.0) < 0.001).is_true()
	assert_that(int(bld.zone_type)).is_equal(2)
	bld.get_production_chain().building_eff = 3.0
	assert_that(float(d.production_chain.building_eff)).is_equal(1.0)

func test_scholar_promotion() -> void:
	var b1: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 0))
	assert_that(b1).is_not_null()
	city.ensure_resource_ctx().add(&"scholar_points", 2.0)
	var reg := _Registry.new()
	var proc := _DemoProc.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [city]
	var report: Dictionary = proc.process(ctx)
	var city_report: Dictionary = (report.cities as Array)[0]
	assert_that(int(city_report.get("promoted", 0))).is_equal(2)
	assert_that(city.count_state(PopUnit.State.SCHOLAR)).is_equal(2)
	assert_bool(city.resource_ctx.amount(&"scholar_points") < 0.001).is_true()
	var report2: Dictionary = proc.process(ctx)
	var city_report2: Dictionary = (report2.cities as Array)[0]
	assert_that(int(city_report2.get("promoted", 0))).is_equal(0)

func test_scholar_promotion_needs_manor() -> void:
	city.ensure_resource_ctx().add(&"scholar_points", 3.0)
	var reg := _Registry.new()
	var proc := _DemoProc.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [city]
	var report: Dictionary = proc.process(ctx)
	var city_report: Dictionary = (report.cities as Array)[0]
	assert_that(int(city_report.get("promoted", 0))).is_equal(0)
	assert_that(city.count_state(PopUnit.State.SCHOLAR)).is_equal(0)
	assert_bool(city.resource_ctx.amount(&"scholar_points") > 2.0).is_true()

func test_scholar_promotion_respects_manor_slots() -> void:
	var b1: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 0))
	assert_that(b1).is_not_null()
	city.ensure_resource_ctx().add(&"scholar_points", 5.0)
	var reg := _Registry.new()
	var proc := _DemoProc.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [city]
	proc.process(ctx)
	assert_that(city.count_state(PopUnit.State.SCHOLAR)).is_equal(2)
	assert_bool(city.resource_ctx.amount(&"scholar_points") > 2.0).is_true()
