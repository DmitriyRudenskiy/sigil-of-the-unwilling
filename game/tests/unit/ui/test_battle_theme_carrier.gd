extends BaseTest

# T-147 (боевой срез): носитель плит боевого экрана приходит из темы, а не из
# add_theme_stylebox_override на узле. Переопределение узла сильнее темы, поэтому
# пока нижняя панель и панель истории получали stylebox кодом, кит шага 4 не мог
# проявиться на них ни при каком изменении темы.
#
# Проверяем не «ожидаемый StyleBoxFlat» (AC3 тикета), а три факта:
#   1) на узле нет stylebox-переопределения;
#   2) узел переведён на зарегистрированный вариант темы;
#   3) резолвится тот же StyleBoxTexture_panel, что лежал в override — то есть
#      пиксельно ничего не изменилось, изменился только владелец стиля.

const _BATTLE_UI_SCENE := preload("res://scenes/ui/battle_ui.tscn")
const _SPELLBOOK_SCENE := preload("res://scenes/ui/battle_spellbook_panel.tscn")
const _THEME := preload("res://assets/theme/game_theme.tres")

var _nodes: Array[Node] = []

func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

func _mk_ui() -> BattleUI:
	var ui: BattleUI = _BATTLE_UI_SCENE.instantiate()
	_nodes.append(ui)
	get_tree().root.add_child(ui)
	return ui

func test_battle_panels_take_carrier_from_theme() -> void:
	var ui: BattleUI = _mk_ui()
	for pair in [["нижняя панель", ui._bottom_bar], ["панель истории", ui._history_panel]]:
		var panel: PanelContainer = pair[1]
		var ov := ThemeCarrierGuard.stylebox_overrides(panel)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message("%s: на узле висит stylebox-переопределение: %s" % [pair[0], ", ".join(ov.keys())])
		assert_str(str(panel.theme_type_variation)).is_equal("PanelPlate") \
			.override_failure_message("%s: панель не переведена на вариант темы PanelPlate" % pair[0])
		assert_bool(ThemeCarrierGuard.resolves_carrier(panel, _THEME, "panel", "PanelPlate")).is_true() \
			.override_failure_message(
				"%s: резолвится не тот носитель, что лежал в override (вид изменится)" % pair[0])

## Вариант темы обязан быть зарегистрирован с base_type: на «Panel» (мешок стилей,
## не тип виджета) движок носитель не резолвит — отдаёт дефолт движка. Гард на
## регрессивный соблазн «упрощу до theme_type_variation = "Panel"».
func test_unregistered_type_does_not_resolve_carrier() -> void:
	var panel := PanelContainer.new()
	_nodes.append(panel)
	panel.theme = _THEME
	panel.theme_type_variation = &"Panel"
	get_tree().root.add_child(panel)
	assert_bool(ThemeCarrierGuard.resolves_carrier(panel, _THEME, "panel", "Panel")).is_false() \
		.override_failure_message("«Panel» резолвится — замер устарел")
	assert_str(str(_THEME.get_type_variation_base("PanelPlate"))).is_equal("PanelContainer") \
		.override_failure_message("PanelPlate не зарегистрирован как вариант PanelContainer")

## Панель спелбука: `panel` — не stylebox-имя Control, движок на мокрое имя молчит,
## поэтому прежнее переопределение было мёртвым кодом. Проверяем, что его больше нет.
func test_spellbook_panel_has_no_dead_stylebox_overrides() -> void:
	var panel: BattleSpellbookPanel = _SPELLBOOK_SCENE.instantiate()
	_nodes.append(panel)
	get_tree().root.add_child(panel)
	assert_bool(panel.has_theme_stylebox("panel")).is_false() \
		.override_failure_message("на Control висит stylebox по имени, которое Control не читает")
	# Кнопочная ветка (_refresh) не драйвится: `panel` не является stylebox-именем и
	# для Button, а молчание движка на мокрое имя уже замерено в
	# test_theme_phase5_components.gd::test_wrong_item_name_is_silent_not_error.
	# Спелбук в этом тесте без темы (в дереве — root без темы), поэтому
	# has_theme_stylebox может быть правдой только по локальному переопределению.
	for btn in panel._spell_buttons:
		assert_bool(btn.has_theme_stylebox("panel")).is_false() \
			.override_failure_message("на Button висит stylebox по имени, которое Button не читает")
