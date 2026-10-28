extends BaseTest

## Тесты носителя `scripts/world/city.gd` — ядро города (население, постройки,
## урожай, хранилище, состояние). Файл = носитель, а не тикет (T-227 С-3): раньше
## задачи «прирастали файлом», и под одним носителем лежало 17 тест-файлов, из-за
## чего новый тест города не имел дома. Сюда влиты `test_city_systems.gd` и
## `test_city_chains.gd` (2026-10-27) — секции помечены; хелперы и тела перенесены
## без правок, единственное изменение — общий `preload` фабрик.
##
## Что осталось отдельными файлами сознательно: у `test_city_housing.gd` свой
## `before_test` (другая фикстура города), у `test_city_processor.gd`/
## `test_city_reputation.gd` носитель — `city_turn_processor.gd`, у
## `test_city_arena.gd` — `city_check.gd`, у `test_smoldering_city.gd` —
## `settlement/SmolderingCity.gd` (в группу city.gd их попадал приписывает эвристика
## имени, а не проверяемый код).
const TestFactories := preload("res://tests/helpers/factories.gd")







var city: City

func before_test() -> void:
	city = City.new()
	city.display_name = "Тест-город"
	city.center = Vector2i(5, 5)

func _food_yield(_cell: Vector2i) -> Dictionary:
	return {&"food": 100.0, &"industry": 10.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}

func test_pop_total_initially_zero() -> void:
	assert_that(city.pop_total()).is_equal(0)

func test_add_followers() -> void:
	var overflow := city.add_followers(5)
	assert_that(city.pop_total()).is_equal(5)
	assert_that(overflow).is_equal(0)

func test_add_followers_overflow() -> void:
	city.add_followers(15)
	var overflow := city.over_limit()
	assert_that(overflow).is_equal(5)

func test_pop_cap_level_1() -> void:
	assert_that(city.pop_cap()).is_equal(10)

func test_pop_cap_level_2() -> void:
	city.stronghold_level = 2
	assert_that(city.pop_cap()).is_equal(20)

func test_pop_cap_level_3() -> void:
	city.stronghold_level = 3
	assert_that(city.pop_cap()).is_equal(35)

func test_count_state() -> void:
	city.add_followers(3)
	assert_that(city.count_state(PopUnit.State.FOLLOWER)).is_equal(3)
	assert_that(city.count_state(PopUnit.State.WORKER)).is_equal(0)

func test_free_followers() -> void:
	city.add_followers(5)
	assert_that(city.free_followers()).is_equal(5)

func test_find_pop() -> void:
	city.add_followers(1)
	var uid: int = city.pop[0].uid
	var found := city.find_pop(uid)
	assert_that(found).is_not_null()
	assert_that(found.uid).is_equal(uid)

func test_find_pop_not_found() -> void:
	var found := city.find_pop(999)
	assert_that(found).is_null()

func test_can_build_borough_center_rejected() -> void:
	var check := city.can_build_borough(city.center)
	assert_bool(check.ok).is_false()

func test_can_build_borough_adjacent_ok() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var check := city.can_build_borough(nb)
	assert_bool(check.ok).is_true()

func test_build_borough() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var result := city.build_borough(nb)
	assert_bool(result).is_true()
	assert_that(city.boroughs.size()).is_equal(1)

func test_build_borough_costs_industry() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	city.build_borough(nb)
	assert_bool(city.storage[&"industry"] < 100.0).is_true()

func test_borough_level_initial() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	city.build_borough(nb)
	assert_that(city.boroughs[0].level).is_equal(1)

func test_can_build_building() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var check := city.can_build_building(BuildingDefs.market(), nb)
	assert_bool(check.ok).is_true()

func test_build_building() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var bld := city.build_building(BuildingDefs.market(), nb)
	assert_that(bld).is_not_null()
	assert_that(bld.level).is_equal(1)

func test_building_requires_site() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var check := city.can_build_building(BuildingDefs.great_temple(), nb)
	assert_bool(check.ok).is_false()

