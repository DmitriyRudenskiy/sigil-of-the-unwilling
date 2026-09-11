extends GdUnitTestSuite

const _BoroughRules = preload("res://scripts/world/BoroughRules.gd")
const _City = preload("res://scripts/world/City.gd")
const _Borough = preload("res://scripts/world/Borough.gd")

var city: RefCounted

func before_test() -> void:
	city = _City.new()
	city.display_name = "Тест"
	city.center = Vector2i(5, 5)

func test_pop_ratio_default() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.DEFAULT)
	assert_that(ratio).is_equal(GameNumbers.BOROUGH_POP_RATIO_DEFAULT)

func test_pop_ratio_necrophage() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.NECROPHAGE)
	assert_that(ratio).is_equal(GameNumbers.BOROUGH_POP_RATIO_WIDE)

func test_pop_ratio_allayi() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.ALLAYI)
	assert_that(ratio).is_equal(GameNumbers.BOROUGH_POP_RATIO_WIDE)

func test_pop_ratio_cultists() -> void:
	var ratio := _BoroughRules.pop_ratio(_City.Faction.CULTISTS)
	assert_that(ratio).is_equal(GameNumbers.BOROUGH_POP_RATIO_DEFAULT)

func test_max_boroughs_empty_city() -> void:
	assert_that(_BoroughRules.max_boroughs(city)).is_equal(0)

func test_max_boroughs_with_pop() -> void:
	for i in 4:
		city.add_followers(1)
	assert_that(_BoroughRules.max_boroughs(city)).is_equal(2)

func test_max_boroughs_wide_ratio() -> void:
	city.faction = _City.Faction.NECROPHAGE
	for i in 4:
		city.add_followers(1)
	assert_that(_BoroughRules.max_boroughs(city)).is_equal(4)

func test_cost_initial() -> void:
	assert_that(_BoroughRules.cost(city)).is_equal(GameNumbers.BOROUGH_BASE_COST)

func test_cost_increases_with_boroughs() -> void:
	city.boroughs.append(_Borough.new())
	var cost2 := _BoroughRules.cost(city)
	assert_that(cost2).is_equal(GameNumbers.BOROUGH_BASE_COST + GameNumbers.BOROUGH_COST_STEP)

func test_level_up_max_level() -> void:
	var b := _Borough.new()
	b.level = GameNumbers.BOROUGH_MAX_LEVEL
	assert_bool(_BoroughRules.can_level_up(city, b)).is_false()

func test_level_up_2_requires_cultists() -> void:
	city.faction = _City.Faction.DEFAULT
	var b := _Borough.new()
	b.level = 2
	assert_bool(_BoroughRules.can_level_up(city, b)).is_false()

func test_level_up_2_cultists_ok() -> void:
	city.faction = _City.Faction.CULTISTS
	var b := _Borough.new()
	b.level = 2
	b.cell = Vector2i(5, 5)
	city.boroughs.append(b)
	var nbs: Array = HexUtils.get_all_neighbors(b.cell)
	for i in GameNumbers.BOROUGH_LEVELUP_NEIGHBORS:
		var nb := _Borough.new()
		nb.level = 2
		nb.cell = nbs[i]
		city.boroughs.append(nb)
	assert_bool(_BoroughRules.can_level_up(city, b)).is_true()

func test_same_level_neighbors() -> void:
	var b := _Borough.new()
	b.cell = Vector2i(5, 5)
	b.level = 1
	assert_that(_BoroughRules.same_level_neighbors(city, b)).is_equal(0)

func test_level_up_requires_neighbors() -> void:
	var b := _Borough.new()
	b.cell = Vector2i(5, 5)
	b.level = 1
	city.boroughs.append(b)
	assert_bool(_BoroughRules.can_level_up(city, b)).is_false()

func test_level_up_with_enough_same_level_neighbors() -> void:
	var b := _Borough.new()
	b.cell = Vector2i(5, 5)
	b.level = 1
	city.boroughs.append(b)
	for nb in HexUtils.get_all_neighbors(b.cell):
		var nb_b := _Borough.new()
		nb_b.cell = nb
		nb_b.level = 1
		city.boroughs.append(nb_b)
	assert_that(_BoroughRules.same_level_neighbors(city, b)).is_equal(6)
	assert_bool(_BoroughRules.can_level_up(city, b)).is_true()

func test_process_level_ups_empty() -> void:
	var result := _BoroughRules.process_level_ups(city)
	assert_that(result).is_equal(0)

func test_process_level_ups_returns_count() -> void:
	city.faction = _City.Faction.CULTISTS
	city.add_followers(10)
	city.storage["industry"] = 1000.0
	var center: Vector2i = city.center
	var center_borough := _Borough.new()
	center_borough.cell = center
	center_borough.level = 1
	city.boroughs.append(center_borough)
	for nb in HexUtils.get_all_neighbors(center):
		var nb_b := _Borough.new()
		nb_b.cell = nb
		nb_b.level = 1
		city.boroughs.append(nb_b)
	var raised := _BoroughRules.process_level_ups(city)
	assert_int(raised).is_greater(0)
	assert_int(center_borough.level).is_greater(1)
