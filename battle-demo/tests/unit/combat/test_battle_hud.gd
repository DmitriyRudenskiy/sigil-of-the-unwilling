#extends GdUnitTestSuite
# tests/unit/combat/test_battle_hud.gd
# Интерфейс по макету: панель показывает то, что считает ядро.
#
# Проверяются значения, а не пиксели: полоса состава = число юнитов боя, ячейки
# воли = focus активного, команда гаснет по причине ядра (кулдаун), рассадка —
# по разным клеткам сетки, свои слева от противника.

extends GdUnitTestSuite

## Юнит с кулдауном: после применения кнопка обязана погаснуть с подписью.
const COOLDOWN := 3


func _screen() -> BattleScreen:
	var screen := auto_free(load("res://scenes/battle.tscn").instantiate()) as BattleScreen
	add_child(screen)
	return screen


func _combat() -> CombatState:
	return BattleFactory.state(
		BattleFactory.roster([
			BattleFactory.stats(
				&"hero_a", 100, 20, 5, 90,
				[BattleFactory.ability(&"smite", 1, COOLDOWN)]
			),
			BattleFactory.stats(&"hero_b", 80, 10, 5, 40),
		]),
		[BattleFactory.stats(&"foe_a", 400, 1, 5, 60)],
		7
	)


func test_strip_has_one_card_per_unit() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_int(screen.hud.strip_count()).is_equal(combat.units.size())


func test_focus_pips_match_the_active_unit() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_int(screen.hud.active_focus_pips()).is_equal(combat.current.focus)


func test_round_counter_follows_the_queue() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_int(screen.hud.round_number()).is_equal(combat.turn_index + 1)
	combat.perform(BattleAction.skip(combat.current))
	assert_int(screen.hud.round_number()).is_equal(combat.turn_index + 1)


func test_ability_button_goes_dark_on_cooldown() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	var actor := combat.current
	assert_bool(screen.hud.command_enabled(&"smite")).is_true()
	screen.hud.command(&"smite").emit_signal(&"pressed")
	# Панель показывает команды активного юнита: за кулдауном смотрим в тот ход,
	# когда способность снова принадлежит активному юниту.
	while not combat.finished and combat.current != actor:
		combat.perform(BattleAction.skip(combat.current))
	assert_str(screen.hud.command_reason(&"smite")).is_equal("перезарядка")
	assert_bool(screen.hud.command_enabled(&"smite")).is_false()


func test_units_stand_on_distinct_hexes_of_their_own_flank() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	var cells := {}
	for unit in combat.units:
		var cell: Vector2i = screen.field.cell_of(unit)
		assert_bool(str(cell) in cells).is_false()
		cells[str(cell)] = true
	var foes: Array[BattleUnit] = combat.foes_of(combat.units[0])
	assert_float(screen.field.view_of(combat.units[0]).position.x).is_less(
		screen.field.view_of(foes[0]).position.x
	)
