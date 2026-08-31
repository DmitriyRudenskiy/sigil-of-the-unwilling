extends Node
class_name BattleTurnExecutor
## State Machine для очередности ходов боя.
## Управляет: начало хода → ожидание ввода / AI → анимация → конец хода.
## Все эффекты через сигналы — контроллер подписывается и реагирует.
## Мутация BattleState происходит ТОЛЬКО здесь.

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
var _ai_think_time := GameSettings.BATTLE_AI_THINK_TIME
var _rng := RandomNumberGenerator.new()
var _end_emitted := false
var _retreat_requested := false
var _morale_allowed := false

var _attack_attacker: BattleState.BattleUnit = null
var _attack_defender: BattleState.BattleUnit = null
var _attack_strikes_left := 0
var _attack_is_melee := false
var _retaliation_phase := false
var _pending_attack: BattleState.BattleUnit = null


func setup(bs: BattleState, ai: BattleAI, obstacles: Dictionary) -> void:
	_battle_state = bs
	_ai = ai
	_obstacles = obstacles
	_state = State.IDLE

	_rng.randomize()

	_end_emitted = false
	_retreat_requested = false
	_morale_allowed = false


func get_current_state() -> State:
	return _state


func is_input_active() -> bool:
	return _state == State.WAITING_INPUT


var _paused := false
enum PendingAction { NONE, MOVE, ATTACK, SPELL }
var _pending_completion: PendingAction = PendingAction.NONE

func pause_battle() -> void:
	_paused = true
	# Freeze tree to stop all tweens and animations mid-frame
	if is_inside_tree():
		get_tree().paused = true

func resume_battle() -> void:
	if is_inside_tree():
		get_tree().paused = false
	_paused = false

	var pending := _pending_completion
	_pending_completion = PendingAction.NONE

	# Без активного боя возвращать pending-действие нечему (напр., resume до setup)
	if _battle_state == null:
		return

	match pending:
		PendingAction.MOVE: on_move_completed()
		PendingAction.ATTACK: on_attack_completed()
		PendingAction.SPELL: on_spell_anim_completed()


func is_paused() -> bool:
	return _paused


## Основной вход: начать бой
func start_battle() -> void:
	_paused = false
	_pending_completion = PendingAction.NONE
	_end_emitted = false
	_retreat_requested = false
	_morale_allowed = false

	if _battle_state.check_end() != BattleState.Side.NONE:
		_transition_to(State.BATTLE_OVER)
		_emit_end()
		return

	_battle_state.build_queue()
	_state = State.TURN_START
	_advance_to_next_turn()


## Выбор юнита игроком: валидация + мутация state
func request_select(unit: BattleState.BattleUnit) -> void:
	if not is_input_active() or unit == null or not unit.is_alive():
		return
	_battle_state.active_unit = unit
	active_unit_changed.emit(unit)

## Вызывается игроком через BattleInput
## Валидирует, мутирует BattleState, затем испускает сигнал для анимации.
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
		path = HexUtils.bfs_path(
			unit.cell,
			target,
			blocked,
			BattleState.BW,
			BattleState.BH
		)

	if path.size() < 2:
		return

	_battle_state.do_move(unit, target)

	var anim_state := State.PLAYER_ANIMATING if unit.side == BattleState.Side.ATTACKER else State.AI_ANIMATING
	_transition_to(anim_state)
	execute_move.emit(unit, path)


## Вызывается игроком через BattleInput
func request_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if _state != State.WAITING_INPUT:
		return

	if atk == null or def == null:
		return

	if atk != _battle_state.active_unit:
		return

	if not atk.is_alive() or not def.is_alive():
		return

	var adjacent_enemy := _has_adjacent_enemy(atk)

	if atk.is_ranged() and not adjacent_enemy:
		# Ranged can shoot any visible enemy.
		pass
	else:
		if HexUtils.hex_distance(atk.cell, def.cell) != 1:
			return

	_morale_allowed = true
	_start_attack(atk, def)


## Вызывается после завершения анимации перемещения (controller → executor)
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
		_start_attack(_battle_state.active_unit, target)
		return

	_morale_allowed = true
	_on_action_completed()


## Вызывается после завершения анимации каста (controller → executor)
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

## Вызывается после завершения анимации атаки (controller → executor)
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

	if _attack_attacker != null:
		if _retaliation_phase:
			_attack_attacker = null
			_attack_defender = null
			_retaliation_phase = false
			_finish_attack_sequence()
			return

		if (
			_attack_strikes_left > 0
			and _attack_attacker.is_alive()
			and _attack_defender != null
			and _attack_defender.is_alive()
		):
			_do_next_attack_strike()
			return

		if _can_retaliate():
			_start_retaliation()
			return

		_finish_attack_sequence()
		return

	_on_action_completed()


