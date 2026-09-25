extends BaseTest

## Unit-тесты D&D 5e core (dnd-battle-system Phase 1, TASK_01..06):
## ability_scores, proficiency_system, armor_class, attack_roll,
## damage_calculator, initiative_tracker.

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260925

# ---------- TASK_01: Ability Scores ----------

func test_modifier_table_boundaries() -> void:
	assert_that(DNDAbilityScores.get_ability_modifier(5)).is_equal(-3)
	assert_that(DNDAbilityScores.get_ability_modifier(8)).is_equal(-1)
	assert_that(DNDAbilityScores.get_ability_modifier(10)).is_equal(0)
	assert_that(DNDAbilityScores.get_ability_modifier(14)).is_equal(2)
	assert_that(DNDAbilityScores.get_ability_modifier(18)).is_equal(4)
	assert_that(DNDAbilityScores.get_ability_modifier(20)).is_equal(5)

func test_modifier_all_scores() -> void:
	var expected = {8: -1, 9: -1, 10: 0, 11: 0, 12: 1, 13: 1, 14: 2, 15: 2, 16: 3, 17: 3, 18: 4, 19: 4, 20: 5}
	for score in expected:
		assert_that(DNDAbilityScores.get_ability_modifier(score)).is_equal(expected[score])

func test_six_scores_and_get_set() -> void:
	var a = DNDAbilityScores.new(15, 14, 13, 12, 10, 8)
	assert_that(a.get_score(DNDAbilityScores.Ability.STR)).is_equal(15)
	assert_that(a.get_score(DNDAbilityScores.Ability.CHA)).is_equal(8)
	a.set_score(DNDAbilityScores.Ability.STR, 20)
	assert_that(a.get_str_mod()).is_equal(5)
	var mods = a.get_all_modifiers()
	assert_that(mods.size()).is_equal(6)

func test_scores_clamped() -> void:
	var a = DNDAbilityScores.new(99, 0, 10, 10, 10, 10)
	assert_that(a.get_score(DNDAbilityScores.Ability.STR)).is_equal(30)
	assert_that(a.get_score(DNDAbilityScores.Ability.DEX)).is_equal(1)

# ---------- TASK_02: Proficiency ----------

func test_proficiency_scaling_by_level() -> void:
	var p = DNDProficiencySystem.new(1)
	assert_that(p.get_proficiency_bonus()).is_equal(2)
	p.set_level(5)
	assert_that(p.get_proficiency_bonus()).is_equal(3)
	p.set_level(9)
	assert_that(p.get_proficiency_bonus()).is_equal(4)
	p.set_level(13)
	assert_that(p.get_proficiency_bonus()).is_equal(5)
	p.set_level(17)
	assert_that(p.get_proficiency_bonus()).is_equal(6)
	p.set_level(25)  # clamp
	assert_that(p.level).is_equal(20)
	assert_that(p.get_proficiency_bonus()).is_equal(6)

func test_proficiency_bonus_only_when_proficient() -> void:
	var p = DNDProficiencySystem.new(4)
	p.add_skill_proficiency("Stealth")
	assert_that(p.get_skill_bonus("Stealth")).is_equal(2)
	assert_that(p.get_skill_bonus("Athletics")).is_equal(0)
	p.add_expertise("Stealth")
	assert_that(p.get_skill_bonus("Stealth")).is_equal(4)

func test_weapon_save_proficiency() -> void:
	var p = DNDProficiencySystem.new(1)
	p.add_weapon_proficiency("longsword")
	p.add_save_proficiency("CON")
	assert_that(p.is_weapon_proficient("longsword")).is_true()
	assert_that(p.is_weapon_proficient("greataxe")).is_false()
	assert_that(p.is_save_proficient("CON")).is_true()

# ---------- TASK_03: Armor Class ----------

func test_unarmored_ac() -> void:
	var ac = DNDArmorClass.new(DNDArmorClass.ArmorType.NONE, 3)
	assert_that(ac.calculate_ac()).is_equal(13)

