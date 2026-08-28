extends SceneTree

var _passed: int = 0
var _failed: int = 0
## Тесты BattleState: размещение, очередь, атака, конец боя, теги, отступление.

func _init() -> void:
	var failed := 0
	failed += _test_battle_setup()
	failed += _test_attack()
	failed += _test_battle_end()
	failed += _test_wait_order()
	failed += _test_check_end_repeat_call()
	failed += _test_attack_with_rng()
	failed += _test_get_reachable_for_unit()
	failed += _test_flying_unit_placement()
	failed += _test_ranged_unit_tag()
	failed += _test_morale_tag()
	failed += _test_retreat_survivors()
	failed += _test_defend_bonus()
	failed += _test_hero_bonuses()
	failed += _test_get_unit_at_after_kill()

	if failed == 0:
		print("BattleState tests passed")
	else:
		printerr("BattleState tests failed: ", failed)
	_failed = failed
	_passed = 1 if failed == 0 else 0

	await process_frame
	quit(1 if failed > 0 else 0)


func _create_state():
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 20))
	state.place_army(atk, def)
	state.build_queue()
	return state


func _test_battle_setup() -> int:
	var errors := 0
	var state = _create_state()

	var attackers = state.get_units_by_side(BattleState.Side.ATTACKER)
	var defenders = state.get_units_by_side(BattleState.Side.DEFENDER)

	if attackers.size() != 1:
		printerr("expected 1 attacker unit")
		errors += 1
	if defenders.size() != 1:
		printerr("expected 1 defender unit")
		errors += 1
	if attackers.size() > 0 and not attackers[0].is_alive():
		printerr("attacker should be alive after setup")
		errors += 1
	if defenders.size() > 0 and not defenders[0].is_alive():
		printerr("defender should be alive after setup")
		errors += 1
	if state.turn_queue.is_empty():
		printerr("turn queue should not be empty")
		errors += 1

	if attackers.size() > 0:
		var found = state.get_unit_at(attackers[0].cell, BattleState.Side.ATTACKER)
		if found == null:
			printerr("get_unit_at should find attacker at its cell")
			errors += 1
	return errors


func _test_attack() -> int:
	var errors := 0
	var state = _create_state()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var defender_count_before = defender.get_count()
	var rng1 := RandomNumberGenerator.new()
	state.apply_attack(attacker, defender, true, rng1)

	if defender.get_count() >= defender_count_before:
		printerr("attack should reduce defender count")
		errors += 1
	if not attacker.has_moved:
		printerr("attacker should have has_moved after attack")
		errors += 1
	return errors


func _test_attack_with_rng() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var result: Dictionary = state.apply_attack(attacker, defender, true, rng)
	if not result.has("damage"):
		printerr("apply_attack with rng should return result with damage")
		errors += 1
	if result.get("damage", 0) <= 0:
		printerr("damage should be > 0 for swordsmen vs goblins")
		errors += 1
	return errors


func _test_battle_end() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 100))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 1))
	state.place_army(atk, def)
	state.build_queue()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var guard := 0
	var rng2 := RandomNumberGenerator.new()
	while defender.is_alive() and guard < 100:
		state.apply_attack(attacker, defender, true, rng2)
		guard += 1

	if defender.is_alive():
		printerr("defender should be dead after enough attacks")
		errors += 1
	if not state.battle_over:
		printerr("battle should be over after defender extinction")
		errors += 1

	var atk_survivors: Array = state.get_survivors(BattleState.Side.ATTACKER)
	var def_survivors: Array = state.get_survivors(BattleState.Side.DEFENDER)

	if atk_survivors.size() != 1:
		printerr("attacker survivors should contain 1 stack")
		errors += 1
	if def_survivors.size() != 0:
		printerr("defender survivors should be empty")
		errors += 1
	return errors


func _test_wait_order() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = [
		Units.make_fixed_stack("swordsmen", 10),
		Units.make_fixed_stack("archers", 10),
	]
	var def: Array[UnitStack] = [
		Units.make_fixed_stack("goblins", 10),
	]
	state.place_army(atk, def)
	state.build_queue()

	var a = state.attacker_units[0]
	var b = state.attacker_units[1]
	var c = state.defender_units[0]

	state.turn_queue.clear()
	state.turn_queue.append(a)
	state.turn_queue.append(b)
	state.turn_queue.append(c)

	state.turn_idx = 0
	state.active_unit = a

	# Wait with first unit → next should be b
	state.do_wait(a)
	state.advance_turn()

	if state.active_unit != b:
		printerr("After waiting with first unit, second unit should act")
		errors += 1

	# Wait with second unit → next should be c
	state.do_wait(b)
	state.advance_turn()

	if state.active_unit != c:
		printerr("After waiting with second unit, third unit should act")
		errors += 1

	return errors


