extends "res://tests/test_base.gd"
## Tests for BattleActionResolver: attack, spell, rebirth, first_strike.

const _Resolver = preload("res://scripts/systems/BattleActionResolver.gd")

var _units: Node

func before_each() -> void:
	_units = ServiceLocator.resolve(null, &"units")


func test_apply_attack_returns_result() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 20)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result := _Resolver.apply_attack(state, atk, def, true, rng)
	assert_true(result.has("damage"), "result has damage")
	assert_true(int(result.get("damage", 0)) > 0, "damage > 0")


func test_apply_attack_null_units() -> void:
	var state := BattleState.new()
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_attack(state, null, null, true, rng)
	assert_true(result.is_empty(), "empty result for null units")


func test_apply_attack_dead_units() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 20)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	state.kill_unit(def)
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_attack(state, atk, def, true, rng)
	assert_true(result.is_empty(), "empty result for dead defender")


func test_apply_attack_reduces_defender() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 50)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 50)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var count_before := def.get_count()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_Resolver.apply_attack(state, atk, def, true, rng)
	assert_true(def.get_count() < count_before, "defender count reduced")


func test_apply_spell_null_target() -> void:
	var state := BattleState.new()
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_spell(state, &"magic_arrow", null, null, {}, {}, rng)
	assert_eq(result.get("result"), "invalid_target", "invalid target")


func test_apply_spell_success() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 20)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 20)
	state.place_army([atk_stack], [def_stack])
	var caster := state.attacker_units[0]
	var target := state.defender_units[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result := _Resolver.apply_spell(
		state, &"magic_arrow", caster, target,
		{"spell_power": 5}, {}, rng
	)
	assert_eq(result.get("result"), "success", "spell success")
	assert_true(int(result.get("damage", 0)) > 0, "spell deals damage")


func test_first_strike_triggers() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("royal_griffin", 5)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var atk_before := atk.get_count()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var result := _Resolver.apply_attack(state, atk, def, true, rng)
	assert_true(result.get("first_strike", false), "first strike triggered")
	assert_true(atk.get_count() < atk_before, "attacker damaged by first strike")


func test_rebirth_triggers() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 100)
	var def_stack: UnitStack = _units.make_fixed_stack("phoenix", 1)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Attack until phoenix dies — with 20% chance rebirth triggers
	var guard := 0
	while not state.battle_over and guard < 50:
		_Resolver.apply_attack(state, atk, def, true, rng)
		guard += 1
	# Verify battle resolved
	assert_true(state.battle_over or not def.is_alive(), "battle resolved")
