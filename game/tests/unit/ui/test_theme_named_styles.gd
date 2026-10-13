extends BaseTest

# UI-3 шаг 0: тема несёт именованные стили (docs/13-art-bible §5–6),
# экраны на них ещё не переведены.

const _Theme := preload("res://assets/theme/game_theme.tres")

func test_named_label_styles_present() -> void:
	for v in ["LabelBody", "LabelSecondary", "LabelStrong", "LabelHeading",
			"LabelTitle", "LabelSuccess", "LabelError", "LabelInfo",
			"LabelNumber", "LabelNumberLg"]:
		assert_bool(_Theme.get_type_variation_list("Label").has(v)).is_true().override_failure_message(
			"нет type variation " + v)
	assert_bool(_Theme.get_type_variation_list("Button").has("BibleButton")).is_true()

func test_scale_and_fonts() -> void:
	assert_int(_Theme.get_font_size("font_size", "LabelBody")).is_equal(20)
	assert_int(_Theme.get_font_size("font_size", "LabelSecondary")).is_equal(16)
	assert_int(_Theme.get_font_size("font_size", "LabelStrong")).is_equal(24)
	assert_int(_Theme.get_font_size("font_size", "LabelHeading")).is_equal(32)
	assert_int(_Theme.get_font_size("font_size", "LabelTitle")).is_equal(48)
	assert_object(_Theme.get_font("font", "LabelBody")).is_not_null()
	assert_object(_Theme.get_font("font", "LabelNumber")).is_not_null()
	# моно отличается от serif
	assert_bool(_Theme.get_font("font", "LabelNumber") != _Theme.get_font("font", "LabelBody")).is_true()

func test_bible_button_states() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_object(_Theme.get_stylebox(state, "BibleButton")).is_not_null().override_failure_message(
			"BibleButton: нет состояния " + state)
	# pressed сдвигает контент +1 px (геометрическое различие)
	var n: StyleBox = _Theme.get_stylebox("normal", "BibleButton")
	var p: StyleBox = _Theme.get_stylebox("pressed", "BibleButton")
	assert_bool(p.content_margin_top > n.content_margin_top).is_true()
