extends BaseTest



var state: Variant

func before_test() -> void:
	state = BattleState.new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack("swordsmen", 10)]
	var def: Array[UnitStack] = [
		Units.make_fixed_stack("goblins", 10),
		Units.make_fixed_stack("goblins", 10),
	]
	state.place_army(atk, def)

func _in_board(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < BattleState.BW and p.y >= 0 and p.y < BattleState.BH

func _neighbor_of(p: Vector2i) -> Vector2i:
	for n in HexUtils.get_all_neighbors(p):
		if _in_board(n):
			return n
	return p

func test_reachable_cache_invalidated_on_kill() -> void:
	var victim = state.defender_units[1]
	var v_cell = victim.cell
	var X := _neighbor_of(v_cell)
	var fn := func() -> Dictionary: return state.build_all_blocked(state.attacker_units[0], {})
	var r1: Dictionary = state.get_reachable(X, 1, fn)
	assert_int(r1.size()).is_greater(0)
	assert_bool(r1.has(v_cell)).is_false()
	BattleActionResolver.kill_unit(state, victim)
	var r2: Dictionary = state.get_reachable(X, 1, fn)
	assert_bool(r2.has(v_cell)).is_true()

func test_reachable_cache_invalidated_on_revive() -> void:
	var victim = state.defender_units[1]
	var v_cell = victim.cell
	var X := _neighbor_of(v_cell)
	var fn := func() -> Dictionary: return state.build_all_blocked(state.attacker_units[0], {})
	BattleActionResolver.kill_unit(state, victim)
	var r1: Dictionary = state.get_reachable(X, 1, fn)
	assert_bool(r1.has(v_cell)).is_true()
	BattleActionResolver.revive_unit(state, victim)
	var r2: Dictionary = state.get_reachable(X, 1, fn)
	assert_bool(r2.has(v_cell)).is_false()

func test_reachable_cache_invalidated_on_move() -> void:
	var other = state.defender_units[0]
	var old_cell = other.cell
	var X := _neighbor_of(old_cell)
	var fn := func() -> Dictionary: return state.build_all_blocked(state.attacker_units[0], {})
	var r1: Dictionary = state.get_reachable(X, 1, fn)
	assert_int(r1.size()).is_greater(0)
	assert_bool(r1.has(old_cell)).is_false()
	var other_fn := func() -> Dictionary: return state.build_all_blocked(other, {})
	var reach: Dictionary = state.get_reachable_for_unit(other, other_fn)
	assert_int(reach.size()).is_greater(0)
	var moved_to := Vector2i(-1, -1)
	for c in reach:
		moved_to = c
		break
	BattleActionResolver.do_move(state, other, moved_to)
	var r2: Dictionary = state.get_reachable(X, 1, fn)
	assert_bool(r2.has(old_cell)).is_true()

func test_reachable_cache_stable_when_unchanged() -> void:
	var unit = state.attacker_units[0]
	var fn := func() -> Dictionary: return state.build_all_blocked(unit, {})
	var r1: Dictionary = state.get_reachable_for_unit(unit, fn)
	var r2: Dictionary = state.get_reachable_for_unit(unit, fn)
	assert_that(r1).is_equal(r2)
