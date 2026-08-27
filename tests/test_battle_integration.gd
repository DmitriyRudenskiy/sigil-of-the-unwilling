extends SceneTree
## Интеграционный тест: полный цикл боя через BattleState.

func _init() -> void:
	var failed := 0
	failed += _test_attacker_wins()
	failed += _test_defender_wins()
	failed += _test_battle_rules_damage()
	failed += _test_ranged_vs_flying()
	failed += _test_morale_check()

	if failed == 0:
		print("Battle integration tests passed")
	else:
		printerr("Battle integration tests failed: ", failed)
	await process_frame
	quit(1 if failed > 0 else 0)


func _test_attacker_wins() -> int:
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
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	while not state.battle_over and guard < 100:
		state.apply_attack(attacker, defender, true, rng1)
		guard += 1

	if not state.battle_over:
		printerr("battle should end when defender is destroyed")
		errors += 1
	if state.get_survivors(BattleState.Side.ATTACKER).size() != 1:
		printerr("attacker should have survivors")
		errors += 1
	if state.get_survivors(BattleState.Side.DEFENDER).size() != 0:
		printerr("defender should have no survivors")
		errors += 1
	return errors


func _test_defender_wins() -> int:
	var errors := 0
	var state = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("goblins", 1))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("swordsmen", 100))
	state.place_army(atk, def)
	state.build_queue()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var guard := 0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	while not state.battle_over and guard < 100:
		state.apply_attack(defender, attacker, true, rng2)
		guard += 1

	if not state.battle_over:
		printerr("battle should end when attacker is destroyed")
		errors += 1
	if state.get_survivors(BattleState.Side.ATTACKER).size() != 0:
		printerr("attacker should have no survivors")
		errors += 1
	if state.get_survivors(BattleState.Side.DEFENDER).size() != 1:
		printerr("defender should have survivors")
		errors += 1
	return errors


func _test_battle_rules_damage() -> int:
	var errors := 0

	# Use BattleState to create proper BattleUnit wrappers
	var state: BattleState = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	var atk_unit: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var def_unit: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.DEFENDER)[0]

	var rules: BattleRules = load("res://scripts/util/BattleRules.gd").new()

	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 42

	var result: Dictionary = rules.calculate_attack(
		atk_unit,
		def_unit,
		false,
		test_rng,
		0,
		0
	)

	var damage: int = int(result.get("damage", 0))

	if damage <= 0:
		printerr("swordsmen should deal damage to goblins")
		errors += 1

	var def_result: Dictionary = rules.calculate_attack(
		def_unit,
		atk_unit,
		false,
		test_rng,
		0,
		0
	)

	var def_damage: int = int(def_result.get("damage", 0))

	if def_damage > damage:
		printerr("goblins should deal less or equal damage to swordsmen")
		errors += 1

	return errors


func _test_ranged_vs_flying() -> int:
	var errors := 0

	var state: BattleState = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("archers", 20))
	atk.append(Units.make_fixed_stack("pegasus", 10))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 5))  # needed for placement
	state.place_army(atk, def)

	var all_units: Array[BattleState.BattleUnit] = state.get_units_by_side(BattleState.Side.ATTACKER)

	# Find archers and pegasus by key instead of position
	var archer: BattleState.BattleUnit = null
	var pegasus: BattleState.BattleUnit = null
	for u in all_units:
		if u.get_key() == "archers":
			archer = u
		elif u.get_key() == "pegasus":
			pegasus = u

	if archer == null or not archer.is_ranged():
		printerr("archers should be ranged")
		errors += 1

	if pegasus == null or not pegasus.is_flying():
		printerr("pegasus should be flying")
		errors += 1

	return errors


func _test_morale_check() -> int:
	var errors := 0

	var state: BattleState = load("res://scripts/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("champions", 10))
	atk.append(Units.make_fixed_stack("skeleton", 10))  # undead = no morale
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 5))  # needed for placement
	state.place_army(atk, def)

	var all_units: Array[BattleState.BattleUnit] = state.get_units_by_side(BattleState.Side.ATTACKER)
	var champion: BattleState.BattleUnit = null
	var skeleton: BattleState.BattleUnit = null
	for u in all_units:
		if u.get_key() == "champions":
			champion = u
		elif u.get_key() == "skeleton":
			skeleton = u

	var rules2: BattleRules = load("res://scripts/util/BattleRules.gd").new()

	if champion == null or not rules2.can_morale(champion):
		printerr("champions should be eligible for morale")
		errors += 1

	if skeleton != null and rules2.can_morale(skeleton):
		printerr("skeleton (undead) should NOT be eligible for morale")
		errors += 1

	return errors
