#extends GdUnitTestSuite
# tests/unit/combat/test_damage.gd
# [AI]: сгенерировано по задаче 4.3 tasks.md, проверено человеком.
# Формула урона: целое, нижняя граница 1, воспроизводимость по seed.

extends GdUnitTestSuite


func _rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


func test_damage_is_integer_and_at_least_one() -> void:
	var weak := BattleUnit.new(BattleFactory.stats(&"weak", 50, 1, 0, 10), BattleUnit.SIDE_PLAYER, 0)
	var tank := BattleUnit.new(BattleFactory.stats(&"tank", 50, 1, 999, 10), BattleUnit.SIDE_ENEMY, 0)
	for seed_value in 40:
		assert_int(CombatRules.damage(weak, tank, null, _rng(seed_value))).is_equal(1)


func test_damage_reproducible_for_same_seed() -> void:
	var actor := BattleUnit.new(BattleFactory.stats(&"a", 50, 20, 5, 10), BattleUnit.SIDE_PLAYER, 0)
	var target := BattleUnit.new(BattleFactory.stats(&"t", 50, 10, 6, 10), BattleUnit.SIDE_ENEMY, 0)
	var first := CombatRules.damage(actor, target, null, _rng(4242))
	var second := CombatRules.damage(actor, target, null, _rng(4242))
	assert_int(first).is_equal(second)


func test_variance_stays_in_band() -> void:
	var actor := BattleUnit.new(BattleFactory.stats(&"a", 50, 100, 0, 10), BattleUnit.SIDE_PLAYER, 0)
	var target := BattleUnit.new(BattleFactory.stats(&"t", 50, 10, 0, 10), BattleUnit.SIDE_ENEMY, 0)
	for seed_value in 200:
		var damage: int = CombatRules.damage(actor, target, null, _rng(seed_value))
		assert_int(damage).is_between(90, 110)


func test_defense_reduces_damage() -> void:
	var actor := BattleUnit.new(BattleFactory.stats(&"a", 50, 30, 0, 10), BattleUnit.SIDE_PLAYER, 0)
	var soft := BattleUnit.new(BattleFactory.stats(&"soft", 50, 10, 0, 10), BattleUnit.SIDE_ENEMY, 0)
	var hard := BattleUnit.new(BattleFactory.stats(&"hard", 50, 10, 30, 10), BattleUnit.SIDE_ENEMY, 0)
	var generator := _rng(11)
	var first_run: Array = []
	for _i in 30:
		first_run.append(CombatRules.damage(actor, soft, null, generator))
	var second_run: Array = []
	for _i in 30:
		second_run.append(CombatRules.damage(actor, hard, null, generator))
	assert_float(_average(first_run)).is_greater(_average(second_run))


func test_defense_ignores_part_of_defense() -> void:
	var actor := BattleUnit.new(BattleFactory.stats(&"a", 50, 30, 0, 10), BattleUnit.SIDE_PLAYER, 0)
	var target := BattleUnit.new(BattleFactory.stats(&"t", 50, 10, 40, 10), BattleUnit.SIDE_ENEMY, 0)
	var pierce := BattleFactory.ability(&"pierce", 1, 0, 1.0,
		Ability.TargetKind.ENEMY_SINGLE, [], [], 1, 1.0)
	var plain := CombatRules.damage(actor, target, null, _rng(5))
	var piercing := CombatRules.damage(actor, target, pierce, _rng(5))
	# Защита игнорируется целиком: урон = атака × разброс, без вычета защиты.
	assert_int(piercing).is_between(27, 33)
	assert_int(piercing).is_greater(plain)


func test_weaken_lowers_attack() -> void:
	var actor := BattleUnit.new(BattleFactory.stats(&"a", 50, 20, 0, 10), BattleUnit.SIDE_PLAYER, 0)
	assert_int(actor.effective_attack()).is_equal(20)
	actor.apply_status(&"weaken")
	assert_int(actor.effective_attack()).is_equal(14)


func _average(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(maxi(1, values.size()))