func test_light_armor_full_dex() -> void:
	var ac = DNDArmorClass.new(DNDArmorClass.ArmorType.LEATHER, 4)
	assert_that(ac.calculate_ac()).is_equal(15)  # 11 + 4

func test_medium_armor_dex_cap_2() -> void:
	var ac = DNDArmorClass.new(DNDArmorClass.ArmorType.CHAIN_MAIL, 5)
	assert_that(ac.calculate_ac()).is_equal(16)  # 16 + min(5,0)=0; chain mail cap 0
	var ac2 = DNDArmorClass.new(DNDArmorClass.ArmorType.HIDE, 5)
	assert_that(ac2.calculate_ac()).is_equal(14)  # 12 + min(5,2)

func test_heavy_armor_no_dex() -> void:
	var ac = DNDArmorClass.new(DNDArmorClass.ArmorType.PLATE, 4)
	assert_that(ac.calculate_ac()).is_equal(18)
	var ac_neg = DNDArmorClass.new(DNDArmorClass.ArmorType.PLATE, -3)
	assert_that(ac_neg.calculate_ac()).is_equal(18)  # negative DEX not applied

func test_shield_bonus_and_proficiency() -> void:
	var ac = DNDArmorClass.new(DNDArmorClass.ArmorType.NONE, 2)
	ac.set_shield(true)
	assert_that(ac.calculate_ac()).is_equal(14)  # 12 + 2
	ac.shield_proficient = false
	assert_that(ac.calculate_ac()).is_equal(12)  # shield ignored

func test_all_phb_armor_types_supported() -> void:
	assert_that(DNDArmorClass.ARMOR_DATA.size()).is_equal(13)  # 12 PHB + NONE

# ---------- TASK_04: Attack Roll ----------

func test_basic_roll_formula() -> void:
	var r = DNDAttackRoll.new()
	var total = r.roll(rng, 3, 2, 1)
	assert_that(total).is_equal(r.d20_result + 3 + 2 + 1)
	assert_that(total).is_between(1 + 6, 20 + 6)

func test_advantage_takes_higher() -> void:
	for i in range(50):
		var r = DNDAttackRoll.new()
		r.roll(rng, 0, 0, 0, true, false)
		assert_that(r.d20_result).is_greater_equal(r.second_d20)

func test_disadvantage_takes_lower() -> void:
	for i in range(50):
		var r = DNDAttackRoll.new()
		r.roll(rng, 0, 0, 0, false, true)
		assert_that(r.d20_result).is_less_equal(r.second_d20)

func test_critical_hit_and_miss() -> void:
	# roll until natural 20 / natural 1 appears and verify flags
	var r20: DNDAttackRoll = null
	var r1: DNDAttackRoll = null
	for i in range(200):
		var r = DNDAttackRoll.new()
		r.roll(rng, 0, 0, 0)
		assert_that(r.is_crit_hit()).is_equal(r.d20_result == 20)
		assert_that(r.is_crit_miss()).is_equal(r.d20_result == 1)
		if r.d20_result == 20:
			r20 = r
		if r.d20_result == 1:
			r1 = r
	assert_that(r20).is_not_null()
	assert_that(r20.is_crit_hit()).is_true()
	assert_that(r1).is_not_null()
	assert_that(r1.is_crit_miss()).is_true()
	var rn = DNDAttackRoll.new()
	rn.d20_result = 12
	assert_that(rn.is_crit_hit()).is_false()
	assert_that(rn.is_crit_miss()).is_false()

func test_advantage_disadvantage_cancel() -> void:
	var r = DNDAttackRoll.new()
	r.roll(rng, 0, 0, 0, true, true)
	assert_that(r.has_advantage).is_false()
	assert_that(r.has_disadvantage).is_false()
	assert_that(r.second_d20).is_equal(0)

# ---------- TASK_05: Damage ----------

