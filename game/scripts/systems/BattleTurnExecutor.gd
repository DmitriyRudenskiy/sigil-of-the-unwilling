extends Node
class_name BattleTurnExecutor

signal status_updated(text: String)
signal clear_highlights
signal pulse_unit(unit: BattleState.BattleUnit)
signal phase_changed(new_phase: State)
signal initiative_changed
signal active_unit_changed(unit: BattleState.BattleUnit)
signal floating_text(cell: Vector2i, text: String, color: Color)
signal execute_move(unit: BattleState.BattleUnit, path: Array[Vector2i])
signal execute_attack(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary
)
signal spell_cast_executed(caster: BattleState.BattleUnit, target: BattleState.BattleUnit, result: Dictionary)
signal spell_cast_failed(reason: String)
signal execute_sacrifice(acting: BattleState.BattleUnit, target: BattleState.BattleUnit, cost: Variant, result: Dictionary)
signal sacrifice_failed(reason: String)
signal end_battle(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

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
var _state_token: int = 0
var _battle_state: BattleState
var _ai: BattleAI
var _obstacles: Dictionary = {}
var _ai_think_time := GameNumbers.BATTLE_AI_THINK_TIME
var _rng := RandomNumberGenerator.new()
var _end_emitted := false
var _morale_allowed := false

var _attack_seq: BattleAttackSequence
var _retreat_policy: BattleRetreatPolicy
var _pending_attack: BattleState.BattleUnit = null

func setup(bs: BattleState, ai: BattleAI, obstacles: Dictionary) -> void:
	_battle_state = bs
	_ai = ai
	_obstacles = obstacles
	_state = State.IDLE

	_rng.randomize()

	_end_emitted = false
	_morale_allowed = false

	if _attack_seq == null:
		_attack_seq = BattleAttackSequence.new()
	if _retreat_policy == null:
		_retreat_policy = BattleRetreatPolicy.new()
	_attack_seq.setup(bs, _rng, self)
	_retreat_policy.setup(bs, self)

func get_current_state() -> State:
	return _state

func is_input_active() -> bool:
	return _state == State.WAITING_INPUT

var _paused := false
enum PendingAction { NONE, MOVE, ATTACK, SPELL }
var _pending_completion: PendingAction = PendingAction.NONE

func pause_battle() -> void:
	_paused = true
	if is_inside_tree():
		get_tree().paused = true

func resume_battle() -> void:
	if is_inside_tree():
		get_tree().paused = false
	_paused = false

	var pending := _pending_completion
	_pending_completion = PendingAction.NONE

	if _battle_state == null:
		return

	match pending:
		PendingAction.MOVE: on_move_completed()
		PendingAction.ATTACK: on_attack_completed()
		PendingAction.SPELL: on_spell_anim_completed()

func is_paused() -> bool:
	return _paused

func start_battle() -> void:
	_paused = false
	_pending_completion = PendingAction.NONE
	_end_emitted = false
	_morale_allowed = false
	_retreat_policy.reset()

	if _battle_state.check_end() != BattleState.Side.NONE:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return

	_battle_state.build_queue()
	_state = State.TURN_START
	_advance_to_next_turn()

func request_select(unit: BattleState.BattleUnit) -> void:
	if not is_input_active() or unit == null or not unit.is_alive():
		return
	_battle_state.active_unit = unit
	active_unit_changed.emit(unit)

func request_move(unit: BattleState.BattleUnit, target: Vector2i) -> void:
	if _state != State.WAITING_INPUT:
		return

	if unit == null:
		return

	if unit != _battle_state.active_unit:
		return

	if not unit.is_alive() or unit.has_moved:
		return

	var blocked := _battle_state.build_all_blocked(unit, _obstacles)
	var reachable := _battle_state.get_reachable_for_unit(
		unit,
		func() -> Dictionary: return blocked
	)

	if not reachable.has(target):
		return

	var path: Array[Vector2i] = []

	if unit.is_flying():
		path = [unit.cell, target]
	else:
		path = HexPathfinding.find_path(
			unit.cell,
			target,
			blocked,
			BattleState.BW,
			BattleState.BH,
			"bfs"
		)

	if path.size() < 2:
		return

	BattleActionResolver.do_move(_battle_state, unit, target)

	var anim_state := State.PLAYER_ANIMATING if unit.side == BattleState.Side.ATTACKER else State.AI_ANIMATING
	_transition_to(anim_state)
	execute_move.emit(unit, path)

func request_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if _state != State.WAITING_INPUT:
		return

	if atk == null or def == null:
		return

	if atk != _battle_state.active_unit:
		return

	if not atk.is_alive() or not def.is_alive():
		return

	var adjacent_enemy := _attack_seq.has_adjacent_enemy(atk)

	if atk.is_ranged() and not adjacent_enemy:
		pass
	else:
		if HexUtils.hex_distance(atk.cell, def.cell) != 1:
			return

	_morale_allowed = true
	_attack_seq.start_attack(atk, def)

func on_move_completed() -> void:
	if _paused:
		_pending_completion = PendingAction.MOVE
		return
	if _state == State.BATTLE_OVER:
		return
	if _battle_state == null:
		return

	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return

	if _pending_attack != null and _pending_attack.is_alive():
		var target := _pending_attack
		_pending_attack = null
		_morale_allowed = true
		_attack_seq.start_attack(_battle_state.active_unit, target)
		return

	_morale_allowed = true
	_on_action_completed()

func on_spell_anim_completed() -> void:
	if _paused:
		_pending_completion = PendingAction.SPELL
		return
	if _state == State.BATTLE_OVER:
		return
	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return
	_on_action_completed()

func on_attack_completed() -> void:
	if _paused:
		_pending_completion = PendingAction.ATTACK
		return
	if _state == State.BATTLE_OVER:
		return

	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return

	if _attack_seq.has_active():
		if _attack_seq.is_retaliating():
			_attack_seq.finish()
			return

		if (
			_attack_seq.strikes_left() > 0
			and _attack_seq.attacker() != null
			and _attack_seq.attacker().is_alive()
			and _attack_seq.defender() != null
			and _attack_seq.defender().is_alive()
		):
			_attack_seq.next_strike()
			return

		if _attack_seq.can_retaliate():
			_attack_seq.start_retaliation()
			return

		_attack_seq.finish()
		return

	_on_action_completed()

func request_wait() -> void:
	if _paused:
		return
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return

	BattleActionResolver.do_wait(_battle_state, _battle_state.active_unit)
	_morale_allowed = false
	_on_action_completed()

func request_skip() -> void:
	if _paused:
		return
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return

	BattleActionResolver.do_skip(_battle_state, _battle_state.active_unit)
	_morale_allowed = false
	_on_action_completed()

func request_spell_cast(spell_id: StringName) -> void:
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return
	status_updated.emit(GameText.battle_spell_target())

func on_spell_target_selected(spell_id: StringName, target: BattleState.BattleUnit) -> void:
	var caster := _battle_state.active_unit
	if caster == null or target == null:
		_on_action_completed()
		return

	var caster_bonus := _battle_state.attacker_hero_bonus if caster.side == BattleState.Side.ATTACKER else _battle_state.defender_hero_bonus
	var target_bonus := _battle_state.defender_hero_bonus if target.side == BattleState.Side.DEFENDER else _battle_state.attacker_hero_bonus

	var result := BattleActionResolver.apply_spell(
		_battle_state, spell_id, caster, target, caster_bonus, target_bonus, _rng
	)

	if result.get("result") == "success":
		SoundManager.play_sfx_cue(&"spell_cast")
		_transition_to(State.PLAYER_ANIMATING)
		spell_cast_executed.emit(caster, target, result)
	else:
		spell_cast_failed.emit(result.get("result", "unknown"))
		status_updated.emit(GameText.battle_spell_failed(str(result.get("result", "unknown"))))

func request_sacrifice(
	acting: BattleState.BattleUnit,
	sacrifice: Dictionary,
	target: BattleState.BattleUnit,
	cost: Variant
) -> void:
	if _state != State.WAITING_INPUT:
		return
	if acting == null or target == null or sacrifice == null or cost == null:
		return
	if acting != _battle_state.active_unit:
		return
	if not acting.is_alive() or not target.is_alive():
		return

	var result := BattleActionResolver.apply_sacrifice(
		_battle_state, acting, sacrifice, target, cost, _rng
	)

	if result.get("result") == "success":
		_transition_to(State.PLAYER_ANIMATING)
		execute_sacrifice.emit(acting, target, cost, result)
	else:
		sacrifice_failed.emit(result.get("result", "unknown"))
		status_updated.emit(GameText.battle_sacrifice_failed(str(result.get("result", "unknown"))))

func request_defend() -> void:
	if _paused:
		return
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return

	BattleActionResolver.do_defend(_battle_state, _battle_state.active_unit)
	status_updated.emit(GameText.battle_defend_bonus())
	_morale_allowed = false
	_on_action_completed()

func request_retreat() -> void:
	_retreat_policy.request()

func force_retreat() -> void:
	_retreat_policy.force()

func _advance_to_next_turn() -> void:
	clear_highlights.emit()

	_battle_state.advance_turn()

	if _check_battle_over():
		return

	var u := _battle_state.active_unit
	if u == null:
		_on_action_completed()
		return

	u.distance_moved_this_turn = 0

	if u.is_stunned():
		var stun_effect := -1
		for eff in u.statuses.keys():
			if StatusEffects.is_stun(eff):
				stun_effect = eff
				break

		_tick_statuses(u)

		status_updated.emit("%s is %s! Skips turn." % [u.get_display_name(), StatusEffects.get_name(stun_effect)])
		u.has_moved = true
		_on_action_completed()
		return

	_tick_statuses(u)

	_transition_to(State.TURN_START)
	status_updated.emit(_battle_state.get_turn_info())

	initiative_changed.emit()
	active_unit_changed.emit(_battle_state.active_unit)
	pulse_unit.emit(_battle_state.active_unit)

	if _battle_state.is_player_turn:
		var token := _state_token
		await get_tree().create_timer(GameNumbers.BATTLE_TURN_DELAY, false).timeout

		if _is_stale(token) or _paused:
			return

		_transition_to(State.WAITING_INPUT)
	else:
		_run_ai_turn()

func _tick_statuses(u: BattleState.BattleUnit) -> void:
	var to_remove: Array[int] = []

	for eff in u.statuses.keys():
		u.statuses[eff] -= 1
		if u.statuses[eff] <= 0:
			to_remove.append(eff)

	for eff in to_remove:
		u.statuses.erase(eff)

func _run_ai_turn() -> void:
	_transition_to(State.AI_THINKING)
	var token := _state_token

	await get_tree().create_timer(_ai_think_time, false).timeout

	if _is_stale(token) or _paused:
		return

	var blocked := _battle_state.build_all_blocked(_battle_state.active_unit, _obstacles)
	var decision := _ai.decide_turn(_battle_state.active_unit, _battle_state, blocked)

	match decision.action:
		BattleAI.Action.ATTACK:
			_attack_seq.start_attack(_battle_state.active_unit, decision.attack_target)
		BattleAI.Action.MOVE:
			_execute_ai_move(decision)
		_:
			_on_action_completed()

func _execute_ai_move(decision: BattleAI.AIResult) -> void:
	var u := _battle_state.active_unit

	if u == null:
		_on_action_completed()
		return

	_pending_attack = decision.move_victim

	BattleActionResolver.do_move(_battle_state, u, decision.target_cell)

	_transition_to(State.AI_ANIMATING)
	clear_highlights.emit()
	execute_move.emit(u, decision.move_path)

func _on_action_completed() -> void:
	if _check_battle_over():
		return

	if _morale_allowed and _attack_seq.try_morale_extra_turn():
		return

	_morale_allowed = false
	_advance_to_next_turn()

func _check_battle_over() -> bool:
	if _battle_state.battle_over:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return true
	return false

func _emit_end() -> void:
	if _end_emitted:
		return

	var winner := _battle_state.check_end()
	if winner == BattleState.Side.NONE:
		return

	var surviving_atk: Array[UnitStack] = []
	var surviving_def: Array[UnitStack] = _battle_state.get_survivors(BattleState.Side.DEFENDER)

	if _retreat_policy.is_requested() and winner == BattleState.Side.DEFENDER:
		surviving_atk = _battle_state.get_retreat_survivors(BattleState.Side.ATTACKER)
	else:
		surviving_atk = _battle_state.get_survivors(BattleState.Side.ATTACKER)

	_end_emitted = true

	end_battle.emit(
		winner,
		surviving_atk,
		surviving_def
	)

func _transition_to(new_state: State) -> void:
	_state = new_state
	_state_token += 1
	phase_changed.emit(new_state)
	if _retreat_policy.is_requested() and new_state == State.WAITING_INPUT:
		_retreat_policy._execute()

func _is_stale(token: int) -> bool:
	return _state == State.BATTLE_OVER or token != _state_token
