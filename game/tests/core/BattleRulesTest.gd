extends GdUnitTestSuite


func _unit(stats: UnitStats, count := 5) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, count))
	u.max_count = count
	return u


func _seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_damage_multiplier_flat_when_equal() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	assert_float(BattleRules.damage_multiplier(atk, def, 0, 0)).is_equal(1.0)


func test_damage_multiplier_attack_advantage() -> void:
	var atk := _unit(UnitStats.new("a", "A", 15, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	assert_float(BattleRules.damage_multiplier(atk, def, 0, 0)).is_equal_approx(1.25, 0.001)


func test_damage_multiplier_defense_advantage() -> void:
	var atk := _unit(UnitStats.new("a", "A", 5, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	assert_float(BattleRules.damage_multiplier(atk, def, 0, 0)).is_equal_approx(0.875, 0.001)


func test_damage_multiplier_defending_boosts_defense() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 10))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 10))
	def.defending = true
	
	assert_float(BattleRules.damage_multiplier(atk, def, 0, 0)).is_equal_approx(0.95, 0.001)


func test_damage_multiplier_clamped_to_bounds() -> void:
	var strong := _unit(UnitStats.new("s", "S", 100, 5, 1, 1, 100))
	var weak := _unit(UnitStats.new("w", "W", 0, 1, 1, 1, 0))
	assert_float(BattleRules.damage_multiplier(strong, weak, 0, 0)).is_equal(GameNumbers.MAX_DAMAGE_MULTIPLIER)
	assert_float(BattleRules.damage_multiplier(weak, strong, 0, 0)).is_equal(GameNumbers.MIN_DAMAGE_MULTIPLIER)


func test_can_luck_immune_tags() -> void:
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("u", "U", 1, 1, 1, 1, 1, ["undead"])))).is_false()
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("e", "E", 1, 1, 1, 1, 1, ["elemental"])))).is_false()
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("m", "M", 1, 1, 1, 1, 1, ["mind_immune"])))).is_false()
	assert_bool(BattleRules.can_luck(_unit(UnitStats.new("n", "N", 1, 1, 1, 1, 1)))).is_true()
	assert_bool(BattleRules.can_luck(null)).is_false()


func test_can_morale_dragon_immune() -> void:
	assert_bool(BattleRules.can_morale(_unit(UnitStats.new("d", "D", 1, 1, 1, 1, 1, ["dragon"])))).is_false()
	assert_bool(BattleRules.can_morale(_unit(UnitStats.new("n", "N", 1, 1, 1, 1, 1)))).is_true()


func test_calculate_attack_deterministic_and_shaped() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	var r1 := BattleRules.calculate_attack(atk, def, true, _seeded_rng(42), 0, 0)
	var r2 := BattleRules.calculate_attack(atk, def, true, _seeded_rng(42), 0, 0)
	assert_dict(r1).is_equal(r2)
	assert_dict(r1).contains_keys(["damage", "kills", "luck", "is_retaliation"])
	assert_int(r1["damage"]).is_greater(0)
	assert_int(r1["kills"]).is_greater_equal(1)
	assert_int(r1["kills"]).is_less_equal(5)


func test_calculate_attack_dead_units_return_empty() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	def.alive = false
	assert_dict(BattleRules.calculate_attack(atk, def, true, _seeded_rng(1), 0, 0)).is_empty()


func test_calculate_attack_ranged_melee_penalty() -> void:
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	var ranged := _unit(UnitStats.new("r", "R", 10, 10, 1, 1, 0, ["ranged"]))
	var melee_unit := _unit(UnitStats.new("m", "M", 10, 10, 1, 1, 0))
	var melee_r := BattleRules.calculate_attack(ranged, def, true, _seeded_rng(7), 0, 0)
	var full_r := BattleRules.calculate_attack(melee_unit, def, true, _seeded_rng(7), 0, 0)
	
	assert_int(melee_r["damage"]).is_less_equal(full_r["damage"])


func test_calculate_attack_kills_capped_by_defender_count() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 100, 1, 1, 0), 10)
	var def := _unit(UnitStats.new("d", "D", 0, 0, 1, 1, 0), 3)
	var r := BattleRules.calculate_attack(atk, def, true, _seeded_rng(3), 0, 0)
	assert_int(r["kills"]).is_equal(3)


func test_preview_text_contains_damage_range() -> void:
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	var txt := BattleRules.preview_text(atk, def, 0, 0)
	assert_str(txt).contains("Damage:")
