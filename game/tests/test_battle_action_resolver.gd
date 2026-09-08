extends GdUnitTestSuite

const _Resolver = preload("res://scripts/systems/BattleActionResolver.gd")
const HeroInventory = preload("res://scripts/entities/HeroInventory.gd")
const Artifact = preload("res://scripts/data/Artifact.gd")

var _units: Node

func before_test() -> void:
	_units = Services.resolve(&"units")


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
	assert_bool(result.has("damage")).is_true()
	assert_bool(int(result.get("damage", 0)) > 0).is_true()


func test_apply_attack_null_units() -> void:
	var state := BattleState.new()
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_attack(state, null, null, true, rng)
	assert_bool(result.is_empty()).is_true()


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
	assert_bool(result.is_empty()).is_true()


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
	assert_bool(def.get_count() < count_before).is_true()


func test_apply_spell_null_target() -> void:
	var state := BattleState.new()
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_spell(state, &"magic_arrow", null, null, {}, {}, rng)
	assert_that(result.get("result")).is_equal("invalid_target")


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
	assert_that(result.get("result")).is_equal("success")
	assert_bool(int(result.get("damage", 0)) > 0).is_true()


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
	assert_bool(result.get("first_strike", false)).is_true()
	assert_bool(atk.get_count() < atk_before).is_true()


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
	var guard := 0
	while not state.battle_over and guard < 50:
		_Resolver.apply_attack(state, atk, def, true, rng)
		guard += 1
	assert_bool(state.battle_over or not def.is_alive()).is_true()


func test_apply_sacrifice_finishes_off_rebirth_unit() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 100)
	var def_stack: UnitStack = _units.make_fixed_stack("phoenix", 1)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	atk.cell = Vector2i(5, 5)
	def.cell = HexUtils.get_neighbor(atk.cell, 0)
	assert_bool(def.has_tag("rebirth")).is_true()
	var rng := RandomNumberGenerator.new()
	var sacrifice := {"type": &"resource", "resource": &"gold", "amount": 10}
	var storage := {&"gold": 100}
	var result := _Resolver.apply_sacrifice(state, atk, sacrifice, def, storage, rng)
	assert_that(result.get("result")).is_equal("success")
	assert_bool(def.is_alive()).is_false()
	assert_bool(def.already_reborn).is_false()
	assert_bool(state.check_end() == BattleState.Side.ATTACKER).is_true()
	assert_bool(atk.has_moved).is_true()


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
	assert_that(result.get("result")).is_equal("invalid_target")
	assert_bool(def.is_alive() == false).is_true()


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
	assert_that(result.get("result")).is_equal("invalid_actor")


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
	assert_that(result.get("result")).is_equal("insufficient_cost")
	assert_bool(def.is_alive()).is_true()
	assert_that(int(storage.get(&"gold", 0))).is_equal(20)


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
	assert_that(result.get("result")).is_equal("success")
	assert_that(int(storage.get(&"gold", 0))).is_equal(40)
	assert_bool(def.is_alive()).is_false()
	assert_bool(atk.has_moved).is_true()


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
	assert_that(result.get("result")).is_equal("success")
	assert_bool(follower.is_alive()).is_false()
	assert_bool(def.is_alive()).is_false()


func test_apply_sacrifice_rejects_foreign_follower() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var follower := state.defender_units[0]  
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_sacrifice(
		state, atk, {"type": &"follower", "unit": follower}, follower, null, rng)
	assert_that(result.get("result")).is_equal("invalid_cost")
	assert_bool(follower.is_alive()).is_true()


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
	assert_that(result.get("result")).is_equal("success")
	assert_that(inv.get_equipped(slot)).is_null()
	assert_bool(def.is_alive()).is_false()


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
	assert_that(result.get("result")).is_equal("invalid_cost")
	assert_bool(def.is_alive()).is_true()


func test_apply_sacrifice_unknown_cost_type() -> void:
	var state := BattleState.new()
	var atk_stack: UnitStack = _units.make_fixed_stack("swordsmen", 10)
	var def_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	state.place_army([atk_stack], [def_stack])
	var atk := state.attacker_units[0]
	var def := state.defender_units[0]
	var rng := RandomNumberGenerator.new()
	var result := _Resolver.apply_sacrifice(state, atk, {"type": &"nothing"}, def, null, rng)
	assert_that(result.get("result")).is_equal("invalid_cost")
	assert_bool(def.is_alive()).is_true()
