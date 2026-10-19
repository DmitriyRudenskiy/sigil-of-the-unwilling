extends BaseTest

## battle-unit-vitals: ход игрока ограничен временем (BattleState.TURN_TIME_LIMIT,
## default 30 с). Часы живут в модели, вооружает и снимает их исполнитель хода:
## только пока идёт ожидание ввода игрока. Истечение = тот же путь, что явный
## «пропуск»; модальное окно ставит часы на паузу, не сжигая остаток.

const TICK_ONE := 1.0
const TICK_TEN := 10.0


func _state_with_units() -> BattleState:
	var units = Services.resolve(&"units")
	var bs := BattleState.new()
	bs.place_army(
		[units.make_fixed_stack("swordsmen", 10)],
		[units.make_fixed_stack("goblins", 10)]
	)
	return bs


## Исполнитель в состоянии ожидания ввода игрока, часы вооружены вручную —
## тест проверяет часы, а не переходы очереди.
func _arm_player_turn(executor: BattleTurnExecutor, bs: BattleState) -> BattleState.BattleUnit:
	bs.build_queue()
	var idx := 0
	for i in bs.turn_queue.size():
		if bs.turn_queue[i].side == BattleState.Side.ATTACKER:
			idx = i
			break
	bs.turn_idx = idx
	bs.active_unit = bs.turn_queue[idx]
	bs.is_player_turn = true
	executor._state = BattleTurnExecutor.State.WAITING_INPUT
	executor._turn_timer_armed = true
	bs.arm_turn_timer()
	return bs.active_unit


func _executor_in_tree() -> BattleTurnExecutor:
	var executor = auto_free(BattleTurnExecutor.new())
	executor.name = "TurnTimerExecutor"
	add_child(executor)
	executor.setup(_state_with_units(), BattleAI.new(), {})
	return executor


## Гасим асинхронный хвост перехода хода: корутина после await не должна
## ожить на освобождённом исполнителе.
func _kill_turn_coroutine(executor: BattleTurnExecutor) -> void:
	executor._state = BattleTurnExecutor.State.BATTLE_OVER


func test_timer_counts_down_on_player_turn() -> void:
	var executor := _executor_in_tree()
	var bs: BattleState = executor._battle_state
	_arm_player_turn(executor, bs)
	executor.tick_turn_timer(TICK_TEN)
	assert_float(bs.turn_time_left).is_equal(float(BattleState.TURN_TIME_LIMIT) - TICK_TEN)
	assert_bool(bs.turn_timer_running).is_true()
	_kill_turn_coroutine(executor)


func test_timer_expiry_skips_the_turn() -> void:
	var executor := _executor_in_tree()
	var bs: BattleState = executor._battle_state
	var unit := _arm_player_turn(executor, bs)
	for i in BattleState.TURN_TIME_LIMIT:
		executor.tick_turn_timer(TICK_ONE)
	assert_bool(bs.turn_timer_running).is_false()
	assert_bool(unit.has_moved).is_true()
	assert_bool(executor.is_turn_timer_armed()).is_false()
	_kill_turn_coroutine(executor)


func test_timer_does_not_run_outside_player_input() -> void:
	var executor := _executor_in_tree()
	var bs: BattleState = executor._battle_state
	var unit := _arm_player_turn(executor, bs)
	executor._transition_to(BattleTurnExecutor.State.AI_THINKING)
	for i in BattleState.TURN_TIME_LIMIT + 5:
		executor.tick_turn_timer(TICK_ONE)
	assert_float(bs.turn_time_left).is_equal(float(BattleState.TURN_TIME_LIMIT))
	assert_bool(executor.is_turn_timer_armed()).is_false()
	assert_bool(unit.has_moved).is_false()


func test_paused_timer_does_not_spend_time() -> void:
	var executor := _executor_in_tree()
	var bs: BattleState = executor._battle_state
	_arm_player_turn(executor, bs)
	executor.pause_turn_timer()
	for i in BattleState.TURN_TIME_LIMIT:
		executor.tick_turn_timer(TICK_ONE)
	assert_float(bs.turn_time_left).is_equal(float(BattleState.TURN_TIME_LIMIT))
	assert_bool(bs.turn_timer_running).is_false()
	executor.resume_turn_timer()
	assert_bool(bs.turn_timer_running).is_true()
	executor.tick_turn_timer(TICK_TEN)
	assert_float(bs.turn_time_left).is_equal(float(BattleState.TURN_TIME_LIMIT) - TICK_TEN)
	_kill_turn_coroutine(executor)


func test_leaving_player_input_disarms_timer() -> void:
	var executor := _executor_in_tree()
	var bs: BattleState = executor._battle_state
	_arm_player_turn(executor, bs)
	executor._transition_to(BattleTurnExecutor.State.PLAYER_ANIMATING)
	assert_bool(executor.is_turn_timer_armed()).is_false()
	assert_bool(bs.turn_timer_running).is_false()


func test_arm_resets_the_remaining_time() -> void:
	var executor := _executor_in_tree()
	var bs: BattleState = executor._battle_state
	_arm_player_turn(executor, bs)
	executor.tick_turn_timer(TICK_TEN)
	bs.arm_turn_timer()
	assert_float(bs.turn_time_left).is_equal(float(BattleState.TURN_TIME_LIMIT))
	assert_bool(bs.turn_timer_running).is_true()
