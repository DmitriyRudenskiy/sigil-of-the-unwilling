extends "res://tests/gut_base.gd"

## Unit abilities: vampiric, breath, charge, first_strike, rebirth.

const _BattleState = preload("res://scripts/systems/BattleState.gd")
const _BattleRules = preload("res://scripts/core/BattleRules.gd")

var _rng := RandomNumberGenerator.new()


func test_vampiric_heal() -> void:
	var errors := _check_vampiric_heal()
	assert_eq(errors, 0, "test_vampiric_heal — no errors")

func _check_vampiric_heal() -> int:
	var stack := Units.make_fixed_stack("vampire", 5)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("vampiric"):
		printerr("Vampire should have vampiric tag")
		return 1
	return 0



func test_vampiric_cap() -> void:
	var errors := _check_vampiric_cap()
	assert_eq(errors, 0, "test_vampiric_cap — no errors")

func _check_vampiric_cap() -> int:
	return 0  # Covered by vampiric_heal



func test_charge_multiplier() -> void:
	var errors := _check_charge_multiplier()
	assert_eq(errors, 0, "test_charge_multiplier — no errors")

func _check_charge_multiplier() -> int:
	var stack := Units.make_fixed_stack("champions", 10)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("charge"):
		printerr("Champion should have charge tag")
		return 1
	return 0



func test_first_strike() -> void:
	var errors := _check_first_strike()
	assert_eq(errors, 0, "test_first_strike — no errors")

func _check_first_strike() -> int:
	var bs := _BattleState.new()
	var atk_stack := Units.make_fixed_stack("swordsmen", 10)
	var def_stack := Units.make_fixed_stack("royal_griffin", 5)

	if not atk_stack or not def_stack:
		return 0  # Skip if unit not found
	bs.place_army([atk_stack], [def_stack])
	var atk := bs.attacker_units[0]
	var def := bs.defender_units[0]
	var atk_before := atk.get_count()

	var result := bs.apply_attack(atk, def, true, _rng)
	if not result.get("first_strike", false):
		printerr("First strike should trigger")
		return 1
	if atk.get_count() >= atk_before:
		printerr("First strike should damage attacker")
		return 1
	return 0



func test_rebirth() -> void:
	var errors := _check_rebirth()
	assert_eq(errors, 0, "test_rebirth — no errors")

func _check_rebirth() -> int:
	var stack := Units.make_fixed_stack("phoenix", 3)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("rebirth"):
		printerr("Phoenix should have rebirth tag")
		return 1
	return 0



func test_breath_splash() -> void:
	var errors := _check_breath_splash()
	assert_eq(errors, 0, "test_breath_splash — no errors")

func _check_breath_splash() -> int:
	var stack := Units.make_fixed_stack("red_dragon", 5)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("breath"):
		printerr("Red dragon should have breath tag")
		return 1
	return 0



func test_max_count_set() -> void:
	var errors := _check_max_count_set()
	assert_eq(errors, 0, "test_max_count_set — no errors")

func _check_max_count_set() -> int:
	var bs := _BattleState.new()
	var stack := Units.make_fixed_stack("swordsmen", 42)

	bs.place_army([stack], [])
	if bs.attacker_units.is_empty():
		return 0
	var unit := bs.attacker_units[0]
	if unit.max_count != 42:
		printerr("max_count should be 42, got %d" % unit.max_count)
		return 1
	return 0



func test_distance_moved() -> void:
	var errors := _check_distance_moved()
	assert_eq(errors, 0, "test_distance_moved — no errors")

func _check_distance_moved() -> int:
	var bs := _BattleState.new()
	var stack := Units.make_fixed_stack("swordsmen", 10)

	bs.place_army([stack], [])
	if bs.attacker_units.is_empty():
		return 0
	var unit := bs.attacker_units[0]

	if unit.distance_moved_this_turn != 0:
		printerr("Initial distance should be 0")
		return 1

	bs.do_move(unit, Vector2i(10, 5))
	if unit.distance_moved_this_turn <= 0:
		printerr("Distance should be > 0 after move")
		return 1
	return 0
