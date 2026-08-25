extends SceneTree
## Тесты BattleState: размещение, очередь, атака, конец боя.

func _init() -> void:
	var failed := 0
	failed += _test_battle_setup()
	failed += _test_attack()
	failed += _test_battle_end()

	if failed == 0:
		print("BattleState tests passed")
	else:
		printerr("BattleState tests failed: ", failed)
	quit(1 if failed > 0 else 0)


func _create_state():
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(UnitRegistry.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	def.append(UnitRegistry.make_fixed_stack("goblins", 20))
	state.place_army(atk, def)
	state.build_queue()
	return state


func _test_battle_setup() -> int:
	var errors := 0
	var state = _create_state()

	var attackers = state.get_units_by_side("attacker")
	var defenders = state.get_units_by_side("defender")

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
		var found = state.get_unit_at(attackers[0].cell, "attacker")
		if found == null:
			printerr("get_unit_at should find attacker at its cell")
			errors += 1
	return errors


func _test_attack() -> int:
	var errors := 0
	var state = _create_state()

	var attacker = state.get_units_by_side("attacker")[0]
	var defender = state.get_units_by_side("defender")[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var defender_count_before = defender.get_count()
	state.apply_attack(attacker, defender)

	if defender.get_count() >= defender_count_before:
		printerr("attack should reduce defender count")
		errors += 1
	if not attacker.has_moved:
		printerr("attacker should have has_moved after attack")
		errors += 1
	return errors


func _test_battle_end() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(UnitRegistry.make_fixed_stack("swordsmen", 100))
	var def: Array[UnitStack] = []
	def.append(UnitRegistry.make_fixed_stack("goblins", 1))
	state.place_army(atk, def)
	state.build_queue()

	var attacker = state.get_units_by_side("attacker")[0]
	var defender = state.get_units_by_side("defender")[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var guard := 0
	while defender.is_alive() and guard < 100:
		state.apply_attack(attacker, defender)
		guard += 1

	if defender.is_alive():
		printerr("defender should be dead after enough attacks")
		errors += 1
	if not state.battle_over:
		printerr("battle should be over after defender extinction")
		errors += 1

	var atk_survivors: Array = state.get_survivors("attacker")
	var def_survivors: Array = state.get_survivors("defender")

	if atk_survivors.size() != 1:
		printerr("attacker survivors should contain 1 stack")
		errors += 1
	if def_survivors.size() != 0:
		printerr("defender survivors should be empty")
		errors += 1
	return errors
