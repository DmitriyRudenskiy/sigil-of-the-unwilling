extends BaseTest

## WCAG-гард палитры экрана города. Тоны читаются из модуля стиля (T-300, подсрез 3):
## раньше тест сверял пары локального словаря `CityScreen.PALETTE`, то есть проверял
## палитру, не видя, чем экран реально красит. Заодно в список попали два тона, у которых
## в старом словаре имени не было (заглушка доски и строка легенды) — они красились
## литералами и WCAG-проверки не проходили.

func test_screen_palette_text_tokens_meet_wcag_aa_on_supported_surfaces() -> void:
	var text_tokens: Array[Color] = [
		ThemeConfig.C_CITY_TEXT,
		ThemeConfig.C_CITY_TEXT_MUTED,
		ThemeConfig.C_CITY_GOLD,
		ThemeConfig.C_CITY_WARNING,
		ThemeConfig.C_CITY_SUCCESS,
		ThemeConfig.C_CITY_TEXT_BODY,
		ThemeConfig.C_CITY_METRIC,
		ThemeConfig.C_CITY_PLACEHOLDER,
		ThemeConfig.C_CITY_LEGEND,
	]
	var surfaces: Array[Color] = [
		ThemeConfig.C_CITY_BG,
		ThemeConfig.C_CITY_PANEL,
		ThemeConfig.C_CITY_BOARD,
	]
	for text_color in text_tokens:
		for surface in surfaces:
			assert_bool(CityScreen.contrast_ratio(text_color, surface) >= 4.5).override_failure_message(
				"contrast %.2f is below WCAG AA" % CityScreen.contrast_ratio(text_color, surface)).is_true()

func test_information_accent_is_contrast_safe_and_native_controls_have_visible_focus() -> void:
	for surface in [ThemeConfig.C_CITY_BG, ThemeConfig.C_CITY_PANEL, ThemeConfig.C_CITY_BOARD]:
		assert_bool(CityScreen.contrast_ratio(ThemeConfig.C_CITY_TEAL, surface) >= 4.5).is_true()
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
	assert_that(focus_style.border_color).is_equal(ThemeConfig.C_CITY_TEAL)
	for resource_button in screen._resource_buttons.values():
		assert_that((resource_button as Button).focus_mode).is_equal(Control.FOCUS_ALL)
		assert_that((resource_button as Button).get_theme_stylebox("focus")).is_not_null()
	assert_that(screen._population_metric.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_that(screen._housing_metric.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_that(screen._board.focus_mode).is_equal(Control.FOCUS_ALL)
	screen.queue_free()
	await get_tree().process_frame
