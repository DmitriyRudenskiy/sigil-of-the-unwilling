extends SceneTree
## Интеграционный тест: полный цикл боя через BattleState.

func _init() -> void:
	var failed := 0
	failed += _test_attacker_wins()
	failed += _test_defender_wins()

	if failed == 0:
		print("Battle integration tests passed")
	else:
		printerr("Battle integration tests failed: ", failed)
	quit(1 if failed > 0 else 0)


func _test_attacker_wins() -> int:
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
	while not state.battle_over and guard < 100:
		state.apply_attack(attacker, defender)
		guard += 1

	if not state.battle_over:
		printerr("battle should end when defender is destroyed")
		errors += 1
	if state.get_survivors("attacker").size() != 1:
		printerr("attacker should have survivors")
		errors += 1
	if state.get_survivors("defender").size() != 0:
		printerr("defender should have no survivors")
		errors += 1
	return errors


func _test_defender_wins() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(UnitRegistry.make_fixed_stack("goblins", 1))
	var def: Array[UnitStack] = []
	def.append(UnitRegistry.make_fixed_stack("swordsmen", 100))
	state.place_army(atk, def)
	state.build_queue()

	var attacker = state.get_units_by_side("attacker")[0]
	var defender = state.get_units_by_side("defender")[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var guard := 0
	while not state.battle_over and guard < 100:
		state.apply_attack(defender, attacker)
		guard += 1

	if not state.battle_over:
		printerr("battle should end when attacker is destroyed")
		errors += 1
	if state.get_survivors("attacker").size() != 0:
		printerr("attacker should have no survivors")
		errors += 1
	if state.get_survivors("defender").size() != 1:
		printerr("defender should have survivors")
		errors += 1
	return errors
