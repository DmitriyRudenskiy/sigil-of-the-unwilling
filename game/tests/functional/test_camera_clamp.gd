extends BaseTest



func test_clamp_basic() -> void:
	assert_that(WorldCamera._clamp_val(5.0, 0.0, 10.0)).is_equal(5.0)
	assert_that(WorldCamera._clamp_val(-5.0, 0.0, 10.0)).is_equal(0.0)
	assert_that(WorldCamera._clamp_val(15.0, 0.0, 10.0)).is_equal(10.0)

func test_clamp_inverted_centers() -> void:
	assert_that(WorldCamera._clamp_val(0.0, 100.0, 0.0)).is_equal(50.0)
	assert_that(WorldCamera._clamp_val(999.0, 100.0, 0.0)).is_equal(50.0)

func test_clamp_equal() -> void:
	assert_that(WorldCamera._clamp_val(0.0, 5.0, 5.0)).is_equal(5.0)

func test_zoom_2_25_large_map() -> void:
	assert_that(WorldCamera._clamp_val(500.0, 100.0, 1000.0)).is_equal(500.0)
	assert_that(WorldCamera._clamp_val(0.0, 100.0, 1000.0)).is_equal(100.0)

func test_all_zoom_levels_positive() -> void:
	for i in SettingsAutoload.ZOOM_LEVELS.size():
		assert_bool(SettingsAutoload.ZOOM_LEVELS[i] > 0).is_true()

