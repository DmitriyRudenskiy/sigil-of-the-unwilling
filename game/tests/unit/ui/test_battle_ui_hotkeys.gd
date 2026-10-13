extends BaseTest

const _BattleUIScene := preload("res://scenes/ui/battle_ui.tscn")

var _ui: Node = null


func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null


func _press(key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	_ui._unhandled_input(ev)


func _setup() -> void:
	var ui: Node = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)


func test_history_hotkeys() -> void:
	_setup()
	_press(KEY_H)
	assert_bool(_ui._history_panel.visible).is_true().override_failure_message(
		"docs/14 §5: H открывает историю")
	_press(KEY_H)
	assert_bool(_ui._history_panel.visible).is_false()
	# ↑/↓ листают лог
	_ui.set_status("первая")
	_ui.set_status("вторая")
	_press(KEY_UP)
	assert_str(_ui._log_line.text).is_equal("первая")
	_press(KEY_DOWN)
	assert_str(_ui._log_line.text).is_equal("вторая")


func test_escape_priority() -> void:
	_setup()
	# открытая панель → закрыть
	_ui._history_panel.visible = true
	_press(KEY_ESCAPE)
	assert_bool(_ui._history_panel.visible).is_false()
	assert_bool(_ui._settings_screen.visible).is_false().override_failure_message(
		"docs/14 §5: Esc при открытой панели закрывает её, а не открывает настройки")
	# иначе — настройки (путь кнопки: settings_requested → контроллер → open_settings)
	var asked := [false]
	_ui.settings_requested.connect(func() -> void: asked[0] = true)
	_press(KEY_ESCAPE)
	assert_bool(asked[0]).is_true().override_failure_message(
		"Esc без открытых панелей обязан просить настройки")
	# открытые настройки → Esc закрывает
	_ui._settings_screen.visible = true
	_press(KEY_ESCAPE)
	assert_bool(_ui._settings_screen.visible).is_false()


func test_action_hotkeys_emit() -> void:
	_setup()
	var fired: Array[String] = []
	for sig in ["skip_requested", "defend_requested", "wait_requested", "attack_mode_requested"]:
		_ui.connect(sig, func() -> void: fired.append(sig))
	_press(KEY_S)
	_press(KEY_D)
	_press(KEY_W)
	_press(KEY_A)
	assert_int(fired.size()).is_equal(4)


func test_final_accepts_f() -> void:
	_setup()
	_ui.show_result(BattleState.Side.ATTACKER, 3, 0)
	var accepted := [false]
	_ui.result_accepted.connect(func() -> void: accepted[0] = true)
	_press(KEY_F)
	assert_bool(accepted[0]).is_true().override_failure_message(
		"docs/14 §4.F: финал подтверждается «Продолжить» (F — клавиша подтверждения)")
