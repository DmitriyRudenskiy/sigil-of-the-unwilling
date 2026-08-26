extends Node
class_name BattleInput
## Ввод боя: обработка кликов, подсветка ходов/атак, выбор юнитов.
## Не содержит логики ходов или AI — только ввод и сигналы.

signal unit_selected(unit: BattleState.BattleUnit)
signal unit_move_requested(unit: BattleState.BattleUnit, target: Vector2i)
signal unit_attack_requested(unit: BattleState.BattleUnit, target: BattleState.BattleUnit)
signal cancel_requested
signal attack_preview_updated(text: String)

var _view: BattleView
var _state: BattleState
var _obstacles: Dictionary = {}
var _action_lock: bool = false
var _attacker_bonus: Dictionary = {}
var _defender_bonus: Dictionary = {}

var highlight_move: Dictionary = {}
var highlight_attack: Dictionary = {}


func setup(view: BattleView, state: BattleState, obstacles: Dictionary) -> void:
	_view = view
	_state = state
	_obstacles = obstacles


func setup_bonuses(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> void:
	_attacker_bonus = attacker_bonus
	_defender_bonus = defender_bonus


func set_action_lock(locked: bool) -> void:
	_action_lock = locked


func _unhandled_input(ev: InputEvent) -> void:
	if _action_lock or _state == null or _state.battle_over or not _state.is_player_turn:
		return

	if ev is InputEventMouseMotion:
		_update_attack_preview()
		return

	if not (ev is InputEventMouseButton) or not ev.pressed:
		return

	if ev.button_index == MOUSE_BUTTON_RIGHT:
		_clear_highlights()
		cancel_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if ev.button_index != MOUSE_BUTTON_LEFT:
		return

	var global_pos := _view.get_global_mouse_position()
	var cell := _view.global_to_map(global_pos)

	if highlight_attack.has(cell):
		var target := _state.get_unit_at(cell, "defender")
		unit_attack_requested.emit(_state.active_unit, target)
		get_viewport().set_input_as_handled()
		return

	if highlight_move.has(cell):
		unit_move_requested.emit(_state.active_unit, cell)
		get_viewport().set_input_as_handled()
		return

	var own := _state.get_unit_at(cell, "attacker")
	if own == null:
		own = _unit_at_pixel(global_pos, "attacker")

	if own != null and not own.has_moved:
		_select(own)
		get_viewport().set_input_as_handled()
		return


func _unit_at_pixel(global_pos: Vector2, side: String) -> BattleState.BattleUnit:
	var local_pos := _view.to_local(global_pos)
	var units := _state.get_units_by_side(side)
	for u in units:
		if u.is_alive():
			var unit_pos := _view.map_to_local(u.cell)
			if local_pos.distance_to(unit_pos) < 60.0:
				return u
	return null


func _select(u: BattleState.BattleUnit) -> void:
	_state.active_unit = u
	_clear_highlights()

	var blocked_dict := _state.build_all_blocked(u, _obstacles)
	var blocked_callable := func() -> Dictionary: return blocked_dict

	highlight_move = _state.get_reachable_for_unit(u, blocked_callable)
	highlight_attack = _compute_attack_highlight(u)

	_view.set_highlights(highlight_move, highlight_attack)
	unit_selected.emit(u)
	_update_attack_preview()

	Logger.battle("selected %s moves=%d" % [u.get_display_name(), highlight_move.size()])


func _update_attack_preview() -> void:
	if _state.active_unit == null:
		attack_preview_updated.emit("")
		return

	var global_pos := _view.get_global_mouse_position()
	var cell := _view.global_to_map(global_pos)

	if highlight_attack.has(cell):
		var target := _state.get_unit_at(cell, "defender")

		if target != null:
			var preview := BattleRules.preview_text(
				_state.active_unit,
				target,
				int(_attacker_bonus.get("attack", 0)),
				int(_defender_bonus.get("defense", 0))
			)
			attack_preview_updated.emit(preview)
			return

	attack_preview_updated.emit("")


func clear_highlights() -> void:
	_clear_highlights()


func _clear_highlights() -> void:
	highlight_move.clear()
	highlight_attack.clear()
	_view.clear_highlights()


func show_attack_only() -> void:
	if _state.active_unit == null or not _state.is_player_turn:
		return
	_clear_highlights()

	var u := _state.active_unit
	highlight_attack = _compute_attack_highlight(u)

	_view.set_highlights({}, highlight_attack)


func _compute_attack_highlight(u: BattleState.BattleUnit) -> Dictionary:
	var result: Dictionary = {}
	var adjacent_enemies: Array[Vector2i] = []

	for nb in HexUtils.get_all_neighbors(u.cell):
		var enemy := _state.get_unit_at(nb, "defender")
		if enemy != null and enemy.is_alive():
			adjacent_enemies.append(nb)

	if u.is_ranged() and adjacent_enemies.is_empty():
		for enemy in _state.get_units_by_side("defender"):
			if enemy.is_alive():
				result[enemy.cell] = 1
	else:
		for cell in adjacent_enemies:
			result[cell] = 1

	return result
