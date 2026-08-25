extends Node
class_name BattleInput
## Ввод боя: обработка кликов, подсветка ходов/атак, выбор юнитов.
## Не содержит логики ходов или AI — только ввод и сигналы.

signal unit_selected(unit: BattleState.BattleUnit)
signal unit_move_requested(unit: BattleState.BattleUnit, target: Vector2i)
signal unit_attack_requested(unit: BattleState.BattleUnit, target: BattleState.BattleUnit)
signal cancel_requested

var _view: BattleView
var _state: BattleState
var _obstacles: Dictionary = {}
var _action_lock: bool = false

var highlight_move: Dictionary = {}
var highlight_attack: Dictionary = {}


func setup(view: BattleView, state: BattleState, obstacles: Dictionary) -> void:
	_view = view
	_state = state
	_obstacles = obstacles


func set_action_lock(locked: bool) -> void:
	_action_lock = locked


func _unhandled_input(ev: InputEvent) -> void:
	if _action_lock or _state.battle_over or not _state.is_player_turn:
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

	var world_pos := get_global_mouse_position()
	var cell := _view.local_to_map(world_pos)

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
		own = _unit_at_pixel(world_pos, "attacker")
	if own != null and not own.has_moved:
		_select(own)
		get_viewport().set_input_as_handled()
		return


func _unit_at_pixel(pos: Vector2, side: String) -> BattleState.BattleUnit:
	var units := _state.get_units_by_side(side)
	for u in units:
		if u.is_alive():
			var up := _view.map_to_local(u.cell)
			if pos.distance_to(up) < 60.0:
				return u
	return null


func _select(u: BattleState.BattleUnit) -> void:
	_state.active_unit = u
	_clear_highlights()

	var speed := u.get_speed()
	var blocked := _state.build_all_blocked(u, _obstacles)
	highlight_move = _state.get_reachable(u.cell, speed, blocked)

	for nb in HexUtils.get_all_neighbors(u.cell):
		var en := _state.get_unit_at(nb, "defender")
		if en != null:
			highlight_attack[nb] = 1

	_view.set_highlights(highlight_move, highlight_attack)
	unit_selected.emit(u)
	print("[Battle] selected ", u.get_display_name(), " moves=", highlight_move.size())


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
	for nb in HexUtils.get_all_neighbors(_state.active_unit.cell):
		var en := _state.get_unit_at(nb, "defender")
		if en != null:
			highlight_attack[nb] = 1
	_view.set_highlights({}, highlight_attack)
