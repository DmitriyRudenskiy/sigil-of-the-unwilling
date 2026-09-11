extends BaseTest


var ts: TimeSystem

func before_test() -> void:
	ts = TimeSystem.new()

func test_init_hour_is_six() -> void:
	assert_that(ts.current_hour).is_equal(6.0)

func test_zero_mp_stays_six() -> void:
	ts.mp_spent_today = 0.0
	assert_that(ts.current_hour).is_equal(6.0)

func test_half_mp_is_15() -> void:
	ts.mp_spent_today = 5.0
	assert_that(ts.current_hour).is_equal(15.0)

func test_full_mp_clamps_24() -> void:
	ts.mp_spent_today = 10.0
	assert_that(ts.current_hour).is_equal(24.0)

func test_3mp_is_11_4_noon() -> void:
	ts.mp_spent_today = 3.0
	assert_that(ts.current_hour).is_equal(11.4)
	assert_bool(ts.is_noon()).is_true()

func test_5mp_is_day_not_night() -> void:
	ts.mp_spent_today = 5.0
	assert_bool(ts.is_night()).is_false()
	assert_bool(ts.is_noon()).is_false()

func test_10mp_is_night() -> void:
	ts.mp_spent_today = 10.0
	assert_bool(ts.is_night()).is_true()

func test_period_name_morning() -> void:
	ts.mp_spent_today = 1.0
	assert_that(ts.get_period_name()).is_equal("day")

func test_period_name_night() -> void:
	ts.mp_spent_today = 9.0
	assert_that(ts.get_period_name()).is_equal("night")

func test_reset() -> void:
	ts.mp_spent_today = 7.0
	ts.reset_for_new_day()
	assert_that(ts.mp_spent_today).is_equal(0.0)
	assert_that(ts.current_hour).is_equal(6.0)

func test_spend_incremental() -> void:
	ts.spend_move_points(2.0)
	assert_that(ts.current_hour).is_equal(9.6)

func test_wait_hours() -> void:
	var cost := ts.wait_hours(3.6)
	assert_that(cost).is_equal(2.0)
	assert_that(ts.current_hour).is_equal(9.6)

func test_wait_until_noon_already_past() -> void:
	ts.mp_spent_today = 5.0
	var cost := ts.wait_until_noon()
	assert_that(cost).is_equal(0.0)

func test_wait_until_night_already_past() -> void:
	ts.mp_spent_today = 10.0
	var cost := ts.wait_until_night()
	assert_that(cost).is_equal(0.0)

func test_format_time() -> void:
	ts.mp_spent_today = 0.0
	assert_that(ts.format_time()).is_equal("🕐 06:00")

func test_format_time_with_minutes() -> void:
	ts.mp_spent_today = 1.0
	assert_that(ts.format_time()).is_equal("🕐 07:48")
