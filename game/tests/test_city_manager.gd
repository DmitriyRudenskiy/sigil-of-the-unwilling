extends "res://tests/test_base.gd"
## Тесты CityManager: регистрация, ход, циклический приток, слава.

const _CityManager = preload("res://world/CityManager.gd")
const _City = preload("res://world/City.gd")
const _CityBalance = preload("res://world/CityBalance.gd")
const _BuildingDefs = preload("res://data/BuildingDefs.gd")

var manager: CityManager
var capital: RefCounted

func before_each() -> void:
	manager = _CityManager.new()
	manager.name = "TestCityManager"
	capital = _City.new()
	capital.display_name = "Столица"
	capital.center = Vector2i(10, 10)
	manager.register_city(capital, true)

func after_each() -> void:
	# CityManager — Node: без free() каждый тест утекает в ObjectDB.
	if manager != null:
		manager.free()
		manager = null

# ==================== РЕГИСТРАЦИЯ ====================

func test_register_city() -> void:
	assert_eq(manager.cities.size(), 1, "1 city registered")

func test_register_city_sets_capital() -> void:
	assert_not_null(manager.capital, "capital set")
	assert_true(manager.capital.is_capital, "capital flag set")

func test_register_duplicate_city() -> void:
	manager.register_city(capital)
	assert_eq(manager.cities.size(), 1, "no duplicate")

func test_register_null_city() -> void:
	manager.register_city(null)
	assert_eq(manager.cities.size(), 1, "null not registered")

func test_register_second_city() -> void:
	var city2 := _City.new()
	city2.display_name = "Второй город"
	city2.center = Vector2i(20, 20)
	manager.register_city(city2)
	assert_eq(manager.cities.size(), 2, "2 cities")
	assert_true(manager.capital.is_capital, "capital still first")
	assert_false(city2.is_capital, "second not capital")

# ==================== СЛАВА ====================

func test_add_glory() -> void:
	manager.add_glory(15.0, &"battle_won")
	var glory := manager.glory.glory_last_window(manager.current_turn + 1)
	assert_true(glory > 0.0, "glory added")

func test_add_glory_zero() -> void:
	manager.add_glory(0.0, &"test")
	var glory := manager.glory.glory_last_window(manager.current_turn + 1)
	assert_eq(glory, 0.0, "zero glory not added")

func test_add_glory_negative() -> void:
	manager.add_glory(-5.0, &"test")
	var glory := manager.glory.glory_last_window(manager.current_turn + 1)
	assert_eq(glory, 0.0, "negative glory not added")

# ==================== ХОД ====================

func test_on_turn_ended_increments_turn() -> void:
	var before := manager.current_turn
	manager.on_turn_ended(1)
	assert_eq(manager.current_turn, before + 1, "turn incremented")

func test_on_turn_ended_returns_report() -> void:
	var report := manager.on_turn_ended(1)
	assert_true(report.has("turn"), "report has turn")
	assert_true(report.has("cities"), "report has cities")
	assert_true(report.has("arrivals"), "report has arrivals")
	assert_true(report.has("cycle"), "report has cycle")

func test_on_turn_ended_no_cycle_initially() -> void:
	var report := manager.on_turn_ended(1)
	assert_false(report.cycle, "no cycle on turn 1")

func test_on_turn_ended_cycle_on_turn_7() -> void:
	for i in 6:
		manager.on_turn_ended(1)
	var report := manager.on_turn_ended(1)
	assert_true(report.cycle, "cycle on turn 7")

# ==================== ЦИКЛИЧЕСКИЙ ПРИТОК ====================

func test_capital_inflow_no_capital() -> void:
	var mgr := _CityManager.new()
	mgr.name = "TestMgr2"
	var inflow := mgr.capital_inflow(1)
	assert_eq(inflow, 0, "no inflow without capital")
	mgr.free()

func test_capital_inflow_base() -> void:
	# Без храма и славы: base = 2, glory_mod = 1, season_mod = 1 (лето)
	var inflow := manager.capital_inflow(7)  # июль = лето
	assert_eq(inflow, 2, "base inflow 2 in summer")

func test_capital_inflow_winter() -> void:
	# Зима: season_mod = 0.5
	var inflow := manager.capital_inflow(1)  # январь = зима
	assert_eq(inflow, 1, "winter inflow halved")

func test_capital_inflow_with_glory() -> void:
	manager.add_glory(50.0, &"test")
	# glory_mod = 1 + 50/50 = 2
	var inflow := manager.capital_inflow(7)
	assert_eq(inflow, 4, "glory doubles inflow")

func test_capital_inflow_with_temple() -> void:
	# Построить храм
	capital.storage[&"industry"] = 1000.0
	capital.add_followers(5)
	var site := HexUtils.get_all_neighbors(capital.center)[0]
	capital.special_sites[site] = _BuildingDefs.SITE_SHRINE
	capital.build_building(_BuildingDefs.great_temple(), site)

	# base = 2 + 1*2 = 4
	var inflow := manager.capital_inflow(7)
	assert_eq(inflow, 4, "temple adds 2 to base")

# ==================== ПРОВАЙДЕР ТАЙЛОВ ====================

func test_set_tile_yield_provider() -> void:
	var yield_fn := func(_cell: Vector2i) -> Dictionary:
		return {&"food": 50.0, &"industry": 5.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	manager.set_tile_yield_provider(yield_fn)
	# Проверяем что провайдер установлен для всех городов
	for c in manager.cities:
		assert_true(c.tile_yield_fn != null, "tile_yield_fn set")

# ==================== ГРАНИЧНЫЕ СЛУЧАИ ====================

func test_on_turn_ended_month_13() -> void:
	# Месяц 13 не должен крешить
	var report := manager.on_turn_ended(13)
	assert_true(report.has("turn"), "report returned for month 13")

func test_on_turn_ended_month_0() -> void:
	var report := manager.on_turn_ended(0)
	assert_true(report.has("turn"), "report returned for month 0")

func test_glory_window_size() -> void:
	assert_eq(manager.glory._window, _CityBalance.CITY_CYCLE_TURNS, "window is 7 turns")
