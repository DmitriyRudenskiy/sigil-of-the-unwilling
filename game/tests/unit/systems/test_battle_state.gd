extends GdUnitTestSuite

func _create_state():
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 20))
	state.place_army(atk, def)
	state.build_queue()
	return state

func test_battle_setup() -> void:
	var state = _create_state()
	var attackers = state.get_units_by_side(BattleState.Side.ATTACKER)
	var defenders = state.get_units_by_side(BattleState.Side.DEFENDER)

	assert_int(attackers.size()).is_equal(1)
	assert_int(defenders.size()).is_equal(1)
	assert_bool(attackers[0].is_alive()).is_true().override_failure_message("attacker should be alive after setup")
	assert_bool(defenders[0].is_alive()).is_true().override_failure_message("defender should be alive after setup")
	assert_bool(state.turn_queue.is_empty()).is_false().override_failure_message("turn queue should not be empty")

	var found = state.get_unit_at(attackers[0].cell, BattleState.Side.ATTACKER)
	assert_object(found).is_not_null().override_failure_message("get_unit_at should find attacker at its cell")

func test_attack() -> void:
	var state = _create_state()

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var defender_count_before = defender.get_count()
	var rng1 := TestFactories.seeded(2748)
	BattleActionResolver.apply_attack(state, attacker, defender, true, rng1)

	assert_int(defender.get_count()).is_less(defender_count_before).override_failure_message("attack should reduce defender count")
	assert_bool(attacker.has_moved).is_true().override_failure_message("attacker should have has_moved after attack")

func test_attack_with_rng() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var rng := TestFactories.seeded(2748)
	rng.seed = 12345

	var result: Dictionary = BattleActionResolver.apply_attack(state, attacker, defender, true, rng)
	assert_dict(result).contains_keys("damage").override_failure_message("apply_attack with rng should return result with damage")
	assert_int(result.get("damage", 0)).is_greater(0).override_failure_message("damage should be > 0 for swordsmen vs goblins")

func test_battle_end() -> void:
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
	var rng2 := TestFactories.seeded(2748)
	while defender.is_alive() and guard < 100:
		BattleActionResolver.apply_attack(state, attacker, defender, true, rng2)
		guard += 1

	assert_bool(defender.is_alive()).is_false().override_failure_message("defender should be dead after enough attacks")
	assert_bool(state.battle_over).is_true().override_failure_message("battle should be over after defender extinction")

	var atk_survivors: Array = state.get_survivors(BattleState.Side.ATTACKER)
	var def_survivors: Array = state.get_survivors(BattleState.Side.DEFENDER)

	assert_int(atk_survivors.size()).is_equal(1).override_failure_message("attacker survivors should contain 1 stack")
	assert_int(def_survivors.size()).is_zero().override_failure_message("defender survivors should be empty")

func test_wait_order() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
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

	BattleActionResolver.do_wait(state, a)
	state.advance_turn()

	assert_bool(state.active_unit == b).is_true().override_failure_message("After waiting with first unit, second unit should act")

	BattleActionResolver.do_wait(state, b)
	state.advance_turn()

	assert_bool(state.active_unit == c).is_true().override_failure_message("After waiting with second unit, third unit should act")

func test_check_end_repeat_call() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 100))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 1))
	state.place_army(atk, def)

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	attacker.cell = Vector2i(5, 5)
	defender.cell = HexUtils.get_neighbor(attacker.cell, 0)

	var rng3 := TestFactories.seeded(2748)
	BattleActionResolver.apply_attack(state, attacker, defender, true, rng3)

	var winner1: BattleState.Side = state.check_end()
	assert_int(winner1).is_equal(BattleState.Side.ATTACKER).override_failure_message("first check_end() should return 'attacker'")

	var winner2: BattleState.Side = state.check_end()
	assert_int(winner2).is_equal(BattleState.Side.ATTACKER).override_failure_message("second check_end() should return 'attacker'")

	var state2 = load("res://scripts/systems/BattleState.gd").new()
	BattleActionResolver.force_end(state2, BattleState.Side.DEFENDER)
	assert_bool(state2.battle_over).is_true().override_failure_message("force_end should set battle_over")
	assert_int(state2.check_end()).is_equal(BattleState.Side.DEFENDER).override_failure_message("check_end after force_end should return 'defender'")

