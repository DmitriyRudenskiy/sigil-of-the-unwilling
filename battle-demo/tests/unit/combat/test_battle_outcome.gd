#extends GdUnitTestSuite
# tests/unit/combat/test_battle_outcome.gd
# [AI]: сгенерировано по задаче 4.6 tasks.md.
# Исход боя: победа, поражение, остановка очереди, страховка по лимиту ходов.

extends GdUnitTestSuite


func _strong_hero() -> UnitStats:
	return BattleFactory.stats(&"hero", 200, 40, 10, 20)


func _weak_foe() -> UnitStats:
	return BattleFactory.stats(&"foe", 30, 1, 0, 1)


func test_victory_when_no_enemies_left() -> void:
	var combat := BattleFactory.state(BattleFactory.roster([_strong_hero()]), [_weak_foe()], 5)
	var endings: Array = []
	combat.battle_ended.connect(func(outcome: int) -> void: endings.append(outcome))
	BattleFactory.auto_play(combat)
	assert_int(combat.result).is_equal(BattleUnit.SIDE_PLAYER)
	assert_bool(combat.finished).is_true()
	assert_int(endings.size()).is_equal(1)


func test_defeat_when_no_player_units_left() -> void:
	var weak_hero := BattleFactory.stats(&"hero", 10, 1, 0, 20)
	var brute := BattleFactory.stats(&"foe", 400, 60, 20, 5)
	var combat := BattleFactory.state(BattleFactory.roster([weak_hero]), [brute], 5)
	BattleFactory.auto_play(combat)
	assert_int(combat.result).is_equal(BattleUnit.SIDE_ENEMY)


func test_queue_stops_after_battle_ended() -> void:
	var combat := BattleFactory.state(BattleFactory.roster([_strong_hero()]), [_weak_foe()], 5)
	BattleFactory.auto_play(combat)
	var frozen_turn := combat.turn_index
	var frozen_current := combat.current
	var endings := 0
	combat.battle_ended.connect(func(_outcome: int) -> void: endings += 1)
	# Повторный вызов ничего не меняет и не эмитит исход во второй раз.
	combat._check_over()
	assert_int(combat.turn_index).is_equal(frozen_turn)
	assert_object(combat.current).is_same(frozen_current)
	assert_int(endings).is_equal(0)


func test_stalemate_guard_reports_no_result() -> void:
	# Два юнита с нулевой атакой друг друга не убьют: включается лимит ходов,
	# и исход остаётся неопределённым, а не превращается в победу.
	var passive := func(id: StringName) -> UnitStats:
		return BattleFactory.stats(id, 100, 0, 100, 10)
	var combat := BattleFactory.state(
		BattleFactory.roster([passive.call(&"hero")]), [passive.call(&"foe")], 5
	)
	var performed := 0
	while not combat.finished and performed < CombatState.MAX_TURNS + 5:
		combat.perform(BattleAction.skip(combat.current))
		performed += 1
	assert_bool(combat.finished).is_true()
	assert_int(combat.result).is_equal(CombatState.NO_RESULT)
	assert_int(combat.turn_index).is_greater_equal(CombatState.MAX_TURNS)
