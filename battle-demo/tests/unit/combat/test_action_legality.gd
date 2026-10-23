#extends GdUnitTestSuite
# tests/unit/combat/test_action_legality.gd
# [AI]: сгенерировано по задаче 4.5 tasks.md, проверено человеком.
# Легальность действий: одно действие за ход, расход, кулдаун, цель.

extends GdUnitTestSuite


func _strike() -> Ability:
	return BattleFactory.ability(&"strike", 2, 2, 1.5)


func _combat_with_player(abilities: Array) -> CombatState:
	return BattleFactory.state(
		BattleFactory.roster([BattleFactory.stats(&"hero", 100, 10, 5, 20, abilities)]),
		[BattleFactory.stats(&"foe", 200, 5, 5, 5)],
		3
	)


func test_one_action_per_turn() -> void:
	var combat := _combat_with_player([])
	var actor := combat.current
	var before := combat.history.size()
	combat.perform(BattleAction.attack(actor, combat.foes_of(actor)[0]))
	# Ровно два действия в истории: одно героя, одно автоматический ход врага.
	# Больше одного действия за ход модель не выполняет ни игроку, ни ИИ.
	assert_int(combat.history.size() - before).is_equal(2)
	var own_actions := 0
	for action in combat.history.slice(before):
		if action.actor == actor:
			own_actions += 1
	assert_int(own_actions).is_equal(1)


func test_ability_requires_focus() -> void:
	var strike := _strike()
	var combat := _combat_with_player([strike])
	var hero := combat.current
	hero.focus = 1
	assert_str(String(combat.ability_state(hero, strike))).is_equal("cost")
	assert_bool(_has_ability(combat, strike)).is_false()
	hero.focus = 2
	assert_str(String(combat.ability_state(hero, strike))).is_equal("ready")
	assert_bool(_has_ability(combat, strike)).is_true()


func test_ability_goes_on_cooldown() -> void:
	var strike := _strike()
	var combat := _combat_with_player([strike])
	var hero := combat.current
	combat.perform(BattleAction.use_ability(hero, strike, [combat.foes_of(hero)[0]]))
	# 3 − 2 за способность + 1 на следующем ходу героя.
	assert_int(hero.focus).is_equal(2)
	assert_str(String(combat.ability_state(hero, strike))).is_equal("cooldown")


func test_cooldown_expires() -> void:
	var strike := _strike()
	var combat := _combat_with_player([strike])
	var hero := combat.current
	combat.perform(BattleAction.use_ability(hero, strike, [combat.foes_of(hero)[0]]))
	assert_str(String(combat.ability_state(hero, strike))).is_equal("cooldown")
	# perform уже уменьшил кулдаун в конце хода героя — хватает ещё одного хода.
	hero.end_turn()
	assert_str(String(combat.ability_state(hero, strike))).is_equal("ready")


func test_ability_without_target_is_unavailable() -> void:
	var strike := _strike()
	var combat := _combat_with_player([strike])
	var hero := combat.current
	for foe in combat.alive(BattleUnit.SIDE_ENEMY):
		foe.deal_damage(9999)
	assert_str(String(combat.ability_state(hero, strike))).is_equal("no_target")


func test_pass_is_always_available() -> void:
	var combat := _combat_with_player([_strike()])
	var actions := combat.legal_actions(combat.current)
	assert_bool(actions[0].kind == BattleAction.Kind.PASS).is_true()


func _has_ability(combat: CombatState, ability: Ability) -> bool:
	for action in combat.legal_actions(combat.current):
		if action.ability == ability:
			return true
	return false
