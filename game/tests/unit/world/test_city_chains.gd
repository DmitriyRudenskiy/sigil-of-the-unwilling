extends GdUnitTestSuite
const TestFactories := preload("res://tests/helpers/factories.gd")

func _add_workers(city: City, n: int) -> void:
	for i in n:
		var u: RefCounted = city.add_migrant(PopUnit.State.WORKER)

func _cell_adjacent_to(city: City, targets: Array, avoid: Array) -> Vector2i:
	for t in targets:
		for bit in 6:
			var c: Vector2i = HexUtils.get_neighbor(t as Vector2i, bit)
			if c == city.center:
				continue
			if avoid.has(c) or city.cell_is_built(c):
				continue
			var check: CityCheck = city.can_build_building(BuildingDefs.farm(), c)
			if check.ok:
				return c
	return Vector2i(-10, -10)

func _run_economy(city: City) -> Dictionary:
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var p := EconomicTurnProcessor.new()
	return p.process(ctx)


func test_registry_city_resources() -> void:
	var reg: Node = ResourceRegistry.new()
	reg.ensure_definitions()
	var grain: ResourceDef = reg.get_resource(&"grain")
	assert_that(grain).is_not_null()
	assert_that(grain.capacity).is_equal(20.0)
	assert_that(grain.biomes.size()).is_equal(0)
	assert_that(reg.get_resource(&"scholar_points")).is_not_null()
	var oak: ResourceDef = reg.get_resource(&"oak")
	assert_that(oak).is_not_null()
	assert_bool(oak.biomes.size() > 0).is_true()
	reg.free()


func test_chain_defs_resolve() -> void:
	var cases: Array = [
		[&"farm", 2], [&"mill", 1], [&"bakery", 1], [&"mine", 2],
		[&"smithy", 1], [&"school", 1], [&"tavern", 1], [&"trade_post", 2],
	]
	for c in cases:
		var d: Variant = BuildingDefs.def_by_id(c[0])
		assert_that(d).is_not_null()
		assert_bool(d.production_chain != null).is_true()
		assert_that(d.production_chain.required_workers).is_equal(c[1])
		assert_bool(d.production_chain.outputs.size() > 0).is_true()

func test_chain_def_isolated_copy() -> void:
	var city := TestFactories.make_city()
	var b1: Variant = city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 0))
	var b2: Variant = city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 1))
	assert_that(b1).is_not_null()
	assert_that(b2).is_not_null()
	assert_bool(b1.production_chain != b2.production_chain).is_true()
	b1.production_chain.building_eff = 2.0
	assert_that(b2.production_chain.building_eff).is_equal(1.0)


func test_farm_produces_grain() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 0))
	_add_workers(city, 2)
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	assert_that(city.resource_ctx.amount(&"grain")).is_equal(3.0)

func test_mill_shortage_no_grain() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.mill(), HexUtils.get_neighbor(city.center, 0))
	_add_workers(city, 1)
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	assert_that(city.resource_ctx.amount(&"flour")).is_equal(0.0)

func test_full_bread_chain() -> void:
	var city := TestFactories.make_city()
	var farm_cell: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var mill_cell: Vector2i = HexUtils.get_neighbor(city.center, 1)
	var bakery_cell: Vector2i = _cell_adjacent_to(city, [mill_cell], [farm_cell, mill_cell])
	city.build_building(BuildingDefs.farm(), farm_cell)
	city.build_building(BuildingDefs.mill(), mill_cell)
	var bakery: Variant = city.build_building(BuildingDefs.bakery(), bakery_cell)
	_add_workers(city, 4)  
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	assert_that(city.resource_ctx.amount(&"grain")).is_equal(1.0)
	assert_that(city.resource_ctx.amount(&"flour")).is_equal(0.0)
	var expected_bread := 2.0 * city.get_logistics_multiplier(bakery_cell) \
		* (bakery as UniqueBuilding).zone_multiplier
	assert_bool(absf(city.resource_ctx.amount(&"bread") - expected_bread) < 1e-9).is_true()

