extends GdUnitTestSuite

const _Season = preload("res://scripts/world/Season.gd")

# 3A: параметризация вместо 9 отдельных тестов (месяц -> сезон).
const _MONTH_SEASONS := {
	1: _Season.ID.WINTER,
	2: _Season.ID.WINTER,
	3: _Season.ID.SPRING,
	5: _Season.ID.SPRING,
	6: _Season.ID.SUMMER,
	8: _Season.ID.SUMMER,
	9: _Season.ID.AUTUMN,
	11: _Season.ID.AUTUMN,
	12: _Season.ID.WINTER,
}


func test_month_to_season() -> void:
	for month in _MONTH_SEASONS:
		assert_that(_Season.from_month(month)).is_equal(_MONTH_SEASONS[month]) \
			.override_failure_message("month %d -> season" % month)


func test_invalid_month_defaults_to_spring() -> void:
	for month in [0, 13, -1, 99]:
		assert_that(_Season.from_month(month)).is_equal(_Season.ID.SPRING) \
			.override_failure_message("month %d -> SPRING" % month)


func test_growth_modifiers() -> void:
	var mods := {
		_Season.ID.WINTER: GameNumbers.INFLOW_WINTER_MOD,
		_Season.ID.SUMMER: GameNumbers.INFLOW_SUMMER_MOD,
		_Season.ID.SPRING: GameNumbers.INFLOW_SPRING_AUTUMN_MOD,
		_Season.ID.AUTUMN: GameNumbers.INFLOW_SPRING_AUTUMN_MOD,
	}
	for season in mods:
		assert_that(_Season.growth_modifier(season)).is_equal(mods[season]) \
			.override_failure_message("growth_modifier(%s)" % str(season))


func test_winter_is_half() -> void:
	assert_that(GameNumbers.INFLOW_WINTER_MOD).is_equal(0.5)


func test_summer_is_full() -> void:
	assert_that(GameNumbers.INFLOW_SUMMER_MOD).is_equal(1.0)
