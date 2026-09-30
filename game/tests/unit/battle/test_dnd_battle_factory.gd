extends BaseTest

## dnd-battle-factory: production API to build and resolve D&D battles from
## explicit character definitions. DnDCharacterDef -> DnDCombatantProfile ->
## UnitStack (with dnd_profile) -> BattleState (via BattleStateBuilder);
## simulate() -> winner + survivors (via BattleEmulator).
##
## This moves the per-character D&D combat model from a test-only capability to
## a production entry point a game scenario can call, without touching the
## stack-model battle flow.

var rng: RandomNumberGenerator


func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260930


## A DnDCharacterDef helper (STR/DEX set, rest default).
func _def(
	id: String,
	name: String,
	str_score: int = 15,
	dex_score: int = 10,
	class_id: String = "",
	race_id: String = "",
	max_hp: int = 10,
	speed: int = 5,
	weapon: String = "longsword"
) -> DnDBattleFactory.DnDCharacterDef:
	var d := DnDBattleFactory.DnDCharacterDef.new(id, name)
	d.abilities = {"str": str_score, "dex": dex_score}
	d.class_id = class_id
	d.race_id = race_id
	d.max_hp = max_hp
	d.speed = speed
	d.weapon = weapon
	return d


# ---------------------------------------------------------------------------
# 1. build_profile
# ---------------------------------------------------------------------------

func test_build_profile_abilities_class_race() -> void:
	var p := DnDBattleFactory.build_profile(
		_def("p1", "P1", 16, 12, "fighter", "dwarf", 20))
	assert_that(p.abilities.get_score(DNDAbilityScores.Ability.STR)).is_equal(16)
	assert_that(p.abilities.get_score(DNDAbilityScores.Ability.DEX)).is_equal(12)
	assert_that(p.class_id).is_equal("fighter")
	assert_that(p.race_id).is_equal("dwarf")
	assert_that(p.max_hp).is_equal(20)
	assert_that(p.weapon).is_equal("longsword")


func test_build_profile_ac_derived_from_dex() -> void:
	# DEX 14 (mod +2), no armor -> AC = 10 + 2 = 12.
	var p := DnDBattleFactory.build_profile(_def("p1", "P1", 15, 14))
	assert_that(p.get_ac()).is_equal(12)


func test_build_profile_ac_with_armor() -> void:
	# DEX 10 (mod 0), chain_mail (base 16, max_dex 0) -> AC = 16.
	var d := _def("p1", "P1", 15, 10)
	d.armor_type = DNDArmorClass.ArmorType.CHAIN_MAIL
	var p := DnDBattleFactory.build_profile(d)
	assert_that(p.get_ac()).is_equal(16)


func test_build_profile_unknown_ability_ignored() -> void:
	var d := _def("p1", "P1", 18, 10)
	d.abilities = {"str": 18, "dex": 10, "foo": 99}  # "foo" is not an ability
	var p := DnDBattleFactory.build_profile(d)
	assert_that(p.abilities.get_score(DNDAbilityScores.Ability.STR)).is_equal(18)
	# Unknown key does not corrupt the profile.
	assert_that(p.get_ac()).is_equal(10)


# ---------------------------------------------------------------------------
# 2. build_stack
# ---------------------------------------------------------------------------

func test_build_stack_carries_profile() -> void:
	var s := DnDBattleFactory.build_stack(_def("p1", "P1", 16, 10, "", "", 20, 6))
	assert_that(s.dnd_profile).is_not_null()
	assert_that(s.count).is_equal(1)
	assert_that(s.stats.speed).is_equal(6)
	assert_that(s.dnd_profile.max_hp).is_equal(20)


func test_build_stack_duplicate_keeps_profile() -> void:
	var s := DnDBattleFactory.build_stack(_def("p1", "P1"))
	var s2: UnitStack = s.duplicate_stack()
	assert_that(s2.dnd_profile).is_not_null()
	assert_that(s2.dnd_profile.id).is_equal("p1")


# ---------------------------------------------------------------------------
# 3. build_battle
# ---------------------------------------------------------------------------

func test_build_battle_both_sides_dnd() -> void:
	var state := DnDBattleFactory.build_battle(
		[_def("a1", "A1", 16, 10, "fighter")],
		[_def("e1", "E1", 10, 10)])
	var atk: Array = state.get_units_by_side(BattleState.Side.ATTACKER)
	var def: Array = state.get_units_by_side(BattleState.Side.DEFENDER)
	assert_that(atk.size()).is_equal(1)
	assert_that(def.size()).is_equal(1)
	assert_that(atk[0].is_dnd_character()).is_true()
	assert_that(def[0].is_dnd_character()).is_true()
	# HP pool initialized to max_hp.
	assert_that(atk[0].dnd_current_hp).is_equal(atk[0].dnd_profile.max_hp)
	# Fresh battle: no winner yet.
	assert_that(state.battle_winner).is_equal(BattleState.Side.NONE)


# ---------------------------------------------------------------------------
# 4. simulate
# ---------------------------------------------------------------------------

func test_simulate_resolves_to_winner() -> void:
	# Strong ally vs weak enemy -> resolves to a winner; loser has 0 survivors.
	var r: Dictionary = DnDBattleFactory.simulate(
		[_def("a1", "A1", 18, 14, "fighter", "dwarf", 30, 6)],
		[_def("e1", "E1", 8, 8, "", "", 5, 3, "dagger")],
		12345)
	assert_that(r.get("battle_over", false)).is_true()
	var winner: String = str(r.get("winner", ""))
	assert_that(winner == "attacker" or winner == "defender").is_true()
	if winner == "attacker":
		assert_that((r.get("def_survivors", []) as Array).size()).is_equal(0)
	else:
		assert_that((r.get("atk_survivors", []) as Array).size()).is_equal(0)


func test_simulate_deterministic_by_seed() -> void:
	var allies := [_def("a1", "A1", 15, 12, "fighter")]
	var enemies := [_def("e1", "E1", 15, 12, "ranger")]
	var r1: Dictionary = DnDBattleFactory.simulate(allies, enemies, 777)
	var r2: Dictionary = DnDBattleFactory.simulate(allies, enemies, 777)
	assert_that(str(r1.get("winner", ""))).is_equal(str(r2.get("winner", "")))
	assert_that(int(r1.get("turns", 0))).is_equal(int(r2.get("turns", 0)))


# ---------------------------------------------------------------------------
# 5. Class/race bonuses flow through the factory (the seam)
# ---------------------------------------------------------------------------

func test_build_profile_class_bonus_present() -> void:
	# A fighter carries a defense bonus; a no-class twin has none (backward-compat).
	var p := DnDBattleFactory.build_profile(_def("a1", "A1", 15, 12, "fighter"))
	assert_that(p.get_defense_bonus()).is_equal(1)
	var p0 := DnDBattleFactory.build_profile(_def("a1", "A1", 15, 12))
	assert_that(p0.get_defense_bonus()).is_equal(0)


func test_build_profile_race_bonus_present() -> void:
	# A halfling carries a crit bonus; class+race bonuses sum.
	var p := DnDBattleFactory.build_profile(_def("a1", "A1", 15, 12, "rogue", "halfling"))
	# rogue crit +1, halfling crit +1 -> total +2.
	assert_that(p.get_crit_bonus()).is_equal(2)
