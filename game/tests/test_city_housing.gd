extends "res://tests/gut_base.gd"
## Спринт 7: жильё (хижина/особняк/казармы), назначение рабочих,
## повышение учёных.

const _City = preload("res://scripts/world/City.gd")
const _Defs = preload("res://scripts/data/BuildingDefs.gd")
const _Chain = preload("res://scripts/economy/ProductionChain.gd")
const _Assignment = preload("res://scripts/world/WorkerAssignment.gd")
const _DemoProc = preload("res://scripts/demographics/DemographicTurnProcessor.gd")
const _Registry = preload("res://scripts/demographics/CharacterRegistry.gd")

var city: Variant
var center := Vector2i(5, 5)


func before_each() -> void:
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
	assert_eq(city.housing_total(), 0)
	assert_eq(city.pop_cap(), CityBalance.POP_CAP_BY_STRONGHOLD[0])
	assert_eq(city.free_housing(PopUnit.State.WORKER), CityBalance.BASE_SETTLEMENT_HOUSING)
	assert_eq(city.free_housing(PopUnit.State.SCHOLAR), 0)
	assert_eq(city.immigrant_state(), PopUnit.State.WORKER)


func test_shack_extends_cap_and_housing() -> void:
	var cap_before: int = city.pop_cap()
	var shack_cell := HexUtils.get_neighbor(center, 0)
	var bld: Variant = city.build_building(_Defs.shack(), shack_cell)
	assert_not_null(bld)
	assert_eq(city.pop_cap(), cap_before + 10)
	assert_eq(city.housing_capacity(PopUnit.State.WORKER), 10)
	assert_eq(city.housing_total(), 10)
	# Базовые 10 + 10 от хижины.
	assert_eq(city.free_housing(PopUnit.State.WORKER), 10 + 10 - city.count_state(PopUnit.State.WORKER))


func test_manor_and_barracks_housing() -> void:
	var b1: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 1))
	assert_not_null(b1)
	var b2: Variant = city.build_building(_Defs.barracks(), HexUtils.get_neighbor(center, 3))
	assert_not_null(b2)
	assert_eq(city.housing_capacity(PopUnit.State.SCHOLAR), 2)
	assert_eq(city.housing_capacity(PopUnit.State.MILITIA), 5)


func test_immigrant_state_priority() -> void:
	# Жильё: 10 базовых + 5 казарм (ополченцы) + 2 особняка (учёные).
	var b1: Variant = city.build_building(_Defs.barracks(), HexUtils.get_neighbor(center, 0))
	var b2: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 2))
	assert_not_null(b1)
	assert_not_null(b2)
	# Свободно всё -> рабочий.
	assert_eq(city.immigrant_state(), PopUnit.State.WORKER)
	# Заполняем рабочих (10 базовых).
	for i in 10:
		city.add_migrant(PopUnit.State.WORKER)
	assert_eq(city.immigrant_state(), PopUnit.State.MILITIA)
	# Заполняем ополчение (5).
	for i in 5:
		city.add_migrant(PopUnit.State.MILITIA)
	assert_eq(city.immigrant_state(), PopUnit.State.SCHOLAR)
	# Заполняем учёных (2).
	for i in 2:
		city.add_migrant(PopUnit.State.SCHOLAR)
	assert_eq(city.immigrant_state(), -1, "жилья нет -> иммиграция закрыта")


func test_assignment_fills_buildings() -> void:
	var d: Variant = _chain_def(&"farm_a", 2)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_not_null(bld)
	# 12 рабочих; здание просит 2.
	for i in 12:
		city.add_migrant(PopUnit.State.WORKER)
	var n: int = _Assignment.rebalance(city)
	assert_eq(n, 2)
	assert_eq(int(bld.assigned_workers), 2)
	var assigned_count := 0
	for u in city.pop:
		if u.assigned_to == bld.uid:
			assigned_count += 1
	assert_eq(assigned_count, 2)
	# Повторный ребаланс ничего не меняет.
	assert_eq(_Assignment.rebalance(city), 0)


func test_assignment_never_overfills() -> void:
	var d: Variant = _chain_def(&"mine_a", 4)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_not_null(bld)
	for i in 3:
		city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_eq(int(bld.assigned_workers), 3)
	# Пришёл ещё один рабочий — добираем.
	city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_eq(int(bld.assigned_workers), 4)
	# И ещё — лишнего не назначаем.
	city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_eq(int(bld.assigned_workers), 4)


