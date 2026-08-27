extends SceneTree
## Тесты BattleAI: решения при отсутствии целей, атака, движение.

const ACTION_SKIP := 0
const ACTION_MOVE := 1
const ACTION_ATTACK := 2

func _init() -> void:
	var failed := 0
	failed += _test_no_target()
	failed += _test_adjacent_attack()
	failed += _test_move_towards_target()
	failed += _test_attacker_ai_targets_defender()

	if failed == 0:
		print("BattleAI tests passed")
	else:
		printerr("BattleAI tests failed: ", failed)
	await process_frame
	quit(1 if failed > 0 else 0)


func _create_state(attacker_alive: bool, def_alive: bool):
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []

	if attacker_alive:
		atk.append(Units.make_fixed_stack("swordsmen", 10))
	if def_alive:
		def.append(Units.make_fixed_stack("goblins", 10))

	state.place_army(atk, def)
	state.build_queue()
	return state


func _test_no_target() -> int:
	var errors := 0
	var state = _create_state(false, true)
	var ai = load("res://scripts/BattleAI.gd").new()

	var defender = state.get_units_by_side("defender")[0]
	var blocked: Dictionary = state.build_all_blocked(defender, {})
	var decision = ai.decide_turn(defender, state, blocked)

	if decision.action != ACTION_SKIP:
		printerr("AI should skip when no attackers exist")
		errors += 1
	return errors


func _test_adjacent_attack() -> int:
	var errors := 0
	var state = _create_state(true, true)
	var ai = load("res://scripts/BattleAI.gd").new()

	var attacker = state.get_units_by_side("attacker")[0]
	var defender = state.get_units_by_side("defender")[0]
	defender.cell = Vector2i(8, 5)
	attacker.cell = HexUtils.get_neighbor(defender.cell, 0)

	if HexUtils.hex_distance(attacker.cell, defender.cell) != 1:
		printerr("test setup failed: units are not adjacent")
		errors += 1
		return errors

	var blocked: Dictionary = state.build_all_blocked(defender, {})
	var decision = ai.decide_turn(defender, state, blocked)

	if decision.action != ACTION_ATTACK:
		printerr("AI should attack adjacent enemy, got %d" % decision.action)
		errors += 1
	if decision.attack_target != attacker:
		printerr("AI should target the adjacent attacker")
		errors += 1
	return errors


func _test_move_towards_target() -> int:
	var errors := 0
	var state = _create_state(true, true)
	var ai = load("res://scripts/BattleAI.gd").new()

	var attacker = state.get_units_by_side("attacker")[0]
	var defender = state.get_units_by_side("defender")[0]
	defender.cell = Vector2i(2, 5)
	attacker.cell = Vector2i(12, 5)

	var blocked: Dictionary = state.build_all_blocked(defender, {})
	var decision = ai.decide_turn(defender, state, blocked)

	if decision.action != ACTION_MOVE:
		printerr("AI should move towards distant enemy, got %d" % decision.action)
		errors += 1
		return errors

	if decision.move_path.size() < 2:
		printerr("AI move path should contain at least start and target")
		errors += 1

	var distance_before = HexUtils.hex_distance(defender.cell, attacker.cell)
	var distance_after = HexUtils.hex_distance(decision.target_cell, attacker.cell)
	if distance_after >= distance_before:
		printerr("AI target cell should reduce distance to attacker")
		errors += 1

	var speed = defender.get_speed()
	var max_steps = decision.move_path.size() - 1
	if max_steps > speed:
		printerr("AI should not move farther than unit speed")
		errors += 1

	# AI must not move onto an occupied enemy cell
	if decision.target_cell == attacker.cell:
		printerr("AI must not move onto occupied enemy cell")
		errors += 1

	if blocked.has(decision.target_cell):
		printerr("AI target cell must not be blocked")
		errors += 1

	return errors


func _test_attacker_ai_targets_defender() -> int:
	var errors := 0
	var state = _create_state(true, true)
	var ai = load("res://scripts/BattleAI.gd").new()

	var attacker = state.get_units_by_side("attacker")[0]
	var defender = state.get_units_by_side("defender")[0]
	attacker.cell = Vector2i(4, 5)
	defender.cell = Vector2i(12, 5)

	# AI playing as attacker side should target defender
	var blocked: Dictionary = state.build_all_blocked(attacker, {})
	var decision = ai.decide_turn(attacker, state, blocked)

	if decision.action != ACTION_MOVE:
		printerr("Attacker AI should move towards distant defender, got %d" % decision.action)
		errors += 1
		return errors

	var distance_before = HexUtils.hex_distance(attacker.cell, defender.cell)
	var distance_after = HexUtils.hex_distance(decision.target_cell, defender.cell)
	if distance_after >= distance_before:
		printerr("Attacker AI target cell should reduce distance to defender")
		errors += 1

	# Place attacker adjacent to defender and verify attack
	attacker.cell = HexUtils.get_neighbor(defender.cell, 3)
	blocked = state.build_all_blocked(attacker, {})
	decision = ai.decide_turn(attacker, state, blocked)

	if decision.action != ACTION_ATTACK:
		printerr("Attacker AI should attack adjacent defender, got %d" % decision.action)
		errors += 1
	if decision.attack_target != defender:
		printerr("Attacker AI should target the adjacent defender")
		errors += 1

	return errors