func test_building_with_site() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	# Ранняя игра: дымовая — Великий храм требует город 9 уровня (early-game-foundation)
	city.level = 9
	var site_cell := HexUtils.get_all_neighbors(city.center)[0]
	city.special_sites[site_cell] = BuildingDefs.SITE_SHRINE
	var check := city.can_build_building(BuildingDefs.great_temple(), site_cell)
	assert_bool(check.ok).is_true()

func test_get_yield_empty_city() -> void:
	city.tile_yield_fn = _food_yield
	var y := city.get_yield()
	assert_that(y[&"food"]).is_equal(0.0)

func test_food_consumption() -> void:
	city.add_followers(1)
	var u: PopUnit = city.pop[0]
	city.request_switch(u.uid, PopUnit.State.WORKER, city.first_free_worker_tile())
	city.process_turn(1)
	var consumption := city.food_consumption()
	assert_bool(consumption > 0.0).is_true()

func test_net_food_negative_without_workers() -> void:
	city.tile_yield_fn = _food_yield
	city.add_followers(2)
	for u in city.pop:
		u.request_switch(PopUnit.State.MILITIA)
	city.process_turn(1)
	var nf := city.net_food()
	assert_bool(nf < 0.0).is_true()

func test_growth_threshold() -> void:
	city.add_followers(2)
	var threshold := city.growth_threshold()
	assert_bool(threshold > 0.0).is_true()

func test_approval_no_boroughs() -> void:
	assert_that(city.approval()).is_equal(0)

func test_approval_starving_penalty() -> void:
	city.starving = true
	var approval := city.approval()
	assert_bool(approval < 0).is_true()

func test_process_turn_returns_report() -> void:
	city.tile_yield_fn = _food_yield
	city.add_followers(2)
	var report := city.process_turn(1)
	assert_bool(report.has("births")).is_true()
	assert_bool(report.has("level_ups")).is_true()
	assert_bool(report.has("starving")).is_true()
	assert_bool(report.has("net_food")).is_true()
	assert_bool(report.has("switched")).is_true()

func test_process_turn_births() -> void:
	city.tile_yield_fn = _food_yield
	city.add_followers(2)
	var report := city.process_turn(1)
	assert_bool(report.births >= 0).is_true()

func test_cell_is_built_center() -> void:
	assert_bool(city.cell_is_built(city.center)).is_true()

func test_cell_is_built_empty() -> void:
	var empty := Vector2i(10, 10)
	assert_bool(city.cell_is_built(empty)).is_false()

func test_is_worker_tile_free() -> void:
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	assert_bool(city.is_worker_tile_free(nb)).is_true()

func test_is_worker_tile_free_center() -> void:
	assert_bool(city.is_worker_tile_free(city.center)).is_false()

func test_first_free_worker_tile() -> void:
	var tile := city.first_free_worker_tile()
	assert_bool(tile.x >= 0).is_true()

func test_city_display_name() -> void:
	assert_that(city.display_name).is_equal("Тест-город")

func test_city_center() -> void:
	assert_that(city.center).is_equal(Vector2i(5, 5))

func test_city_faction_default() -> void:
	assert_that(city.faction).is_equal(City.Faction.DEFAULT)

func test_city_is_capital() -> void:
	assert_bool(city.is_capital).is_false()
	city.is_capital = true
	assert_bool(city.is_capital).is_true()

# --- влито из test_city_systems.gd: городские системы (урожай, рабочие, соседство клеток) ──

func _cell_at_distance(city: City, d: int) -> Vector2i:
	if d <= 0:
		return city.center
	var frontier: Array = [city.center]
	var seen: Dictionary = {city.center: true}
	for _i in 200:
		var next: Array = []
		for cell in frontier:
			for nb in HexUtils.get_all_neighbors(cell):
				if seen.has(nb):
					continue
				seen[nb] = true
				if HexUtils.hex_distance(nb, city.center) == d:
					return nb
				next.append(nb)
		frontier = next
	return Vector2i(-1, -1)

