extends BaseTest

const _BattleUIScene := preload("res://scenes/ui/BattleUI.tscn")

var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null

func test_battle_ui_onready_resolved_and_connected() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)

	assert_object(ui._bottom_bar).is_not_null().override_failure_message("_bottom_bar не разрешился")
	assert_object(ui._settings_screen).is_not_null().override_failure_message("_settings_screen не разрешился")
	assert_object(ui._spellbook_panel).is_not_null().override_failure_message("_spellbook_panel не разрешился")

	assert_bool(ui._retreat_btn.pressed.is_connected(ui._on_retreat)).is_true().override_failure_message("retreat_btn.pressed не подключён")
	assert_bool(ui._wait_btn.pressed.is_connected(ui._on_wait)).is_true().override_failure_message("wait_btn.pressed не подключён")
	assert_bool(ui._attack_button.pressed.is_connected(ui._on_attack_mode)).is_true().override_failure_message("attack_btn.pressed не подключён")
	assert_bool(ui._defend_btn.pressed.is_connected(ui._on_defend)).is_true().override_failure_message("defend_btn.pressed не подключён")
	assert_bool(ui._skip_btn.pressed.is_connected(ui._on_skip)).is_true().override_failure_message("skip_btn.pressed не подключён")

	assert_bool(ui._spellbook_panel.spell_chosen.is_connected(ui._on_spellbook_chosen)).is_true().override_failure_message("spell_chosen не подключён")

func test_battle_ui_log_history_nodes() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)

	assert_object(ui._turn_line).is_not_null().override_failure_message("turn_line не разрешился")
	assert_object(ui._log_line).is_not_null().override_failure_message("log_line не разрешился")
	assert_object(ui._history_btn).is_not_null().override_failure_message("history_btn не разрешился")
	assert_object(ui._history_panel).is_not_null().override_failure_message("history_panel не разрешился")
	assert_bool(ui._history_panel.visible).is_false().override_failure_message("история должна быть скрыта по умолчанию")

func test_battle_ui_history_navigation() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)

	ui.set_status("первое")
	ui.set_status("второе")
	ui.set_status("третье")
	assert_str(ui._log_line.text).is_equal("третье")

	ui._on_history_up()
	assert_str(ui._log_line.text).is_equal("второе")
	ui._on_history_up()
	assert_str(ui._log_line.text).is_equal("первое")
	ui._on_history_up()
	assert_str(ui._log_line.text).is_equal("первое").override_failure_message("начало истории — дальше не листать")

	ui._on_history_down()
	assert_str(ui._log_line.text).is_equal("второе")
	ui._on_history_down()
	assert_str(ui._log_line.text).is_equal("третье")
	ui._on_history_down()
	assert_str(ui._log_line.text).is_equal("третье").override_failure_message("конец истории — дальше не листать")

	ui._on_history_toggle()
	assert_bool(ui._history_panel.visible).is_true()
	assert_int(ui._history_list.item_count).is_equal(3)
	ui._on_history_toggle()
	assert_bool(ui._history_panel.visible).is_false()
