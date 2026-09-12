extends BaseTest






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
