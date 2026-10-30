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
		"bottom_bar/bar_box/left_box/retreat_btn",
		"bottom_bar/bar_box/left_box/attack_btn",
		"bottom_bar/bar_box/right_box/spellbook_btn",
		"bottom_bar/bar_box/right_box/wait_btn",
		"bottom_bar/bar_box/right_box/cancel_btn",
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
		# Все восемь команд несут пластину комплекта (D-293, лист 7.4): пластина и знак
		# одним кадром из `assets/ui/widgets/battle/`. Прежние круглые эмблемы
		# (`emblem_swords`, `emblem_skip`) сняты вместе с вариацией RoundIconButton —
		# медальон без пластины читался чужим в ряду (T-314, T-315).
		"bottom_bar/bar_box/left_box/retreat_btn": "retreat.png",
		"bottom_bar/bar_box/left_box/attack_btn": "attack.png",
		"bottom_bar/bar_box/right_box/spellbook_btn": "spellbook.png",
		"bottom_bar/bar_box/right_box/wait_btn": "wait.png",
		"bottom_bar/bar_box/left_box/defend_btn": "defend.png",
		"bottom_bar/bar_box/right_box/skip_btn": "skip.png",
		"bottom_bar/bar_box/left_box/auto_btn": "auto.png",
		"bottom_bar/bar_box/right_box/cancel_btn": "cancel.png",
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
## ▲▼ окна сообщений вернул новый носитель — описание владельца (4.2).
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


## T-315: отключённый медальон обязан быть ТЕМНЕЕ ряда, а не светлее его.
## Замер канонным кадром 1920×1080 (фикстура `battle_hud_full`,
## `scripts/measure_medallion_row.py`): пластина «Отступить» при `disabled = true` и
## `self_modulate = (1,1,1,1)` даёт линейную яркость 0.226 против 0.052 у
## включённых соседей — в 4.38 раза светлее при критерии «не светлее ×1.5».
## Причина не в теме и не в «сыром альфа-канале пикса»: движок гасит иконку
## отключённой кнопки альфой ~0.4, а theme-ключ `icon_disabled_modulate` у `Button`
## отсутствует (замер `get_theme_color` → (0,0,0,1)), поэтому рычаг — узловой
## `self_modulate`, а компенсирующее затемнение (`ThemeConfig.C_BATTLE_MEDALLION_DIM`)
## обязано приходить вместе с `disabled`, а не только по наведению мыши.
func test_zone_d_disabled_medallion_paints_dim() -> void:
	var ui: BattleUI = _mk_ui()
	var med := _zone_d_medallions(ui)
	assert_int(med.size()).override_failure_message(
		"медальонов в ряду %d, макет 11 — восемь" % med.size()
	).is_equal(8)
	# Начальное состояние: «Атака» заглушена до выбора цели — и уже обязана нести
	# затемнение, иначе первый же кадр ряда содержит светлый отключённый медальон.
	_assert_zone_d_medallion_paint(med, "сборка ряда (_ready)")
	assert_bool(_zone_d_medallion(med, "attack_btn").disabled).override_failure_message(
		"«Атака» не заглушена до выбора цели"
	).is_true()

	# «Нечего спасать» — эта ветка глушит «Отступить» мимо наведения мыши.
	ui.set_rescue_enabled(false)
	assert_bool(_zone_d_medallion(med, "retreat_btn").disabled).override_failure_message(
		"«Отступить» не глушится вместе с «нечего спасать»"
	).is_true()
	_assert_zone_d_medallion_paint(med, "set_rescue_enabled(false)")
	ui.set_rescue_enabled(true)
	_assert_zone_d_medallion_paint(med, "set_rescue_enabled(true)")

	ui.set_attack_enabled(false)
	_assert_zone_d_medallion_paint(med, "set_attack_enabled(false)")
	ui.set_attack_enabled(true)
	_assert_zone_d_medallion_paint(med, "set_attack_enabled(true)")

	ui.set_controls_enabled(false)
	_assert_zone_d_medallion_paint(med, "set_controls_enabled(false)")
	ui.set_controls_enabled(true)
	_assert_zone_d_medallion_paint(med, "set_controls_enabled(true)")


## Медальоны ряда собираются обходом дерева, а не списком путей: `_apply_command_row`
## переставляет кнопки между `left_box` и `right_box`, и путь из сцены под live-
## порядком не гарантирован (проверено кадром: `attack_btn` живёт в `left_box`).
func _zone_d_medallions(node: Node) -> Array:
	var acc: Array = []
	_collect_zone_d_medallions(node, acc)
	return acc


func _collect_zone_d_medallions(node: Node, acc: Array) -> void:
	for c in node.get_children():
		if c is Button and (c as Button).theme_type_variation == "BattleMedallion":
			acc.append(c)
		_collect_zone_d_medallions(c, acc)


func _zone_d_medallion(medallions: Array, node_name: String) -> Button:
	for b in medallions:
		if (b as Button).name == node_name:
			return b as Button
	return null


## Инвариант ряда: закраска пластины однозначно выведена из её доступности.
## Сравнение строк, а не `Color`: значения считаются из `ThemeConfig`, а сообщение
## обязано показывать обе стороны (какой медальон, какое состояние, что нарисовано).
func _assert_zone_d_medallion_paint(medallions: Array, what: String) -> void:
	for b in medallions:
		var btn := b as Button
		var want: Color = ThemeConfig.C_BATTLE_MEDALLION_DIM if btn.disabled else Color.WHITE
		var msg := (
			"%s: %s disabled=%s закрашен %s, ожидался %s — отключённый медальон без затемнения читается ярче ряда (T-315)"
			% [what, str(btn.name), str(btn.disabled), str(btn.self_modulate), str(want)])
		assert_str(str(btn.self_modulate)).override_failure_message(msg).is_equal(str(want))
