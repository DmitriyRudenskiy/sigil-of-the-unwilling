class_name BattleRetreatPolicy
extends RefCounted

func setup(state: BattleState, executor: BattleTurnExecutor) -> void:
	_battle_state = state
	_executor = executor
	_requested = false

var _executor: BattleTurnExecutor
var _battle_state: BattleState
var _requested := false

func reset() -> void:
	_requested = false

func is_requested() -> bool:
	return _requested

func request() -> void:
	if _executor.is_paused() or _battle_state == null:
		return
	if _executor.get_current_state() == BattleTurnExecutor.State.BATTLE_OVER or _battle_state.battle_over:
		return
	if _executor.get_current_state() != BattleTurnExecutor.State.WAITING_INPUT:
		_requested = true
		_executor.status_updated.emit(GameText.battle_retreat_wait())
		return
	_execute()

func force() -> void:
	if _battle_state == null or _executor._end_emitted:
		return
	_executor.status_updated.emit(GameText.battle_forced_retreat())
	_execute()

func _execute() -> void:
	_requested = true
	BattleActionResolver.force_end(_battle_state, BattleState.Side.DEFENDER)
	_executor._transition_to(BattleTurnExecutor.State.BATTLE_OVER)
	_executor.status_updated.emit(GameText.battle_retreat_confirm())
	_executor._emit_end()
