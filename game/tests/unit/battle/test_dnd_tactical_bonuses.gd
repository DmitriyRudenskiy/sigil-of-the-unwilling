extends BaseTest

## dnd-class-race-tactical-bonuses: class/race -> tactical battle bonuses.
##
## A DnDCombatantProfile with class_id/race_id gets four tactical bonuses
## (attack/defense/crit/damage) that DnDBattleBridge.resolve_attack applies.
## Class + race bonuses ADD. Unknown ids / no class/race (default "") -> 0
## (backward compatible: resolution unchanged).
##
## Deterministic strategy:
##   - attack_bonus & damage_bonus: compared with/without the bonus using two
##     same-seed RNGs (identical d20/dice; only the bonus differs by a known +N).
##   - defense_bonus & crit_bonus: pure data (no RNG) via get_total_ac() and
##     crits_on(natural).

var rng: RandomNumberGenerator


func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260929


## Build a DnDCombatantProfile with a target AC (via armor.armor_bonus, DEX 10).
## DEX 10 -> mod 0, so AC = 10 + 0 + armor_bonus = 10 + (ac - 10) = ac.
func _profile(p_id: String, p_name: String, str_score: int = 10,
		ac: int = 15, p_max_hp: int = 10) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(p_id, p_name)
	p.abilities.set_score(DNDAbilityScores.Ability.STR, str_score)
	p.abilities.set_score(DNDAbilityScores.Ability.DEX, 10)  # mod 0, no AC shift
	p.armor.armor_type = DNDArmorClass.ArmorType.NONE
	p.armor.armor_bonus = ac - 10
	p.max_hp = p_max_hp
	return p


# ---------------------------------------------------------------------------
# 1. Data: class_id / race_id on the profile
# ---------------------------------------------------------------------------

func test_profile_default_no_class_race() -> void:
	var p := DnDCombatantProfile.new("a", "A")
	assert_that(p.class_id).is_equal("")
	assert_that(p.race_id).is_equal("")
	# No class/race -> all four bonuses 0 (backward compatible).
	assert_that(p.get_attack_bonus()).is_equal(0)
	assert_that(p.get_defense_bonus()).is_equal(0)
	assert_that(p.get_crit_bonus()).is_equal(0)
	assert_that(p.get_damage_bonus()).is_equal(0)


func test_profile_serialization_roundtrip_class_race() -> void:
	var p := _profile("knight", "Sir")
	p.class_id = "fighter"
	p.race_id = "dwarf"
	var back := DnDCombatantProfile.from_dict(p.to_dict())
	assert_that(back.class_id).is_equal("fighter")
	assert_that(back.race_id).is_equal("dwarf")
	# Bonuses survive the roundtrip (fighter +1, dwarf +1 = defense +2).
	assert_that(back.get_defense_bonus()).is_equal(2)


func test_profile_get_total_ac_includes_defense_bonus() -> void:
	var p := _profile("a", "A", 10, 15)
	# No class/race: total AC == base AC.
	assert_that(p.get_total_ac()).is_equal(p.get_ac())
	p.class_id = "fighter"  # defense +1
	assert_that(p.get_total_ac()).is_equal(p.get_ac() + 1)


# ---------------------------------------------------------------------------
# 2. Table: DnDTacticalBonuses lookup
# ---------------------------------------------------------------------------

func test_table_known_class_bonus() -> void:
	assert_that(DnDTacticalBonuses.get_defense_bonus("fighter", "")).is_equal(1)
	assert_that(DnDTacticalBonuses.get_crit_bonus("rogue", "")).is_equal(1)
	assert_that(DnDTacticalBonuses.get_attack_bonus("ranger", "")).is_equal(1)
	assert_that(DnDTacticalBonuses.get_damage_bonus("barbarian", "")).is_equal(1)


func test_table_known_race_bonus() -> void:
	assert_that(DnDTacticalBonuses.get_defense_bonus("", "dwarf")).is_equal(1)
	assert_that(DnDTacticalBonuses.get_attack_bonus("", "human")).is_equal(1)
	assert_that(DnDTacticalBonuses.get_damage_bonus("", "dragonborn")).is_equal(1)
	assert_that(DnDTacticalBonuses.get_crit_bonus("", "halfling")).is_equal(1)


func test_table_unknown_id_is_zero() -> void:
	assert_that(DnDTacticalBonuses.get_attack_bonus("ninja", "")).is_equal(0)
	assert_that(DnDTacticalBonuses.get_defense_bonus("", "elf")).is_equal(0)
	assert_that(DnDTacticalBonuses.get_crit_bonus("ninja", "elf")).is_equal(0)
	assert_that(DnDTacticalBonuses.get_damage_bonus("", "")).is_equal(0)


