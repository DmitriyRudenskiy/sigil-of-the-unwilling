extends Node2D
class_name BattleController
## Координатор боя: состояние → BattleState, решения → BattleAI, визуал → BattleView.
## Ввод → BattleInput (отдельный узел). Последовательности ходов — здесь.

const _BattleInput = preload("res://scripts/BattleInput.gd")

signal battle_finished(winner: String, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

var _state: BattleState
var _ai: BattleAI
var _view: BattleView
var _ui: BattleUI
var _input: BattleInput
var obstacles: Dictionary = {}


# ==================== READY ====================
func _ready() -> void:
	_state = BattleState.new()
	_ai = BattleAI.new()

	_view = BattleView.new()
	_view.name = "BattleView"
	add_child(_view)
	_view.setup()
	_view.paint_field()
	_place_obstacles()

	_ui = BattleUI.new()
	_ui.name = "BattleUI"
	add_child(_ui)
	_ui.retreat_requested.connect(_on_retreat)
	_ui.wait_requested.connect(_on_wait)
	_ui.attack_mode_requested.connect(_on_attack_mode)
	_ui.skip_requested.connect(_on_skip)
	_ui.defend_requested.connect(_on_defend)

	_input = BattleInput.new()
	_input.name = "BattleInput"
	add_child(_input)
	_input.setup(_view, _state, obstacles)
	_input.unit_selected.connect(_on_unit_selected)
	_input.unit_move_requested.connect(_do_move)
	_input.unit_attack_requested.connect(_do_attack)
	_input.cancel_requested.connect(_on_cancel)

	await get_tree().process_frame
	_view.fit_camera()


func _place_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var n := 0
	while n < 8:
		var cell := Vector2i(rng.randi_range(4, BattleState.BW - 5), rng.randi_range(1, BattleState.BH - 2))
		if obstacles.has(cell):
			continue
		obstacles[cell] = true
		var emoji := "🪨" if rng.randf() > 0.5 else "🌳"
		_view.add_obstacle(cell, emoji)
		n += 1


# ==================== INPUT CALLBACKS ====================
func _on_unit_selected(u: BattleState.BattleUnit) -> void:
	_ui.set_status("%s: синий контур — ход, красный — атака." % u.get_display_name())


func _on_cancel() -> void:
	_ui.set_status("Выберите существо…")


# ==================== START ====================
func start_battle(atk: Array[UnitStack], def: Array[UnitStack]) -> void:
	_state.place_army(atk, def)

	for u in _state.get_units_by_side("attacker"):
		_view.create_unit_sprite(u)
	for u in _state.get_units_by_side("defender"):
		_view.create_unit_sprite(u)

	_view.spawn_hero_figure()
	_view.fit_camera()
	_state.build_queue()
	_next_turn()


# ==================== TURNS ====================
func _next_turn() -> void:
	if _input:
		_input.set_action_lock(false)

	if _state.battle_over:
		return
	_input.clear_highlights()
	_state.advance_turn()

	if _state.battle_over:
		return

	_ui.set_status(_state.get_turn_info())
	_view.pulse_unit(_state.active_unit)

	if not _state.is_player_turn:
		await get_tree().create_timer(0.7).timeout
		_ai_turn()


func _end_turn() -> void:
	if not _state.battle_over:
		_next_turn()


# ==================== ACTIONS ====================
func _do_move(u: BattleState.BattleUnit, target: Vector2i) -> void:
	if _input:
		_input.set_action_lock(true)
	var blocked := _state.build_all_blocked(u, obstacles)
	var path := HexUtils.bfs_path(u.cell, target, blocked, BattleState.BW, BattleState.BH)
	_state.do_move(u, target)

	_input.clear_highlights()
	_view.animate_move(u, path)
	await get_tree().create_timer(0.4).timeout
	_end_turn()


func _do_attack(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if def == null:
		return
	var result := _state.apply_attack(atk, def)
	if result.is_empty():
		if _input:
			_input.set_action_lock(false)
		return

	if _input:
		_input.set_action_lock(true)

	_input.clear_highlights()

	_view.update_unit_count(def)
	_view.flash_unit(def)
	print("[Battle] %s -> %s: урон %d, убито %d" % [
		atk.get_display_name(), def.get_display_name(), result["damage"], result["kills"]])

	if def.get_count() <= 0:
		_view.remove_unit(def)

	if _state.battle_over:
		if _input:
			_input.set_action_lock(false)
		_emit_end()
		return

	await get_tree().create_timer(0.4).timeout
	_end_turn()


# ==================== AI ====================
func _ai_turn() -> void:
	if _state.battle_over or _state.active_unit == null:
		return

	var blocked := _state.build_all_blocked(_state.active_unit, obstacles)
	var decision := _ai.decide_turn(_state.active_unit, _state, blocked)

	match decision.action:
		BattleAI.Action.ATTACK:
			await _execute_ai_attack(decision.attack_target)
		BattleAI.Action.MOVE:
			await _execute_ai_move(decision)
		_:
			_end_turn()


func _execute_ai_attack(target: BattleState.BattleUnit) -> void:
	if target == null:
		_end_turn()
		return
	await _do_attack(_state.active_unit, target)


func _execute_ai_move(decision: BattleAI.AIResult) -> void:
	var u := _state.active_unit

	_state.do_move(u, decision.target_cell)
	_input.clear_highlights()
	_view.animate_move(u, decision.move_path)
	await get_tree().create_timer(0.4).timeout

	if decision.move_victim != null and decision.move_victim.is_alive():
		await _do_attack(u, decision.move_victim)
		return

	_end_turn()


# ==================== BUTTONS ====================
func _on_retreat() -> void:
	_state.battle_over = true
	_ui.set_status("Отступление!")
	battle_finished.emit("defender", _state.get_survivors("attacker"), _state.get_survivors("defender"))


func _on_wait() -> void:
	if _state.active_unit != null and _state.is_player_turn:
		_state.do_wait(_state.active_unit)
		_end_turn()


func _on_attack_mode() -> void:
	if _input:
		_input.show_attack_only()
	_ui.set_status("⚔️ Кликните врага с красным контуром.")


func _on_skip() -> void:
	if _state.is_player_turn and _state.active_unit != null:
		_state.do_skip(_state.active_unit)
		_end_turn()


func _on_defend() -> void:
	if _state.is_player_turn and _state.active_unit != null:
		_state.do_defend(_state.active_unit)
		_ui.set_status("🛡️ Защита: входящий урон вдвое меньше до следующего хода.")
		_end_turn()


# ==================== END ====================
func _emit_end() -> void:
	var winner := _state.check_end()
	if winner == "":
		return
	battle_finished.emit(
		winner,
		_state.get_survivors("attacker"),
		_state.get_survivors("defender")
	)
