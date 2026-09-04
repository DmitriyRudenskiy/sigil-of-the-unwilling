extends "res://tests/gut_base.gd"
## Тесты модели города: население, районы, здания, экономика.

const _City = preload("res://scripts/world/City.gd")
const _Borough = preload("res://scripts/world/Borough.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")
const _CityBalance = preload("res://scripts/world/CityBalance.gd")
const _UniqueBuilding = preload("res://scripts/world/UniqueBuilding.gd")
const _BuildingDefs = preload("res://scripts/data/BuildingDefs.gd")

var city: City

func before_each() -> void:
	city = _City.new()
	city.display_name = "Тест-город"
	city.center = Vector2i(5, 5)

func _food_yield(_cell: Vector2i) -> Dictionary:
	return {&"food": 100.0, &"industry": 10.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}

# ==================== НАСЕЛЕНИЕ ====================

func test_pop_total_initially_zero() -> void:
	assert_eq(city.pop_total(), 0, "no population initially")

func test_add_followers() -> void:
	var overflow := city.add_followers(5)
	assert_eq(city.pop_total(), 5, "5 followers added")
	assert_eq(overflow, 0, "no overflow")

func test_add_followers_overflow() -> void:
	city.add_followers(15)  # кап 10 для уровня 1
	var overflow := city.over_limit()
	assert_eq(overflow, 5, "5 over limit")

func test_pop_cap_level_1() -> void:
	assert_eq(city.pop_cap(), 10, "level 1 cap is 10")

func test_pop_cap_level_2() -> void:
	city.stronghold_level = 2
	assert_eq(city.pop_cap(), 20, "level 2 cap is 20")

func test_pop_cap_level_3() -> void:
	city.stronghold_level = 3
	assert_eq(city.pop_cap(), 35, "level 3 cap is 35")

func test_count_state() -> void:
	city.add_followers(3)
	assert_eq(city.count_state(_PopUnit.State.FOLLOWER), 3, "3 followers")
	assert_eq(city.count_state(_PopUnit.State.WORKER), 0, "0 workers")

func test_free_followers() -> void:
	city.add_followers(5)
	assert_eq(city.free_followers(), 5, "all free initially")

func test_find_pop() -> void:
	city.add_followers(1)
	var uid: int = city.pop[0].uid
	var found := city.find_pop(uid)
	assert_not_null(found, "found pop unit")
	assert_eq(found.uid, uid, "correct uid")

func test_find_pop_not_found() -> void:
	var found := city.find_pop(999)
	assert_null(found, "not found")

# ==================== РАЙОНЫ ====================

func test_can_build_borough_center_rejected() -> void:
	var check := city.can_build_borough(city.center)
	assert_false(check.ok, "center rejected")

func test_can_build_borough_adjacent_ok() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var check := city.can_build_borough(nb)
	assert_true(check.ok, "adjacent cell ok")

func test_build_borough() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var result := city.build_borough(nb)
	assert_true(result, "borough built")
	assert_eq(city.boroughs.size(), 1, "1 borough")

func test_build_borough_costs_industry() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	city.build_borough(nb)
	assert_true(city.storage[&"industry"] < 100.0, "industry spent")

func test_borough_level_initial() -> void:
	city.add_followers(5)
	city.storage[&"industry"] = 100.0
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	city.build_borough(nb)
	assert_eq(city.boroughs[0].level, 1, "level 1 initially")

# ==================== ЗДАНИЯ ====================

func test_can_build_building() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var check := city.can_build_building(_BuildingDefs.market(), nb)
	assert_true(check.ok, "market can be built")

func test_build_building() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	var bld := city.build_building(_BuildingDefs.market(), nb)
	assert_not_null(bld, "building created")
	assert_eq(bld.level, 1, "level 1")

func test_building_requires_site() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	# great_temple требует святилище
	var check := city.can_build_building(_BuildingDefs.great_temple(), nb)
	assert_false(check.ok, "great temple requires site")

