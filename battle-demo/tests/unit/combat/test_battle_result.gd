extends GdUnitTestSuite
# tests/unit/combat/test_battle_result.gd
# [AI]: сгенерировано по задаче 9.7 tasks.md.
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


## Команд после финала нет: панель их снимает, поэтому висящая кнопка была бы
## падением, а не ходом.
func test_no_battle_actions_after_the_result() -> void:
	var screen := _screen()
	var combat := _combat()
	screen.run(combat)
	BattleFactory.auto_play(combat)
	assert_int(screen.hud.command_count()).is_equal(0)


## AC «Действие после результата игнорируется» — про модель, а не про панель:
## попытка выполнить боевое действие после финала не меняет состояние. Прежняя
## проверка держалась только на отсутствии кнопок, а `perform` на финише
## утверждал, т.е. в релизной сборке (где `assert` вырезан) бой жил бы и за
## модалкой.
func test_action_after_the_result_changes_nothing() -> void:
	var combat := _combat()
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	var before := _snapshot(combat)
	combat.perform(BattleAction.skip(combat.current))
	assert_str(_snapshot(combat)).is_equal(before)


## Всё внешнее состояние боя одной строкой: очередь, счётчик, исход, HP.
func _snapshot(combat: CombatState) -> String:
	var hp: Array[String] = []
	for unit in combat.units:
		hp.append("%s:%d" % [unit.stats.id, unit.hp])
	return "order=%d turn=%d result=%d done=%s history=%d hp=%s" % [
		combat.order.size(), combat.turn_index, combat.result,
		str(combat.finished), combat.history.size(), ",".join(hp),
	]
