extends BaseTest

## ui-mockup-parity §5.7 — тесты от сигнала UI: нажатая команда боя меняет
## состояние боя, недоступная команда состояние не меняет, HUD равен состоянию.
## Бой настоящий: сцена battle.tscn, у которой корень — контроллер.

func _battle_with_armies(hero_key: String = "skeleton") -> Node:
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	var atk: Array[UnitStack] = [
		UnitStack.new(UnitStats.new(hero_key, "Скелет", 3, 3, 10, 4, 1, []), 3)
	]
	var def: Array[UnitStack] = [
		UnitStack.new(UnitStats.new("zombie", "Зомби", 2, 2, 12, 3, 0, []), 3)
	]
	battle.start_battle(atk, def, {}, {}, {}, {}, 0, null)
	return battle


func test_pressed_command_changes_battle_state() -> void:
	var battle := _battle_with_armies()
	await await_millis(300)
	var ui: Node = battle.get_node("BattleUI")
	var state: BattleState = battle.get("_state")
	var active := state.active_unit
	assert_that(active).is_not_null()
	assert_bool(active.defending).is_false()

	ui.defend_requested.emit()

	assert_bool(active.defending).is_true()
	assert_bool(active.has_moved).is_true()
	# Немедленный free(): отложенное освобождение GdUnit не доживает до конца
	# кадров анимации, и её узлы записываются в сироты.
	battle.free()
	await await_millis(50)


func test_unavailable_command_changes_nothing() -> void:
	var battle := _battle_with_armies()
	await await_millis(300)
	var ui: Node = battle.get_node("BattleUI")
	var state: BattleState = battle.get("_state")
	# «Спасение» некого вызывать: никто не лежит → кнопка глуха, а сигнал в обход
	# кнопки не должен двигать бой.
	# D-294: кнопки «Спасения» в ряду нет — проверка глухости ушла к диалогу выхода.
	var before := {}
	for u in state.attacker_units:
		before[u.uid] = u
		before["%d_hp" % u.uid] = u.get_hp()
		before["%d_mv" % u.uid] = u.has_moved
	var active_uid := state.active_unit.uid

	ui.rescue_requested.emit()
	await await_millis(50)

	assert_int(state.active_unit.uid).is_equal(active_uid)
	for u in state.attacker_units:
		assert_int(u.get_hp()).is_equal(before["%d_hp" % u.uid])
		assert_bool(u.has_moved).is_equal(before["%d_mv" % u.uid])
		assert_bool(u.defending).is_false()
	battle.free()
	await await_millis(50)


func test_hud_equals_state_after_actions() -> void:
	# Герой стороны атакующего — юнит с ключом "hero" (HeroController.get_hero_battle_stack).
	var battle := _battle_with_armies("hero")
	await await_millis(300)
	var ui: Node = battle.get_node("BattleUI")
	var state: BattleState = battle.get("_state")

	var hero: BattleState.BattleUnit = ui.call("_hero_of_side", state, BattleState.Side.ATTACKER)
	assert_that(hero).is_not_null()
	hero.dnd_profile = DnDCombatantProfile.new()
	hero.dnd_profile.max_hp = 40
	hero.dnd_profile.level = 9
	hero.dnd_current_hp = 17
	battle.call("_refresh_hero_hud")

	var card: Control = ui.get("_hero_left")
	assert_bool(card.visible).is_true()
	assert_str(card.get_node("row/info/name").text).is_equal("Скелет")
	assert_str(card.get_node("row/info/hp_row/hp_num").text).is_equal("17/40")
	assert_str(card.get_node("row/info/level_row/level_num").text).is_equal("9")
	# Маны у стороны нет (hero_magic == null) → полосы нет, а не ноль.
	assert_bool(card.get_node("row/info/mana_row").visible).is_false()
	battle.free()
	await await_millis(50)