func test_get_reachable_for_unit() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]

	var blocked := func() -> Dictionary: return {}
	var reachable: Dictionary = state.get_reachable_for_unit(unit, blocked)

	assert_int(reachable.size()).is_greater(1).override_failure_message("reachable should include unit's own cell + neighbors")
	assert_bool(reachable.has(unit.cell)).is_false().override_failure_message("reachable must not include the unit's own cell")

func test_get_unreachable_ring() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var blocked := func() -> Dictionary: return {}

	var reachable: Dictionary = state.get_reachable_for_unit(unit, blocked)
	var ring: Dictionary = state.get_unreachable_ring(unit, blocked)

	assert_bool(ring.has(unit.cell)).is_false().override_failure_message("unreachable ring must not include the unit's own cell")

	for cell in ring:
		assert_bool(reachable.has(cell)).is_false().override_failure_message("unreachable ring must not overlap the walkable set: %s" % cell)

	var near: Dictionary = state.get_reachable(unit.cell, unit.get_speed() + 1, blocked, unit)
	for cell in ring:
		assert_bool(near.has(cell)).is_true().override_failure_message("unreachable ring cell must be reachable in speed+1 steps: %s" % cell)

func test_flying_unit_placement() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("pegasus", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	assert_bool(unit.is_flying()).is_true().override_failure_message("pegasus should be flying")

func test_ranged_unit_tag() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("archers", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	assert_bool(unit.is_ranged()).is_true().override_failure_message("archers should be ranged")

func test_morale_tag() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("champions", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var unit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	assert_bool(unit.has_morale()).is_true().override_failure_message("champions should have morale")

func test_retreat_survivors() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = [
		Units.make_fixed_stack("swordsmen", 50),
		Units.make_fixed_stack("archers", 20),
		Units.make_fixed_stack("mages", 10),
	]
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var survivors: Array = state.get_retreat_survivors(BattleState.Side.ATTACKER)

	assert_int(survivors.size()).is_equal(2).override_failure_message("retreat survivors should be 2")
	assert_int(survivors[0].count).is_equal(25).override_failure_message("first retreat stack should have 25 (50/2)")

func test_defend_bonus() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	var defender = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	BattleActionResolver.do_defend(state, defender)

	assert_bool(defender.is_defending()).is_true().override_failure_message("defender should be defending after do_defend")

	var rules := load("res://scripts/core/BattleRules.gd")
	assert_float(GameNumbers.DEFEND_DEFENSE_BONUS).is_equal(1.2).override_failure_message("DEFEND_DEFENSE_BONUS should be 1.2")

func test_hero_bonuses() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 50))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	state.place_army(atk, def)

	state.set_hero_bonuses({"attack": 5, "defense": 3}, {"defense": 2})

	assert_int(state.attacker_hero_bonus.get("attack", 0)).is_equal(5).override_failure_message("attacker bonus attack should be 5")
	assert_int(state.defender_hero_bonus.get("defense", 0)).is_equal(2).override_failure_message("defender bonus defense should be 2")

func test_max_units_per_side_cap() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []
	for i in 10:
		atk.append(Units.make_fixed_stack("swordsmen", 10))
		def.append(Units.make_fixed_stack("goblins", 10))
	state.place_army(atk, def)

	var atk_units = state.get_units_by_side(BattleState.Side.ATTACKER)
	var def_units = state.get_units_by_side(BattleState.Side.DEFENDER)
	assert_int(atk_units.size()).is_equal(7).override_failure_message("attacker units should be capped at 7")
	assert_int(def_units.size()).is_equal(7).override_failure_message("defender units should be capped at 7")

func test_initiative_sorted_by_speed() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []

	var slow := Units.make_fixed_stack("swordsmen", 10)
	slow.stats.speed = 3
	var fast := Units.make_fixed_stack("archers", 10)
	fast.stats.speed = 9
	var mid := Units.make_fixed_stack("cavalry", 10)
	mid.stats.speed = 6

	atk.append(slow)
	atk.append(fast)
	atk.append(mid)
	def.append(Units.make_fixed_stack("goblins", 10))
	state.place_army(atk, def)
	state.build_queue()

	var prev: int = 100
	for u in state.turn_queue:
		assert_int(u.get_speed()).is_less_equal(prev).override_failure_message("turn queue not sorted by speed descending")
		prev = u.get_speed()
	if state.turn_queue.size() > 0:
		assert_int(state.turn_queue[0].get_speed()).is_equal(9).override_failure_message("fastest unit should act first")

func test_initiative_rebuilt_each_round() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []
	var fast := Units.make_fixed_stack("cavalry", 10)
	fast.stats.speed = 9
	var slow := Units.make_fixed_stack("swordsmen", 10)
	slow.stats.speed = 3
	atk.append(fast)
	atk.append(slow)
	def.append(Units.make_fixed_stack("goblins", 10))
	state.place_army(atk, def)
	state.build_queue()

	var sword = state.get_units_by_side(BattleState.Side.ATTACKER)[1]

	state.turn_queue.clear()
	state.turn_queue.append(sword)
	state.turn_queue.append(fast)
	state.turn_idx = state.turn_queue.size()
	state.active_unit = sword

	state.advance_turn()

	assert_bool(state.turn_queue.is_empty()).is_false().override_failure_message("turn queue should not be empty after round rebuild")

func test_get_unit_at_after_kill() -> void:
	var state = _create_state()
	var def = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	var cell = def.cell

	var attacker = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	attacker.cell = HexUtils.get_neighbor(def.cell, 0)
	var rng := TestFactories.seeded(2748)
	BattleActionResolver.apply_attack(state, attacker, def, true, rng)

	if def.is_alive():
		var found = state.get_unit_at(cell, BattleState.Side.DEFENDER)
		if found != null:
			assert_bool(found.is_alive()).is_true().override_failure_message("get_unit_at returned a dead unit")
	else:
		var found = state.get_unit_at(cell, BattleState.Side.DEFENDER)
		assert_object(found).is_null().override_failure_message("dead unit still in grid at %s" % cell)

func test_deployment_line_at_edge() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()

	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []
	for k in 5:
		atk.append(Units.make_fixed_stack("swordsmen", 10))
		def.append(Units.make_fixed_stack("goblins", 10))
	state.place_army(atk, def)

	var attackers = state.get_units_by_side(BattleState.Side.ATTACKER)
	var defenders = state.get_units_by_side(BattleState.Side.DEFENDER)

	assert_int(attackers.size()).is_equal(5).override_failure_message("expected 5 attacker units")
	assert_int(defenders.size()).is_equal(5).override_failure_message("expected 5 defender units")

	var seen: Dictionary = {}
	for k in attackers.size():
		var u = attackers[k]
		assert_int(u.cell.x).is_equal(0).override_failure_message("attacker %d should be in column 0" % k)
		assert_int(u.cell.y).is_equal(k).override_failure_message("attacker %d should be at row %d" % [k, k])
		assert_bool(seen.has(u.cell)).is_false().override_failure_message("duplicate attacker cell %s" % u.cell)
		seen[u.cell] = true

	for k in defenders.size():
		var u = defenders[k]
		assert_int(u.cell.x).is_equal(BattleState.BW - 1).override_failure_message("defender %d should be in column %d" % [k, BattleState.BW - 1])
		assert_int(u.cell.y).is_equal(k).override_failure_message("defender %d should be at row %d" % [k, k])
		assert_bool(seen.has(u.cell)).is_false().override_failure_message("duplicate defender cell %s" % u.cell)
		seen[u.cell] = true

func test_deployment_max_capacity() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()

	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []
	for k in 7:
		atk.append(Units.make_fixed_stack("swordsmen", 5))
		def.append(Units.make_fixed_stack("goblins", 5))
	state.place_army(atk, def)

	var attackers = state.get_units_by_side(BattleState.Side.ATTACKER)
	var defenders = state.get_units_by_side(BattleState.Side.DEFENDER)

	assert_int(attackers.size()).is_equal(7).override_failure_message("expected 7 attacker units")
	assert_int(defenders.size()).is_equal(7).override_failure_message("expected 7 defender units")

	for k in attackers.size():
		assert_bool(attackers[k].cell.x == 0 and attackers[k].cell.y == k).is_true().override_failure_message("max-cap attacker %d bad cell %s" % [k, attackers[k].cell])
	for k in defenders.size():
		assert_bool(defenders[k].cell.x == BattleState.BW - 1 and defenders[k].cell.y == k).is_true().override_failure_message("max-cap defender %d bad cell %s" % [k, defenders[k].cell])

func test_cell_taken_avoids_occupied() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()

	var atk: Array[UnitStack] = [Units.make_fixed_stack("swordsmen", 5)]
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var taken = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	taken.cell = Vector2i(0, 0)
	var units: Array = [taken]

	var builder: BattleStateBuilder = BattleStateBuilder.new()
	assert_bool(builder._cell_taken(0, 0, units)).is_true().override_failure_message("_cell_taken should report (0,0) as occupied")
	assert_bool(builder._cell_taken(0, 1, units)).is_false().override_failure_message("_cell_taken should report (0,1) as free")
	assert_bool(builder._cell_taken(1, 0, units)).is_false().override_failure_message("_cell_taken should report (1,0) as free")

func test_reachable_reflects_move() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 10))
	atk.append(Units.make_fixed_stack("swordsmen", 10))
	var def: Array[UnitStack] = []
	state.place_army(atk, def)

	var units: Array = state.get_units_by_side(BattleState.Side.ATTACKER)
	var A = units[0]
	var B = units[1]

	var X := Vector2i(1, 1)
	var fn := func() -> Dictionary: return state.build_all_blocked(A, {})

	var b_cell := Vector2i(0, 1)
	var r1: Dictionary = state.get_reachable(X, 1, fn)
	assert_bool(r1.has(b_cell)).is_false().override_failure_message("r1: клетка B (%s) должна быть заблокирована" % b_cell)

	BattleActionResolver.do_move(state, B, Vector2i(16, 10))
	var r2: Dictionary = state.get_reachable(X, 1, fn)
	assert_bool(r2.has(b_cell)).is_true().override_failure_message("r2: после ухода B клетка %s должна стать достижимой (кэш не протух)" % b_cell)

