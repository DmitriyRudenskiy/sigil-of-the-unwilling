extends BaseTest

# UI-3 шаг 2: зоны B (карточка цели), F (финал) — презентационный слой.
# Зона A (лента очереди) снята со сцены сменой battle-99-hex-clean-hud.

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


## Макет 11: у нижних медальонов — эмблема-файл, а не текстовый глиф. Эмодзи в
## `Button.text` рисовался шрифтом системы (на одном экране — цветные иконки
## Windows, на другом — квадраты), не масштабировался под кольцо и не красился
## в состояния. Подпись вынесена в дочерний `caption`, поэтому `text` кнопки
## обязан остаться пустым — иначе шрифт вернётся в кадр.
func test_zone_d_medallions_show_emblem_textures() -> void:
	var ui: BattleUI = _mk_ui()
	await get_tree().process_frame
	var emblems := {
		"bottom_bar/bar_box/left_box/settings_btn": "emblem_gear.png",
		"bottom_bar/bar_box/left_box/retreat_btn": "emblem_flag.png",
		"bottom_bar/bar_box/left_box/rescue_btn": "emblem_ring.png",
		"bottom_bar/bar_box/right_box/attack_btn": "emblem_swords.png",
		"bottom_bar/bar_box/right_box/spellbook_btn": "emblem_book.png",
		"bottom_bar/bar_box/right_box/wait_btn": "emblem_hourglass.png",
		"bottom_bar/bar_box/right_box/defend_btn": "emblem_shield.png",
		"bottom_bar/bar_box/right_box/skip_btn": "emblem_skip.png",
	}
	for p: String in emblems:
		var b := ui.get_node_or_null(p) as Button
		assert_bool(b != null).override_failure_message("нет медальона %s" % p).is_true()
		if b == null:
			continue
		assert_bool(b.icon != null).override_failure_message(
			"%s: эмблема не назначена — в кадре снова текстовый глиф" % p
		).is_true()
		if b.icon != null:
			assert_str(b.icon.resource_path.get_file()).override_failure_message(
				"%s: ожидался %s" % [p, emblems[p]]
			).is_equal(emblems[p])
		assert_str(b.text).override_failure_message(
			"%s: подпись макета — под кольцом, не внутри него" % p
		).is_empty()


## Правый ряд макета 11 начинается с двух пустых медальонов (слоты под будущие
## команды). Они не кнопки: несвязанный Button обещал бы нажатие, которого нет.
## Стрелки ▲▼ прокрутки лога макет не несёт — сняты, вход в историю один — ☰.
func test_zone_d_empty_slots_and_log_controls() -> void:
	var ui: BattleUI = _mk_ui()
	var right := ui.get_node_or_null("bottom_bar/bar_box/right_box") as HBoxContainer
	assert_bool(right != null).is_true()
	if right == null:
		return
	assert_int(right.get_child_count()).override_failure_message(
		"правый ряд: два пустых слота + шесть команд (книга/отмена/ждать/защита + "
		"атака и пропуск, у которых носитель механики есть)"
	).is_equal(8)
	for slot_name: String in ["slot_empty_1", "slot_empty_2"]:
		var slot := right.get_node_or_null(slot_name)
		assert_bool(slot != null).override_failure_message("нет слота %s" % slot_name).is_true()
		if slot == null:
			continue
		assert_bool(not (slot is Button)).override_failure_message(
			"%s: декорация не должна быть кнопкой" % slot_name
		).is_true()
		assert_int(slot.mouse_filter).override_failure_message(
			"%s: слот ловит клики/фокус" % slot_name
		).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_bool(right.get_child(0) == right.get_node_or_null("slot_empty_1")).is_true() \
		.override_failure_message("слоты — первыми в ряду, как в макете")
	# ▲▼ окна сообщений вернуло НОВОЕ описание владельца (alpha-battle-field 4.2);
	# прежняя строка «кластер ▲▼ макет не задумывал» относилась к макету 11 и
	# снята вместе с ним — окно сообщений со стрелками теперь требование спеки.
	assert_object(ui.get_node_or_null("bottom_bar/info_box/log_row/log_up_btn")).is_not_null()
	assert_object(ui.get_node_or_null("bottom_bar/info_box/log_row/log_down_btn")).is_not_null()
	assert_bool(ui.get_node_or_null("bottom_bar/info_box/log_row/history_btn") != null) \
		.override_failure_message("☰ — единственная кнопка входа в историю боя").is_true()
	# До первой записи лога смотреть нечего — ☰ не висит сиротским табом.
	assert_bool(ui._history_btn.visible).is_false() \
		.override_failure_message("пустая история — кнопки истории в кадре нет")
	ui.set_status("скелет атакует")
	assert_bool(ui._history_btn.visible).is_true() \
		.override_failure_message("первая запись — ☰ появляется")


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
