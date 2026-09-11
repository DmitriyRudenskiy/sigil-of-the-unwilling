extends BaseTest


func _make_executor() -> Dictionary:
	var bs: BattleState = BattleState.new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 40))
	atk.append(Units.make_fixed_stack("archers", 20))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	bs.place_army(atk, def)
	var ex = auto_free( BattleTurnExecutor.new())
	ex.name = "TestRetreatExec"
	ex.setup(bs, BattleAI.new(), {})
	return {"executor": ex, "state": bs}

func _survivor_total(a: Array) -> int:
	var total := 0
	for s in a:
		total += s.count
	return total

func test_immediate_retreat_at_waiting_input() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	ex._state = BattleTurnExecutor.State.WAITING_INPUT
	ex.request_retreat()

	assert_that(ex.get_current_state()).is_equal(BattleTurnExecutor.State.BATTLE_OVER)
	assert_bool(bs.battle_over).is_true()
	assert_that(end_events.size()).is_equal(1)
	if end_events.size() == 1:
		assert_that(end_events[0][0]).is_equal(BattleState.Side.DEFENDER)
		assert_that(_survivor_total(end_events[0][1])).is_equal(30)
		ex.free()

func test_early_retreat_queued_until_waiting_input() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	ex._state = BattleTurnExecutor.State.TURN_START
	ex.request_retreat()

	assert_that(ex.get_current_state()).is_equal(BattleTurnExecutor.State.TURN_START)
	assert_bool(bs.battle_over).is_false()
	assert_that(end_events.size()).is_equal(0)

	ex._transition_to(BattleTurnExecutor.State.WAITING_INPUT)

	assert_that(ex.get_current_state()).is_equal(BattleTurnExecutor.State.BATTLE_OVER)
	assert_bool(bs.battle_over).is_true()
	assert_that(end_events.size()).is_equal(1)
	if end_events.size() == 1:
		assert_that(_survivor_total(end_events[0][1])).is_equal(30)
		ex.free()

func test_queued_retreat_ignores_other_transitions() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]

	ex._state = BattleTurnExecutor.State.TURN_START
	ex.request_retreat()

	ex._transition_to(BattleTurnExecutor.State.AI_ANIMATING)
	assert_bool(bs.battle_over).is_false()
	assert_that(ex.get_current_state()).is_equal(BattleTurnExecutor.State.AI_ANIMATING)

	ex._transition_to(BattleTurnExecutor.State.WAITING_INPUT)
	assert_bool(bs.battle_over).is_true()
	ex.free()

func test_force_retreat_from_stuck_ai_turn() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	ex._state = BattleTurnExecutor.State.AI_THINKING
	ex.force_retreat()

	assert_that(ex.get_current_state()).is_equal(BattleTurnExecutor.State.BATTLE_OVER)
	assert_bool(bs.battle_over).is_true()
	assert_that(end_events.size()).is_equal(1)
	if end_events.size() == 1:
		assert_that(end_events[0][0]).is_equal(BattleState.Side.DEFENDER)
		assert_that(_survivor_total(end_events[0][1])).is_equal(30)
		ex.free()

func test_force_retreat_noop_after_battle_over() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]

	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	ex._state = BattleTurnExecutor.State.WAITING_INPUT
	ex.request_retreat()
	assert_that(end_events.size()).is_equal(1)

	ex.force_retreat()
	assert_that(end_events.size()).is_equal(1)
	ex.free()

func test_force_retreat_on_over_state_without_end_emitted() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	BattleActionResolver.force_end(bs, BattleState.Side.DEFENDER)
	ex._state = BattleTurnExecutor.State.AI_ANIMATING

	ex.force_retreat()

	assert_that(ex.get_current_state()).is_equal(BattleTurnExecutor.State.BATTLE_OVER)
	assert_that(end_events.size()).is_equal(1)
	if end_events.size() == 1:
		assert_that(end_events[0][0]).is_equal(BattleState.Side.DEFENDER)

	ex.force_retreat()
	assert_that(end_events.size()).is_equal(1)
	ex.free()
