extends GdUnitTestSuite

func test_attacker_wins() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
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
	var rng1 := TestFactories.seeded(4479)
	rng1.seed = 42
	while not state.battle_over and guard < 100:
		state.apply_attack(attacker, defender, true, rng1)
		guard += 1

	assert_bool(state.battle_over).is_true().override_failure_message("battle should end when defender is destroyed")
	assert_int(state.get_survivors(BattleState.Side.ATTACKER).size()).is_equal(1).override_failure_message("attacker should have survivors")
	assert_int(state.get_survivors(BattleState.Side.DEFENDER).size()).is_zero().override_failure_message("defender should have no survivors")

func test_defender_wins() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
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
	var rng2 := TestFactories.seeded(4479)
	rng2.seed = 42
	while not state.battle_over and guard < 100:
		state.apply_attack(defender, attacker, true, rng2)
		guard += 1

	assert_bool(state.battle_over).is_true().override_failure_message("battle should end when attacker is destroyed")
	assert_int(state.get_survivors(BattleState.Side.ATTACKER).size()).is_zero().override_failure_message("attacker should have no survivors")
	assert_int(state.get_survivors(BattleState.Side.DEFENDER).size()).is_equal(1).override_failure_message("defender should have survivors")

func test_battle_rules_damage() -> void:
	var state: BattleState = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	var atk_unit: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var def_unit: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.DEFENDER)[0]

	var rules: BattleRules = load("res://scripts/core/BattleRules.gd").new()

	var test_rng := TestFactories.seeded(4479)
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

	assert_int(damage).is_greater(0).override_failure_message("swordsmen should deal damage to goblins")

	var def_result: Dictionary = rules.calculate_attack(
		def_unit,
		atk_unit,
		false,
		test_rng,
		0,
		0
	)

	var def_damage: int = int(def_result.get("damage", 0))

	assert_int(def_damage).is_less_equal(damage).override_failure_message("goblins should deal less or equal damage to swordsmen")

func test_ranged_vs_flying() -> void:
	var state: BattleState = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("archers", 20))
	atk.append(Units.make_fixed_stack("pegasus", 10))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 5))
	state.place_army(atk, def)

	var all_units: Array[BattleState.BattleUnit] = state.get_units_by_side(BattleState.Side.ATTACKER)

	var archer: BattleState.BattleUnit = null
	var pegasus: BattleState.BattleUnit = null
	for u in all_units:
		if u.get_key() == "archers":
			archer = u
		elif u.get_key() == "pegasus":
			pegasus = u

	assert_object(archer).is_not_null().override_failure_message("archers unit not found")
	assert_bool(archer.is_ranged()).is_true().override_failure_message("archers should be ranged")

	assert_object(pegasus).is_not_null().override_failure_message("pegasus unit not found")
	assert_bool(pegasus.is_flying()).is_true().override_failure_message("pegasus should be flying")

func test_morale_check() -> void:
	var state: BattleState = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("champions", 10))
	atk.append(Units.make_fixed_stack("skeleton", 10))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 5))
	state.place_army(atk, def)

	var all_units: Array[BattleState.BattleUnit] = state.get_units_by_side(BattleState.Side.ATTACKER)
	var champion: BattleState.BattleUnit = null
	var skeleton: BattleState.BattleUnit = null
	for u in all_units:
		if u.get_key() == "champions":
			champion = u
		elif u.get_key() == "skeleton":
			skeleton = u

	var rules2: BattleRules = load("res://scripts/core/BattleRules.gd").new()

	assert_object(champion).is_not_null().override_failure_message("champions unit not found")
	assert_bool(rules2.can_morale(champion)).is_true().override_failure_message("champions should be eligible for morale")

	if skeleton != null:
		assert_bool(rules2.can_morale(skeleton)).is_false().override_failure_message("skeleton (undead) should NOT be eligible for morale")
