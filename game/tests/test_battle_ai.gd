extends GdUnitTestSuite


const ACTION_SKIP := 0
const ACTION_MOVE := 1
const ACTION_ATTACK := 2

func _create_state(attacker_alive: bool, def_alive: bool):
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []

	if attacker_alive:
		atk.append(Units.make_fixed_stack("swordsmen", 10))
	if def_alive:
		def.append(Units.make_fixed_stack("goblins", 10))

	state.place_army(atk, def)
	state.build_queue()
	return state



func test_no_target() -> void:
	var state = _create_state(false, true)
	var ai = load("res://scripts/systems/BattleAI.gd").new()

	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	var blocked: Dictionary = state.build_all_blocked(defender, {})
	var decision = ai.decide_turn(defender, state, blocked)

	assert_int(decision.action).is_equal(ACTION_SKIP).override_failure_message("AI should skip when no attackers exist")



func test_adjacent_attack() -> void:
	var state = _create_state(true, true)
	var ai = load("res://scripts/systems/BattleAI.gd").new()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	defender.cell = Vector2i(8, 5)
	attacker.cell = HexUtils.get_neighbor(defender.cell, 0)

	assert_int(HexUtils.hex_distance(attacker.cell, defender.cell)).is_equal(1).override_failure_message("test setup failed: units are not adjacent")

	var blocked: Dictionary = state.build_all_blocked(defender, {})
	var decision = ai.decide_turn(defender, state, blocked)

	assert_int(decision.action).is_equal(ACTION_ATTACK).override_failure_message("AI should attack adjacent enemy")
	assert_bool(decision.attack_target == attacker).is_true().override_failure_message("AI should target the adjacent attacker")



func test_move_towards_target() -> void:
	var state = _create_state(true, true)
	var ai = load("res://scripts/systems/BattleAI.gd").new()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	defender.cell = Vector2i(2, 5)
	attacker.cell = Vector2i(12, 5)

	var blocked: Dictionary = state.build_all_blocked(defender, {})
	var decision = ai.decide_turn(defender, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE).override_failure_message("AI should move towards distant enemy")

	assert_int(decision.move_path.size()).is_greater_equal(2).override_failure_message("AI move path should contain at least start and target")

	var distance_before = HexUtils.hex_distance(defender.cell, attacker.cell)
	var distance_after = HexUtils.hex_distance(decision.target_cell, attacker.cell)
	assert_int(distance_after).is_less(distance_before).override_failure_message("AI target cell should reduce distance to attacker")

	var speed = defender.get_speed()
	var max_steps = decision.move_path.size() - 1
	assert_int(max_steps).is_less_equal(speed).override_failure_message("AI should not move farther than unit speed")

	assert_bool(decision.target_cell == attacker.cell).is_false().override_failure_message("AI must not move onto occupied enemy cell")
	assert_bool(blocked.has(decision.target_cell)).is_false().override_failure_message("AI target cell must not be blocked")



func test_attacker_ai_targets_defender() -> void:
	var state = _create_state(true, true)
	var ai = load("res://scripts/systems/BattleAI.gd").new()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(4, 5)
	defender.cell = Vector2i(12, 5)

	var blocked: Dictionary = state.build_all_blocked(attacker, {})
	var decision = ai.decide_turn(attacker, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE).override_failure_message("Attacker AI should move towards distant defender")

	var distance_before = HexUtils.hex_distance(attacker.cell, defender.cell)
	var distance_after = HexUtils.hex_distance(decision.target_cell, defender.cell)
	assert_int(distance_after).is_less(distance_before).override_failure_message("Attacker AI target cell should reduce distance to defender")

	attacker.cell = HexUtils.get_neighbor(defender.cell, 3)
	blocked = state.build_all_blocked(attacker, {})
	decision = ai.decide_turn(attacker, state, blocked)

	assert_int(decision.action).is_equal(ACTION_ATTACK).override_failure_message("Attacker AI should attack adjacent defender")
	assert_bool(decision.attack_target == defender).is_true().override_failure_message("Attacker AI should target the adjacent defender")


func test_flying_ai_lands_on_attackable_cell() -> void:
	var setup: Dictionary = _setup_flying_vs_ground()
	_assert_flying_landing({}, setup)

func test_flying_ai_falls_back_when_adjacent_blocked() -> void:
	var setup: Dictionary = _setup_flying_vs_ground()
	var obstacles := {}
	for nb in HexUtils.get_all_neighbors(setup["defender"].cell):
		obstacles[nb] = true
	_assert_flying_landing(obstacles, setup)

func _setup_flying_vs_ground():
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("pegasus", 10))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 10))
	state.place_army(atk, def)
	var pegasus = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var goblins = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	pegasus.cell = Vector2i(6, 5)
	goblins.cell = Vector2i(12, 5)
	state._rebuild_unit_grid()
	return {"state": state, "flying": pegasus, "defender": goblins}

func _assert_flying_landing(obstacles: Dictionary, setup: Dictionary) -> void:
	var state: RefCounted = setup["state"]
	var pegasus: RefCounted = setup["flying"]
	var goblins: RefCounted = setup["defender"]
	var ai = load("res://scripts/systems/BattleAI.gd").new()

	var blocked: Dictionary = state.build_all_blocked(pegasus, obstacles)
	var decision = ai.decide_turn(pegasus, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE).override_failure_message("Flying AI should MOVE")
	assert_bool(decision.move_path.size() == 2 and decision.move_path[0] == pegasus.cell).is_true().override_failure_message("Flying move_path must be [start, landing], got %s" % str(decision.move_path))
	assert_bool(decision.target_cell == Vector2i(-1, -1)).is_false().override_failure_message("Flying decision must have target_cell")
	assert_int(HexUtils.hex_distance(pegasus.cell, decision.target_cell)).is_less_equal(pegasus.get_speed()).override_failure_message("Landing cell is beyond speed: %s" % str(decision.target_cell))
	assert_bool(blocked.has(decision.target_cell)).is_false().override_failure_message("Landing cell must not be blocked")

	var dist_to_target := HexUtils.hex_distance(decision.target_cell, goblins.cell)
	if obstacles.is_empty():
		assert_int(dist_to_target).is_equal(1).override_failure_message("Melee flying unit should land adjacent to target, got dist %d (%s)" % [dist_to_target, str(decision.target_cell)])
		assert_bool(decision.attack_target == goblins).is_true().override_failure_message("Landing cell should be able to attack the target")
	else:
		assert_int(dist_to_target).is_greater_equal(2).override_failure_message("All adjacent cells blocked; landing must be at distance >= 2, got %d" % dist_to_target)
		assert_object(decision.attack_target).is_null().override_failure_message("No adjacent enemy — attack_target must be null")
