extends GdUnitTestSuite

const FOOD_PER_TILE := 100.0


func _city() -> City:
	var c := City.new()
	c.display_name = "Тест-город"
	c.center = Vector2i(5, 5)
	return c


func _food_yield(_cell: Vector2i) -> Dictionary:
	return {&"food": FOOD_PER_TILE, &"industry": 10.0, &"dust": 0.0,
		&"science": 0.0, &"influence": 0.0}


func _mk_borough(cell: Vector2i) -> Borough:
	var b := Borough.new()
	b.cell = cell
	b.level = 1
	return b


func assert_almost_eq(a: float, b: float, delta: float, _msg: String = "") -> void:
	assert_float(a).is_equal_approx(b, delta)


func test_militia_excluded_from_pop_cap() -> void:
	var c := _city()
	c.add_followers(12)
	for u in c.pop.slice(0, 5):
		u.request_switch(PopUnit.State.MILITIA)
	c.process_turn(1)
	assert_that(c.count_state(PopUnit.State.MILITIA)).is_equal(5)
	assert_that(c.pop_capped()).is_equal(7)
	assert_that(c.over_limit()).is_equal(0)

func test_switch_takes_full_turn() -> void:
	var c := _city()
	c.add_followers(1)
	var u: PopUnit = c.pop[0]
	assert_bool(c.request_switch(u.uid, PopUnit.State.WORKER, c.first_free_worker_tile())).is_true()
	assert_that(u.state).is_equal(PopUnit.State.FOLLOWER)
	assert_bool(u.is_available()).is_false()
	c.process_turn(1)
	assert_that(u.state).is_equal(PopUnit.State.WORKER)
	assert_bool(u.is_available()).is_true()

func test_growth_births_follow_threshold() -> void:
	var c := _city()
	c.tile_yield_fn = _food_yield
	c.add_followers(2)
	var u: PopUnit = c.pop[0]
	c.request_switch(u.uid, PopUnit.State.WORKER, c.first_free_worker_tile())
	var r := c.process_turn(1)
	assert_that(r.births).is_equal(1)
	assert_almost_eq(c.food_stockpile, FOOD_PER_TILE - 1.0 - 5.0 * pow(2.0, 2.75), 0.01, "food stockpile after birth")

func test_cycle_inflow_summer_with_glory_and_temple() -> void:
	var mgr := CityManager.new()
	var cap := _city()
	mgr.register_city(cap, true)
	cap.storage[&"industry"] = 1000.0
	cap.special_sites[HexUtils.get_all_neighbors(cap.center)[0]] = BuildingDefs.SITE_SHRINE
	assert_that(cap.build_building(BuildingDefs.great_temple(), \
		HexUtils.get_all_neighbors(cap.center)[0])).is_not_null()
	mgr.add_glory(50.0, &"test")  
	for i in GameNumbers.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(7)      
	assert_that(cap.pop_total()).is_equal(8)
	mgr.free()

func test_cycle_inflow_winter_halved() -> void:
	var mgr := CityManager.new()
	var cap := _city()
	mgr.register_city(cap, true)  
	for i in GameNumbers.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(1)      
	assert_that(cap.pop_total()).is_equal(1)  
	mgr.free()

func test_borough_limit_by_faction() -> void:
	var c := _city()
	c.add_followers(5)
	assert_that(BoroughRules.max_boroughs(c)).is_equal(2)
	c.faction = City.Faction.NECROPHAGE
	assert_that(BoroughRules.max_boroughs(c)).is_equal(5)

func test_borough_levelup_needs_4_same_level() -> void:
	var c := _city()
	var x := Vector2i(5, 5)
	var nb: Array = HexUtils.get_all_neighbors(x)
	c.boroughs.append(_mk_borough(x))
	for i in 4:
		c.boroughs.append(_mk_borough(nb[i]))
	assert_that(BoroughRules.same_level_neighbors(c, c.boroughs[0])).is_equal(4)
	var ups := BoroughRules.process_level_ups(c)
	assert_that(ups).is_equal(1)
	assert_that(c.boroughs[0].level).is_equal(2)
	assert_bool(BoroughRules.can_level_up(c, c.boroughs[0])).is_false()

