#extends GdUnitTestSuite
# tests/unit/combat/test_determinism.gd
# [AI]: сгенерировано по задаче 4.7 tasks.md.
# Детерминизм: тот же seed и тот же ввод дают тот же бой.

extends GdUnitTestSuite


func _pool() -> Array:
	return [
		BattleFactory.stats(&"a", 90, 18, 6, 14, [BattleFactory.ability(&"cut", 2, 2, 1.6)]),
		BattleFactory.stats(&"b", 70, 22, 4, 9, [BattleFactory.ability(&"bleed_hit", 2, 3, 1.1,
			Ability.TargetKind.ENEMY_SINGLE, [&"bleed"])]),
		BattleFactory.stats(&"c", 110, 12, 10, 6),
	]


func _enemies() -> Array:
	return [BattleFactory.stats(&"foe", 260, 20, 8, 11,
		[BattleFactory.ability(&"sweep", 2, 3, 1.2, Ability.TargetKind.ENEMY_ALL, [&"bleed"])])]


## Подпись боя: исход, длина очереди и фактический урон каждого действия.
func _signature(combat: CombatState) -> String:
	var lines: Array[String] = ["%d/%d" % [combat.result, combat.turn_index]]
	for action in combat.history:
		var parts: Array[String] = [BattleAction.Kind.keys()[action.kind], action.actor.uid()]
		for target in action.targets:
			parts.append(target.uid())
		var keys := action.damage.keys()
		keys.sort()
		for key in keys:
			parts.append("%s=%d" % [key, int(action.damage[key])])
		lines.append("|".join(parts))
	return "\n".join(lines)


func _run(seed_value: int) -> String:
	var combat := BattleFactory.state(BattleFactory.roster(_pool()), _enemies(), seed_value)
	BattleFactory.auto_play(combat)
	return _signature(combat)


func test_same_seed_reproduces_the_whole_battle() -> void:
	assert_str(_run(20261024)).is_equal(_run(20261024))


func test_battle_actually_happened() -> void:
	# Защита от «детерминированного» пустого прогона: бой должен кончиться исходом.
	var combat := BattleFactory.state(BattleFactory.roster(_pool()), _enemies(), 20261024)
	BattleFactory.auto_play(combat)
	assert_bool(combat.finished).is_true()
	assert_int(combat.result).is_not_equal(CombatState.NO_RESULT)
	assert_int(combat.history.size()).is_greater(3)


func test_different_seed_changes_damage_draw() -> void:
	# Разные seed дают разные числа урона — иначе «variance» в формуле лишний.
	var a := BattleFactory.state(BattleFactory.roster(_pool()), _enemies(), 1)
	var b := BattleFactory.state(BattleFactory.roster(_pool()), _enemies(), 999999)
	BattleFactory.auto_play(a)
	BattleFactory.auto_play(b)
	assert_str(_signature(a)).is_not_equal(_signature(b))
