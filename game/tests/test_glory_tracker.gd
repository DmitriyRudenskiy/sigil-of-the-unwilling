extends GdUnitTestSuite

const _GloryTracker = preload("res://scripts/world/GloryTracker.gd")

var tracker: RefCounted

func before_test() -> void:
	tracker = _GloryTracker.new()


func test_initial_glory_zero() -> void:
	assert_that(tracker.glory_last_window(1)).is_equal(0.0)

func test_add_glory() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	assert_that(tracker.glory_last_window(1)).is_equal(10.0)

func test_add_multiple_glory() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 2, &"village")
	assert_that(tracker.glory_last_window(2)).is_equal(15.0)

func test_add_zero_glory() -> void:
	tracker.add_glory(0.0, 1, &"test")
	assert_that(tracker.glory_last_window(1)).is_equal(0.0)

func test_add_negative_glory() -> void:
	tracker.add_glory(-5.0, 1, &"test")
	assert_that(tracker.glory_last_window(1)).is_equal(0.0)


func test_glory_window_expires() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	assert_that(tracker.glory_last_window(7)).is_equal(10.0)
	assert_that(tracker.glory_last_window(8)).is_equal(0.0)

func test_glory_window_partial() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 5, &"village")
	assert_that(tracker.glory_last_window(8)).is_equal(5.0)

func test_glory_window_all_expired() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 2, &"village")
	assert_that(tracker.glory_last_window(100)).is_equal(0.0)


func test_prune_removes_old_events() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 5, &"village")
	tracker.prune(8)
	assert_that(tracker.glory_last_window(8)).is_equal(5.0)

func test_prune_empty_tracker() -> void:
	tracker.prune(1)
	assert_that(tracker.glory_last_window(1)).is_equal(0.0)


func test_window_size_minimum() -> void:
	var t := _GloryTracker.new(0)
	assert_that(t._window).is_equal(1)

func test_window_size_negative() -> void:
	var t := _GloryTracker.new(-5)
	assert_that(t._window).is_equal(1)

func test_custom_window_size() -> void:
	var t := _GloryTracker.new(3)
	assert_that(t._window).is_equal(3)
	t.add_glory(10.0, 1, &"test")
	assert_that(t.glory_last_window(3)).is_equal(10.0)
	assert_that(t.glory_last_window(4)).is_equal(0.0)

func test_default_window_is_cycle_size() -> void:
	assert_that(tracker._window).is_equal(GameNumbers.CITY_CYCLE_TURNS)