## Кнопка «Ждать» — переносит активного юнита в конец очереди
func request_wait() -> void:
	if _paused:
		return
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return

	_battle_state.do_wait(_battle_state.active_unit)
	_morale_allowed = false
	_on_action_completed()


## Кнопка «Пропустить»
func request_skip() -> void:
	if _paused:
		return
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return

	_battle_state.do_skip(_battle_state.active_unit)
	_morale_allowed = false
	_on_action_completed()


func request_spell_cast(spell_id: StringName) -> void:
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return
	status_updated.emit("Выберите цель для заклинания… (ПКМ — отмена)")


func on_spell_target_selected(spell_id: StringName, target: BattleState.BattleUnit) -> void:
	var caster := _battle_state.active_unit
	if caster == null or target == null:
		_on_action_completed()
		return

	var caster_bonus := _battle_state.attacker_hero_bonus if caster.side == BattleState.Side.ATTACKER else _battle_state.defender_hero_bonus
	var target_bonus := _battle_state.defender_hero_bonus if target.side == BattleState.Side.DEFENDER else _battle_state.attacker_hero_bonus

	var result := _battle_state.apply_spell(spell_id, caster, target, caster_bonus, target_bonus, _rng)

	if result.get("result") == "success":
		SoundManager.play_sfx_cue(&"spell_cast")
		_transition_to(State.PLAYER_ANIMATING)
		spell_cast_executed.emit(caster, target, result)
	else:
		spell_cast_failed.emit(result.get("result", "unknown"))
		status_updated.emit("Заклинание не сработало: %s" % result.get("result", "unknown"))


## Кнопка «Защита»
func request_defend() -> void:
	if _paused:
		return
	if _state != State.WAITING_INPUT or _battle_state.active_unit == null:
		return

	_battle_state.do_defend(_battle_state.active_unit)
	status_updated.emit("🛡️ Защита: +20% DEF до конца раунда.")
	_morale_allowed = false
	_on_action_completed()


## Кнопка «Отступление».
## Если запрос пришёл, пока ход игрока ещё не в WAITING_INPUT (TURN_START,
## задержка начала хода, ход ИИ), отступление ставится в очередь и
## выполняется при первом входе в WAITING_INPUT. Иначе ранний запрос
## теряется: бой не завершён, без повтора RETREAT клиент зацикливается
## на висящем бое.
func request_retreat() -> void:
	if _paused or _battle_state == null:
		return
	if _state == State.BATTLE_OVER or _battle_state.battle_over:
		return
	if _state != State.WAITING_INPUT:
		_retreat_requested = true
		status_updated.emit("Отступление: ждём начала хода игрока…")
		return
	_execute_retreat()


func _execute_retreat() -> void:
	_retreat_requested = true
	_battle_state.force_end(BattleState.Side.DEFENDER)
	_transition_to(State.BATTLE_OVER)
	status_updated.emit("Отступление! Потеря 50% стеков.")
	_emit_end()


## Принудительное отступление — аварийный выход из зависшего боя
## (например, скрипт-ошибка рванула ход и стейт-машина не доходит до
## WAITING_INPUT). В обход стейт-машины завершает бой отступлением.
##
## ВАЖНО: нельзя ставить guard по _battle_state.battle_over — боевой стейт
## может быть уже завершён (последний удар убил последнего врага/юнита),
## но end_battle ещё не испущен (executor завис в анимации). Тогда бой
## «уже окончен» по стейту, но не завершён по стейт-машине — именно в этом
## случае force_retreat обязан сработать. Идемпотентность даёт _end_emitted.
func force_retreat() -> void:
	if _battle_state == null or _end_emitted:
		return
	status_updated.emit("Принудительное отступление (бой завис).")
	_execute_retreat()


## === Внутренняя логика ===

func _advance_to_next_turn() -> void:
	clear_highlights.emit()

	_battle_state.advance_turn()

	if _check_battle_over():
		return

	var u := _battle_state.active_unit
	if u == null:
		_on_action_completed()
		return

	# Reset charge tracker
	u.distance_moved_this_turn = 0

	# Статусы с длительностью 1 должны сработать до начала хода.
	# Иначе длительность исчезнет до проверки stun, и ход не будет пропущен.
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
		await get_tree().create_timer(GameSettings.BATTLE_TURN_DELAY, false).timeout

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
			_start_attack(_battle_state.active_unit, decision.attack_target)
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

	_battle_state.do_move(u, decision.target_cell)

	_transition_to(State.AI_ANIMATING)
	clear_highlights.emit()
	execute_move.emit(u, decision.move_path)


