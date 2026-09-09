extends GdUnitTestSuite

const _CityManager = preload("res://scripts/world/CityManager.gd")
const _City = preload("res://scripts/world/City.gd")
const _BuildingDefs = preload("res://scripts/data/BuildingDefs.gd")

var manager: CityManager
var capital: RefCounted

func before_test() -> void:
	manager = _CityManager.new()
	manager.name = "TestCityManager"
	capital = _City.new()
	capital.display_name = "Столица"
	capital.center = Vector2i(10, 10)
	manager.register_city(capital, true)

func after_test() -> void:
	if manager != null:
		manager.free()
		manager = null

func test_register_city() -> void:
	assert_that(manager.cities.size()).is_equal(1)

func test_register_city_sets_capital() -> void:
	assert_that(manager.capital).is_not_null()
	assert_bool(manager.capital.is_capital).is_true()

func test_register_duplicate_city() -> void:
	manager.register_city(capital)
	assert_that(manager.cities.size()).is_equal(1)

func test_register_null_city() -> void:
	manager.register_city(null)
	assert_that(manager.cities.size()).is_equal(1)

func test_register_second_city() -> void:
	var city2 := _City.new()
	city2.display_name = "Второй город"
	city2.center = Vector2i(20, 20)
	manager.register_city(city2)
	assert_that(manager.cities.size()).is_equal(2)
	assert_bool(manager.capital.is_capital).is_true()
	assert_bool(city2.is_capital).is_false()

func test_add_glory() -> void:
	manager.add_glory(15.0, &"battle_won")
	var glory := manager.glory.glory_last_window(manager.current_turn + 1)
	assert_bool(glory > 0.0).is_true()

func test_add_glory_zero() -> void:
	manager.add_glory(0.0, &"test")
	var glory := manager.glory.glory_last_window(manager.current_turn + 1)
	assert_that(glory).is_equal(0.0)

func test_add_glory_negative() -> void:
	manager.add_glory(-5.0, &"test")
	var glory := manager.glory.glory_last_window(manager.current_turn + 1)
	assert_that(glory).is_equal(0.0)

func test_on_turn_ended_increments_turn() -> void:
	var before := manager.current_turn
	manager.on_turn_ended(1)
	assert_that(manager.current_turn).is_equal(before + 1)

func test_on_turn_ended_returns_report() -> void:
	var report := manager.on_turn_ended(1)
	assert_bool(report.has("turn")).is_true()
	assert_bool(report.has("cities")).is_true()
	assert_bool(report.has("arrivals")).is_true()
	assert_bool(report.has("cycle")).is_true()

func test_on_turn_ended_no_cycle_initially() -> void:
	var report := manager.on_turn_ended(1)
	assert_bool(report.cycle).is_false()

func test_on_turn_ended_cycle_on_turn_7() -> void:
	for i in 6:
		manager.on_turn_ended(1)
	var report := manager.on_turn_ended(1)
	assert_bool(report.cycle).is_true()

func test_capital_inflow_no_capital() -> void:
	var mgr := _CityManager.new()
	mgr.name = "TestMgr2"
	var inflow := mgr.capital_inflow(1)
	assert_that(inflow).is_equal(0)
	mgr.free()

func test_capital_inflow_base() -> void:
	var inflow := manager.capital_inflow(7)
	assert_that(inflow).is_equal(2)

func test_capital_inflow_winter() -> void:
	var inflow := manager.capital_inflow(1)
	assert_that(inflow).is_equal(1)

func test_capital_inflow_with_glory() -> void:
	manager.add_glory(50.0, &"test")
	var inflow := manager.capital_inflow(7)
	assert_that(inflow).is_equal(4)

func test_capital_inflow_with_temple() -> void:
	capital.storage[&"industry"] = 1000.0
	capital.add_followers(5)
	var site := HexUtils.get_all_neighbors(capital.center)[0]
	capital.special_sites[site] = _BuildingDefs.SITE_SHRINE
	capital.build_building(_BuildingDefs.great_temple(), site)

	var inflow := manager.capital_inflow(7)
	assert_that(inflow).is_equal(4)

func test_set_tile_yield_provider() -> void:
	var yield_fn := func(_cell: Vector2i) -> Dictionary:
		return {&"food": 50.0, &"industry": 5.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	manager.set_tile_yield_provider(yield_fn)
	for c in manager.cities:
		assert_bool(c.tile_yield_fn != null).is_true()

func test_on_turn_ended_month_13() -> void:
	var report := manager.on_turn_ended(13)
	assert_bool(report.has("turn")).is_true()

func test_on_turn_ended_month_0() -> void:
	var report := manager.on_turn_ended(0)
	assert_bool(report.has("turn")).is_true()

func test_glory_window_size() -> void:
	assert_that(manager.glory._window).is_equal(GameNumbers.CITY_CYCLE_TURNS)
