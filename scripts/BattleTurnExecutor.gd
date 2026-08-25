extends Node
class_name BattleTurnExecutor
## State Machine для очередности ходов боя.
## Управляет: начало хода → ожидание ввода / AI → анимация → конец хода.
## Все эффекты через сигналы — контроллер подписывается и реагирует.

signal status_updated(text: String)
signal clear_highlights
signal pulse_unit(unit: BattleState.BattleUnit)
signal execute_move(unit: BattleState.BattleUnit, target: Vector2i)
signal execute_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit)
signal end_battle(winner: String, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

enum State {
	IDLE,
	TURN_START,
	WAITING_INPUT,
	AI_THINKING,
	PLAYER_ANIMATING,
	AI_ANIMATING,
	BATTLE_OVER,
}

var _state := State.IDLE
var _battle_state: BattleState
var _ai: BattleAI
var _obstacles: Dictionary = {}
var _animation_duration := 0.4
var _ai_think_time := 0.7


func setup(bs: BattleState, ai: BattleAI, obstacles: Dictionary) -> void:
	_battle_state = bs
	_ai = ai
	_obstacles = obstacles
	_state = State.IDLE


func get_current_state() -> State:
	return _state


func is_input_active() -> bool:
	return _state == State.WAITING_INPUT


## Основной вход: начать бой
func start_battle() -> void:
	_state = State.TURN_START
	_advance_to_next_turn()


## Вызывается игроком через BattleInput
func request_move(unit: BattleState.BattleUnit, target: Vector2i) -> void:
	if _state != State.WAITING_INPUT:
		return
	_state = State.PLAYER_ANIMATING
	execute_move.emit(unit, target)


## Вызывается игроком через BattleInput
func request_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if _state != State.WAITING_INPUT:
		return
	_state = State.PLAYER_ANIMATING
	execute_attack.emit(atk, def)


## Вызывается после завершения анимации хода (controller → executor)
func on_move_completed() -> void:
	_on_action_completed()


## Вызывается после завершения анимации атаки (controller → executor)
func on_attack_completed() -> void:
	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return
	_on_action_completed()


## Кнопка «Ждать» — переносит активного юнита в конец очереди
func request_wait() -> void:
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return
	_battle_state.do_wait(_battle_state.active_unit)
	_on_action_completed()


## Кнопка «Пропустить»
func request_skip() -> void:
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return
	_battle_state.do_skip(_battle_state.active_unit)
	_on_action_completed()


## Кнопка «Защита»
func request_defend() -> void:
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return
	_battle_state.do_defend(_battle_state.active_unit)
	status_updated.emit("🛡️ Защита: входящий урон вдвое меньше до следующего хода.")
	_on_action_completed()


## Кнопка «Отступление»
func request_retreat() -> void:
	_battle_state.battle_over = true
	_transition_to(State.BATTLE_OVER)
	status_updated.emit("Отступление!")
	end_battle.emit("defender", _battle_state.get_survivors("attacker"), _battle_state.get_survivors("defender"))


## === Внутренняя логика ===

func _advance_to_next_turn() -> void:
	clear_highlights.emit()
	_battle_state.advance_turn()

	if _check_battle_over():
		return

	_transition_to(State.TURN_START)
	status_updated.emit(_battle_state.get_turn_info())
	pulse_unit.emit(_battle_state.active_unit)

	if _battle_state.is_player_turn:
		# Небольшая задержка перед переходом в ожидание ввода
		await get_tree().create_timer(0.15).timeout
		if _state == State.BATTLE_OVER:
			return
		_transition_to(State.WAITING_INPUT)
	else:
		_run_ai_turn()


func _run_ai_turn() -> void:
	_transition_to(State.AI_THINKING)
	await get_tree().create_timer(_ai_think_time).timeout
	if _state == State.BATTLE_OVER:
		return

	var blocked := _battle_state.build_all_blocked(_battle_state.active_unit, _obstacles)
	var decision := _ai.decide_turn(_battle_state.active_unit, _battle_state, blocked)

	match decision.action:
		BattleAI.Action.ATTACK:
			_state = State.AI_ANIMATING
			execute_attack.emit(_battle_state.active_unit, decision.attack_target)
		BattleAI.Action.MOVE:
			_execute_ai_move(decision)
		_:
			_on_action_completed()


func _execute_ai_move(decision: BattleAI.AIResult) -> void:
	var u := _battle_state.active_unit
	_state = State.AI_ANIMATING
	_battle_state.do_move(u, decision.target_cell)
	clear_highlights.emit()

	execute_move.emit(u, decision.move_path)

	await get_tree().create_timer(_animation_duration).timeout
	if _state == State.BATTLE_OVER:
		return

	# После хода AI проверяем, есть ли цель для атаки
	if decision.move_victim != null and decision.move_victim.is_alive():
		execute_attack.emit(u, decision.move_victim)
		await get_tree().create_timer(_animation_duration).timeout
		if _state == State.BATTLE_OVER:
			return
	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return
	_on_action_completed()


func _on_action_completed() -> void:
	if _check_battle_over():
		return
	_advance_to_next_turn()


func _check_battle_over() -> bool:
	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return true
	return false


func _emit_end() -> void:
	var winner := _battle_state.check_end()
	if winner != "":
		end_battle.emit(
			winner,
			_battle_state.get_survivors("attacker"),
			_battle_state.get_survivors("defender")
		)


func _transition_to(new_state: State) -> void:
	_state = new_state