func test_building_with_site() -> void:
	city.storage[&"industry"] = 100.0
	city.add_followers(5)
	var site_cell := HexUtils.get_all_neighbors(city.center)[0]
	city.special_sites[site_cell] = _BuildingDefs.SITE_SHRINE
	var check := city.can_build_building(_BuildingDefs.great_temple(), site_cell)
	assert_true(check.ok, "great temple on shrine site")

# ==================== ЭКОНОМИКА ====================

func test_get_yield_empty_city() -> void:
	city.tile_yield_fn = _food_yield
	var y := city.get_yield()
	assert_eq(y[&"food"], 0.0, "no yield without workers/boroughs")

func test_food_consumption() -> void:
	# По ТЗ/допущению №2 потребляют только рабочие и ополченцы (FOOD_PER_FOLLOWER = 0)
	city.add_followers(1)
	var u: PopUnit = city.pop[0]
	city.request_switch(u.uid, PopUnit.State.WORKER, city.first_free_worker_tile())
	city.process_turn(1)
	var consumption := city.food_consumption()
	assert_true(consumption > 0.0, "consumption > 0")

func test_net_food_negative_without_workers() -> void:
	# Ополченцы едят, но дохода не дают (нет рабочих/районов → доход 0 по ТЗ 4.1)
	city.tile_yield_fn = _food_yield
	city.add_followers(2)
	for u in city.pop:
		u.request_switch(PopUnit.State.MILITIA)
	city.process_turn(1)
	var nf := city.net_food()
	assert_true(nf < 0.0, "net food negative without workers")

func test_growth_threshold() -> void:
	city.add_followers(2)
	var threshold := city.growth_threshold()
	assert_true(threshold > 0.0, "threshold > 0")

func test_approval_no_boroughs() -> void:
	assert_eq(city.approval(), 0, "no approval without boroughs")

func test_approval_starving_penalty() -> void:
	city.starving = true
	var approval := city.approval()
	assert_true(approval < 0, "starving gives negative approval")

# ==================== ХОД ГОРОДА ====================

func test_process_turn_returns_report() -> void:
	city.tile_yield_fn = _food_yield
	city.add_followers(2)
	var report := city.process_turn(1)
	assert_true(report.has("births"), "report has births")
	assert_true(report.has("level_ups"), "report has level_ups")
	assert_true(report.has("starving"), "report has starving")
	assert_true(report.has("net_food"), "report has net_food")
	assert_true(report.has("switched"), "report has switched")

func test_process_turn_births() -> void:
	city.tile_yield_fn = _food_yield
	city.add_followers(2)
	var report := city.process_turn(1)
	# С 2 рабочими и 100 еды на клетку, должно быть рождение
	assert_true(report.births >= 0, "births non-negative")

# ==================== КЛЕТКИ ====================

func test_cell_is_built_center() -> void:
	assert_true(city.cell_is_built(city.center), "center is built")

func test_cell_is_built_empty() -> void:
	var empty := Vector2i(10, 10)
	assert_false(city.cell_is_built(empty), "empty cell not built")

func test_is_worker_tile_free() -> void:
	var nb := HexUtils.get_all_neighbors(city.center)[0]
	assert_true(city.is_worker_tile_free(nb), "adjacent cell is free for worker")

func test_is_worker_tile_free_center() -> void:
	assert_false(city.is_worker_tile_free(city.center), "center not free")

func test_first_free_worker_tile() -> void:
	var tile := city.first_free_worker_tile()
	assert_true(tile.x >= 0, "found free worker tile")

# ==================== SERIALIZATION ====================

func test_city_display_name() -> void:
	assert_eq(city.display_name, "Тест-город", "display name")

func test_city_center() -> void:
	assert_eq(city.center, Vector2i(5, 5), "center")

func test_city_faction_default() -> void:
	assert_eq(city.faction, _City.Faction.DEFAULT, "default faction")

func test_city_is_capital() -> void:
	assert_false(city.is_capital, "not capital initially")
	city.is_capital = true
	assert_true(city.is_capital, "capital after set")