func test_roll_dice_ranges() -> void:
	var total = DNDDamageCalculator.roll_dice("2d6", rng)
	assert_that(total).is_between(2, 12)
	var one = DNDDamageCalculator.roll_dice("1d4", rng)
	assert_that(one).is_between(1, 4)
	assert_that(DNDDamageCalculator.roll_dice("0d0", rng)).is_equal(0)

func test_calculate_damage_normal_and_crit() -> void:
	var calc = DNDDamageCalculator.new()
	var res = calc.calculate_damage(rng, "longsword", 2, false)
	assert_that(res["base_damage"]).is_between(1, 8)
	assert_that(res["total"]).is_equal(res["base_damage"] + 2)
	assert_that(res["damage_type"]).is_equal(DNDDamageCalculator.DamageType.SLASHING)
	var crit = calc.calculate_damage(rng, "longsword", 2, true)
	assert_that(crit["is_critical"]).is_true()
	assert_that(crit["base_damage"]).is_between(2, 16)  # double dice

func test_resistance_vulnerability_immunity() -> void:
	var calc = DNDDamageCalculator.new()
	var fire = DNDDamageCalculator.DamageType.FIRE
	assert_that(calc.apply_resistance(10, fire, [fire])).is_equal(5)
	assert_that(calc.apply_resistance(10, fire, [], [fire])).is_equal(20)
	assert_that(calc.apply_resistance(10, fire, [], [], [fire])).is_equal(0)
	# resistance rounds down, min 1
	assert_that(calc.apply_resistance(1, fire, [fire])).is_equal(1)

func test_all_13_damage_types() -> void:
	assert_that(DNDDamageCalculator.DAMAGE_TYPE_NAMES.size()).is_equal(13)
	for i in 13:
		assert_that(DNDDamageCalculator.get_damage_type_name(i)).is_not_empty()

# ---------- TASK_06: Initiative ----------

func test_initiative_formula_and_order() -> void:
	var t = DNDInitiativeTracker.new()
	t.add_combatant("a", "A", 10, 2)
	t.add_combatant("b", "B", 12, 1)
	t.add_combatant("c", "C", 9, 3)
	var order = t.get_turn_order()
	assert_that(order[0]["id"]).is_equal("b")
	assert_that(order[1]["id"]).is_equal("a")
	assert_that(order[2]["id"]).is_equal("c")

func test_initiative_tie_broken_by_dex() -> void:
	var t = DNDInitiativeTracker.new()
	t.add_combatant("low_dex", "L", 10, 1)
	t.add_combatant("high_dex", "H", 10, 4)
	var order = t.get_turn_order()
	assert_that(order[0]["id"]).is_equal("high_dex")

func test_next_turn_cycles_and_rounds() -> void:
	var t = DNDInitiativeTracker.new()
	t.add_combatant("a", "A", 10, 2)
	t.add_combatant("b", "B", 12, 1)
	assert_that(t.next_turn().id).is_equal("b")
	assert_that(t.next_turn().id).is_equal("a")
	assert_that(t.next_turn().id).is_equal("b")
	assert_that(t.current_round).is_equal(2)

func test_add_remove_combatant_mid_combat() -> void:
	var t = DNDInitiativeTracker.new()
	t.add_combatant("a", "A", 10, 2)
	t.add_combatant("b", "B", 12, 1)
	assert_that(t.remove_combatant("b")).is_true()
	assert_that(t.get_turn_order().size()).is_equal(1)
	assert_that(t.remove_combatant("nope")).is_false()
	t.add_combatant("c", "C", 15, 0)
	assert_that(t.get_turn_order()[0]["id"]).is_equal("c")

func test_roll_initiative_uses_dex_and_bonus() -> void:
	var t = DNDInitiativeTracker.new()
	var r = RandomNumberGenerator.new()
	r.seed = 42
	var init = t.roll_initiative("x", "X", 3, r, 1)
	assert_that(init).is_between(1 + 4, 20 + 4)
	assert_that(t.get_turn_order()[0]["id"]).is_equal("x")
