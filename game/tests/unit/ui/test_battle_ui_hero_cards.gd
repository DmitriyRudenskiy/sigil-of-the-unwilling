extends BaseTest

## ui-mockup-parity §5 (макет боевого HUD): карточки героев, бейджи уровня в
## очереди инициативы, таймер хода, кнопка «Спасение».
## Проверается то, что требует макет и спека battle-hud: носитель → элемент,
## и отсутствие элемента, когда носителя нет (правило «никаких фейковых чисел»).

const _BATTLE_UI_SCENE := preload("res://scenes/ui/battle_ui.tscn")

var _ui: BattleUI = null
var _uid_seq: int = 5000


func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
	_ui = null


func _mk_ui() -> BattleUI:
	var ui: BattleUI = _BATTLE_UI_SCENE.instantiate()
	_ui = ui
	get_tree().root.add_child(ui)
	return ui


func _hero(side: BattleState.Side, p_name: String, hp: int, max_hp: int, level: int) -> BattleState.BattleUnit:
	var key := String(GameNumbersHero.HERO_BATTLE_KEY)
	var stack := UnitStack.new(UnitStats.new(key, p_name, 3, 3, 1, 5, 1, []), 1)
	var u := BattleState.BattleUnit.new(stack)
	var p := DnDCombatantProfile.new(key, p_name)
	p.max_hp = max_hp
	p.level = level
	u.dnd_profile = p
	u.dnd_current_hp = hp
	_uid_seq += 1
	u.uid = _uid_seq
	u.side = side
	return u


func _unit(side: BattleState.Side, p_name: String, level: int) -> BattleState.BattleUnit:
	var stack := UnitStack.new(UnitStats.new("skeleton", p_name, 1, 1, 7, 4, 0, []), 3)
	var u := BattleState.BattleUnit.new(stack)
	var p := DnDCombatantProfile.new("skeleton", p_name)
	p.level = level
	u.dnd_profile = p
	u.dnd_current_hp = 7
	_uid_seq += 1
	u.uid = _uid_seq
	u.side = side
	return u


func _magic(current: int, maximum: int) -> HeroMagic:
	var m := HeroMagic.new()
	m.mana_max = maximum
	m.mana_current = current
	return m


func _card(ui: BattleUI, right: bool) -> Dictionary:
	var panel: Control = ui._hero_right if right else ui._hero_left
	return {
		"panel": panel,
		"name": panel.get_node("row/info/name"),
		"level_row": panel.get_node("row/info/level_row"),
		"level_num": panel.get_node("row/info/level_row/level_num"),
		"hp_row": panel.get_node("row/info/hp_row"),
		"hp_bar": panel.get_node("row/info/hp_row/hp_bar"),
		"hp_num": panel.get_node("row/info/hp_row/hp_num"),
		"mana_row": panel.get_node("row/info/mana_row"),
		"mana_bar": panel.get_node("row/info/mana_row/mana_bar"),
		"mana_num": panel.get_node("row/info/mana_row/mana_num"),
	}


# --- Карточки героев (5.2) --------------------------------------------------

func test_cards_hidden_when_no_hero_on_either_side() -> void:
	var ui := _mk_ui()
	var state := BattleState.new()
	var a := _unit(BattleState.Side.ATTACKER, "Скелет", 1)
	var d := _unit(BattleState.Side.DEFENDER, "Зомби", 2)
	state.attacker_units.append(a)
	state.defender_units.append(d)

	ui.update_hero_cards(state, _magic(10, 20))

	assert_bool(_card(ui, false)["panel"].visible).is_false()
	assert_bool(_card(ui, true)["panel"].visible).is_false()


func test_own_hero_card_shows_name_hp_and_mana() -> void:
	var ui := _mk_ui()
	var state := BattleState.new()
	state.attacker_units.append(_hero(BattleState.Side.ATTACKER, "Веном Карен", 30, 40, 7))

	ui.update_hero_cards(state, _magic(14, 20))

	var c := _card(ui, false)
	assert_bool(c["panel"].visible).is_true()
	assert_str(c["name"].text).is_equal("Веном Карен")
	assert_bool(c["hp_row"].visible).is_true()
	assert_str(c["hp_num"].text).is_equal("30/40")
	assert_float(c["hp_bar"].value).is_equal(30.0)
	assert_float(c["hp_bar"].max_value).is_equal(40.0)
	assert_bool(c["mana_row"].visible).is_true()
	assert_str(c["mana_num"].text).is_equal("14/20")
	assert_str(c["level_num"].text).is_equal("7")