func test_building_upgrade_requires_hero_and_followers() -> void:
	var c := _city()
	c.add_followers(5)
	c.storage[&"industry"] = 500.0
	c.storage[&"gold"] = 500.0
	var cell := c.first_free_worker_tile()
	var bld := c.build_building(BuildingDefs.market(), cell)
	assert_that(bld.level).is_equal(1)
	assert_bool(c.can_upgrade_building(bld, Vector2i(99, 99)).ok).is_false()
	assert_bool(c.can_upgrade_building(bld, bld.cell).ok).is_true()
	assert_bool(c.perform_upgrade(bld)).is_true()
	assert_that(bld.level).is_equal(2)
	assert_that(c.free_followers()).is_equal(3)
	assert_bool(c.perform_upgrade(bld)).is_true()
	assert_that(bld.level).is_equal(3)
	assert_that(c.free_followers()).is_equal(0)

func test_free_building_placement_distance() -> void:
	var c := _city()
	c.storage[&"industry"] = 1000.0
	var far := c.center
	for i in GameNumbers.BUILDING_MAX_DIST_BASE + 1:
		far = HexUtils.get_all_neighbors(far)[0]
	assert_bool(c.can_build_building(BuildingDefs.market(), far).ok).is_false()
	var near: Vector2i = HexUtils.get_all_neighbors(c.center)[0]
	assert_bool(c.can_build_building(BuildingDefs.market(), near).ok).is_true()

func test_overflow_transfer_between_cities() -> void:
	var mgr := CityManager.new()
	var cap := _city()
	var other := _city()
	mgr.register_city(cap, true)
	mgr.register_city(other)
	cap.add_followers(9)
	for i in GameNumbers.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(7)  
	assert_that(cap.over_limit()).is_equal(1)
	assert_that(cap.send_followers_to(other, 1)).is_equal(1)
	assert_that(cap.over_limit()).is_equal(0)
	assert_that(other.pop_total()).is_equal(1)
	mgr.free()

func test_patrol_gives_safety() -> void:
	var c := _city()
	c.add_followers(2)
	for u in c.pop:
		u.request_switch(PopUnit.State.MILITIA)
	c.process_turn(1)
	c.set_patrol(c.pop[0].uid, true)
	assert_that(c.safety()).is_equal(GameNumbers.SAFETY_PER_PATROL)

func test_worker_switch_invalidates_yield() -> void:
	var c := _city()
	c.tile_yield_fn = _food_yield
	c.add_followers(1)
	var y0: float = c.get_yield()[&"food"]
	c.request_switch(c.pop[0].uid, PopUnit.State.WORKER, c.first_free_worker_tile())
	c.process_turn(1)  
	var y1: float = c.get_yield()[&"food"]
	assert_bool(y1 > y0).is_true()

func test_can_build_rejects_worker_cell() -> void:
	var c := _city()
	c.add_followers(3)
	c.storage[&"industry"] = 500.0  
	var u: PopUnit = c.pop[0]
	assert_bool(c.request_switch(u.uid, PopUnit.State.WORKER, c.first_free_worker_tile())).is_true()
	c.process_turn(1)  
	var worker_cell: Vector2i = u.tile
	assert_that(u.state).is_equal(PopUnit.State.WORKER)
	assert_bool(worker_cell.x >= 0).is_true()

	var chk := c.can_build_building(BuildingDefs.market(), worker_cell)
	assert_bool(chk.ok).is_false()
	assert_bool(chk.reason != "").is_true()

	assert_that(u.state).is_equal(PopUnit.State.WORKER)
	assert_that(u.tile).is_equal(worker_cell)
	assert_that(c.count_state(PopUnit.State.WORKER)).is_equal(1)

	var other: Vector2i = c.first_free_worker_tile()
	assert_bool(other == worker_cell).is_false()
	var _dbg := c.can_build_building(BuildingDefs.market(), other)
	assert_bool(_dbg.ok).is_true()
	assert_bool(c.can_build_building(BuildingDefs.market(), other).ok).is_true()