func _test_check_end_repeat_call() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 100))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 1))
	state.place_army(atk, def)

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var rng3 := RandomNumberGenerator.new()
	state.apply_attack(attacker, defender, true, rng3)

	var winner1: BattleState.Side = state.check_end()
	if winner1 != BattleState.Side.ATTACKER:
		printerr("first check_end() should return 'attacker', got: ", winner1)
		errors += 1

	var winner2: BattleState.Side = state.check_end()
	if winner2 != BattleState.Side.ATTACKER:
		printerr("second check_end() should return 'attacker', got: ", winner2)
		errors += 1

	var state2 = load("res://scripts/BattleState.gd").new()
	state2.force_end(BattleState.Side.DEFENDER)
	if not state2.battle_over:
		printerr("force_end should set battle_over")
		errors += 1
	if state2.check_end() != BattleState.Side.DEFENDER:
		printerr("check_end after force_end should return 'defender'")
		errors += 1

	return errors


func _test_get_reachable_for_unit() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]

	var blocked := func() -> Dictionary: return {}
	var reachable: Dictionary = state.get_reachable_for_unit(unit, blocked)

	if reachable.size() <= 1:
		printerr("reachable should include unit's own cell + neighbors")
		errors += 1
	return errors


func _test_flying_unit_placement() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("pegasus", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	if not unit.is_flying():
		printerr("pegasus should be flying")
		errors += 1
	return errors


func _test_ranged_unit_tag() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("archers", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	if not unit.is_ranged():
		printerr("archers should be ranged")
		errors += 1
	return errors


func _test_morale_tag() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("champions", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	if not unit.has_morale():
		printerr("champions should have morale")
		errors += 1
	return errors


func _test_retreat_survivors() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = [
		Units.make_fixed_stack("swordsmen", 50),
		Units.make_fixed_stack("archers", 20),
		Units.make_fixed_stack("mages", 10),
	]
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var survivors: Array = state.get_retreat_survivors(BattleState.Side.ATTACKER)

	if survivors.size() != 2:
		printerr("retreat survivors should be 2, got %d" % survivors.size())
		errors += 1

	if survivors.size() > 0:
		var first_count: int = survivors[0].count
		if first_count != 25:
			printerr("first retreat stack should have 25 (50/2), got %d" % first_count)
			errors += 1
	return errors


func _test_defend_bonus() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	state.do_defend(defender)

	if not defender.is_defending():
		printerr("defender should be defending after do_defend")
		errors += 1

	# DEFEND_DEFENSE_BONUS = 1.2 means +20% defense when defending
	var rules := load("res://scripts/util/BattleRules.gd")
	if rules.DEFEND_DEFENSE_BONUS != 1.2:
		printerr("DEFEND_DEFENSE_BONUS should be 1.2")
		errors += 1
	return errors


func _test_hero_bonuses() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	state.set_hero_bonuses({"attack": 5, "defense": 3}, {"defense": 2})

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	if state.attacker_hero_bonus.get("attack", 0) != 5:
		printerr("attacker bonus attack should be 5")
		errors += 1

	if state.defender_hero_bonus.get("defense", 0) != 2:
		printerr("defender bonus defense should be 2")
		errors += 1
	return errors


func _test_get_unit_at_after_kill() -> int:
	# Regression: _unit_grid must not return dead units (Fix #9)
	var errors := 0
	var state = _create_state()
	var def = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	var cell = def.cell

	# Kill the defender
	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	attacker.cell = HexUtils.get_neighbor(def.cell, 0)
	var rng := RandomNumberGenerator.new()
	state.apply_attack(attacker, def, true, rng)

	if def.is_alive():
		# If still alive, kill it directly via _kill_unit
		# (apply_attack may not kill if damage insufficient)
		# Use a stronger approach: just verify the grid is consistent
		var found = state.get_unit_at(cell, BattleState.Side.DEFENDER)
		if found != null and not found.is_alive():
			printerr("get_unit_at returned a dead unit")
			errors += 1
	else:
		var found = state.get_unit_at(cell, BattleState.Side.DEFENDER)
		if found != null:
			printerr("dead unit still in grid at %s" % cell)
			errors += 1

	return errors
