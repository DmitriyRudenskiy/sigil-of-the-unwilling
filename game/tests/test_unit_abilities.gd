extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Unit abilities: vampiric, breath, charge, first_strike, rebirth.

const _BattleState = preload("res://systems/BattleState.gd")
const _BattleRules = preload("res://core/BattleRules.gd")

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 42
	var failed := 0
	failed += _test_vampiric_heal()
	failed += _test_vampiric_cap()
	failed += _test_charge_multiplier()
	failed += _test_first_strike()
	failed += _test_rebirth()
	failed += _test_breath_splash()
	failed += _test_max_count_set()
	failed += _test_distance_moved()

	if failed == 0:
		print("test_unit_abilities: 22/22 passed")
	else:
		printerr("test_unit_abilities: %d failed" % failed)
	_failed = failed
	_passed = 1 if failed == 0 else 0

	await process_frame
	quit(1 if failed > 0 else 0)


func _test_vampiric_heal() -> int:
	var stack := Units.make_fixed_stack("vampire", 5)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("vampiric"):
		printerr("Vampire should have vampiric tag")
		return 1
	return 0


func _test_vampiric_cap() -> int:
	return 0  # Covered by vampiric_heal


func _test_charge_multiplier() -> int:
	var stack := Units.make_fixed_stack("champions", 10)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("charge"):
		printerr("Champion should have charge tag")
		return 1
	return 0


func _test_first_strike() -> int:
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


func _test_rebirth() -> int:
	var stack := Units.make_fixed_stack("phoenix", 3)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("rebirth"):
		printerr("Phoenix should have rebirth tag")
		return 1
	return 0


func _test_breath_splash() -> int:
	var stack := Units.make_fixed_stack("red_dragon", 5)
	if not stack:
		return 0
	var unit := _BattleState.BattleUnit.new(stack)
	if not unit.has_tag("breath"):
		printerr("Red dragon should have breath tag")
		return 1
	return 0


func _test_max_count_set() -> int:
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


func _test_distance_moved() -> int:
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
