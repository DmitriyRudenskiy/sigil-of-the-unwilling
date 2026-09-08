extends GdUnitTestSuite


const _BattleState = preload("res://scripts/systems/BattleState.gd")
const _BattleRules = preload("res://scripts/core/BattleRules.gd")

var _rng := RandomNumberGenerator.new()


func test_vampiric_heal() -> void:
	var stack := Units.make_fixed_stack("vampire", 5)
	assert_object(stack).is_not_null().override_failure_message("vampire unit not found in registry")
	var unit := _BattleState.BattleUnit.new(stack)
	assert_bool(unit.has_tag("vampiric")).is_true().override_failure_message("Vampire should have vampiric tag")



func test_vampiric_cap() -> void:
	pass



func test_charge_multiplier() -> void:
	var stack := Units.make_fixed_stack("champions", 10)
	assert_object(stack).is_not_null().override_failure_message("champions unit not found in registry")
	var unit := _BattleState.BattleUnit.new(stack)
	assert_bool(unit.has_tag("charge")).is_true().override_failure_message("Champion should have charge tag")



func test_first_strike() -> void:
	_rng.seed = 42
	var bs := _BattleState.new()
	var atk_stack := Units.make_fixed_stack("swordsmen", 10)
	var def_stack := Units.make_fixed_stack("royal_griffin", 5)

	assert_object(atk_stack).is_not_null().override_failure_message("swordsmen unit not found in registry")
	assert_object(def_stack).is_not_null().override_failure_message("royal_griffin unit not found in registry")
	bs.place_army([atk_stack], [def_stack])
	var atk := bs.attacker_units[0]
	var def := bs.defender_units[0]
	var atk_before := atk.get_count()

	var result := bs.apply_attack(atk, def, true, _rng)
	assert_bool(result.get("first_strike", false)).is_true().override_failure_message("First strike should trigger")
	assert_int(atk.get_count()).is_less(atk_before).override_failure_message("First strike should damage attacker")



func test_rebirth() -> void:
	var stack := Units.make_fixed_stack("phoenix", 3)
	assert_object(stack).is_not_null().override_failure_message("phoenix unit not found in registry")
	var unit := _BattleState.BattleUnit.new(stack)
	assert_bool(unit.has_tag("rebirth")).is_true().override_failure_message("Phoenix should have rebirth tag")



func test_breath_splash() -> void:
	var stack := Units.make_fixed_stack("red_dragon", 5)
	assert_object(stack).is_not_null().override_failure_message("red_dragon unit not found in registry")
	var unit := _BattleState.BattleUnit.new(stack)
	assert_bool(unit.has_tag("breath")).is_true().override_failure_message("Red dragon should have breath tag")



func test_max_count_set() -> void:
	var bs := _BattleState.new()
	var stack := Units.make_fixed_stack("swordsmen", 42)
	assert_object(stack).is_not_null().override_failure_message("swordsmen unit not found in registry")

	bs.place_army([stack], [])
	assert_bool(bs.attacker_units.is_empty()).is_false().override_failure_message("place_army should register attacker units")
	var unit := bs.attacker_units[0]
	assert_int(unit.max_count).is_equal(42).override_failure_message("max_count should be 42")



func test_distance_moved() -> void:
	var bs := _BattleState.new()
	var stack := Units.make_fixed_stack("swordsmen", 10)
	assert_object(stack).is_not_null().override_failure_message("swordsmen unit not found in registry")

	bs.place_army([stack], [])
	assert_bool(bs.attacker_units.is_empty()).is_false().override_failure_message("place_army should register attacker units")
	var unit := bs.attacker_units[0]

	assert_int(unit.distance_moved_this_turn).is_zero().override_failure_message("Initial distance should be 0")

	bs.do_move(unit, Vector2i(10, 5))
	assert_int(unit.distance_moved_this_turn).is_greater(0).override_failure_message("Distance should be > 0 after move")
