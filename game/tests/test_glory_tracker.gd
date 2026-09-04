extends "res://tests/gut_base.gd"
## Тесты GloryTracker: скользящее окно славы.

const _GloryTracker = preload("res://scripts/world/GloryTracker.gd")
const _CityBalance = preload("res://scripts/world/CityBalance.gd")

var tracker: RefCounted

func before_each() -> void:
	tracker = _GloryTracker.new()

# ==================== БАЗОВЫЕ ОПЕРАЦИИ ====================

func test_initial_glory_zero() -> void:
	assert_eq(tracker.glory_last_window(1), 0.0, "initial glory is 0")

func test_add_glory() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	assert_eq(tracker.glory_last_window(1), 10.0, "10 glory added")

func test_add_multiple_glory() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 2, &"village")
	assert_eq(tracker.glory_last_window(2), 15.0, "15 total glory")

func test_add_zero_glory() -> void:
	tracker.add_glory(0.0, 1, &"test")
	assert_eq(tracker.glory_last_window(1), 0.0, "zero not added")

func test_add_negative_glory() -> void:
	tracker.add_glory(-5.0, 1, &"test")
	assert_eq(tracker.glory_last_window(1), 0.0, "negative not added")

# ==================== СКОЛЬЗЯЩЕЕ ОКНО ====================

func test_glory_window_expires() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	# Окно 7 ходов: на ходу 8 событие хода 1 должно быть вне окна
	assert_eq(tracker.glory_last_window(7), 10.0, "still in window at turn 7")
	assert_eq(tracker.glory_last_window(8), 0.0, "expired at turn 8")

func test_glory_window_partial() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 5, &"village")
	# На ходу 8: событие хода 1 вне окна, событие хода 5 в окне
	assert_eq(tracker.glory_last_window(8), 5.0, "only recent glory")

func test_glory_window_all_expired() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 2, &"village")
	assert_eq(tracker.glory_last_window(100), 0.0, "all expired")

# ==================== PRUNE ====================

func test_prune_removes_old_events() -> void:
	tracker.add_glory(10.0, 1, &"battle")
	tracker.add_glory(5.0, 5, &"village")
	tracker.prune(8)
	# После prune на ходу 8: событие хода 1 удалено
	assert_eq(tracker.glory_last_window(8), 5.0, "old event pruned")

func test_prune_empty_tracker() -> void:
	tracker.prune(1)
	assert_eq(tracker.glory_last_window(1), 0.0, "empty tracker ok")

# ==================== ГРАНИЧНЫЕ СЛУЧАИ ====================

func test_window_size_minimum() -> void:
	var t := _GloryTracker.new(0)
	assert_eq(t._window, 1, "minimum window is 1")

func test_window_size_negative() -> void:
	var t := _GloryTracker.new(-5)
	assert_eq(t._window, 1, "negative window clamped to 1")

func test_custom_window_size() -> void:
	var t := _GloryTracker.new(3)
	assert_eq(t._window, 3, "custom window size")
	t.add_glory(10.0, 1, &"test")
	assert_eq(t.glory_last_window(3), 10.0, "in window")
	assert_eq(t.glory_last_window(4), 0.0, "out of window")

func test_default_window_is_cycle_size() -> void:
	assert_eq(tracker._window, _CityBalance.CITY_CYCLE_TURNS, "default window is cycle size")