func _neighbor_of(a: Vector2i, exclude: Vector2i) -> Vector2i:
	for nb in HexUtils.get_all_neighbors(a):
		if nb != exclude:
			return nb
	return Vector2i(-1, -1)

func _add_building(city: City, cell: Vector2i, zone: int) -> UniqueBuilding:
	var b := UniqueBuilding.new()
	b.uid = city.buildings.size() + 1
	b.cell = cell
	b.level = 1
	b.zone_type = zone
	city.buildings.append(b)
	return b

func test_logistics_adjacent_full() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 1)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9).is_true()

func test_logistics_distance_falloff() -> void:
	var city := TestFactories.make_city()
	assert_bool(absf(city.get_logistics_multiplier(_cell_at_distance(city, 2)) - 0.85) < 1e-9).is_true()
	assert_bool(absf(city.get_logistics_multiplier(_cell_at_distance(city, 3)) - 0.7) < 1e-9).is_true()
	assert_bool(absf(city.get_logistics_multiplier(_cell_at_distance(city, 5)) - 0.4) < 1e-9).is_true()

func test_logistics_min_clamp() -> void:
	var city := TestFactories.make_city()
	var m: float = city.get_logistics_multiplier(_cell_at_distance(city, 10))
	assert_that(m).is_equal(GameNumbers.LOGISTICS_MIN_MULT)

func test_logistics_borough_shortens_distance() -> void:
	var city := TestFactories.make_city()
	var far: Vector2i = _cell_at_distance(city, 4)
	var b := Borough.new()
	b.cell = far
	b.level = 1
	b.uid = 900
	city.boroughs.append(b)
	var nb: Vector2i = _cell_at_distance_from(far, city, 1)
	assert_that(HexUtils.hex_distance(nb, city.center) > 1).is_equal(true)
	assert_bool(absf(city.get_logistics_multiplier(nb) - 1.0) < 1e-9).is_true()

func _cell_at_distance_from(from: Vector2i, _city: City, d: int) -> Vector2i:
	var frontier: Array = [from]
	var seen: Dictionary = {from: true}
	for _i in 200:
		var next: Array = []
		for cell in frontier:
			for nb in HexUtils.get_all_neighbors(cell):
				if seen.has(nb):
					continue
				seen[nb] = true
				if HexUtils.hex_distance(nb, from) == d:
					return nb
				next.append(nb)
		frontier = next
	return Vector2i(-1, -1)

func test_logistics_road_on_cell() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	city.add_road(cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9).is_true()

func test_logistics_road_adjacent() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	var road_cell: Vector2i = _cell_at_distance_from(cell, city, 1)
	city.add_road(road_cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9).is_true()

func test_logistics_road_cap() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 1)
	city.add_road(cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.15) < 1e-9).is_true()

func test_logistics_road_removed() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	city.add_road(cell)
	city.remove_road(cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 0.85) < 1e-9).is_true()

func test_zone_can_place_rules() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	var d2: Vector2i = _cell_at_distance(city, 2)
	assert_bool(ZoningSystem.can_place(city, city.center, ZoningSystem.ZoneType.NONE).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, city.center, ZoningSystem.ZoneType.RESIDENTIAL).ok).is_false()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.RESIDENTIAL).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.COMMERCIAL).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.INDUSTRIAL).ok).is_false()
	assert_bool(ZoningSystem.can_place(city, d2, ZoningSystem.ZoneType.INDUSTRIAL).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.SPECIAL).ok).is_false()
	city.special_sites[adj] = &"ruins"
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.SPECIAL).ok).is_true()

func test_zone_multiplier_isolated() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	_add_building(city, adj, ZoningSystem.ZoneType.RESIDENTIAL)
	assert_bool(absf(ZoningSystem.zone_multiplier(city, adj, ZoningSystem.ZoneType.RESIDENTIAL) - 1.0) < 1e-9).is_true()

