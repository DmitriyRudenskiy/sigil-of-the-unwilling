extends BaseTest
## Носитель: scripts/world/city_manager.gd — цикл города (on_turn_ended), приток
## населения по сезону, слава и перелишек последователей между городами.
## Прежнее имя — `unit/test_city_system.gd`; в шаге 3 T-305 файл разделён по
## носителям: население и стройки остались в нём, правила Borough ушли в
## `unit/world/test_borough_rules.gd`.

func _city() -> City:
	var c := City.new()
	c.display_name = "Тест-город"
	c.center = Vector2i(5, 5)
	return c

func test_cycle_inflow_summer_with_glory_and_temple() -> void:
	var mgr = auto_free( CityManager.new())
	var cap := _city()
	mgr.register_city(cap, true)
	cap.storage[&"industry"] = 1000.0
	cap.special_sites[HexUtils.get_all_neighbors(cap.center)[0]] = BuildingDefs.SITE_SHRINE
	# Ранняя игра: дымовая — храм требует уровень (early-game-foundation)
	cap.level = 11
	assert_that(cap.build_building(BuildingDefs.great_temple(), \
		HexUtils.get_all_neighbors(cap.center)[0])).is_not_null()
	mgr.add_glory(50.0, &"test")
	for i in GameNumbers.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(7)
	assert_that(cap.pop_total()).is_equal(8)
	mgr.free()

func test_cycle_inflow_winter_halved() -> void:
	var mgr = auto_free( CityManager.new())
	var cap := _city()
	mgr.register_city(cap, true)
	for i in GameNumbers.CITY_CYCLE_TURNS:
		mgr.on_turn_ended(1)
	assert_that(cap.pop_total()).is_equal(1)
	mgr.free()

func test_overflow_transfer_between_cities() -> void:
	var mgr = auto_free( CityManager.new())
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
