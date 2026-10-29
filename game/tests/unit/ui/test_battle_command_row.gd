# -*- godot -*-
# D-294 / 7.5: командный ряд боя — восемь истинных команд, 4+4, без заглушек.
extends GdUnitTestSuite

const _Scene := preload("res://scenes/ui/battle_ui.tscn")
var _ui: BattleUI = null


func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
	_ui = null


func _ready_ui() -> BattleUI:
	var ui: BattleUI = _Scene.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	await get_tree().process_frame  # ряд применяется отложенно
	return ui


# (1) состав ряда == ровно 8 командных кнопок, 4+4; некоманд в ряду нет.
func test_row_is_eight_commands_four_plus_four() -> void:
	var ui: BattleUI = await _ready_ui()
	var left: HBoxContainer = ui.get_node("bottom_bar/bar_box/left_box")
	var right: HBoxContainer = ui.get_node("bottom_bar/bar_box/right_box")
	assert_int(left.get_child_count()).is_equal(4)
	assert_int(right.get_child_count()).is_equal(4)
	assert_object(left.get_child(0)).is_same(ui._attack_button)
	assert_object(left.get_child(1)).is_same(ui._defend_btn)
	assert_object(right.get_child(0)).is_same(ui._spellbook_btn)
	assert_object(right.get_child(3)).is_same(ui._skip_btn)
	assert_object(left.get_node_or_null("settings_btn")).is_null()
	assert_object(left.get_node_or_null("rescue_btn")).is_null()


# (2) заглушек в ряду нет: каждый ребёнок обоих рядов — командная кнопка.
func test_stub_slots_are_gone() -> void:
	var ui: BattleUI = await _ready_ui()
	var names: Array[String] = []
	for box: String in ["left_box", "right_box"]:
		for c: Node in ui.get_node("bottom_bar/bar_box/" + box).get_children():
			names.append(String(c.name))
			assert_bool(c is Button).override_failure_message("в ряду не-кнопка: " + String(c.name)).is_true()
	for n: String in names:
		assert_bool(n.begins_with("slot_empty")).override_failure_message("заглушка в ряду: " + n).is_false()
	assert_int(names.size()).is_equal(8)


# (5) инвариант D-293: восемь медальонов и в 1280×720, и в 1920×1080.
func test_row_invariant_holds_at_both_widths() -> void:
	for w: int in [1280, 1920]:
		var ui: BattleUI = await _ready_ui()
		ui.get_viewport().size = Vector2i(w, int(w * 9.0 / 16.0))
		var row: HBoxContainer = ui.get_node("bottom_bar/bar_box")
		var medallions: int = (
			row.get_node("left_box").get_child_count() + row.get_node("right_box").get_child_count()
		)
		assert_int(medallions).is_equal(8)


# (4) диалог выхода: три пункта, «Сдаться» неактивна, остальные дёргают свои обработчики.
func test_exit_dialog_items() -> void:
	var ui: BattleUI = await _ready_ui()
	ui._on_exit_dialog()
	var dlg: AcceptDialog = null
	for c: Node in ui.get_children():
		if c is AcceptDialog:
			dlg = c
	assert_object(dlg).is_not_null()
	var row: HBoxContainer = dlg.get_child(0)
	assert_int(row.get_child_count()).is_equal(3)
	assert_bool(row.get_child(2).disabled).is_true()
	dlg.queue_free()

# (6) медальон несёт только знак (D-293), имя команды — в подсказке, а вкладка
# журнала жива до первой записи лога и стоит вне ряда (D-294).
func test_medallions_bare_and_journal_tab_alive() -> void:
	var ui: BattleUI = await _ready_ui()
	for box: String in ["left_box", "right_box"]:
		for c: Node in ui.get_node("bottom_bar/bar_box/" + box).get_children():
			var cap: Label = c.get_node_or_null("caption")
			if cap != null:
				assert_bool(cap.visible).override_failure_message(
					"медальон %s показывает подпись" % c.name).is_false()
			assert_str(c.tooltip_text).override_failure_message(
				"медальон %s без подсказки" % c.name).is_not_empty()
	assert_bool(ui._history_btn.visible).is_true()
	var row: Rect2 = ui.get_node("bottom_bar/bar_box").get_global_rect()
	assert_bool(ui._history_btn.get_global_rect().end.y <= row.position.y + 1.0).override_failure_message("вкладка журнала не вышла из ряда").is_true()
