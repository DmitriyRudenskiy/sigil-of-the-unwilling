extends "res://tests/gut_base.gd"
const TestFactories := preload("res://tests/helpers/test_factories.gd")
## Спринт 8: цепочки ресурсов + adjacency.
##
## - городские ресурсы в реестре (ёмкость амбара);
## - цепочки зданий BuildingDefs (ферма->мельница->пекарня и т.д.);
## - экономика считает назначенных рабочих (WorkerAssignment);
## - adjacency-бонусы (AdjacencySystem) в выходы и репутацию.

func _add_workers(city: City, n: int) -> void:
	for i in n:
		var u: RefCounted = city.add_migrant(PopUnit.State.WORKER)

## Клетка, соседняя хотя бы с одной из `targets`, свободная и достроенная.
func _cell_adjacent_to(city: City, targets: Array, avoid: Array) -> Vector2i:
	for t in targets:
		for bit in 6:
			var c: Vector2i = HexUtils.get_neighbor(t as Vector2i, bit)
			if c == city.center:
				continue
			if avoid.has(c) or city.cell_is_built(c):
				continue
			var check: Dictionary = city.can_build_building(BuildingDefs.farm(), c)
			if check.ok:
				return c
	return Vector2i(-10, -10)

func _run_economy(city: City) -> Dictionary:
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var p := EconomicTurnProcessor.new()
	return p.process(ctx)

# ==================== РЕЕСТР ====================

func test_registry_city_resources() -> void:
	var reg: Node = ResourceRegistry.new()
	reg.ensure_definitions()
	var grain: ResourceDef = reg.get_resource(&"grain")
	assert_not_null(grain, "grain в реестре")
	assert_eq(grain.capacity, 20.0, "ёмкость амбара зерна")
	assert_eq(grain.biomes.size(), 0, "не спавнится на карте")
	assert_not_null(reg.get_resource(&"scholar_points"), "scholar_points")
	# Жилы не задеты.
	var oak: ResourceDef = reg.get_resource(&"oak")
	assert_not_null(oak, "oak остался")
	assert_true(oak.biomes.size() > 0, "у дуба есть биомы")
	reg.free()

# ==================== ОПРЕДЕЛЕНИЯ ЦЕПОЧЕК ====================

func test_chain_defs_resolve() -> void:
	var cases: Array = [
		[&"farm", 2], [&"mill", 1], [&"bakery", 1], [&"mine", 2],
		[&"smithy", 1], [&"school", 1], [&"tavern", 1], [&"trade_post", 2],
	]
	for c in cases:
		var d: Variant = BuildingDefs.def_by_id(c[0])
		assert_not_null(d, "%s: def" % c[0])
		assert_true(d.production_chain != null, "%s: chain" % c[0])
		assert_eq(d.production_chain.required_workers, c[1], "%s: workers" % c[0])
		assert_true(d.production_chain.outputs.size() > 0, "%s: outputs" % c[0])

func test_chain_def_isolated_copy() -> void:
	var city := TestFactories.make_city()
	var b1: Variant = city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 0))
	var b2: Variant = city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 1))
	assert_not_null(b1, "farm1")
	assert_not_null(b2, "farm2")
	assert_true(b1.production_chain != b2.production_chain, "per-building копии цепочек")
	b1.production_chain.building_eff = 2.0
	assert_eq(b2.production_chain.building_eff, 1.0, "эффективность изолирована")

# ==================== ПРОИЗВОДСТВО ====================

func test_farm_produces_grain() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 0))
	_add_workers(city, 2)
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	assert_eq(city.resource_ctx.amount(&"grain"), 3.0, "зерно +3")

func test_mill_shortage_no_grain() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.mill(), HexUtils.get_neighbor(city.center, 0))
	_add_workers(city, 1)
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	assert_eq(city.resource_ctx.amount(&"flour"), 0.0, "муки нет (нет зерна)")

func test_full_bread_chain() -> void:
	var city := TestFactories.make_city()
	var farm_cell: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var mill_cell: Vector2i = HexUtils.get_neighbor(city.center, 1)
	var bakery_cell: Vector2i = _cell_adjacent_to(city, [mill_cell], [farm_cell, mill_cell])
	city.build_building(BuildingDefs.farm(), farm_cell)
	city.build_building(BuildingDefs.mill(), mill_cell)
	var bakery: Variant = city.build_building(BuildingDefs.bakery(), bakery_cell)
	_add_workers(city, 4)  # 2 + 1 + 1
	WorkerAssignment.assign_all(city)
	_run_economy(city)
	# Ферма: зерно +3; мельница: зерно -2 -> мука +2; пекарня: мука -2 -> хлеб +2
	# (хлеб × логистика пекарни — дистанция влияет на выход).
	assert_eq(city.resource_ctx.amount(&"grain"), 1.0, "зерно 3-2=1")
	assert_eq(city.resource_ctx.amount(&"flour"), 0.0, "мука 2-2=0")
	var expected_bread := 2.0 * city.get_logistics_multiplier(bakery_cell) \
		* (bakery as UniqueBuilding).zone_multiplier
	assert_true(absf(city.resource_ctx.amount(&"bread") - expected_bread) < 1e-9,
		"хлеб %f = 2 x логистика %f" % [city.resource_ctx.amount(&"bread"), expected_bread])