func test_table_class_and_race_sum() -> void:
	# paladin (defense +1) + dwarf (defense +1) = defense +2
	assert_that(DnDTacticalBonuses.get_defense_bonus("paladin", "dwarf")).is_equal(2)
	# paladin (damage +1) + dragonborn (damage +1) = damage +2
	assert_that(DnDTacticalBonuses.get_damage_bonus("paladin", "dragonborn")).is_equal(2)


# ---------------------------------------------------------------------------
# 3. attack_bonus: raises the d20 attack roll
# ---------------------------------------------------------------------------

func test_attack_bonus_raises_roll_total() -> void:
	var base := _profile("b", "B", 10, 15)          # no class/race
	var ranger := _profile("r", "R", 10, 15)
	ranger.class_id = "ranger"                        # attack +1
	assert_that(ranger.get_attack_bonus()).is_equal(1)

	var def := _profile("d", "D", 10, 1)              # AC 1 -> always hit
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 777
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 777
	var r_base: Dictionary = DnDBattleBridge.resolve_attack(base, def, rng1)
	var r_ranger: Dictionary = DnDBattleBridge.resolve_attack(ranger, def, rng2)
	# Same d20 (same seed); ranger's attack total is exactly +1.
	assert_that(int(r_ranger["roll_total"])).is_equal(int(r_base["roll_total"]) + 1)


# ---------------------------------------------------------------------------
# 4. defense_bonus: raises effective AC
# ---------------------------------------------------------------------------

func test_defense_bonus_raises_ac_in_resolve() -> void:
	var atk := _profile("a", "A", 10, 15)
	var def_plain := _profile("d1", "D1", 10, 15)
	var def_fighter := _profile("d2", "D2", 10, 15)
	def_fighter.class_id = "fighter"                  # defense +1
	assert_that(def_fighter.get_total_ac()).is_equal(def_plain.get_ac() + 1)

	# In resolve, the reported AC reflects the defense bonus.
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 778
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 778
	var r1: Dictionary = DnDBattleBridge.resolve_attack(atk, def_plain, rng1)
	var r2: Dictionary = DnDBattleBridge.resolve_attack(atk, def_fighter, rng2)
	assert_that(int(r2["ac"])).is_equal(int(r1["ac"]) + 1)


# ---------------------------------------------------------------------------
# 5. crit_bonus: extends the crit range
# ---------------------------------------------------------------------------

func test_crit_bonus_extends_range() -> void:
	var rogue := _profile("r", "R", 10, 15)
	rogue.class_id = "rogue"                           # crit +1 (range 19-20)
	assert_that(rogue.get_crit_bonus()).is_equal(1)
	assert_that(rogue.crits_on(19)).is_equal(true)
	assert_that(rogue.crits_on(20)).is_equal(true)
	assert_that(rogue.crits_on(18)).is_equal(false)


func test_crit_no_bonus_only_natural_20() -> void:
	var p := _profile("a", "A", 10, 15)                # no class/race
	assert_that(p.get_crit_bonus()).is_equal(0)
	assert_that(p.crits_on(20)).is_equal(true)
	assert_that(p.crits_on(19)).is_equal(false)
	assert_that(p.crits_on(1)).is_equal(false)


# ---------------------------------------------------------------------------
# 6. damage_bonus: adds flat damage on a hit
# ---------------------------------------------------------------------------

func test_damage_bonus_adds_flat_damage() -> void:
	var base := _profile("b", "B", 10)                 # attacker (AC irrelevant)
	var barb := _profile("r", "R", 10)
	barb.class_id = "barbarian"                         # damage +1
	assert_that(barb.get_damage_bonus()).is_equal(1)

	var def := _profile("d", "D", 10, 1)               # AC 1 -> always hit
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 779
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 779
	var r_base: Dictionary = DnDBattleBridge.resolve_attack(base, def, rng1)
	var r_barb: Dictionary = DnDBattleBridge.resolve_attack(barb, def, rng2)
	assert_that(r_base["hit"]).is_equal(true)
	# Same d20 & dice (same seed, both crit_bonus=0); barbarian's damage is +1.
	assert_that(int(r_barb["damage"])).is_equal(int(r_base["damage"]) + 1)


# ---------------------------------------------------------------------------
# 7. Backward-compat: no class/race -> resolution unchanged
# ---------------------------------------------------------------------------

func test_backward_compat_no_class_race_matches_plain() -> void:
	# A profile with explicit empty class/race behaves identically to one that
	# never set them: all bonuses 0, total AC == base AC, crit only on nat 20.
	var a := _profile("a", "A", 10, 15)
	a.class_id = ""
	a.race_id = ""
	assert_that(a.get_total_ac()).is_equal(a.get_ac())
	assert_that(a.crits_on(19)).is_equal(false)
	assert_that(a.crits_on(20)).is_equal(true)