func test_advance_turn_skips_dead_units() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = [
		Units.make_fixed_stack("swordsmen", 10),
		Units.make_fixed_stack("archers", 10),
	]
	var def: Array[UnitStack] = [
		Units.make_fixed_stack("goblins", 10),
	]
	state.place_army(atk, def)

	var a1 = state.attacker_units[0]
	var a2 = state.attacker_units[1]
	var d = state.defender_units[0]

	state.turn_queue.clear()
	state.turn_queue.append(a1)
	state.turn_queue.append(a2)
	state.turn_queue.append(d)
	state.turn_idx = -1

	BattleActionResolver.kill_unit(state, a1)
	state.advance_turn()

	assert_object(state.active_unit).is_equal(a2).override_failure_message(
		"advance_turn должен пропустить мёртвую юнит и активировать следующего живого")

func test_build_queue_excludes_dead_units() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = [
		Units.make_fixed_stack("swordsmen", 10),
		Units.make_fixed_stack("archers", 10),
	]
	var def: Array[UnitStack] = [
		Units.make_fixed_stack("goblins", 10),
	]
	state.place_army(atk, def)
	state.build_queue()
	assert_int(state.turn_queue.size()).is_equal(3)

	var dead = state.attacker_units[0]
	BattleActionResolver.kill_unit(state, dead)
	state.build_queue()

	assert_int(state.turn_queue.size()).is_equal(2).override_failure_message(
		"мёртвый юнит не должен попасть в очередь")
	for u in state.turn_queue:
		assert_object(u).is_not_equal(dead).override_failure_message(
			"build_queue не должен включать мёртвых")

func test_new_round_resets_flags() -> void:
	var state = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack("swordsmen", 10)]
	var def: Array[UnitStack] = [Units.make_fixed_stack("goblins", 10)]
	state.place_army(atk, def)
	state.build_queue()

	var a = state.attacker_units[0]
	var d = state.defender_units[0]
	a.has_moved = true
	a.defending = true
	d.has_moved = true
	d.defending = true

	state.advance_turn()
	state.advance_turn()
	state.advance_turn()

	assert_object(state.active_unit).is_not_null().override_failure_message("после нового раунда должен быть активный юнит")
	assert_int(state.turn_idx).is_equal(0).override_failure_message("новый раунд начинается с индекса 0")
	assert_bool(a.has_moved).is_false().override_failure_message("новый раунд сбрасывает has_moved")
	assert_bool(a.defending).is_false().override_failure_message("новый раунд сбрасывает defending")
	assert_bool(d.has_moved).is_false().override_failure_message("новый раунд сбрасывает has_moved (защитник)")
	assert_bool(d.defending).is_false().override_failure_message("новый раунд сбрасывает defending (защитник)")
