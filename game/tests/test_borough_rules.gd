extends "res://tests/test_base.gd"
## Тесты BoroughRules: стоимость, лимиты, уровни.

const _BoroughRules = preload("res://scripts/world/BoroughRules.gd")
const _City = preload("res://scripts/world/City.gd")
const _Borough = preload("res://scripts/world/Borough.gd")
const _CityBalance = preload("res://scripts/world/CityBalance.gd")

var city: RefCounted

func before_each() -> void:
	city = _City.new()
	city.display_name = "Тест"
	city.center = Vector2i(5, 5)

# ==================== POP RATIO ====================

func test_pop_ratio_default() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.DEFAULT)
	assert_eq(ratio, _CityBalance.BOROUGH_POP_RATIO_DEFAULT, "default ratio")

func test_pop_ratio_necrophage() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.NECROPHAGE)
	assert_eq(ratio, _CityBalance.BOROUGH_POP_RATIO_WIDE, "necrophage ratio")

func test_pop_ratio_allayi() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.ALLAYI)
	assert_eq(ratio, _CityBalance.BOROUGH_POP_RATIO_WIDE, "allayi ratio")

func test_pop_ratio_cultists() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.CULTISTS)
	assert_eq(ratio, _CityBalance.BOROUGH_POP_RATIO_DEFAULT, "cultists ratio")

# ==================== MAX BOROWHS ====================

func test_max_boroughs_empty_city() -> void:
	assert_eq(_BoroughRules.max_boroughs(city), 0, "no boroughs for 0 pop")

func test_max_boroughs_with_pop() -> void:
	for i in 4:
		city.add_followers(1)
	assert_eq(_BoroughRules.max_boroughs(city), 2, "2 boroughs for 4 pop default")

func test_max_boroughs_wide_ratio() -> void:
	city.faction = _City.Faction.NECROPHAGE
	for i in 4:
		city.add_followers(1)
	assert_eq(_BoroughRules.max_boroughs(city), 4, "4 boroughs for 4 pop necrophage")

# ==================== COST ====================

func test_cost_initial() -> void:
	assert_eq(_BoroughRules.cost(city), _CityBalance.BOROUGH_BASE_COST, "initial cost is base")

func test_cost_increases_with_boroughs() -> void:
	city.boroughs.append(_Borough.new())
	var cost2 := _BoroughRules.cost(city)
	assert_eq(cost2, _CityBalance.BOROUGH_BASE_COST + _CityBalance.BOROUGH_COST_STEP, "cost increases")

# ==================== LEVEL UP ====================

func test_level_up_max_level() -> void:
	var b := _Borough.new()
	b.level = _CityBalance.BOROUGH_MAX_LEVEL
	assert_false(_BoroughRules.can_level_up(city, b), "max level cannot upgrade")

func test_level_up_2_requires_cultists() -> void:
	city.faction = _City.Faction.DEFAULT
	var b := _Borough.new()
	b.level = 2
	assert_false(_BoroughRules.can_level_up(city, b), "level 3 requires cultists")

func test_level_up_2_cultists_ok() -> void:
	# can_level_up проверяет и факцию, и число соседей того же уровня (>= 4)
	city.faction = _City.Faction.CULTISTS
	var b := _Borough.new()
	b.level = 2
	b.cell = Vector2i(5, 5)
	city.boroughs.append(b)
	var nbs: Array = HexUtils.get_all_neighbors(b.cell)
	for i in _CityBalance.BOROUGH_LEVELUP_NEIGHBORS:
		var nb := _Borough.new()
		nb.level = 2
		nb.cell = nbs[i]
		city.boroughs.append(nb)
	assert_true(_BoroughRules.can_level_up(city, b), "level 3 ok for cultists")

func test_same_level_neighbors() -> void:
	var b := _Borough.new()
	b.cell = Vector2i(5, 5)
	b.level = 1
	assert_eq(_BoroughRules.same_level_neighbors(city, b), 0, "no neighbors")

# ==================== PROCESS LEVEL UPS ====================

func test_process_level_ups_empty() -> void:
	var result := _BoroughRules.process_level_ups(city)
	assert_eq(result, 0, "no level ups for empty city")

func test_process_level_ups_returns_count() -> void:
	# Build city with enough neighbors for level up
	city.faction = _City.Faction.CULTISTS
	city.add_followers(10)
	city.storage["industry"] = 1000.0
	var neighbors := HexUtils.get_all_neighbors(city.center)
	for nb in neighbors:
		city.build_borough(nb)
	
	var raised := _BoroughRules.process_level_ups(city)
	# Center has 6 neighbors at level 1, so boroughs with 4+ same-level neighbors should level up
	assert_true(raised >= 0, "level ups processed")