func test_zone_agglomeration_bonus() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	assert_bool(b1 != b2).is_true()
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)
	assert_that(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL)).is_equal(1.0 + GameNumbers.ZONE_AGGLOMERATION_BONUS)
	var c: Vector2i = _cell_at_distance(city, 4)
	var d: Vector2i = _neighbor_of(c, city.center)
	_add_building(city, c, ZoningSystem.ZoneType.RESIDENTIAL)
	_add_building(city, d, ZoningSystem.ZoneType.RESIDENTIAL)
	assert_that(ZoningSystem.adjacent_same_zone_count(city, d, ZoningSystem.ZoneType.RESIDENTIAL)).is_equal(1)
	assert_that(ZoningSystem.zone_multiplier(city, d, ZoningSystem.ZoneType.RESIDENTIAL)).is_equal(1.0)

func test_zone_commercial_near_residential() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 1)
	var b: Vector2i = _cell_at_distance_from(a, city, 1)
	_add_building(city, a, ZoningSystem.ZoneType.RESIDENTIAL)
	var c := _add_building(city, b, ZoningSystem.ZoneType.COMMERCIAL)
	assert_that(c.zone_type).is_equal(ZoningSystem.ZoneType.COMMERCIAL)
	assert_that(ZoningSystem.zone_multiplier(city, b, ZoningSystem.ZoneType.COMMERCIAL)).is_equal(1.0 + GameNumbers.ZONE_COMMERCIAL_MARKET)

func test_zone_industrial_road_bonus() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	var road_cell: Vector2i = _cell_at_distance_from(a, city, 1)
	city.add_road(road_cell)
	assert_that(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL)).is_equal(1.0 + GameNumbers.ZONE_INDUSTRIAL_ROAD)

func test_zone_combined_bonuses() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)
	var r := Vector2i(-1, -1)
	for nb in HexUtils.get_all_neighbors(a):
		if nb != b1 and nb != b2:
			r = nb
			break
	assert_bool(r != Vector2i(-1, -1)).is_true()
	city.add_road(r)
	assert_that(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL)).is_equal(1.0 + GameNumbers.ZONE_AGGLOMERATION_BONUS + GameNumbers.ZONE_INDUSTRIAL_ROAD)

func test_scale_tiers_by_population() -> void:
	assert_that(ScaleShiftManager.tier_for(0)).is_equal(0)
	assert_that(ScaleShiftManager.tier_for(4)).is_equal(0)
	assert_that(ScaleShiftManager.tier_for(5)).is_equal(1)
	assert_that(ScaleShiftManager.tier_for(14)).is_equal(1)
	assert_that(ScaleShiftManager.tier_for(15)).is_equal(2)
	assert_that(ScaleShiftManager.tier_for(29)).is_equal(2)
	assert_that(ScaleShiftManager.tier_for(30)).is_equal(3)
	assert_that(ScaleShiftManager.tier_for(35)).is_equal(3)

func test_scale_tier_names() -> void:
	assert_that(ScaleShiftManager.tier_name(0)).is_equal("Селение")
	assert_that(ScaleShiftManager.tier_name(1)).is_equal("Деревня")
	assert_that(ScaleShiftManager.tier_name(2)).is_equal("Город")
	assert_that(ScaleShiftManager.tier_name(3)).is_equal("Метрополия")
	assert_that(ScaleShiftManager.tier_name(99)).is_equal("Метрополия")

func test_scale_multipliers() -> void:
	assert_that(ScaleShiftManager.storage_multiplier(0)).is_equal(1.0)
	assert_that(ScaleShiftManager.storage_multiplier(1)).is_equal(1.25)
	assert_that(ScaleShiftManager.storage_multiplier(2)).is_equal(1.5)
	assert_that(ScaleShiftManager.storage_multiplier(3)).is_equal(2.0)
	assert_that(ScaleShiftManager.auto_resource_multiplier(1)).is_equal(1.1)
	assert_that(ScaleShiftManager.auto_resource_multiplier(3)).is_equal(1.4)
	assert_that(ScaleShiftManager.upkeep_multiplier(2)).is_equal(0.9)
	assert_that(ScaleShiftManager.upkeep_multiplier(3)).is_equal(0.85)
	assert_that(ScaleShiftManager.storage_multiplier(99)).is_equal(2.0)

