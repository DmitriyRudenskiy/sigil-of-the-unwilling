extends "../gut_base.gd"
## Тесты системы населения и градостроительства.

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


func assert_almost_eq(a: float, b: float, delta: float, msg: String = "") -> void:
	if absf(a - b) > delta:
		_fail("assert_almost_eq failed: %s (got %.4f, expected %.4f ±%.4f)" % [msg, a, b, delta])
	else:
		_pass(msg)


func test_militia_excluded_from_pop_cap() -> void:
	var c := _city()
	c.add_followers(12)
	for u in c.pop.slice(0, 5):
		u.request_switch(PopUnit.State.MILITIA)
	c.process_turn(1)
	assert_eq(c.count_state(PopUnit.State.MILITIA), 5, "militia count")
	assert_eq(c.pop_capped(), 7, "pop_capped excludes militia")
	assert_eq(c.over_limit(), 0, "no overflow")

func test_switch_takes_full_turn() -> void:
	var c := _city()
	c.add_followers(1)
	var u: PopUnit = c.pop[0]
	assert_true(c.request_switch(u.uid, PopUnit.State.WORKER, c.first_free_worker_tile()), "request OK")
	assert_eq(u.state, PopUnit.State.FOLLOWER, "still follower before turn")
	assert_false(u.is_available(), "unavailable while pending")
	c.process_turn(1)
	assert_eq(u.state, PopUnit.State.WORKER, "worker after turn")
	assert_true(u.is_available(), "available after apply")

func test_growth_births_follow_threshold() -> void:
	var c := _city()
	c.tile_yield_fn = _food_yield
	# ТЗ 4.1: доход дают только клетки рабочих (и соседи районов) —
	# 1 рабочий (100 еды с его клетки) + 1 последователь (N=2, без дохода)
	c.add_followers(2)
	var u: PopUnit = c.pop[0]
	c.request_switch(u.uid, PopUnit.State.WORKER, c.first_free_worker_tile())
	var r := c.process_turn(1)
	# Порог N=2: 5×2^2.75 ≈ 33.64 → 1 рождение; N=3: ≈ 102.5 > остатка 65.4
	# Склад = 100 (клетка рабочего) − 1 (еда рабочего) − 33.64 (рождение)
	assert_eq(r.births, 1, "one birth")
	assert_almost_eq(c.food_stockpile, FOOD_PER_TILE - 1.0 - 5.0 * pow(2.0, 2.75), 0.01, "food stockpile after birth")

func test_cycle_inflow_summer_with_glory_and_temple() -> void:
	var mgr := CityManager.new()
	var cap := _city()
	mgr.register_city(cap, true)
	cap.storage[&"industry"] = 1000.0
	cap.special_sites[HexUtils.get_all_neighbors(cap.center)[0]] = BuildingDefs.SITE_SHRINE
	assert_not_null(cap.build_building(BuildingDefs.great_temple(), \
		HexUtils.get_all_neighbors(cap.center)[0]), "temple built")
	mgr.add_glory(50.0, &"test")  # модификатор = 1 + 50/50 = 2.0
	for i in CityBalance.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(7)      # июль = лето = 1.0
	# База = 2 + 1×2 = 4; итог floor(4 × 2 × 1) = 8
	assert_eq(cap.pop_total(), 8, "8 followers from cycle")
	mgr.free()

func test_cycle_inflow_winter_halved() -> void:
	var mgr := CityManager.new()
	var cap := _city()
	mgr.register_city(cap, true)  # без храма и славы
	for i in CityBalance.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(1)      # январь = зима = 0.5
	assert_eq(cap.pop_total(), 1, "winter halved to 1")  # floor(2 × 1 × 0.5)
	mgr.free()

func test_borough_limit_by_faction() -> void:
	var c := _city()
	c.add_followers(5)
	assert_eq(BoroughRules.max_boroughs(c), 2, "default faction limit")
	c.faction = City.Faction.NECROPHAGE
	assert_eq(BoroughRules.max_boroughs(c), 5, "necrophage limit")

