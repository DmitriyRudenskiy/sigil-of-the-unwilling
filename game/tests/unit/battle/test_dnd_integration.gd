extends BaseTest

## D&D battle-system Phase 6 (TASK_21) integration tests:
## DnDCombatantProfile (combatant D&D stats) + DnDBattleBridge (attack resolution
## delegating to D&D system, initiative via DNDInitiativeTracker) + BattleUnit seam.
## Hit/miss is made deterministic via extreme AC (AC=1 always hit, AC=99 always
## miss) — no RNG rigging needed.

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260926


func _make_profile(p_id: String, p_name: String, str_score: int, dex_score: int,
	ac_override: int = -1) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(p_id, p_name)
	p.abilities.set_score(DNDAbilityScores.Ability.STR, str_score)
	p.abilities.set_score(DNDAbilityScores.Ability.DEX, dex_score)
	if ac_override >= 0:
		# Force a known AC by using unarmored 10+DEX then patching armor bonus.
		p.armor.armor_bonus = ac_override - (10 + DNDAbilityScores.get_ability_modifier(dex_score))
	return p


# ---------- Profile ----------

func test_profile_unarmored_ac() -> void:
	var p := DnDCombatantProfile.new("a", "A")
	p.abilities.set_score(DNDAbilityScores.Ability.DEX, 14)
	assert_that(p.get_ac()).is_equal(12)  # 10 + 2


func test_profile_attack_mod_melee_uses_str() -> void:
	var p := DnDCombatantProfile.new("a", "A")
	p.abilities.set_score(DNDAbilityScores.Ability.STR, 16)
	p.abilities.set_score(DNDAbilityScores.Ability.DEX, 10)
	assert_that(p.get_attack_ability_mod()).is_equal(3)


func test_profile_attack_mod_ranged_uses_dex() -> void:
	var p := DnDCombatantProfile.new("a", "A")
	p.is_ranged = true
	p.abilities.set_score(DNDAbilityScores.Ability.STR, 18)
	p.abilities.set_score(DNDAbilityScores.Ability.DEX, 14)
	assert_that(p.get_attack_ability_mod()).is_equal(2)


func test_profile_serialization_roundtrip() -> void:
	var p := DnDCombatantProfile.new("knight", "Sir")
	p.abilities.set_score(DNDAbilityScores.Ability.STR, 18)
	p.proficiency_bonus = 3
	p.weapon = "greatsword"
	p.is_ranged = false
	var back := DnDCombatantProfile.from_dict(p.to_dict())
	assert_that(back.id).is_equal("knight")
	assert_that(back.name).is_equal("Sir")
	assert_that(back.abilities.get_score(DNDAbilityScores.Ability.STR)).is_equal(18)
	assert_that(back.proficiency_bonus).is_equal(3)
	assert_that(back.weapon).is_equal("greatsword")
	assert_that(back.is_ranged).is_equal(false)


# ---------- Bridge: attack resolution ----------

func test_bridge_attack_hit_against_low_ac() -> void:
	var atk := _make_profile("a", "A", 18, 10)
	var def := _make_profile("d", "D", 10, 10, 1)  # AC 1 -> always hit
	var r: Dictionary = DnDBattleBridge.resolve_attack(atk, def, rng)
	assert_that(r["hit"]).is_equal(true)
	assert_that(r["miss"]).is_equal(false)
	assert_that(r["ac"]).is_equal(1)
	assert_that(r["damage"]).is_greater_equal(1)
	assert_that(r.has("roll_total")).is_equal(true)
	assert_that(r.has("breakdown")).is_equal(true)


func test_bridge_attack_miss_against_high_ac() -> void:
	var atk := _make_profile("a", "A", 1, 1)
	var def := _make_profile("d", "D", 10, 10, 99)  # AC 99 -> always miss
	var r: Dictionary = DnDBattleBridge.resolve_attack(atk, def, rng)
	assert_that(r["hit"]).is_equal(false)
	assert_that(r["miss"]).is_equal(true)
	assert_that(r["damage"]).is_equal(0)


func test_bridge_advantage_never_worse_than_single() -> void:
	# With advantage the natural roll is max of two d20, so it is >= either single
	# roll. We only assert the result is well-formed and the natural roll is in range.
	var atk := _make_profile("a", "A", 10, 10)
	var def := _make_profile("d", "D", 10, 10, 1)
	var r: Dictionary = DnDBattleBridge.resolve_attack(atk, def, rng, true, false)
	assert_that(r["natural_roll"]).is_between(1, 20)
	assert_that(r["hit"]).is_equal(true)


# ---------- Bridge: initiative ----------

func test_bridge_initiative_sorted_desc() -> void:
	var a := DnDCombatantProfile.new("a", "A")
	a.abilities.set_score(DNDAbilityScores.Ability.DEX, 18)
	var b := DnDCombatantProfile.new("b", "B")
	b.abilities.set_score(DNDAbilityScores.Ability.DEX, 8)
	var tracker: DNDInitiativeTracker = DnDBattleBridge.build_initiative([a, b], rng)
	assert_that(tracker.turn_order.size()).is_equal(2)
	var order: Array[Dictionary] = tracker.get_turn_order()
	assert_that(order.size()).is_equal(2)
	assert_that(order[0]["initiative"]).is_greater_equal(order[1]["initiative"])


# ---------- BattleUnit seam (backward compatibility) ----------

func test_battleunit_default_has_no_dnd_profile() -> void:
	var u: BattleState.BattleUnit = BattleState.BattleUnit.new()
	assert_that(u.dnd_profile).is_null()


func test_battleunit_can_carry_dnd_profile_and_attack() -> void:
	var u: BattleState.BattleUnit = BattleState.BattleUnit.new()
	var p := _make_profile("u", "U", 18, 10)
	u.dnd_profile = p
	var def := _make_profile("d", "D", 10, 10, 1)
	var r: Dictionary = DnDBattleBridge.resolve_attack(u.dnd_profile, def, rng)
	assert_that(r["hit"]).is_equal(true)
	assert_that(r["damage"]).is_greater_equal(1)
	# Stack-model fields untouched (backward compat)
	assert_that(u.get_count()).is_equal(0)