func test_unassigned_workers_produce_nothing() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 0))
	_run_economy(city)
	assert_that(city.resource_ctx.amount(&"grain")).is_equal(0.0)
	var u: RefCounted = city.add_migrant(PopUnit.State.WORKER)
	_run_economy(city)
	assert_that(city.resource_ctx.amount(&"grain")).is_equal(0.0)
	WorkerAssignment.assign_all(city)
	assert_that((u as PopUnit).assigned_to).is_equal((city.buildings[0] as UniqueBuilding).uid)
	_run_economy(city)
	assert_bool(city.resource_ctx.amount(&"grain") > 0.0).is_true()

func test_upkeep_blocks_chain_resources() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.mill(), HexUtils.get_neighbor(city.center, 0))
	_add_workers(city, 1)
	WorkerAssignment.assign_all(city)
	var res := city.ensure_resource_ctx()
	res.add(&"grain", 5.0)
	res.add(&"wood", 0.5)
	var report: Dictionary = _run_economy(city)
	assert_that(int(report.get("upkeep_ok", -1))).is_equal(1)
	assert_that(city.resource_ctx.amount(&"flour")).is_equal(2.0)


func test_adjacency_mill_bonus() -> void:
	var city := TestFactories.make_city()
	var farm1: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var mill: Vector2i = HexUtils.get_neighbor(city.center, 1)
	var farm2: Vector2i = _cell_adjacent_to(city, [mill], [farm1, mill])
	city.build_building(BuildingDefs.farm(), farm1)
	city.build_building(BuildingDefs.mill(), mill)
	city.build_building(BuildingDefs.farm(), farm2)
	_add_workers(city, 4)
	WorkerAssignment.assign_all(city)
	city.ensure_resource_ctx().add(&"grain", 10.0)
	_run_economy(city)
	assert_that(city.resource_ctx.amount(&"flour")).is_equal(3.0)

func test_adjacency_smithy_bonus() -> void:
	var city := TestFactories.make_city()
	var mine_cell: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var smithy_cell: Vector2i = _cell_adjacent_to(city, [mine_cell], [mine_cell])
	city.build_building(BuildingDefs.mine(), mine_cell)
	var smithy: Variant = city.build_building(BuildingDefs.smithy(), smithy_cell)
	_add_workers(city, 3)
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	var expected_tools := 3.0 * city.get_logistics_multiplier(smithy_cell) \
		* (smithy as UniqueBuilding).zone_multiplier
	assert_bool(absf(city.resource_ctx.amount(&"tools") - expected_tools) < 1e-9).is_true()
	assert_that(city.resource_ctx.amount(&"ore")).is_equal(1.0)

func test_adjacency_reputation_bonus() -> void:
	var city := TestFactories.make_city()
	var shack_cell: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var temple_cell: Vector2i = _cell_adjacent_to(city, [shack_cell], [shack_cell])
	city.special_sites[temple_cell] = "temple"  
	city.build_building(BuildingDefs.shack(), shack_cell)
	city.build_building(BuildingDefs.great_temple(), temple_cell)
	
	
	
	
	
	var bonus: int = AdjacencySystem.reputation_bonus(city)
	var rep_before := city.reputation
	ReputationSystem.process_turn(city)
	assert_that(bonus).is_equal(2)
	assert_that(city.reputation - rep_before).is_equal(bonus)
	var city2 := TestFactories.make_city(2)
	var mine_cell2: Vector2i = HexUtils.get_neighbor(city2.center, 0)
	var manor_cell2: Vector2i = _cell_adjacent_to(city2, [mine_cell2], [mine_cell2])
	city2.build_building(BuildingDefs.mine(), mine_cell2)
	city2.build_building(BuildingDefs.manor(), manor_cell2)
	assert_that(AdjacencySystem.reputation_bonus(city2)).is_equal(-2)

func test_adjacency_no_neighbors_no_bonus() -> void:
	var city := TestFactories.make_city()
	var mill: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var b: Variant = city.build_building(BuildingDefs.mill(), mill)
	assert_that(b).is_not_null()
	assert_that(AdjacencySystem.building_output_mult(city, b)).is_equal(1.0)