func test_road_add_remove_signal() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	var changes: Array = []
	city.buildings_changed.connect(func(): changes.append(1))
	assert_bool(city.has_road(adj)).is_false()
	city.add_road(adj)
	assert_bool(city.has_road(adj)).is_true()
	city.add_road(adj)
	assert_that(changes.size()).is_equal(1)
	city.remove_road(adj)
	assert_bool(city.has_road(adj)).is_false()
	assert_that(changes.size()).is_equal(2)
	city.remove_road(adj)
	assert_that(changes.size()).is_equal(2)


# --- влито из test_city_chains.gd: цепочки производства и реестр ресурсов города ──

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
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city.level = 11
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
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city.level = 11
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
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city.level = 11
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
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city.level = 11
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
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city.level = 11
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
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city2.level = 11
	var mine_cell2: Vector2i = HexUtils.get_neighbor(city2.center, 0)
	var manor_cell2: Vector2i = _cell_adjacent_to(city2, [mine_cell2], [mine_cell2])
	city2.build_building(BuildingDefs.mine(), mine_cell2)
	city2.build_building(BuildingDefs.manor(), manor_cell2)
	assert_that(AdjacencySystem.reputation_bonus(city2)).is_equal(-2)

func test_adjacency_no_neighbors_no_bonus() -> void:
	var city := TestFactories.make_city()
	# Ранняя игра: дымовая — здание требует уровень (early-game-foundation)
	city.level = 11
	var mill: Vector2i = HexUtils.get_neighbor(city.center, 0)
	var b: Variant = city.build_building(BuildingDefs.mill(), mill)
	assert_that(b).is_not_null()
	assert_that(AdjacencySystem.building_output_mult(city, b)).is_equal(1.0)

# --- влито из test_city_housing.gd: жильё, вместимость, расселение ────────────────────

## Фикстура секции жилья (перенесена из `before_test` снятого
## `test_city_housing.gd`): город 11 уровня, 10 последователей, 200 industry.
## Вызывается из каждого теста явно: два разных `before_test` в одном классе
## не уживаются, а молча делить один — значило бы менять смысл 13 тестов.
func _housing_city() -> City:
	var hcity := City.new()
	hcity.uid = 7
	hcity.center = Vector2i(5, 5)
	hcity.stronghold_level = 1
	# Ранняя игра: дымовая — особняк требует уровень (early-game-foundation)
	hcity.level = 11
	hcity.add_followers(10)
	hcity.storage[&"industry"] = 200.0
	return hcity

func _chain_def(id: StringName, workers: int) -> Variant:
	var d := UniqueBuilding.Def.new()
	d.id = id
	d.display_name = String(id)
	var req := UniqueBuilding.LevelReq.new()
	req.industry = 10.0
	d.levels = [req]
	var c := ProductionChain.new()
	c.id = id + "_chain"
	c.required_workers = workers
	c.outputs[&"grain"] = 2.0
	d.production_chain = c
	return d

func test_no_housing_base() -> void:
	var hcity: City = _housing_city()
	assert_that(hcity.housing_total()).is_equal(0)
	assert_that(hcity.pop_cap()).is_equal(GameNumbers.POP_CAP_BY_STRONGHOLD[0])
	assert_that(hcity.free_housing(PopUnit.State.WORKER)).is_equal(GameNumbers.BASE_SETTLEMENT_HOUSING)
	assert_that(hcity.free_housing(PopUnit.State.SCHOLAR)).is_equal(0)
	assert_that(hcity.immigrant_state()).is_equal(PopUnit.State.WORKER)

