#extends GdUnitTestSuite
# tests/unit/combat/test_stepwise_only.gd
# [AI]: задача 4.11 tasks.md, проверено человеком.
# Пошаговость: пока выбор действия не подтверждён, мир стоит — ни чужих ходов,
# ни сдвинутых шкал. От ATB и real-time модель защищена отсутствием собственного
# шага по времени: у CombatState нет _process, мир меняется только из perform().

extends GdUnitTestSuite


func test_world_frozen_while_choosing() -> void:
	var combat := _battle()
	var before := _snapshot(combat)
	# «Выбор» = перебор легальных действий и чтение состояния. Это только чтение.
	for _round in 10:
		combat.legal_actions(combat.current)
		combat.alive(BattleUnit.SIDE_ENEMY)
		combat.ability_state(combat.current, BattleFactory.ability(&"smite", 2, 1))
	assert_str(_snapshot(combat)).is_equal(before)
	assert_bool(combat.has_method("_process")).is_false()


func test_world_changes_only_on_confirmed_choice() -> void:
	var combat := _battle()
	var actor := combat.current
	assert_int(_player_actions(combat)).is_equal(0)
	combat.perform(BattleAction.skip(actor))
	assert_int(_player_actions(combat)).is_equal(1)
	assert_int(actor.turns_taken).is_equal(1)


func _battle() -> CombatState:
	return BattleFactory.state(
		BattleFactory.roster([BattleFactory.stats(&"hero", 100, 20, 5, 20)]),
		[BattleFactory.stats(&"foe", 60, 10, 5, 10)],
		7,
	)


func _player_actions(combat: CombatState) -> int:
	var count := 0
	for action in combat.history:
		if action.actor.side == BattleUnit.SIDE_PLAYER:
			count += 1
	return count


func _snapshot(combat: CombatState) -> String:
	var parts := ["turn=%d" % combat.turn_index, "current=%s" % combat.current.uid()]
	for unit in combat.units:
		parts.append("%s hp=%d focus=%d st=%s cd=%s" % [
			unit.uid(), unit.hp, unit.focus, str(unit.durations), str(unit.cooldowns),
		])
	return "|".join(parts)