func test_release_building_frees_workers() -> void:
	var d: Variant = _chain_def(&"mill_a", 2)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_not_null(bld)
	for i in 4:
		city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	assert_eq(int(bld.assigned_workers), 2)
	var freed: int = _Assignment.release_building(city, bld.uid)
	assert_eq(freed, 2)
	var free_workers := 0
	for u in city.pop:
		if u.state == PopUnit.State.WORKER and u.assigned_to == -1:
			free_workers += 1
	assert_eq(free_workers, 4)


func test_orphans_released_on_rebalance() -> void:
	var d: Variant = _chain_def(&"bakery_a", 1)
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_not_null(bld)
	for i in 2:
		city.add_migrant(PopUnit.State.WORKER)
	_Assignment.rebalance(city)
	# Ломаем ссылку (симуляция снесённого здания).
	city.pop[1].assigned_to = 999
	bld.assigned_workers = 0
	var n: int = _Assignment.rebalance(city)
	assert_true(n >= 1, "сломанный рабочий вернулся в строй: %d" % n)
	var orphan := 0
	for u in city.pop:
		if u.assigned_to == 999:
			orphan += 1
	assert_eq(orphan, 0)


func test_building_def_applies_chain_upkeep_zone() -> void:
	var d: Variant = _chain_def(&"smithy_a", 2)
	d.default_upkeep[&"wood"] = 2.0
	d.default_zone = 2
	var bld: Variant = city.build_building(d, HexUtils.get_neighbor(center, 0))
	assert_not_null(bld)
	assert_not_null(bld.get_production_chain())
	assert_true(bld.get_production_chain() != d.production_chain, "копия цепочки, а не общий объект")
	assert_eq(int(bld.get_production_chain().required_workers), 2)
	assert_true(absf(float(bld.get_upkeep()[&"wood"]) - 2.0) < 0.001)
	assert_eq(int(bld.zone_type), 2)
	# Per-building building_eff: изменение копии не трогает определение.
	bld.get_production_chain().building_eff = 3.0
	assert_eq(float(d.production_chain.building_eff), 1.0)


func test_scholar_promotion() -> void:
	var b1: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 0))
	assert_not_null(b1)
	city.ensure_resource_ctx().add(&"scholar_points", 2.0)
	var reg := _Registry.new()
	var proc := _DemoProc.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [city]
	var report: Dictionary = proc.process(ctx)
	var city_report: Dictionary = (report.cities as Array)[0]
	assert_eq(int(city_report.get("promoted", 0)), 2, "два балла -> два учёных")
	assert_eq(city.count_state(PopUnit.State.SCHOLAR), 2)
	assert_true(city.resource_ctx.amount(&"scholar_points") < 0.001, "баллы списаны")
	# Следующий ход: баллов нет -> некого повышать.
	var report2: Dictionary = proc.process(ctx)
	var city_report2: Dictionary = (report2.cities as Array)[0]
	assert_eq(int(city_report2.get("promoted", 0)), 0)


func test_scholar_promotion_needs_manor() -> void:
	# Особняка нет — баллы копятся.
	city.ensure_resource_ctx().add(&"scholar_points", 3.0)
	var reg := _Registry.new()
	var proc := _DemoProc.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [city]
	var report: Dictionary = proc.process(ctx)
	var city_report: Dictionary = (report.cities as Array)[0]
	assert_eq(int(city_report.get("promoted", 0)), 0)
	assert_eq(city.count_state(PopUnit.State.SCHOLAR), 0)
	assert_true(city.resource_ctx.amount(&"scholar_points") > 2.0, "баллы сохранены: %f" % city.resource_ctx.amount(&"scholar_points"))


func test_scholar_promotion_respects_manor_slots() -> void:
	var b1: Variant = city.build_building(_Defs.manor(), HexUtils.get_neighbor(center, 0))
	assert_not_null(b1)  # 2 слота
	city.ensure_resource_ctx().add(&"scholar_points", 5.0)
	var reg := _Registry.new()
	var proc := _DemoProc.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [city]
	proc.process(ctx)
	assert_eq(city.count_state(PopUnit.State.SCHOLAR), 2, "лимит — 2 слота особняка")
	assert_true(city.resource_ctx.amount(&"scholar_points") > 2.0, "лишние баллы сохранены")