func test_unassigned_workers_produce_nothing() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.farm(), HexUtils.get_neighbor(city.center, 0))
	# Рабочих нет вовсе -> цепочка молчит.
	_run_economy(city)
	assert_eq(city.resource_ctx.amount(&"grain"), 0.0, "без рабочих нет зерна")
	# Рабочий есть, но не назначен (assigned_to == -1) -> тоже нет.
	var u: RefCounted = city.add_migrant(PopUnit.State.WORKER)
	_run_economy(city)
	assert_eq(city.resource_ctx.amount(&"grain"), 0.0, "неназначенный не работает")
	WorkerAssignment.assign_all(city)
	assert_eq((u as PopUnit).assigned_to, (city.buildings[0] as UniqueBuilding).uid,
		"назначен на ферму")
	_run_economy(city)
	assert_true(city.resource_ctx.amount(&"grain") > 0.0, "после назначения — зерно")

func test_upkeep_blocks_chain_resources() -> void:
	var city := TestFactories.make_city()
	city.build_building(BuildingDefs.mill(), HexUtils.get_neighbor(city.center, 0))
	_add_workers(city, 1)
	WorkerAssignment.assign_all(city)
	var res := city.ensure_resource_ctx()
	res.add(&"grain", 5.0)
	res.add(&"wood", 0.5)
	# Авто-дрова +2 дают 2.5 -> upkeep 1.0 оплачивается, цепочка работает.
	var report: Dictionary = _run_economy(city)
	assert_eq(int(report.get("upkeep_ok", -1)), 1, "upkeep оплачен (авто-дрова)")
	assert_eq(city.resource_ctx.amount(&"flour"), 2.0, "мука +2")

# ==================== ADJACENCY ====================

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
	# Мельница у 2 ферм: мука 2 * 1.5 = 3.
	assert_eq(city.resource_ctx.amount(&"flour"), 3.0, "мука x1.5 у двух ферм")

func test_adjacency_smithy_bonus() -> void:
	var city := TestFactories.make_city()
	var mine_cell: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var smithy_cell: Vector2i = _cell_adjacent_to(city, [mine_cell], [mine_cell])
	city.build_building(BuildingDefs.mine(), mine_cell)
	var smithy: Variant = city.build_building(BuildingDefs.smithy(), smithy_cell)
	_add_workers(city, 3)
	WorkerAssignment.assign_all(city)
	# Рудник: руда +2; кузница у рудника: инструменты 1 * 3 (adjacency)
	# * логистика (руды хватает, авто-дрова закрывают вход 1).
	_run_economy(city)
	var expected_tools := 3.0 * city.get_logistics_multiplier(smithy_cell) \
		* (smithy as UniqueBuilding).zone_multiplier
	assert_true(absf(city.resource_ctx.amount(&"tools") - expected_tools) < 1e-9,
		"инструменты x3 у рудника (получено %f, ждём %f)"
		% [city.resource_ctx.amount(&"tools"), expected_tools])
	assert_eq(city.resource_ctx.amount(&"ore"), 1.0, "руда 2-1=1")

func test_adjacency_reputation_bonus() -> void:
	var city := TestFactories.make_city()
	var shack_cell: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var temple_cell: Vector2i = _cell_adjacent_to(city, [shack_cell], [shack_cell])
	city.special_sites[temple_cell] = "temple"  # храм требует площадку
	city.build_building(BuildingDefs.shack(), shack_cell)
	city.build_building(BuildingDefs.great_temple(), temple_cell)
	var bonus: int = AdjacencySystem.reputation_bonus(city)
	assert_eq(bonus, 2, "храм у жилья +2")
	assert_eq(city.reputation + bonus, ReputationSystem.process_turn(city),
		"бонус входит в фактор хода")
	# Особняк у рудника: минус.
	var city2 := TestFactories.make_city(2)
	var mine_cell2: Vector2i = HexUtils.get_neighbor(city2.center, 0)
	var manor_cell2: Vector2i = _cell_adjacent_to(city2, [mine_cell2], [mine_cell2])
	city2.build_building(BuildingDefs.mine(), mine_cell2)
	city2.build_building(BuildingDefs.manor(), manor_cell2)
	assert_eq(AdjacencySystem.reputation_bonus(city2), -2, "особняк у рудника -2")

func test_adjacency_no_neighbors_no_bonus() -> void:
	var city := TestFactories.make_city()
	var mill: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var b: Variant = city.build_building(BuildingDefs.mill(), mill)
	assert_not_null(b, "мельница построена")
	assert_eq(AdjacencySystem.building_output_mult(city, b), 1.0, "без соседей x1.0")