func test_borough_levelup_needs_4_same_level() -> void:
	var c := _city()
	var x := Vector2i(5, 5)
	var nb: Array = HexUtils.get_all_neighbors(x)
	c.boroughs.append(_mk_borough(x))
	for i in 4:
		c.boroughs.append(_mk_borough(nb[i]))
	assert_eq(BoroughRules.same_level_neighbors(c, c.boroughs[0]), 4, "4 same-level neighbors")
	var ups := BoroughRules.process_level_ups(c)
	assert_eq(ups, 1, "one level-up")
	assert_eq(c.boroughs[0].level, 2, "central borough level 2")
	# Уровень 3 недоступен не-Культистам:
	assert_false(BoroughRules.can_level_up(c, c.boroughs[0]), "no level 3 for non-cultists")

func test_building_upgrade_requires_hero_and_followers() -> void:
	var c := _city()
	c.add_followers(5)
	c.storage[&"industry"] = 500.0
	c.storage[&"gold"] = 500.0
	var cell := c.first_free_worker_tile()
	var bld := c.build_building(BuildingDefs.market(), cell)
	assert_eq(bld.level, 1, "building level 1")
	assert_false(c.can_upgrade_building(bld, Vector2i(99, 99)).ok, "hero not present")
	assert_true(c.can_upgrade_building(bld, bld.cell).ok, "hero on cell OK")
	assert_true(c.perform_upgrade(bld), "upgrade 1→2 OK")
	assert_eq(bld.level, 2, "building level 2")
	assert_eq(c.free_followers(), 3, "3 free followers after 2 assigned")
	assert_true(c.perform_upgrade(bld), "upgrade 2→3 OK")
	assert_eq(bld.level, 3, "building level 3")
	assert_eq(c.free_followers(), 0, "0 free followers after 3 assigned")

func test_free_building_placement_distance() -> void:
	var c := _city()
	c.storage[&"industry"] = 1000.0
	var far := c.center
	for i in CityBalance.BUILDING_MAX_BUILD_DISTANCE + 1:
		far = HexUtils.get_all_neighbors(far)[0]
	assert_false(c.can_build_building(BuildingDefs.market(), far).ok, "too far rejected")
	var near: Vector2i = HexUtils.get_all_neighbors(c.center)[0]
	assert_true(c.can_build_building(BuildingDefs.market(), near).ok, "nearby OK")

func test_overflow_transfer_between_cities() -> void:
	var mgr := CityManager.new()
	var cap := _city()
	var other := _city()
	mgr.register_city(cap, true)
	mgr.register_city(other)
	cap.add_followers(9)
	for i in CityBalance.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(7)  # +2 → 11 при капе 10
	assert_eq(cap.over_limit(), 1, "overflow 1")
	assert_eq(cap.send_followers_to(other, 1), 1, "transferred 1")
	assert_eq(cap.over_limit(), 0, "no overflow after transfer")
	assert_eq(other.pop_total(), 1, "other city has 1")
	mgr.free()

func test_patrol_gives_safety() -> void:
	var c := _city()
	c.add_followers(2)
	for u in c.pop:
		u.request_switch(PopUnit.State.MILITIA)
	c.process_turn(1)
	c.set_patrol(c.pop[0].uid, true)
	assert_eq(c.safety(), CityBalance.SAFETY_PER_PATROL_MILITIA, "patrol safety")

func test_worker_switch_invalidates_yield() -> void:
	# Regression: cache invalidation on follower→worker switch (Fix #5)
	var c := _city()
	c.tile_yield_fn = _food_yield
	c.add_followers(1)
	var y0: float = c.get_yield()[&"food"]
	c.request_switch(c.pop[0].uid, PopUnit.State.WORKER, c.first_free_worker_tile())
	c.process_turn(1)  # applies pending switch
	var y1: float = c.get_yield()[&"food"]
	assert_true(y1 > y0, "yield must rise after worker placed (cache invalidated)")
