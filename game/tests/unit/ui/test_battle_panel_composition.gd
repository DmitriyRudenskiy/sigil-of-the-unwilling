extends BaseTest

# alpha-battle-field 4.2: состав нижней панели = список команд описания
# владельца. Проверка — «обязательные присутствуют + капитуляции нет», а не
# точное равенство множества: у «Атаки», «Пропуска» и «Спасения» носитель
# механики есть, а спека снимает только команды без носителя
# (`specs/battle-hud/spec.md`, «Команда без механики не макетируется»).
# Срезать рабочие команды — решение владельца, не деталь раскладки.

const _BATTLE_UI_SCENE := preload("res://scenes/ui/battle_ui.tscn")

# команда → путь узла (носитель раскладки — сцена, поэтому путь, а не имя)
const _COMMANDS := {
	"опции боя": "bottom_bar/bar_box/left_box/settings_btn",
	"отступить": "bottom_bar/bar_box/left_box/retreat_btn",
	"автобой": "bottom_bar/bar_box/left_box/auto_btn",
	"книга заклинаний": "bottom_bar/bar_box/right_box/spellbook_btn",
	"отмена": "bottom_bar/bar_box/right_box/cancel_btn",
	"ждать": "bottom_bar/bar_box/right_box/wait_btn",
	"защищаться": "bottom_bar/bar_box/right_box/defend_btn",
}

var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null

func _mk_ui() -> BattleUI:
	var ui: BattleUI = _BATTLE_UI_SCENE.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	return ui

func test_panel_has_every_command_of_the_owner_list() -> void:
	var ui := _mk_ui()
	for command in _COMMANDS:
		var btn := ui.get_node_or_null(NodePath(_COMMANDS[command])) as Button
		assert_object(btn).is_not_null().override_failure_message("команда «%s» на панели" % command)
		if btn != null:
			assert_bool(btn.visible).is_true().override_failure_message("«%s» видна" % command)

func test_panel_has_no_surrender() -> void:
	# Капитуляция — кампанийный слой (T-282): команды нет, значит нет и кнопки.
	var ui := _mk_ui()
	var stack: Array[Node] = [ui]
	var found: Array[String] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if String(c.name).to_lower().contains("surrender") or String(c.name).to_lower().contains("capitul"):
				found.append(str(c.get_path()))
			stack.append(c)
	assert_array(found).is_empty().override_failure_message("капитуляция не рендерится: %s" % found)

func test_message_window_has_scroll_arrows() -> void:
	var ui := _mk_ui()
	assert_object(ui._log_up_btn).is_not_null()
	assert_object(ui._log_down_btn).is_not_null()
	assert_str(ui._log_up_btn.text).is_equal("▲")
	assert_str(ui._log_down_btn.text).is_equal("▼")
	# Стрелки — часть окна сообщений, а не отдельный кластер: сидят в той же строке.
	assert_object(ui._log_up_btn.get_parent()).is_same(ui._log_line.get_parent())

func test_new_commands_block_with_the_rest() -> void:
	# Передача хода/команды глушит панель целиком (`set_controls_enabled`);
	# «Автобой» и «Отмена» — команды боя, а не навигация, поэтому глохнут вместе.
	var ui := _mk_ui()
	ui.set_controls_enabled(false)
	assert_bool(ui._auto_btn.disabled).is_true()
	assert_bool(ui._cancel_btn.disabled).is_true()
	ui.set_controls_enabled(true)
	assert_bool(ui._auto_btn.disabled).is_false()
	assert_bool(ui._cancel_btn.disabled).is_false()
