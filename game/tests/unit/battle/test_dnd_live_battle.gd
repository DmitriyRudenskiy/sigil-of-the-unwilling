extends BaseTest

## dnd-live-battle-wiring: per-character D&D combat in the live battle loop.
##
## A UnitStack carrying a DnDCombatantProfile is a single D&D character with a
## real HP pool. When both sides of an attack are D&D characters, the attack
## resolves via DnDBattleBridge (d20 + ability mod + proficiency vs AC; dice
## damage to the target's HP pool; death at HP 0). Pure stack units are
## unchanged (backward compatible).
##
## Deterministic hit/miss: get_ac() overwrites armor.dex_modifier with the DEX
## mod, so AC is controlled via armor.armor_bonus (DEX kept at 10 -> mod 0):
##   AC = 10 (no armor) + 0 (dex) + armor_bonus = 10 + armor_bonus.
## AC = 1 (armor_bonus -9) -> always hit; AC = 99 (armor_bonus 89) -> always miss.

var rng: RandomNumberGenerator


func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260928


## Build a DnDCombatantProfile with a target AC (via armor.armor_bonus, DEX 10).
func _profile(p_id: String, p_name: String, str_score: int,
		ac: int = 15, p_max_hp: int = 20) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(p_id, p_name)
	p.abilities.set_score(DNDAbilityScores.Ability.STR, str_score)
	p.abilities.set_score(DNDAbilityScores.Ability.DEX, 10)  # mod 0, no AC shift
	p.armor.armor_type = DNDArmorClass.ArmorType.NONE
	p.armor.armor_bonus = ac - 10  # AC = 10 + 0 + armor_bonus
	p.max_hp = p_max_hp
	return p


## Build a single D&D-character BattleUnit (stack for movement + profile).
func _dnd_unit(p_id: String, p_name: String, str_score: int,
		ac: int = 15, p_max_hp: int = 20, speed: int = 5) -> BattleState.BattleUnit:
	var stats := UnitStats.new(p_id, p_name, 0, 0, 1, speed, 0, [])
	var stack := UnitStack.new(stats, 1)
	var p := _profile(p_id, p_name, str_score, ac, p_max_hp)
	stack.dnd_profile = p
	var u := BattleState.BattleUnit.new(stack)
	u.dnd_profile = p
	u.init_dnd_hp()
	return u


## Build a UnitStack that is a single D&D character (for the builder / emulator).
func _dnd_stack(p_id: String, p_name: String, str_score: int,
		ac: int = 15, p_max_hp: int = 20, speed: int = 5) -> UnitStack:
	var stats := UnitStats.new(p_id, p_name, 0, 0, 1, speed, 0, [])
	var stack := UnitStack.new(stats, 1)
	stack.dnd_profile = _profile(p_id, p_name, str_score, ac, p_max_hp)
	return stack


# ---------------------------------------------------------------------------
# 1. Data: profile max_hp + UnitStack carries the profile
# ---------------------------------------------------------------------------

func test_profile_max_hp_serialization() -> void:
	var p := _profile("h", "Hero", 16, 15, 33)
	var d: Dictionary = p.to_dict()
	assert_that(int(d.get("max_hp", 0))).is_equal(33)
	var p2: DnDCombatantProfile = DnDCombatantProfile.from_dict(d)
	assert_that(p2.max_hp).is_equal(33)


func test_profile_max_hp_default() -> void:
	var p := DnDCombatantProfile.new("x", "X")
	assert_that(p.max_hp).is_equal(10)


func test_unitstack_carries_profile_duplicate() -> void:
	var s := _dnd_stack("h", "Hero", 16, 15, 30)
	assert_that(s.dnd_profile).is_not_null()
	var d: UnitStack = s.duplicate_stack()
	assert_that(d.dnd_profile).is_not_null()
	assert_that(d.dnd_profile.id).is_equal("h")


func test_unitstack_profile_serialization() -> void:
	var s := _dnd_stack("h", "Hero", 16, 15, 30)
	var d: Dictionary = s.to_dict()
	assert_that(d.has("dnd_profile")).is_true()
	var s2: UnitStack = UnitStack.from_dict(d, s.stats)
	assert_that(s2.dnd_profile).is_not_null()
	assert_that(s2.dnd_profile.max_hp).is_equal(30)