func test_enemy_hero_card_has_no_mana_bar_without_carrier() -> void:
	var ui := _mk_ui()
	var state := BattleState.new()
	state.attacker_units.append(_hero(BattleState.Side.ATTACKER, "Свой", 10, 10, 1))
	state.defender_units.append(_hero(BattleState.Side.DEFENDER, "Лейн", 99, 100, 30))

	ui.update_hero_cards(state, _magic(5, 20))

	var right := _card(ui, true)
	assert_bool(right["panel"].visible).is_true()
	assert_str(right["name"].text).is_equal("Лейн")
	assert_str(right["hp_num"].text).is_equal("99/100")
	# Маны врага в состоянии нет → полоса скрыта, а не обнулена.
	assert_bool(right["mana_row"].visible).is_false()


func test_hero_without_hp_pool_hides_health_bar() -> void:
	# Стековый герой (не dnd-персонаж): get_hp() равен максимуму всегда, полоса
	# всегда была бы полной — то есть врала бы о неизменности здоровья.
	var ui := _mk_ui()
	var state := BattleState.new()
	var stack := UnitStack.new(
		UnitStats.new(String(GameNumbersHero.HERO_BATTLE_KEY), "Герой без пула", 1, 1, 25, 5, 0, []), 1
	)
	var u := BattleState.BattleUnit.new(stack)
	_uid_seq += 1
	u.uid = _uid_seq
	u.side = BattleState.Side.ATTACKER
	state.attacker_units.append(u)

	ui.update_hero_cards(state, null)

	var c := _card(ui, false)
	assert_bool(c["panel"].visible).is_true()
	assert_bool(c["hp_row"].visible).is_false()
	assert_bool(c["mana_row"].visible).is_false()


# --- Очередь инициативы: портрет и бейдж уровня (5.2) -----------------------

func test_initiative_cell_has_portrait_and_level_badge() -> void:
	var ui := _mk_ui()
	var with_level := _unit(BattleState.Side.ATTACKER, "Скелет", 4)
	var no_level := _unit(BattleState.Side.ATTACKER, "Тень", 0)

	ui.update_initiative([with_level, no_level], with_level)

	var first: Control = ui._init_box.get_node("cell_%d" % with_level.uid)
	var portrait := first.get_node_or_null("row/portrait_box/portrait") as TextureRect
	assert_that(portrait).is_not_null()
	assert_that(portrait.texture).is_not_null()
	var badge := first.get_node_or_null("row/portrait_box/level_badge") as Label
	assert_that(badge).is_not_null()
	assert_str(badge.text).is_equal("4")

	var second: Control = ui._init_box.get_node("cell_%d" % no_level.uid)
	assert_that(second.get_node_or_null("row/portrait_box/level_badge")).is_null()


# --- Таймер хода (5.3) ------------------------------------------------------

func test_timer_shows_remaining_seconds() -> void:
	var ui := _mk_ui()
	var timer: Control = ui.get_node("turn_timer")
	assert_bool(timer.visible).is_true()

	ui.set_turn_timer(12.4, 30, true)

	assert_str(timer.get_node("num").text).is_equal("13")


func test_timer_without_time_limit_is_explicitly_inactive() -> void:
	# Спека battle-hud, «Режим без таймера»: элемент не отображается ЛИБО
	# отображается в явном неактивном состоянии. У нас — второй вариант.
	var ui := _mk_ui()
	var timer: Control = ui.get_node("turn_timer")

	ui.set_turn_timer(0.0, 0, false)

	assert_bool(timer.visible).is_true()
	assert_str(timer.get_node("num").text).is_equal("—")


# --- Кнопка «Спасение» (5.2) ------------------------------------------------

func test_rescue_button_emits_rescue_request() -> void:
	var ui := _mk_ui()
	var fired := [false]
	ui.rescue_requested.connect(func() -> void: fired[0] = true)

	ui._rescue_btn.emit_signal("pressed")

	assert_bool(fired[0]).is_true()


func test_rescue_button_follows_availability_and_locks_with_controls() -> void:
	var ui := _mk_ui()

	ui.set_rescue_enabled(true)
	assert_bool(ui._rescue_btn.disabled).is_false()
	ui.set_controls_enabled(false)
	assert_bool(ui._rescue_btn.disabled).is_true()
	# Инвариант 07-ui-ux:53 — «Пропустить» не глушится ничем.
	assert_bool(ui._skip_btn.disabled).is_false()
