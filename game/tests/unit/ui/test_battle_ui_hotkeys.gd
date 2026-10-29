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
	_press(KEY_J)
	assert_bool(_ui._history_panel.visible).is_true().override_failure_message(
		"D-294: J открывает журнал")
	_press(KEY_J)
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
		"docs/14 §5: Esc при открытой панели закрывает её, а не зовёт команду")
	# иначе — «Отмена» (4.3: Esc переехал с настроек на отмену)
	var cancelled := [false]
	_ui.cancel_requested.connect(func() -> void: cancelled[0] = true)
	_press(KEY_ESCAPE)
	assert_bool(cancelled[0]).is_true().override_failure_message(
		"Esc без открытых панелей обязан звать отмену")
	# открытые настройки → Esc закрывает
	_ui._settings_screen.visible = true
	_press(KEY_ESCAPE)
	assert_bool(_ui._settings_screen.visible).is_false()


func test_action_hotkeys_emit() -> void:
	_setup()
	var fired: Array[String] = []
	for sig in ["skip_requested", "defend_requested", "wait_requested", "attack_mode_requested",
			"auto_battle_requested"]:
		_ui.connect(sig, func() -> void: fired.append(sig))
	_press(KEY_S)
	_press(KEY_D)
	_press(KEY_W)
	# «Атака» рождается глухой (`_connect_skeleton`), а тест — про клавишу,
	# а не про фазу боя: команду будим вручную.
	_press(KEY_A)
	assert_int(fired.size()).is_equal(4).override_failure_message(
		"каждая клавиша панели звала свою команду: %s" % fired)


# 4.3: недоступная команда не двигает бой. Проверка от клавиши, а не от метода
# боя: раньше хоткеи звали `_on_*` напрямую и `disabled` обходили.
func test_hotkey_of_disabled_command_is_silent() -> void:
	_setup()
	var fired: Array[String] = []
	for sig in ["defend_requested", "wait_requested", "retreat_requested", "auto_battle_requested"]:
		_ui.connect(sig, func() -> void: fired.append(sig))
	_ui.set_controls_enabled(false)
	for key in [KEY_D, KEY_W, KEY_C, KEY_A]:
		_press(key)
	assert_array(fired).is_empty()
	# «Пропуск» — инвариант 07-ui-ux:53, он не глохнет и зовёт команду всегда
	_ui.skip_requested.connect(func() -> void: fired.append("skip_requested"))
	assert_bool(_ui._skip_btn.disabled).is_false()
	_press(KEY_S)
	assert_int(fired.size()).is_equal(1)
	assert_str(fired[0]).is_equal("skip_requested")


func test_final_accepts_f() -> void:
	_setup()
	_ui.show_result(BattleState.Side.ATTACKER, 3, 0)
	var accepted := [false]
	_ui.result_accepted.connect(func() -> void: accepted[0] = true)
	_press(KEY_F)
	assert_bool(accepted[0]).is_true().override_failure_message(
		"docs/14 §4.F: финал подтверждается «Продолжить» (F — клавиша подтверждения)")
