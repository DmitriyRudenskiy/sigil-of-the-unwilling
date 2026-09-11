extends BaseTest


var settings: Object

func before_test() -> void:
	settings = SettingsAutoload.new()

func after_test() -> void:
	if settings != null:
		settings.free()
		settings = null

func test_zoom_levels_count() -> void:
	assert_that(SettingsAutoload.ZOOM_LEVELS.size()).is_equal(9)

func test_zoom_levels_order() -> void:
	var levels := SettingsAutoload.ZOOM_LEVELS
	for i in levels.size() - 1:
		assert_bool(levels[i] < levels[i + 1]).is_true()

func test_zoom_default() -> void:
	assert_that(SettingsAutoload.DEFAULT_ZOOM_INDEX).is_equal(2)
	assert_that(SettingsAutoload.ZOOM_LEVELS[SettingsAutoload.DEFAULT_ZOOM_INDEX]).is_equal(1.0)

func test_zoom_min_max() -> void:
	assert_that(SettingsAutoload.ZOOM_LEVELS[0]).is_equal(0.5)
	assert_that(SettingsAutoload.ZOOM_LEVELS[-1]).is_equal(2.25)

func test_zoom_get() -> void:
	settings.zoom_index = 0
	assert_that(settings.get_zoom()).is_equal(0.5)
	settings.zoom_index = 4
	assert_that(settings.get_zoom()).is_equal(1.25)
	settings.zoom_index = 8
	assert_that(settings.get_zoom()).is_equal(2.25)

func test_zoom_step_up() -> void:
	settings.zoom_index = 0
	assert_that(settings.step_zoom(1)).is_equal(1)
	assert_that(settings.zoom_index).is_equal(1)

func test_zoom_step_down() -> void:
	settings.zoom_index = 5
	assert_that(settings.step_zoom(-1)).is_equal(-1)
	assert_that(settings.zoom_index).is_equal(4)

func test_zoom_step_up_at_max() -> void:
	settings.zoom_index = 8
	assert_that(settings.step_zoom(1)).is_equal(0)
	assert_that(settings.zoom_index).is_equal(8)

func test_zoom_step_down_at_min() -> void:
	settings.zoom_index = 0
	assert_that(settings.step_zoom(-1)).is_equal(0)
	assert_that(settings.zoom_index).is_equal(0)

func test_zoom_set_exact() -> void:
	settings.set_zoom(1.25)
	assert_that(settings.zoom_index).is_equal(4)
	settings.set_zoom(2.25)
	assert_that(settings.zoom_index).is_equal(8)

func test_zoom_values_exact() -> void:
	var expected := [0.5, 0.7, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.25]
	for i in expected.size():
		assert_that(SettingsAutoload.ZOOM_LEVELS[i]).is_equal(expected[i])
