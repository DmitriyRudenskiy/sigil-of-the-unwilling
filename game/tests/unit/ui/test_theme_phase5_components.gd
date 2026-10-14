extends BaseTest

# Фаза 5 (гайд §9, строки П-1/П-2/П-3/К-1/К-3/К-5/К-6/К-7/К-8/К-9).
#
# Тема обязана объявлять компоненты канона, а не только Label-вариации: до фазы 5
# Slider/LineEdit/CheckBox/вкладки/тултип рисовались дефолтной темой движка
# (синее семейство + чужая геометрия). Тест держит три инварианта:
#   1) компоненты объявлены во всех состояниях канона (К-1/К-3/К-5/К-6);
#   2) геометрия и тени не уехали: 9-слис = толщина рамки в текстуре (К-8/К-9),
#      тень — сажа, а не золото (К-7), углы панелей/слотов прямые;
#   3) синего семейства П-1 в тронутых типах не осталось (ни в константах кода,
#      ни в цветах темы).
# Кегли и шкала шрифтов здесь НЕ проверяются: типографика — один акт билета
# UI-AC7 (Т-1/Т-4/Т-5), а не фаза 5.

const _theme := preload("res://assets/theme/game_theme.tres")
const _SOOT := Color(0, 0, 0, 0.6)  # §3: тень — сажа rgba(0,0,0,0.6)

# ─── К-1: фокус кнопки ────────────────────────────────────────────────────────

func test_button_focus_state_declared() -> void:
	# до фазы 5 Button/styles/focus отсутствовал → фокус с клавиатуры невидим
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_object(_theme.get_stylebox(state, "Button")).is_not_null().override_failure_message(
			"Button: нет состояния " + state)
	var focus: StyleBoxFlat = _theme.get_stylebox("focus", "Button")
	assert_bool(focus.draw_center).is_false().override_failure_message(
		"фокус кнопки не должен заливать поле")
	assert_that(focus.border_width_left).is_equal(2)

# ─── К-3: Slider ─────────────────────────────────────────────────────────────

func test_slider_declared_for_both_orientations() -> void:
	# тип темы — HSlider/VSlider (Slider абстрактен); имена темы 4.7:
	# slider, grabber_area, grabber_area_highlight + grabber*
	for control in ["HSlider", "VSlider"]:
		for style in ["slider", "grabber_area", "grabber_area_highlight"]:
			assert_object(_theme.get_stylebox(style, control)).is_not_null().override_failure_message(
				control + ": нет стиля " + style)
		for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
			assert_object(_theme.get_icon(icon, control)).is_not_null().override_failure_message(
				control + ": нет иконки " + icon)
	assert_str((_theme.get_stylebox("slider", "HSlider") as StyleBoxTexture)
		.texture.resource_path).contains("slider_track.png")

# ─── К-6: LineEdit / CheckBox / вкладки / тултип ─────────────────────────────

func test_lineedit_declared() -> void:
	for style in ["normal", "focus", "read_only"]:
		assert_object(_theme.get_stylebox(style, "LineEdit")).is_not_null().override_failure_message(
			"LineEdit: нет стиля " + style)
	# имена темы 4.7 — font_uneditable_color и caret_color (не font_readonly_color
	# / cursor_color); выделение тоже объявлено: по умолчанию оно синее
	for color in ["font_color", "font_placeholder_color", "font_uneditable_color",
			"font_selected_color", "caret_color", "selection_color"]:
		assert_object(_theme.get_color(color, "LineEdit")).is_not_null().override_failure_message(
			"LineEdit: нет цвета " + color)

func test_checkbox_declared() -> void:
	for style in ["normal", "hover", "pressed", "focus"]:
		assert_object(_theme.get_stylebox(style, "CheckBox")).is_not_null().override_failure_message(
			"CheckBox: нет стиля " + style)
	for icon in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		assert_object(_theme.get_icon(icon, "CheckBox")).is_not_null().override_failure_message(
			"CheckBox: нет иконки " + icon)
	# §4.5 зона нажатия ≥ 40 px, а не 20: иконка 20 + верх/низ по 10
	var normal: StyleBox = _theme.get_stylebox("normal", "CheckBox")
	assert_that(int(normal.content_margin_top + normal.content_margin_bottom + 20)) \
		.is_greater_equal(40)