func test_unitstack_without_profile_unchanged() -> void:
	var stats := UnitStats.new("k", "Knight", 3, 3, 50, 5, 3, [])
	var s := UnitStack.new(stats, 10)
	assert_that(s.dnd_profile).is_null()
	var d: Dictionary = s.to_dict()
	assert_that(d.has("dnd_profile")).is_false()


# ---------------------------------------------------------------------------
# 2. BattleUnit HP pool
# ---------------------------------------------------------------------------

func test_battleunit_dnd_hp_init() -> void:
	var u := _dnd_unit("h", "Hero", 16, 15, 33)
	assert_that(u.is_dnd_character()).is_true()
	assert_that(u.dnd_current_hp).is_equal(33)
	assert_that(u.get_hp()).is_equal(33)
	assert_that(u.is_alive()).is_true()


func test_battleunit_dnd_hp_death() -> void:
	var u := _dnd_unit("h", "Hero", 16, 15, 33)
	u.dnd_current_hp = 0
	assert_that(u.is_alive()).is_false()
	assert_that(u.get_hp()).is_equal(1)


func test_battleunit_stack_unchanged() -> void:
	var stats := UnitStats.new("k", "Knight", 3, 3, 50, 5, 3, [])
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, 10))
	assert_that(u.is_dnd_character()).is_false()
	assert_that(u.is_alive()).is_true()
	assert_that(u.get_hp()).is_equal(50)


func test_builder_inits_dnd_hp() -> void:
	var atk: Array = [_dnd_stack("a1", "A1", 16, 15, 30),
		_dnd_stack("a2", "A2", 14, 14, 25)]
	var def: Array = [_dnd_stack("d1", "D1", 16, 15, 30)]
	var state := BattleStateBuilder.new() \
		.set_attacker_army(atk).set_defender_army(def).build()
	var a1: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	assert_that(a1.is_dnd_character()).is_true()
	assert_that(a1.dnd_current_hp).is_equal(30)


# ---------------------------------------------------------------------------
# 3. Live-loop D&D attack (deterministic via extreme AC)
# ---------------------------------------------------------------------------

func _setup_attack(atk_ac: int, def_ac: int, def_hp: int) -> Array:
	# Returns [state, atk, def].
	var atk := _dnd_unit("a", "Atk", 16, atk_ac, 30)
	var def := _dnd_unit("d", "Def", 14, def_ac, def_hp)
	var state := BattleState.new()
	state.attacker_units = [atk]
	state.defender_units = [def]
	atk.cell = Vector2i(1, 5)
	def.cell = Vector2i(2, 5)
	atk.side = BattleState.Side.ATTACKER
	def.side = BattleState.Side.DEFENDER
	atk.alive = true
	def.alive = true
	state._rebuild_unit_grid()
	state.invalidate_board_cache()
	return [state, atk, def]


func test_dnd_attack_hit_deals_damage() -> void:
	var arr: Array = _setup_attack(15, 1, 30)  # def AC 1 -> always hit
	var state: BattleState = arr[0]
	var atk: BattleState.BattleUnit = arr[1]
	var def: BattleState.BattleUnit = arr[2]
	var res: Dictionary = BattleActionResolver.apply_attack(state, atk, def, true, rng, true)
	assert_that(res.get("dnd", false)).is_true()
	assert_that(res.get("hit", false)).is_true()
	var dmg: int = int(res.get("damage_dealt", 0))
	assert_that(dmg).is_greater_equal(1)
	assert_that(def.dnd_current_hp).is_equal(30 - dmg)


func test_dnd_attack_miss_no_damage() -> void:
	var arr: Array = _setup_attack(15, 99, 30)  # def AC 99 -> always miss
	var state: BattleState = arr[0]
	var atk: BattleState.BattleUnit = arr[1]
	var def: BattleState.BattleUnit = arr[2]
	var res: Dictionary = BattleActionResolver.apply_attack(state, atk, def, true, rng, true)
	assert_that(res.get("hit", false)).is_false()
	assert_that(def.dnd_current_hp).is_equal(30)


func test_dnd_attack_kills() -> void:
	var arr: Array = _setup_attack(15, 1, 1)  # def AC 1, hp 1 -> one hit kills
	var state: BattleState = arr[0]
	var atk: BattleState.BattleUnit = arr[1]
	var def: BattleState.BattleUnit = arr[2]
	BattleActionResolver.apply_attack(state, atk, def, true, rng, true)
	assert_that(def.is_alive()).is_false()
	assert_that(def.dnd_current_hp).is_equal(0)
	assert_that(state.battle_over).is_true()