## === Боевая последовательность ===

func _start_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if atk == null or def == null or not def.is_alive():
		_on_action_completed()
		return

	if not atk.is_alive():
		_on_action_completed()
		return

	var distance := HexUtils.hex_distance(atk.cell, def.cell)
	var adjacent_enemy := _has_adjacent_enemy(atk)

	var is_ranged_shot := atk.is_ranged() and distance > 1 and not adjacent_enemy
	var is_melee_attack := not is_ranged_shot

	_attack_attacker = atk
	_attack_defender = def
	_attack_is_melee = is_melee_attack
	_attack_strikes_left = 2 if atk.is_double_strike() else 1
	_retaliation_phase = false

	var anim_state := State.PLAYER_ANIMATING if atk.side == BattleState.Side.ATTACKER else State.AI_ANIMATING
	_transition_to(anim_state)

	_do_next_attack_strike()


func _do_next_attack_strike() -> void:
	if _attack_attacker == null or _attack_defender == null:
		_finish_attack_sequence()
		return

	if not _attack_attacker.is_alive() or not _attack_defender.is_alive():
		_finish_attack_sequence()
		return

	if _attack_strikes_left <= 0:
		_finish_attack_sequence()
		return

	_attack_strikes_left -= 1

	var result := _battle_state.apply_attack(
		_attack_attacker,
		_attack_defender,
		_attack_is_melee,
		_rng,
		not _retaliation_phase
	)

	if result.is_empty():
		_finish_attack_sequence()
		return

	SoundManager.play_sfx_cue(&"battle_hit")
	result["is_retaliation"] = _retaliation_phase

	if result.get("luck", false):
		floating_text.emit(_attack_defender.cell, "LUCK!", Color.RED)

	execute_attack.emit(_attack_attacker, _attack_defender, result)


func _finish_attack_sequence() -> void:
	_attack_attacker = null
	_attack_defender = null
	_attack_strikes_left = 0
	_retaliation_phase = false

	_morale_allowed = true
	_on_action_completed()


func _can_retaliate() -> bool:
	if _attack_attacker == null or _attack_defender == null:
		return false

	if not _attack_is_melee:
		return false

	if not _attack_defender.is_alive():
		return false

	if not _attack_attacker.is_alive():
		return false

	if _attack_defender.has_retaliated:
		return false

	if _attack_attacker.is_no_retaliation():
		return false

	return true


func _start_retaliation() -> void:
	var original_attacker := _attack_attacker
	var original_defender := _attack_defender

	_retaliation_phase = true
	_attack_attacker = original_defender
	_attack_defender = original_attacker
	_attack_strikes_left = 1
	_attack_is_melee = true

	original_defender.has_retaliated = true

	var anim_state := State.PLAYER_ANIMATING if _attack_attacker.side == BattleState.Side.ATTACKER else State.AI_ANIMATING
	_transition_to(anim_state)

	floating_text.emit(_attack_attacker.cell, "RETALIATION", Color.ORANGE)

	_do_next_attack_strike()


## === Мораль и вспомогательные ===

func _try_morale_extra_turn() -> bool:
	var unit := _battle_state.active_unit

	if unit == null or not unit.is_alive():
		return false

	if not BattleRules.can_morale(unit):
		return false

	if _rng.randf() >= BattleRules.MORALE_CHANCE:
		return false

	floating_text.emit(unit.cell, "HIGH MORALE!", Color.YELLOW)

	unit.has_moved = false

	if _battle_state.is_player_turn:
		_transition_to(State.WAITING_INPUT)
	else:
		_run_ai_turn()

	return true


func _has_adjacent_enemy(unit: BattleState.BattleUnit) -> bool:
	if unit == null:
		return false

	var target_side := BattleState.Side.DEFENDER if unit.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER

	for nb in HexUtils.get_all_neighbors(unit.cell):
		var u := _battle_state.get_unit_at(nb, target_side)
		if u != null and u.is_alive():
			return true

	return false


func _on_action_completed() -> void:
	if _check_battle_over():
		return

	if _morale_allowed and _try_morale_extra_turn():
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

	if _retreat_requested and winner == BattleState.Side.DEFENDER:
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
	# RETREAT, отправленный до начала хода игрока (ранний запрос): исполняем
	# при входе в WAITING_INPUT — с любого пути входа (обычный ход, мораль).
	if _retreat_requested and new_state == State.WAITING_INPUT:
		_execute_retreat()


func _is_stale(token: int) -> bool:
	return _state == State.BATTLE_OVER or token != _state_token