func test_tabs_declared_on_tabbar_and_tabcontainer() -> void:
	# TabContainer перекладывает стили ярлыков внутренней TabBar своими overrides,
	# поэтому канон обязан лежать на обоих типах — иначе вкладки внутри
	# TabContainer остаются дефолтной темы (проверено кадром kitchen-sink).
	for control in ["TabBar", "TabContainer"]:
		for style in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
			assert_object(_theme.get_stylebox(style, control)).is_not_null().override_failure_message(
				control + ": нет стиля " + style)
		for color in ["font_selected_color", "font_unselected_color", "font_hovered_color",
				"font_disabled_color"]:
			assert_object(_theme.get_color(color, control)).is_not_null().override_failure_message(
				control + ": нет цвета " + color)
	assert_object(_theme.get_stylebox("panel", "TabContainer")).is_not_null()

func test_tooltip_declared() -> void:
	var panel: StyleBoxFlat = _theme.get_stylebox("panel", "TooltipPanel")
	assert_object(panel).is_not_null()
	assert_that(panel.border_width_left).is_equal(1)  # §3: рамка 1 px C_GOLD
	assert_object(_theme.get_color("font_color", "TooltipLabel")).is_not_null()

# ─── К-5: состояния армейского слота ─────────────────────────────────────────

func test_army_slot_states_declared() -> void:
	# §4.2 требует empty/hover/valid-target/invalid-target/disabled. Фаза 5 закрыла
	# hover/selected/disabled (формулировка строки К-5 реестра); valid/invalid-target
	# и применение стейтов в сценах — билет UI-5 (docs/mvp/TICKETS.md).
	for style in ["army_slot", "army_slot_hover", "army_slot_selected", "army_slot_disabled"]:
		var sb: StyleBoxFlat = _theme.get_stylebox(style, "Panel")
		assert_object(sb).is_not_null().override_failure_message("нет стиля " + style)
		assert_that(sb.corner_radius_top_left).is_equal(0)  # §4.2: радиус 0
	var hover: StyleBoxFlat = _theme.get_stylebox("army_slot_hover", "Panel")
	var base: StyleBoxFlat = _theme.get_stylebox("army_slot", "Panel")
	assert_bool(hover.border_color != base.border_color).is_true().override_failure_message(
		"hover не отличается от normal")

# ─── К-7: тень — сажа, углы — прямые ─────────────────────────────────────────

func test_shadows_are_soot_not_gold() -> void:
	var shadowed: Array = [
		["Panel", "window"], ["Panel", "outline"], ["Panel", "doll_slot"],
		["Panel", "backpack_slot"], ["Panel", "side_slot"], ["Panel", "army_slot"],
		["TooltipPanel", "panel"],
	]
	for entry in shadowed:
		var sb: StyleBoxFlat = _theme.get_stylebox(entry[1], entry[0])
		assert_object(sb).is_not_null().override_failure_message("%s/%s потерян" % entry)
		assert_bool(sb.shadow_color.is_equal_approx(_SOOT)).is_true().override_failure_message(
			"%s/%s: тень %s, канон — сажа rgba(0,0,0,0.6)" % [entry[0], entry[1], sb.shadow_color])
		assert_that(sb.shadow_offset).is_equal(Vector2(0, 2))

func test_panel_and_slot_corners_are_square() -> void:
	for style in ["window", "slot_thin", "label", "backpack_slot", "side_slot", "army_slot"]:
		var sb: StyleBoxFlat = _theme.get_stylebox(style, "Panel")
		assert_that(sb.corner_radius_top_left).is_equal(0).override_failure_message(
			"Panel/%s: §3 требует прямые углы" % style)

# ─── К-8 / К-9: 9-слис и носитель слота ──────────────────────────────────────

