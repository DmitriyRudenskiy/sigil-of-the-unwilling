extends BaseTest

const _BattleUIScene := preload("res://scenes/ui/battle_ui.tscn")

var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null

func test_skip_survives_controls_lock() -> void:
	var ui: BattleUI = _BattleUIScene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)

	ui.set_controls_enabled(false)
	assert_bool(ui._skip_btn.disabled).is_false().override_failure_message(
		"инвариант 07-ui-ux:53 — «Пропустить» нельзя глушить вместе с остальными")
	assert_bool(ui._retreat_btn.disabled).is_true()
	assert_bool(ui._wait_btn.disabled).is_true()
	assert_bool(ui._attack_button.disabled).is_true()
	assert_bool(ui._defend_btn.disabled).is_true()

	ui.set_controls_enabled(true)
	assert_bool(ui._skip_btn.disabled).is_false()
	assert_bool(ui._wait_btn.disabled).is_false()
	assert_bool(ui._defend_btn.disabled).is_false()
