extends BaseTest

# UI-3 шаг 2: зоны A (инициатива), B (карточка цели), F (финал) — презентационный слой.

const _BATTLE_UI_SCENE := preload("res://scenes/ui/battle_ui.tscn")

var _ui: Node = null

# uid — детерминированный счётчик. Раньше был `get_child_count() + randi() % 1000`,
# и изредка два юнита получали одинаковый uid: Godot переименовывал второго узла в
# `cell_<uid>@2`, а тест искал ячейку по `"cell_%d" % uid` и брал чужую (мёртвую
# ячейку — активной), отсюда плавающий FAILED в полном прогоне. Коллизия
# воспроизведена вручную: `Expecting: 'PanelDead' but was 'PanelActive'`.
var _uid_seq: int = 1000

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null

func _mk_unit(p_name: String, count: int, hp: int = 5) -> BattleState.BattleUnit:
	var stats := UnitStats.new(p_name.to_lower(), p_name, 5, 3, hp, 2, 4)
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, count))
	_uid_seq += 1
	u.uid = _uid_seq
	return u

func _mk_ui() -> BattleUI:
	var ui: BattleUI = _BATTLE_UI_SCENE.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	return ui

func test_zone_a_initiative_cells_and_active() -> void:
	var ui: BattleUI = _mk_ui()
	var alive := _mk_unit("Скелет", 5)
	var active := _mk_unit("Вампир", 3)
	var dead := _mk_unit("Зомби", 0)
	var units: Array[BattleState.BattleUnit] = [alive, active, dead]

	ui.update_initiative(units, active)

	var box: HBoxContainer = ui._init_box
	assert_int(box.get_child_count()).is_equal(3)
	var cells := {}
	for c in box.get_children():
		cells[c.name] = c
	var active_cell: PanelContainer = cells["cell_%d" % active.uid]
	var dead_cell: PanelContainer = cells["cell_%d" % dead.uid]
	var plain_cell: PanelContainer = cells["cell_%d" % alive.uid]
	assert_str(str(active_cell.theme_type_variation)).is_equal("PanelQueueTileActive")
	assert_str(str(dead_cell.theme_type_variation)).is_equal("PanelQueueTileDead")
	assert_str(str(plain_cell.theme_type_variation)).is_equal("PanelQueueTile")

func test_zone_b_target_card_live_fields() -> void:
	var ui: BattleUI = _mk_ui()
	assert_bool(ui._target_card.visible).is_false() \
		.override_failure_message("карточка скрыта по умолчанию")

	var u := _mk_unit("Гаргулья", 7)
	ui.show_target_card(u)
	assert_bool(ui._target_card.visible).is_true()
	assert_str(ui._tc_name.text).is_equal("Гаргулья")
	assert_str(ui._tc_hp.text).is_equal("5")
	assert_str(ui._tc_count.text).is_equal("7")

	ui.set_attack_preview("Урон 3 · Убийств 1")
	assert_str(ui._tc_preview.text).is_equal("Урон 3 · Убийств 1")
	assert_bool(ui._tc_preview.visible).is_true()

	ui.set_attack_preview("")
	assert_bool(ui._tc_preview.visible).is_false() \
		.override_failure_message("пустое превью не рисуется")

	ui.hide_target_card()
	assert_bool(ui._target_card.visible).is_false()

func test_zone_b_zero_defense_row_hidden() -> void:
	var ui: BattleUI = _mk_ui()
	var u := _mk_unit("Тень", 1)
	u.stack.stats.defense = 0
	ui.show_target_card(u)
	assert_bool(ui._tc_def.visible).is_false() \
		.override_failure_message("нет источника — строка скрыта")

## Медальон нижней панели — квадрат, а не эллипс. `HBoxContainer` растягивает
## детей поперёк оси, и кнопка 100×100 в полосе высотой 134 становилась
## эллипсом 96×134: тесты зовут хендлеры и этого не видят, а на снимке круг
## выглядит «почти круглым». Замер макета 11 — design.md §5 п.8.
func test_zone_d_medallions_stay_square() -> void:
	var ui: BattleUI = _mk_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	var paths := [
		"bottom_bar/bar_box/left_box/settings_btn",
		"bottom_bar/bar_box/left_box/retreat_btn",
		"bottom_bar/bar_box/left_box/rescue_btn",
		"bottom_bar/bar_box/right_box/attack_btn",
		"bottom_bar/bar_box/right_box/spellbook_btn",
		"bottom_bar/bar_box/right_box/wait_btn",
		"bottom_bar/bar_box/right_box/defend_btn",
		"bottom_bar/bar_box/right_box/skip_btn",
	]
	for p: String in paths:
		var b := ui.get_node_or_null(p) as Button
		assert_bool(b != null).override_failure_message("нет медальона %s" % p).is_true()
		if b == null:
			continue
		var size := b.get_global_rect().size
		assert_int(int(size.y)).override_failure_message(
			"%s: медальон %s — контейнер растянул его в эллипс" % [p, str(size)]
		).is_equal(int(size.x))
		assert_int(int(size.x)).override_failure_message(
			"%s: медальон %d px, макет 11 — 100 px" % [p, int(size.x)]
		).is_equal(100)


func test_zone_f_result_overlay_single_exit() -> void:
	var ui: BattleUI = _mk_ui()
	assert_bool(ui._end_overlay.visible).is_false()

	var accepted := [false]
	ui.result_accepted.connect(func() -> void: accepted[0] = true)

	ui.show_result(BattleState.Side.ATTACKER, 3, 0)
	assert_bool(ui._end_overlay.visible).is_true()
	assert_str(ui._end_title.text).is_equal("Победа")
	assert_str(ui._end_numbers.text).is_equal("3 / 0")

	ui._continue_btn.emit_signal("pressed")
	assert_bool(accepted[0]).is_true() \
		.override_failure_message("«Продолжить» → сигнал в flow")