func test_shack_extends_cap_and_housing() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var cap_before: int = hcity.pop_cap()
	var shack_cell := HexUtils.get_neighbor(hcenter, 0)
	var bld: Variant = hcity.build_building(BuildingDefs.shack(), shack_cell)
	assert_that(bld).is_not_null()
	assert_that(hcity.pop_cap()).is_equal(cap_before + 10)
	assert_that(hcity.housing_capacity(PopUnit.State.WORKER)).is_equal(10)
	assert_that(hcity.housing_total()).is_equal(10)
	assert_that(hcity.free_housing(PopUnit.State.WORKER)).is_equal(10 + 10 - hcity.count_state(PopUnit.State.WORKER))

func test_manor_and_barracks_housing() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var b1: Variant = hcity.build_building(BuildingDefs.manor(), HexUtils.get_neighbor(hcenter, 1))
	assert_that(b1).is_not_null()
	var b2: Variant = hcity.build_building(BuildingDefs.barracks(), HexUtils.get_neighbor(hcenter, 3))
	assert_that(b2).is_not_null()
	assert_that(hcity.housing_capacity(PopUnit.State.SCHOLAR)).is_equal(2)
	assert_that(hcity.housing_capacity(PopUnit.State.MILITIA)).is_equal(5)

func test_immigrant_state_priority() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var b1: Variant = hcity.build_building(BuildingDefs.barracks(), HexUtils.get_neighbor(hcenter, 0))
	var b2: Variant = hcity.build_building(BuildingDefs.manor(), HexUtils.get_neighbor(hcenter, 2))
	assert_that(b1).is_not_null()
	assert_that(b2).is_not_null()
	assert_that(hcity.immigrant_state()).is_equal(PopUnit.State.WORKER)
	for i in 10:
		hcity.add_migrant(PopUnit.State.WORKER)
	assert_that(hcity.immigrant_state()).is_equal(PopUnit.State.MILITIA)
	for i in 5:
		hcity.add_migrant(PopUnit.State.MILITIA)
	assert_that(hcity.immigrant_state()).is_equal(PopUnit.State.SCHOLAR)
	for i in 2:
		hcity.add_migrant(PopUnit.State.SCHOLAR)
	assert_that(hcity.immigrant_state()).is_equal(-1)

func test_assignment_fills_buildings() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var d: Variant = _chain_def(&"farm_a", 2)
	var bld: Variant = hcity.build_building(d, HexUtils.get_neighbor(hcenter, 0))
	assert_that(bld).is_not_null()
	for i in 12:
		hcity.add_migrant(PopUnit.State.WORKER)
	var n: int = WorkerAssignment.rebalance(hcity)
	assert_that(n).is_equal(2)
	assert_that(int(bld.assigned_workers)).is_equal(2)
	var assigned_count := 0
	for u in hcity.pop:
		if u.assigned_to == bld.uid:
			assigned_count += 1
	assert_that(assigned_count).is_equal(2)
	assert_that(WorkerAssignment.rebalance(hcity)).is_equal(0)

func test_assignment_never_overfills() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var d: Variant = _chain_def(&"mine_a", 4)
	var bld: Variant = hcity.build_building(d, HexUtils.get_neighbor(hcenter, 0))
	assert_that(bld).is_not_null()
	for i in 3:
		hcity.add_migrant(PopUnit.State.WORKER)
	WorkerAssignment.rebalance(hcity)
	assert_that(int(bld.assigned_workers)).is_equal(3)
	hcity.add_migrant(PopUnit.State.WORKER)
	WorkerAssignment.rebalance(hcity)
	assert_that(int(bld.assigned_workers)).is_equal(4)
	hcity.add_migrant(PopUnit.State.WORKER)
	WorkerAssignment.rebalance(hcity)
	assert_that(int(bld.assigned_workers)).is_equal(4)

