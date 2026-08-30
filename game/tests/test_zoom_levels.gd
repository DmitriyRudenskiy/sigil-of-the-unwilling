extends "res://tests/test_base.gd"

const _Settings = preload("res://core/Settings.gd")

var settings: Object

func before_each() -> void:
	settings = _Settings.new()

func after_each() -> void:
	if settings != null:
		settings.free()
		settings = null


# --- Zoom levels spec ---

func test_zoom_levels_count() -> void:
	assert_eq(_Settings.ZOOM_LEVELS.size(), 9, "9 levels")

func test_zoom_levels_order() -> void:
	var levels := _Settings.ZOOM_LEVELS
	for i in levels.size() - 1:
		assert_true(levels[i] < levels[i + 1], "ascending at %d" % i)

func test_zoom_default() -> void:
	assert_eq(_Settings.DEFAULT_ZOOM_INDEX, 2, "default index=2")
	assert_eq(_Settings.ZOOM_LEVELS[_Settings.DEFAULT_ZOOM_INDEX], 1.0, "default=1.0")

func test_zoom_min_max() -> void:
	assert_eq(_Settings.ZOOM_LEVELS[0], 0.5, "min=0.5")
	assert_eq(_Settings.ZOOM_LEVELS[-1], 2.25, "max=2.25")

func test_zoom_get() -> void:
	settings.zoom_index = 0
	assert_eq(settings.get_zoom(), 0.5, "index 0 → 0.5")
	settings.zoom_index = 4
	assert_eq(settings.get_zoom(), 1.25, "index 4 → 1.25")
	settings.zoom_index = 8
	assert_eq(settings.get_zoom(), 2.25, "index 8 → 2.25")

func test_zoom_step_up() -> void:
	settings.zoom_index = 0
	assert_eq(settings.step_zoom(1), 1, "step up from 0")
	assert_eq(settings.zoom_index, 1, "index now 1")

func test_zoom_step_down() -> void:
	settings.zoom_index = 5
	assert_eq(settings.step_zoom(-1), -1, "step down from 5")
	assert_eq(settings.zoom_index, 4, "index now 4")

func test_zoom_step_up_at_max() -> void:
	settings.zoom_index = 8
	assert_eq(settings.step_zoom(1), 0, "no step at max")
	assert_eq(settings.zoom_index, 8, "stays at 8")

func test_zoom_step_down_at_min() -> void:
	settings.zoom_index = 0
	assert_eq(settings.step_zoom(-1), 0, "no step at min")
	assert_eq(settings.zoom_index, 0, "stays at 0")

func test_zoom_set_exact() -> void:
	settings.set_zoom(1.25)
	assert_eq(settings.zoom_index, 4, "set 1.25 → index 4")
	settings.set_zoom(2.25)
	assert_eq(settings.zoom_index, 8, "set 2.25 → index 8")

func test_zoom_values_exact() -> void:
	var expected := [0.5, 0.7, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25]
	for i in expected.size():
		assert_eq(_Settings.ZOOM_LEVELS[i], expected[i], "level[%d]" % i)
