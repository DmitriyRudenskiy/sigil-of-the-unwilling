#extends GdUnitTestSuite
# tests/unit/combat/test_enemy_ai.gd
# [AI]: сгенерировано по задаче 4.8 tasks.md, проверено человеком.
# ИИ противника: ход без игрока, выбор способности, цель по слабости, пропуск под stun.

extends GdUnitTestSuite


func _foe(abilities: Array) -> UnitStats:
	return BattleFactory.stats(&"foe", 300, 20, 5, 1, abilities)


func _heroes(pool: Array) -> RosterData:
	return BattleFactory.roster(pool)


func test_enemy_acts_without_player_input() -> void:
	var combat := BattleFactory.state(
		_heroes([BattleFactory.stats(&"hero", 200, 1, 0, 20)]), [_foe([])], 5)
	var before := combat.history.size()
	combat.perform(BattleAction.skip(combat.current))
	var enemy_actions := 0
	for action in combat.history.slice(before):
		if action.actor.side == BattleUnit.SIDE_ENEMY:
			enemy_actions += 1
	assert_int(enemy_actions).is_equal(1)


## Пропускает ходы игрока, пока противник не сходит, и возвращает его действия.
func _enemy_actions(combat: CombatState, max_rounds: int = 10) -> Array:
	var found: Array = []
	for _round in max_rounds:
		if combat.finished:
			break
		var before := combat.history.size()
		combat.perform(BattleAction.skip(combat.current))
		for action in combat.history.slice(before):
			if action.actor.side == BattleUnit.SIDE_ENEMY:
				found.append(action)
		if not found.is_empty():
			break
	return found


func test_enemy_uses_ready_ability() -> void:
	var sweep := BattleFactory.ability(&"sweep", 2, 3, 1.2, Ability.TargetKind.ENEMY_ALL)
	var combat := BattleFactory.state(
		_heroes([
			BattleFactory.stats(&"hero_a", 200, 1, 0, 30),
			BattleFactory.stats(&"hero_b", 200, 1, 0, 25),
		]),
		[_foe([sweep])],
		5
	)
	var acted := _enemy_actions(combat)
	assert_int(acted.size()).is_greater(0)
	assert_int((acted[0] as BattleAction).kind).is_equal(BattleAction.Kind.ABILITY)


func test_enemy_falls_back_to_attack_without_focus() -> void:
	var sweep := BattleFactory.ability(&"sweep", 5, 0, 1.2, Ability.TargetKind.ENEMY_ALL)
	var combat := BattleFactory.state(
		_heroes([BattleFactory.stats(&"hero", 200, 1, 0, 20)]), [_foe([sweep])], 5)
	var acted := _enemy_actions(combat)
	assert_int((acted[0] as BattleAction).kind).is_equal(BattleAction.Kind.ATTACK)


func test_enemy_targets_weakest_player_unit() -> void:
	var wounded := BattleFactory.stats(&"wounded", 200, 5, 0, 30)
	var healthy := BattleFactory.stats(&"healthy", 200, 5, 0, 25)
	var combat := BattleFactory.state(_heroes([wounded, healthy]), [_foe([])], 5)
	var wounded_unit: BattleUnit
	for unit in combat.alive(BattleUnit.SIDE_PLAYER):
		if unit.stats.id == &"wounded":
			wounded_unit = unit
	wounded_unit.deal_damage(150)
	var struck: Array = []
	for action in _enemy_actions(combat, 20):
		for target in (action as BattleAction).targets:
			struck.append(target.uid())
	assert_bool(struck.has(wounded_unit.uid())).is_true()


func test_stunned_enemy_passes() -> void:
	var combat := BattleFactory.state(
		_heroes([BattleFactory.stats(&"hero", 300, 1, 0, 20)]),
		[_foe([BattleFactory.ability(&"sweep", 0, 0, 1.5)])],
		5
	)
	var foe := combat.alive(BattleUnit.SIDE_ENEMY)[0]
	foe.apply_status(&"stun")
	var acted := _enemy_actions(combat)
	assert_int(acted.size()).is_equal(1)
	assert_int((acted[0] as BattleAction).kind).is_equal(BattleAction.Kind.PASS)
