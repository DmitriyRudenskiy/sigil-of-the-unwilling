extends BaseTest

func test_screen_palette_text_tokens_meet_wcag_aa_on_supported_surfaces() -> void:
	var text_tokens: Array[Color] = [
		CityScreen.PALETTE.text_primary,
		CityScreen.PALETTE.text_muted,
		CityScreen.PALETTE.accent_gold,
		CityScreen.PALETTE.text_warning,
		CityScreen.PALETTE.text_success,
		CityScreen.PALETTE.text_body,
		CityScreen.PALETTE.text_metric,
	]
	var surfaces: Array[Color] = [
		CityScreen.PALETTE.background,
		CityScreen.PALETTE.panel,
		CityScreen.PALETTE.board,
	]
	for text_color in text_tokens:
		for surface in surfaces:
			assert_bool(CityScreen.contrast_ratio(text_color, surface) >= 4.5).override_failure_message(
				"contrast %.2f is below WCAG AA" % CityScreen.contrast_ratio(text_color, surface)).is_true()

func test_information_accent_is_contrast_safe_and_native_controls_have_visible_focus() -> void:
	for surface in [CityScreen.PALETTE.background, CityScreen.PALETTE.panel, CityScreen.PALETTE.board]:
		assert_bool(CityScreen.contrast_ratio(CityScreen.PALETTE.accent_teal, surface) >= 4.5).is_true()
	var screen := CityScreen.new()
	Engine.get_main_loop().root.add_child(screen)
	var shade := screen.get_node("ScreenShade") as ColorRect
	assert_float(shade.color.a).is_equal_approx(0.68, 0.001)
	var board_panel := screen.get_node("ScreenMargin/ScreenLayout/CityWorkspace/CityBoardPanel") as PanelContainer
	assert_float((board_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a).is_equal_approx(0.45, 0.001)
	assert_that(screen._category_buttons.size()).is_equal(CityScreen.CATALOG_CATEGORIES.size())
	assert_that(screen._category_buttons[0].focus_mode).is_equal(Control.FOCUS_ALL)
	var close_button := screen.get_node("ScreenMargin/ScreenLayout/ScreenHeader/HeaderRow/Close") as Button
	assert_that(close_button.focus_mode).is_equal(Control.FOCUS_ALL)
	var focus_style := close_button.get_theme_stylebox("focus") as StyleBoxFlat
	assert_that(focus_style).is_not_null()
	assert_that(focus_style.border_color).is_equal(CityScreen.PALETTE.accent_teal)
	for resource_button in screen._resource_buttons.values():
		assert_that((resource_button as Button).focus_mode).is_equal(Control.FOCUS_ALL)
		assert_that((resource_button as Button).get_theme_stylebox("focus")).is_not_null()
	assert_that(screen._population_metric.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_that(screen._housing_metric.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_that(screen._board.focus_mode).is_equal(Control.FOCUS_ALL)
	screen.queue_free()
	await get_tree().process_frame
