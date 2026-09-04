extends "res://tests/gut_base.gd"
## Тесты Season: определение сезона по месяцу, модификаторы.

const _Season = preload("res://scripts/world/Season.gd")
const _CityBalance = preload("res://scripts/world/CityBalance.gd")

# ==================== ОПРЕДЕЛЕНИЕ СЕЗОНА ====================

func test_january_is_winter() -> void:
	assert_eq(_Season.from_month(1), _Season.ID.WINTER, "January is winter")

func test_february_is_winter() -> void:
	assert_eq(_Season.from_month(2), _Season.ID.WINTER, "February is winter")

func test_march_is_spring() -> void:
	assert_eq(_Season.from_month(3), _Season.ID.SPRING, "March is spring")

func test_may_is_spring() -> void:
	assert_eq(_Season.from_month(5), _Season.ID.SPRING, "May is spring")

func test_june_is_summer() -> void:
	assert_eq(_Season.from_month(6), _Season.ID.SUMMER, "June is summer")

func test_august_is_summer() -> void:
	assert_eq(_Season.from_month(8), _Season.ID.SUMMER, "August is summer")

func test_september_is_autumn() -> void:
	assert_eq(_Season.from_month(9), _Season.ID.AUTUMN, "September is autumn")

func test_november_is_autumn() -> void:
	assert_eq(_Season.from_month(11), _Season.ID.AUTUMN, "November is autumn")

func test_december_is_winter() -> void:
	assert_eq(_Season.from_month(12), _Season.ID.WINTER, "December is winter")

# ==================== МОДИФИКАТОРЫ ====================

func test_winter_modifier() -> void:
	assert_eq(_Season.growth_modifier(_Season.ID.WINTER), _CityBalance.INFLOW_WINTER_MOD, "winter mod")

func test_summer_modifier() -> void:
	assert_eq(_Season.growth_modifier(_Season.ID.SUMMER), _CityBalance.INFLOW_SUMMER_MOD, "summer mod")

func test_spring_modifier() -> void:
	assert_eq(_Season.growth_modifier(_Season.ID.SPRING), _CityBalance.INFLOW_SPRING_AUTUMN_MOD, "spring mod")

func test_autumn_modifier() -> void:
	assert_eq(_Season.growth_modifier(_Season.ID.AUTUMN), _CityBalance.INFLOW_SPRING_AUTUMN_MOD, "autumn mod")

func test_winter_is_half() -> void:
	assert_eq(_CityBalance.INFLOW_WINTER_MOD, 0.5, "winter is 0.5")

func test_summer_is_full() -> void:
	assert_eq(_CityBalance.INFLOW_SUMMER_MOD, 1.0, "summer is 1.0")

# ==================== ГРАНИЧНЫЕ СЛУЧАИ ====================

func test_month_0_defaults_to_spring() -> void:
	assert_eq(_Season.from_month(0), _Season.ID.SPRING, "month 0 defaults to spring")

func test_month_13_defaults_to_spring() -> void:
	assert_eq(_Season.from_month(13), _Season.ID.SPRING, "month 13 defaults to spring")

func test_month_negative_defaults_to_spring() -> void:
	assert_eq(_Season.from_month(-1), _Season.ID.SPRING, "negative month defaults to spring")
