extends "res://tests/test_base.gd"
## TimeSystem tests: hour calculation, periods, wait actions.

const _TimeSystem = preload("res://scripts/data/TimeSystem.gd")

var ts: TimeSystem


func before_each() -> void:
	ts = _TimeSystem.new()


func test_init_hour_is_six() -> void:
	assert_eq(ts.current_hour, 6.0, "init hour")


func test_zero_mp_stays_six() -> void:
	ts.mp_spent_today = 0.0
	assert_eq(ts.current_hour, 6.0, "zero mp")


func test_half_mp_is_15() -> void:
	ts.mp_spent_today = 5.0
	assert_eq(ts.current_hour, 15.0, "5mp hour")


func test_full_mp_clamps_24() -> void:
	ts.mp_spent_today = 10.0
	assert_eq(ts.current_hour, 24.0, "10mp hour")


func test_3mp_is_11_4_noon() -> void:
	ts.mp_spent_today = 3.0
	assert_eq(ts.current_hour, 11.4, "3mp hour")
	assert_true(ts.is_noon(), "is noon")


func test_5mp_is_day_not_night() -> void:
	ts.mp_spent_today = 5.0
	assert_false(ts.is_night(), "not night at 5mp")
	assert_false(ts.is_noon(), "not noon at 5mp")


func test_10mp_is_night() -> void:
	ts.mp_spent_today = 10.0
	assert_true(ts.is_night(), "night at 10mp")


func test_period_name_morning() -> void:
	ts.mp_spent_today = 1.0
	assert_eq(ts.get_period_name(), "day", "morning")


func test_period_name_night() -> void:
	ts.mp_spent_today = 9.0
	assert_eq(ts.get_period_name(), "night", "night period")


func test_reset() -> void:
	ts.mp_spent_today = 7.0
	ts.reset_for_new_day()
	assert_eq(ts.mp_spent_today, 0.0, "reset mp")
	assert_eq(ts.current_hour, 6.0, "reset hour")


func test_spend_incremental() -> void:
	ts.spend_move_points(2.0)
	assert_eq(ts.current_hour, 9.6, "incremental")


func test_wait_hours() -> void:
	# 3.6 ч / 1.8 ч за MP = 2.0 MP; 6.0 + 2.0 * 1.8 = 9.6 (та же формула, что в остальных тестах)
	var cost := ts.wait_hours(3.6)
	assert_eq(cost, 2.0, "wait cost")
	assert_eq(ts.current_hour, 9.6, "wait hour")


func test_wait_until_noon_already_past() -> void:
	ts.mp_spent_today = 5.0
	var cost := ts.wait_until_noon()
	assert_eq(cost, 0.0, "already past noon")


func test_wait_until_night_already_past() -> void:
	ts.mp_spent_today = 10.0
	var cost := ts.wait_until_night()
	assert_eq(cost, 0.0, "already past night")


func test_format_time() -> void:
	ts.mp_spent_today = 0.0
	assert_eq(ts.format_time(), "🕐 06:00", "format 6am")


func test_format_time_with_minutes() -> void:
	ts.mp_spent_today = 1.0
	assert_eq(ts.format_time(), "🕐 07:48", "format with minutes")