func test_release_building_frees_workers() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var d: Variant = _chain_def(&"mill_a", 2)
	var bld: Variant = hcity.build_building(d, HexUtils.get_neighbor(hcenter, 0))
	assert_that(bld).is_not_null()
	for i in 4:
		hcity.add_migrant(PopUnit.State.WORKER)
	WorkerAssignment.rebalance(hcity)
	assert_that(int(bld.assigned_workers)).is_equal(2)
	var freed: int = WorkerAssignment.release_building(hcity, bld.uid)
	assert_that(freed).is_equal(2)
	var free_workers := 0
	for u in hcity.pop:
		if u.state == PopUnit.State.WORKER and u.assigned_to == -1:
			free_workers += 1
	assert_that(free_workers).is_equal(4)

func test_orphans_released_on_rebalance() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var d: Variant = _chain_def(&"bakery_a", 1)
	var bld: Variant = hcity.build_building(d, HexUtils.get_neighbor(hcenter, 0))
	assert_that(bld).is_not_null()
	for i in 2:
		hcity.add_migrant(PopUnit.State.WORKER)
	WorkerAssignment.rebalance(hcity)
	hcity.pop[1].assigned_to = 999
	bld.assigned_workers = 0
	var n: int = WorkerAssignment.rebalance(hcity)
	assert_bool(n >= 1).is_true()
	var orphan := 0
	for u in hcity.pop:
		if u.assigned_to == 999:
			orphan += 1
	assert_that(orphan).is_equal(0)

func test_rebalance_preserves_campaign_building_workers() -> void:
	var hcity: City = _housing_city()
	var worker: PopUnit = hcity.add_migrant(PopUnit.State.WORKER)
	worker.assigned_to = 77
	hcity.campaign_buildings.append({
		"uid": 77, "id": "bakery", "state": "active", "jobs": 1,
		"recipes": [{"id": "food", "workers": 1, "outputs": {"food": 1}}],
	})
	assert_that(WorkerAssignment.rebalance(hcity)).is_equal(0)
	assert_that(worker.assigned_to).is_equal(77)

func test_building_def_applies_chain_upkeep_zone() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var d: Variant = _chain_def(&"smithy_a", 2)
	d.default_upkeep[&"wood"] = 2.0
	d.default_zone = 2
	var bld: Variant = hcity.build_building(d, HexUtils.get_neighbor(hcenter, 0))
	assert_that(bld).is_not_null()
	assert_that(bld.get_production_chain()).is_not_null()
	assert_bool(bld.get_production_chain() != d.production_chain).is_true()
	assert_that(int(bld.get_production_chain().required_workers)).is_equal(2)
	assert_bool(absf(float(bld.get_upkeep()[&"wood"]) - 2.0) < 0.001).is_true()
	assert_that(int(bld.zone_type)).is_equal(2)
	bld.get_production_chain().building_eff = 3.0
	assert_that(float(d.production_chain.building_eff)).is_equal(1.0)

func test_scholar_promotion() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var b1: Variant = hcity.build_building(BuildingDefs.manor(), HexUtils.get_neighbor(hcenter, 0))
	assert_that(b1).is_not_null()
	hcity.ensure_resource_ctx().add(&"scholar_points", 2.0)
	var reg := CharacterRegistry.new()
	var proc := DemographicTurnProcessor.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [hcity]
	var report: Dictionary = proc.process(ctx)
	var city_report: Dictionary = (report.cities as Array)[0]
	assert_that(int(city_report.get("promoted", 0))).is_equal(2)
	assert_that(hcity.count_state(PopUnit.State.SCHOLAR)).is_equal(2)
	assert_bool(hcity.resource_ctx.amount(&"scholar_points") < 0.001).is_true()
	var report2: Dictionary = proc.process(ctx)
	var city_report2: Dictionary = (report2.cities as Array)[0]
	assert_that(int(city_report2.get("promoted", 0))).is_equal(0)

