extends BaseTest

# T-147 (перенос экрана настроек в тему). Технический перенос: add_theme_stylebox_override
# на узлах экрана рисовал StyleBoxFlat, который сильнее темы, — кит шага 4 не мог
# проявиться на этом экране ни при каком её изменении. Стиль переехал в
# game_theme.tres (PanelSettings, SettingsButton) с нулевой визуальной дельтой:
# макета у экрана нет, дизайн не меняется, меняется только владелец стиля.
#
# Отсюда и проверки:
#   1) на узлах нет stylebox-переопределений (AC1);
#   2) узлы переведены на зарегистрированные варианты темы (AC3 — стиль ищется в теме);
#   3) тема отдаёт ровно те значения, что рисовал снятый override (AC2 как «не хуже»:
#      побитово тот же стиль → тот же пиксел);
#   4) негативный контроль: незарегистрированный тип носителя не резолвит.

const _SCREEN_SCENE := preload("res://scenes/ui/settings_screen.tscn")
const _THEME := preload("res://assets/theme/game_theme.tres")

const _BTN_STATES := ["normal", "hover", "pressed"]

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


## Экран инициализирует контент только получив настройки (см. _ready), поэтому
## setup() обязателен: без него _apply_style() не вызывается и тест был бы пустым.
func _mk_screen() -> Control:
	var screen: Control = _SCREEN_SCENE.instantiate()
	var settings := SettingsAutoload.new()
	_nodes.append(settings)
	screen.setup(settings)
	_nodes.append(screen)
	get_tree().root.add_child(screen)
	return screen


func _settings_buttons(screen: Control) -> Array[Button]:
	var out: Array[Button] = []
	for btn_name in ["ApplyButton", "ResetButton", "CancelButton"]:
		out.append(screen.get_node("Panel/Box/ButtonRow/" + btn_name) as Button)
	return out


func test_settings_screen_has_no_stylebox_overrides() -> void:
	var screen := _mk_screen()
	var panel := screen.get_node("Panel") as PanelContainer
	var pov := ThemeCarrierGuard.stylebox_overrides(panel)
	assert_int(pov.size()).is_equal(0) \
		.override_failure_message(
			"на панели экрана настроек висит stylebox-переопределение: %s" % ", ".join(pov.keys())
		)
	for btn in _settings_buttons(screen):
		var bov := ThemeCarrierGuard.stylebox_overrides(btn)
		assert_int(bov.size()).is_equal(0) \
			.override_failure_message(
				"на кнопке экрана настроек висит stylebox-переопределение: %s" % ", ".join(bov.keys())
			)


func test_settings_nodes_take_carrier_from_theme() -> void:
	var screen := _mk_screen()
	var panel := screen.get_node("Panel") as PanelContainer
	assert_str(str(panel.theme_type_variation)).is_equal("PanelSettings") \
		.override_failure_message("панель не переведена на вариант темы PanelSettings")
	for btn in _settings_buttons(screen):
		assert_str(str(btn.theme_type_variation)).is_equal("SettingsButton") \
			.override_failure_message("кнопка не переведена на вариант темы SettingsButton")


## Тема обязана отдавать те же значения, что рисовал снятый override: иначе перенос
## меняет пиксел, а обещанная нулевая визуальная дельта нарушается.
func test_theme_carries_the_removed_style_values() -> void:
	var screen := _mk_screen()
	var panel := screen.get_node("Panel") as PanelContainer
	var plate: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_object(plate).is_not_null().override_failure_message("панель не получила носитель из темы")
	assert_bool(plate.bg_color == ThemeConfig.C_PANEL_DARK).is_true() \
		.override_failure_message("фон панели отличается от снятого override")
	assert_bool(plate.border_color == ThemeConfig.C_PANEL_BORDER_ALT).is_true() \
		.override_failure_message("рамка панели отличается от снятого override")
	assert_int(plate.border_width_left).is_equal(2) \
		.override_failure_message("толщина рамки панели должна остаться 2")

	var expected := {
		"normal": ThemeConfig.C_BTN_NORMAL,
		"hover": ThemeConfig.C_BTN_HOVER,
		"pressed": ThemeConfig.C_BTN_PRESSED,
	}
	for btn in _settings_buttons(screen):
		for state in _BTN_STATES:
			var sb: StyleBoxFlat = btn.get_theme_stylebox(state) as StyleBoxFlat
			assert_object(sb).is_not_null() \
				.override_failure_message("кнопка не получила stylebox %s из темы" % state)
			assert_bool(sb.bg_color == expected[state]).is_true() \
				.override_failure_message("фон кнопки в состоянии %s отличается от снятого override" % state)
			assert_bool(sb.border_color == ThemeConfig.C_BTN_BORDER).is_true() \
				.override_failure_message("рамка кнопки в состоянии %s отличается от снятого override" % state)
			assert_int(sb.border_width_left).is_equal(1) \
				.override_failure_message("толщина рамки кнопки должна остаться 1")
			assert_int(sb.corner_radius_top_left).is_equal(6) \
				.override_failure_message("скругление кнопки должен остаться 6")


# T-227 (С-2): проверки «в исходниках нет обхода темы» и «несуществующий тип не
# резолвит» переехали в res://tests/unit/ui/test_theme_source_scan.gd (скан всего
# production-кода, а не «своих» файлов) и res://tests/unit/ui/test_theme_variation_matrix.gd
# (контракт от носителя: все 70 вариантов темы, а не три экрана, которым завели файл).
# Здесь остались только проверки, привязанные к этому экрану: что ТЕМА отдаёт ровно те
# значения, которые рисовал снятый override (AC2), и что живой узел экрана не получает
# переопределений в рантайме.
