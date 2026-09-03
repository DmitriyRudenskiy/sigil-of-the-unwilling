extends "res://tests/test_base.gd"
## Tests for BattleActionResolver: attack, spell, rebirth, first_strike.

const _Resolver = preload("res://scripts/systems/BattleActionResolver.gd")
const HeroInventory = preload("res://scripts/entities/HeroInventory.gd")
const Artifact = preload("res://scripts/data/Artifact.gd")

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


func test_apply_sacrifice_finishes_off_rebirth_unit() -> void:
	## РФ4-1: жертва добивает цель в обход перерождения.
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 100)
	var def_stack: UnitStack = _units.make_fixed_stack("phoenix", 1)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	assert_true(def.has_tag("rebirth"), "phoenix has rebirth tag")
	var rng := RandomNumberGenerator.new()
	var sacrifice := {"type": &"resource", "resource": &"gold", "amount": 10}
	var storage := {&"gold": 100}
	var result := _Resolver.apply_sacrifice(state, atk, sacrifice, def, storage, rng)
	assert_eq(result.get("result"), "success", "sacrifice success")
	assert_false(def.is_alive(), "rebirth target stays dead after sacrifice")
	assert_false(def.already_reborn, "rebirth path NOT taken (already_reborn false)")
	assert_true(state.check_end() == BattleState.Side.ATTACKER, "attacker wins after finish-off")
	assert_true(atk.has_moved, "acting consumed one action")


func test_apply_sacrifice_invalid_dead_target() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	state.kill_unit(def)
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_sacrifice(
		state, atk, {"type": &"resource", "resource": &"gold", "amount": 10}, def, {&"gold": 100}, rng)
	assert_eq(result.get("result"), "invalid_target", "dead target rejected")
	assert_true(def.is_alive() == false, "dead target stays dead")


func test_apply_sacrifice_invalid_dead_actor() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	state.kill_unit(atk)
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_sacrifice(
		state, atk, {"type": &"resource", "resource": &"gold", "amount": 10}, def, {&"gold": 100}, rng)
	assert_eq(result.get("result"), "invalid_actor", "dead actor rejected")


func test_apply_sacrifice_rejects_insufficient_resource() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var rng := RandomNumberGenerator.new()
	var storage := {&"gold": 20}
	var result := _Resolver.apply_sacrifice(
		state, atk, {"type": &"resource", "resource": &"gold", "amount": 50}, def, storage, rng)
	assert_eq(result.get("result"), "insufficient_cost", "insufficient resource rejected")
	assert_true(def.is_alive(), "target unchanged on invalid sacrifice")
	assert_eq(int(storage.get(&"gold", 0)), 20, "storage unchanged on invalid sacrifice")


func test_apply_sacrifice_consumes_resource_and_finishes() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var rng := RandomNumberGenerator.new()
	var storage := {&"gold": 100}
	var result := _Resolver.apply_sacrifice(
		state, atk, {"type": &"resource", "resource": &"gold", "amount": 60}, def, storage, rng)
	assert_eq(result.get("result"), "success", "sacrifice success")
	assert_eq(int(storage.get(&"gold", 0)), 40, "resource deducted by amount")
	assert_false(def.is_alive(), "target finished off")
	assert_true(atk.has_moved, "one action consumed")


func test_apply_sacrifice_consumes_follower() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var follower_stack: UnitStack = _units.make_fixed_stack("archers", 5)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack, follower_stack], [def_stack])
	var atk := state.attacker_units[0]
	var follower := state.attacker_units[1]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var rng := RandomNumberGenerator.new()
	var sacrifice := {"type": &"follower", "unit": follower}
	var result := _Resolver.apply_sacrifice(state, atk, sacrifice, def, null, rng)
	assert_eq(result.get("result"), "success", "sacrifice success")
	assert_false(follower.is_alive(), "follower cost consumed (killed)")
	assert_false(def.is_alive(), "target finished off")


func test_apply_sacrifice_rejects_foreign_follower() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var follower := state.defender_units[0]  # enemy unit, not ally
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_sacrifice(
		state, atk, {"type": &"follower", "unit": follower}, follower, null, rng)
	assert_eq(result.get("result"), "invalid_cost", "foreign follower rejected")
	assert_true(follower.is_alive(), "target unchanged on invalid follower")


func test_apply_sacrifice_consumes_artifact() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	var rng := RandomNumberGenerator.new()
	var inv := HeroInventory.new()
	var slot := Artifact.Slot.HEAD
	var art := Artifact.new(&"test_artifact", "", Artifact.Slot.HEAD)
	inv.equipped[slot] = art
	var sacrifice := {"type": &"artifact", "slot": slot}
	var result := _Resolver.apply_sacrifice(state, atk, sacrifice, def, inv, rng)
	assert_eq(result.get("result"), "success", "sacrifice success")
	assert_null(inv.get_equipped(slot), "artifact removed from slot")
	assert_false(def.is_alive(), "target finished off")


func test_apply_sacrifice_rejects_missing_artifact() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	var rng := RandomNumberGenerator.new()
	var inv := HeroInventory.new()
	var sacrifice := {"type": &"artifact", "slot": Artifact.Slot.HEAD}
	var result := _Resolver.apply_sacrifice(state, atk, sacrifice, def, inv, rng)
	assert_eq(result.get("result"), "invalid_cost", "empty slot rejected")
	assert_true(def.is_alive(), "target unchanged on invalid artifact")


func test_apply_sacrifice_unknown_cost_type() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_sacrifice(state, atk, {"type": &"nothing"}, def, null, rng)
	assert_eq(result.get("result"), "invalid_cost", "unknown cost type rejected")
	assert_true(def.is_alive(), "target unchanged on unknown cost type")