func test_scholar_promotion_needs_manor() -> void:
	var hcity: City = _housing_city()
	hcity.ensure_resource_ctx().add(&"scholar_points", 3.0)
	var reg := CharacterRegistry.new()
	var proc := DemographicTurnProcessor.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [hcity]
	var report: Dictionary = proc.process(ctx)
	var city_report: Dictionary = (report.cities as Array)[0]
	assert_that(int(city_report.get("promoted", 0))).is_equal(0)
	assert_that(hcity.count_state(PopUnit.State.SCHOLAR)).is_equal(0)
	assert_bool(hcity.resource_ctx.amount(&"scholar_points") > 2.0).is_true()

func test_scholar_promotion_respects_manor_slots() -> void:
	var hcity: City = _housing_city()
	var hcenter: Vector2i = hcity.center
	var b1: Variant = hcity.build_building(BuildingDefs.manor(), HexUtils.get_neighbor(hcenter, 0))
	assert_that(b1).is_not_null()
	hcity.ensure_resource_ctx().add(&"scholar_points", 5.0)
	var reg := CharacterRegistry.new()
	var proc := DemographicTurnProcessor.new()
	proc.setup(reg)
	var ctx := TurnContext.new()
	ctx.turn_number = 5
	ctx.cities = [hcity]
	proc.process(ctx)
	assert_that(hcity.count_state(PopUnit.State.SCHOLAR)).is_equal(2)
	assert_bool(hcity.resource_ctx.amount(&"scholar_points") > 2.0).is_true()

# --- влито из integration/test_city_cycle.gd и test_city_economy.gd: цикл города и голод за 10 ходов ──────

func _cycle_city() -> City:
	var c := City.new()
	c.center = Vector2i(10, 10)
	c.display_name = "Cyclonia"
	c.food_stockpile = 100.0
	c.storage[&"industry"] = 10000.0
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 10.0, &"industry": 1.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	for i in 3:
		c.add_migrant(PopUnit.State.WORKER, 1)
	return c

func test_city_ten_turn_cycle_growth_build_production() -> void:
	var cy := _cycle_city()

	# Строительство: район примыкает к центру
	var built := false
	for nb in HexUtils.get_all_neighbors(cy.center, true):
		if cy.build_borough(nb):
			built = true
			break
	assert_bool(built).is_true()

	var pop_start := cy.pop_capped()
	var industry_start := float(cy.storage[&"industry"])
	var starving_seen := false
	var total_births := 0

	for t in 10:
		var report: Dictionary = cy.process_turn(t)
		starving_seen = starving_seen or bool(report.get("starving", false))
		total_births += int(report.get("births", 0))

	assert_bool(starving_seen).is_false()
	assert_int(cy.pop_capped()).is_greater(pop_start)
	assert_int(total_births).is_greater(0)
	# Производство: индустрия накапливается (урожай 1/ход > 0)
	assert_float(float(cy.storage[&"industry"])).is_greater(industry_start)
	# Район сохранён и не голод
	assert_int(cy.boroughs.size()).is_equal(1)
	assert_bool(cy.starving).is_false()

func _economy_city() -> City:
	var ecity := City.new()
	ecity.center = Vector2i(10, 10)
	ecity.display_name = "Testville"
	ecity.food_stockpile = 50.0
	ecity.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 0.0, &"industry": 0.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	return ecity

func test_city_starvation_logic() -> void:
	var ecity: City = _economy_city()
	for i in 10:
		ecity.add_migrant(PopUnit.State.WORKER, 1)

	assert_bool(ecity.starving).is_false()

	ecity.food_stockpile = 10.0
	var report := ecity.process_turn(1)

	assert_bool(ecity.starving).is_true()
	assert_float(ecity.food_stockpile).is_equal(0.0)
	assert_bool(report.get("starving", false)).is_true()

func test_city_population_growth() -> void:
	var ecity: City = _economy_city()
	var initial_pop := ecity.pop_capped()
	ecity.food_stockpile = 100.0
	ecity.process_turn(1)

	assert_int(ecity.pop_capped()).is_greater(initial_pop)