func test_dnd_attack_consumes_action() -> void:
	var arr: Array = _setup_attack(15, 1, 30)
	var state: BattleState = arr[0]
	var atk: BattleState.BattleUnit = arr[1]
	var def: BattleState.BattleUnit = arr[2]
	assert_that(atk.has_moved).is_false()
	BattleActionResolver.apply_attack(state, atk, def, true, rng, true)
	assert_that(atk.has_moved).is_true()


func test_dnd_resurrection_restores_hp() -> void:
	var arr: Array = _setup_attack(15, 1, 1)
	var state: BattleState = arr[0]
	var atk: BattleState.BattleUnit = arr[1]
	var def: BattleState.BattleUnit = arr[2]
	BattleActionResolver.apply_attack(state, atk, def, true, rng, true)
	assert_that(def.is_alive()).is_false()
	BattleActionResolver.revive_unit(state, def)
	assert_that(def.is_alive()).is_true()
	assert_that(def.dnd_current_hp).is_equal(1)


# ---------------------------------------------------------------------------
# 4. Backward-compat: pure stack battle unchanged
# ---------------------------------------------------------------------------

func test_stack_attack_uses_stack_formula() -> void:
	# Pure stack units (no profile) -> stack formula, not the D&D branch.
	var atk_stats := UnitStats.new("a", "Atk", 10, 8, 50, 5, 3, [])
	var def_stats := UnitStats.new("d", "Def", 3, 3, 50, 5, 3, [])
	var atk := BattleState.BattleUnit.new(UnitStack.new(atk_stats, 10))
	var def := BattleState.BattleUnit.new(UnitStack.new(def_stats, 10))
	var state := BattleState.new()
	state.attacker_units = [atk]
	state.defender_units = [def]
	atk.cell = Vector2i(1, 5)
	def.cell = Vector2i(2, 5)
	atk.side = BattleState.Side.ATTACKER
	def.side = BattleState.Side.DEFENDER
	atk.alive = true
	def.alive = true
	state._rebuild_unit_grid()
	state.invalidate_board_cache()
	var res: Dictionary = BattleActionResolver.apply_attack(state, atk, def, true, rng, true)
	assert_that(res.has("dnd")).is_false()
	var kills: int = int(res.get("kills", 0))
	assert_that(kills).is_greater_equal(0)
	assert_that(def.get_count()).is_less_equal(10)


# ---------------------------------------------------------------------------
# 5. Integration: full D&D battle via the emulator
# ---------------------------------------------------------------------------

func _build_dnd_state() -> BattleState:
	var atk_army: Array = [
		_dnd_stack("a1", "A1", 18, 15, 24, 5),
		_dnd_stack("a2", "A2", 16, 14, 20, 5),
	]
	var def_army: Array = [
		_dnd_stack("d1", "D1", 14, 14, 18, 5),
		_dnd_stack("d2", "D2", 12, 13, 16, 5),
	]
	return BattleStateBuilder.new() \
		.set_attacker_army(atk_army).set_defender_army(def_army).build()


func test_full_dnd_battle_resolves() -> void:
	var state := _build_dnd_state()
	for u in state.get_units_by_side(BattleState.Side.ATTACKER):
		assert_that(u.is_dnd_character()).is_true()
		assert_that(u.dnd_current_hp).is_greater(0)

	var emu := BattleEmulator.new()
	var r: Dictionary = emu.run_auto_battle(state, rng)
	assert_that(r.get("battle_over", false)).is_true()
	var winner: String = str(r.get("winner", ""))
	assert_that(winner == "attacker" or winner == "defender").is_true()
	if winner == "attacker":
		assert_that((r.get("def_survivors", []) as Array).size()).is_equal(0)
	else:
		assert_that((r.get("atk_survivors", []) as Array).size()).is_equal(0)


func test_full_dnd_battle_deterministic() -> void:
	var emu := BattleEmulator.new()
	var mk = func() -> Dictionary:
		var s := _build_dnd_state()
		var r := RandomNumberGenerator.new()
		r.seed = 20260928
		return emu.run_auto_battle(s, r)
	var r1: Dictionary = mk.call()
	var r2: Dictionary = mk.call()
	assert_that(r1.get("winner")).is_equal(r2.get("winner"))
	assert_that(r1.get("turns")).is_equal(r2.get("turns"))
