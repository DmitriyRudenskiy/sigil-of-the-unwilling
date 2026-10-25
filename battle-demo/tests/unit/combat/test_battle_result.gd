extends GdUnitTestSuite
# tests/unit/combat/test_battle_result.gd
# [AI]: сгенерировано по задаче 9.7 tasks.md, проверено человеком.
#
# Экран результата: исход берётся из модели, а не пересказывается; после финала
# боевые действия не предлагаются.


func _screen() -> BattleScreen:
	var screen := auto_free(load("res://scenes/battle.tscn").instantiate()) as BattleScreen
	add_child(screen)
	return screen


func _combat() -> CombatState:
	return BattleFactory.state(
		BattleFactory.roster([BattleFactory.stats(&"hero_a", 100, 20, 5, 90)]),
		[BattleFactory.stats(&"foe_a", 60, 1, 5, 60)],
		5
	)


func test_result_screen_appears_with_the_outcome() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	assert_bool(screen.result_view.visible).is_false()
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_bool(screen.result_view.visible).is_true()
	var expected := (
		"Победа"
		if combat.result == BattleUnit.SIDE_PLAYER
		else ("Поражение" if combat.result == BattleUnit.SIDE_ENEMY else "Бой не окончен")
	)
	assert_str(screen.result_view.outcome_text()).is_equal(expected)


## Команд после финала нет: `CombatState.perform` на финише утверждает, поэтому
## висящая кнопка была бы падением, а не ходом.
func test_no_battle_actions_after_the_result() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	assert_int(screen.hud.command_count()).is_equal(0)