func test_nine_slice_margins_match_frame_thickness() -> void:
	# маржа = толщина рамки в текстуре (8 px для 32×32), иначе ядро схлопывается
	# и центр рисуется растянутым пикселем (К-8 — находка фазы 5)
	for style in ["panel", "slot"]:
		var sb: StyleBoxTexture = _theme.get_stylebox(style, "Panel")
		assert_that(int(sb.texture_margin_left)).is_equal(8).override_failure_message(
			"Panel/%s: texture_margin должен равняться толщине рамки (8)" % style)
		assert_that(int(sb.texture_margin_right)).is_equal(8)
	# внутренний отступ панели — PAD 16 (§1.3); слот 40×40 таких полей не вмещает,
	# у него контент прижат к рамке (8 = толщина)
	assert_that(int((_theme.get_stylebox("panel", "Panel") as StyleBoxTexture)
		.content_margin_left)).is_equal(16)
	assert_that(int((_theme.get_stylebox("slot", "Panel") as StyleBoxTexture)
		.content_margin_left)).is_equal(8)

func test_slot_uses_slot_texture_not_panel() -> void:
	# К-9: slot_bg.png лежал в репо, тема рисовала слот панелью
	var slot: StyleBoxTexture = _theme.get_stylebox("slot", "Panel")
	assert_str(slot.texture.resource_path).contains("slot_bg.png")

# ─── П-1: синее семейство не должно вернуться ────────────────────────────────

func test_no_blue_left_in_phase5_theme_types() -> void:
	for control in ["Button", "HSlider", "VSlider", "LineEdit", "CheckBox", "CheckButton",
			"TabBar", "TabContainer", "TooltipPanel", "TooltipLabel", "Panel", "ProgressBar"]:
		for color in _theme_colors_of(control):
			assert_bool(_is_blue_family(color)).is_false().override_failure_message(
				"%s: синий цвет %s (находка П-1)" % [control, color])

func test_theme_config_button_family_is_wood_not_blue() -> void:
	# П-1 в коде: ThemeConfig.C_BTN_* кормят процедурные кнопки (battle_ui и др.)
	for entry in [["normal", ThemeConfig.C_BTN_NORMAL], ["hover", ThemeConfig.C_BTN_HOVER],
			["pressed", ThemeConfig.C_BTN_PRESSED], ["border", ThemeConfig.C_BTN_BORDER],
			["shadow", ThemeConfig.C_BTN_SHADOW]]:
		assert_bool(_is_blue_family(entry[1])).is_false().override_failure_message(
			"C_BTN_%s синий: %s" % [entry[0].to_upper(), entry[1]])
	# П-3: успех — C_OK #7aa85a, а не кислотный #33ff66
	assert_bool(ThemeConfig.C_TEXT_SUCCESS.is_equal_approx(Color("#7aa85a"))).is_true()
	# П-2: обводка — латунь, а не жёлтый #ffff00
	assert_bool(not ThemeConfig.C_GOLD_OUTLINE.is_equal_approx(Color(1, 1, 0, 0.6))).is_true()


func _theme_colors_of(control: String) -> Array[Color]:
	var out: Array[Color] = []
	for item in _theme.get_color_list(control):
		out.append(_theme.get_color(item, control))
	for item in _theme.get_stylebox_list(control):
		var sb: StyleBox = _theme.get_stylebox(item, control)
		if sb is StyleBoxFlat:
			out.append((sb as StyleBoxFlat).bg_color)
			out.append((sb as StyleBoxFlat).border_color)
			out.append((sb as StyleBoxFlat).shadow_color)
	return out


## Синий = сине-доминантный и достаточно яркий; чернильный C_INK #090b0e
## канонный (почти чёрный), поэтому отсечён по яркости.
func _is_blue_family(c: Color) -> bool:
	var brightest: float = maxf(c.r, maxf(c.g, c.b))
	return c.b > c.r * 1.2 and c.b > c.g * 1.2 and brightest > 0.15
