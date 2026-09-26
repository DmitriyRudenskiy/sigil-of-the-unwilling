extends Node
class_name BattleInput

signal unit_pick_requested(unit: BattleState.BattleUnit)
signal unit_selected(unit: BattleState.BattleUnit)
signal unit_move_requested(unit: BattleState.BattleUnit, target: Vector2i)
signal unit_attack_requested(unit: BattleState.BattleUnit, target: BattleState.BattleUnit)
signal spell_cast_requested(spell_id: StringName, target: BattleState.BattleUnit)
signal cancel_requested
signal attack_preview_updated(text: String)

var _view: BattleView
var _state: BattleState
var _obstacles: Dictionary = {}
var _action_lock: bool = false

var _pending_spell_id: StringName = ""
var _pending_target_side: BattleState.Side = BattleState.Side.DEFENDER
var _include_dead: bool = false

var highlight_move: Dictionary = {}
var highlight_attack: Dictionary = {}
var highlight_unreachable: Dictionary = {}

var _cursor_mode := BattleView.CursorMode.DEFAULT

func set_cursor_mode(mode: int) -> void:
	_cursor_mode = mode as BattleView.CursorMode
	if _view != null:
		_view.set_cursor_mode(mode)

func setup(view: BattleView, state: BattleState, obstacles: Dictionary) -> void:
	_view = view
	_state = state
	_obstacles = obstacles

func set_action_lock(locked: bool) -> void:
	_action_lock = locked

func start_spell_targeting(spell_id: StringName, target_side: BattleState.Side, include_dead: bool = false) -> void:

	_clear_highlights()
	_pending_spell_id = spell_id
	_pending_target_side = target_side
	_include_dead = include_dead
	_cursor_mode = BattleView.CursorMode.SPELL
	if _view != null:
		_view.set_cursor_mode(_cursor_mode)
	for u in _state.get_units_by_side(target_side):
		if u.is_alive() or (include_dead and u.stack != null):
			highlight_attack[u.cell] = 1
	_view.set_highlights({}, highlight_attack)
	GameLogger.battle("Spell targeting started: %s" % spell_id)

func _unhandled_input(ev: InputEvent) -> void:
	if _action_lock or _state == null or _state.battle_over or not _state.is_player_turn:
		return

	if _pending_spell_id != "":
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_RIGHT:
				_pending_spell_id = ""
				_clear_highlights()
				cancel_requested.emit()
				get_viewport().set_input_as_handled()
				return

			if ev.button_index == MOUSE_BUTTON_LEFT:
				var sp_pos := _view.get_global_mouse_position()
				var sp_cell := _view.global_to_map(sp_pos)
				if highlight_attack.has(sp_cell):
					var target := _state.get_unit_at(sp_cell, _pending_target_side)
					if _include_dead and target == null:
						for u in _state.get_units_by_side(_pending_target_side):
							if u.cell == sp_cell and not u.is_alive():
								target = u
								break
					if target != null:
						spell_cast_requested.emit(_pending_spell_id, target)
						_pending_spell_id = ""
						_clear_highlights()
						get_viewport().set_input_as_handled()
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
		var target := _state.get_unit_at(cell, BattleState.Side.DEFENDER)
		unit_attack_requested.emit(_state.active_unit, target)
		get_viewport().set_input_as_handled()
		return

	if highlight_move.has(cell):
		unit_move_requested.emit(_state.active_unit, cell)
		get_viewport().set_input_as_handled()
		return

	var own := _state.get_unit_at(cell, BattleState.Side.ATTACKER)
	if own == null:
		own = _unit_at_pixel(global_pos, BattleState.Side.ATTACKER)

	if own != null and not own.has_moved:
		_select(own)
		get_viewport().set_input_as_handled()
		return

func _unit_at_pixel(global_pos: Vector2, side: BattleState.Side) -> BattleState.BattleUnit:
	var cell := _view.global_to_map(global_pos)
	var unit := _state.get_unit_at(cell, side)
	if unit != null:
		return unit
	var local_pos := _view.to_local(global_pos)
	for nb in HexUtils.get_all_neighbors(cell, _state.hex_shift_right):
		unit = _state.get_unit_at(nb, side)
		if unit != null:
			var unit_pos := _view.map_to_local(nb)
			if local_pos.distance_to(unit_pos) < GameNumbers.BATTLE_CLICK_RADIUS_PX:
				return unit
	return null

func _select(u: BattleState.BattleUnit) -> void:
	unit_pick_requested.emit(u)
	_clear_highlights()

	var blocked_dict := _state.build_all_blocked(u, _obstacles)
	var blocked_callable := func() -> Dictionary: return blocked_dict

	highlight_move = _state.get_reachable_for_unit(u, blocked_callable)
	highlight_attack = _compute_attack_highlight(u)
	highlight_unreachable = _state.get_unreachable_ring(u, blocked_callable)

	_view.set_highlights(highlight_move, highlight_attack)
	_view.set_unreachable_highlights(highlight_unreachable)
	_cursor_mode = BattleView.CursorMode.MOVE
	_view.set_cursor_mode(_cursor_mode)
	unit_selected.emit(u)
	_update_attack_preview()

	GameLogger.battle("selected %s moves=%d" % [u.get_display_name(), highlight_move.size()])

func _update_attack_preview() -> void:
	if _state.active_unit == null:
		attack_preview_updated.emit("")
		return

	var global_pos := _view.get_global_mouse_position()
	var cell := _view.global_to_map(global_pos)

	if highlight_attack.has(cell):
		var target := _state.get_unit_at(cell, BattleState.Side.DEFENDER)

		if target != null:
			var atk_bon: int = int(_state.attacker_hero_bonus.get(&"attack", 0))
			var def_bon: int = int(_state.defender_hero_bonus.get(&"defense", 0))
			var preview := BattleRules.preview_text(
				_state.active_unit,
				target,
				atk_bon,
				def_bon
			)
			attack_preview_updated.emit(preview)
			return

	attack_preview_updated.emit("")

func clear_highlights() -> void:
	_clear_highlights()

func set_unreachable_highlights(cells: Dictionary) -> void:
	highlight_unreachable = cells
	if _view != null:
		_view.set_unreachable_highlights(cells)

func _clear_highlights() -> void:
	_pending_spell_id = ""
	highlight_move.clear()
	highlight_attack.clear()
	highlight_unreachable.clear()
	if _view != null:
		_view.clear_highlights()

func show_attack_only() -> void:
	if _state.active_unit == null or not _state.is_player_turn:
		return
	_clear_highlights()

	var u := _state.active_unit
	highlight_attack = _compute_attack_highlight(u)

	if u.is_ranged():
		_cursor_mode = BattleView.CursorMode.RANGED
	else:
		_cursor_mode = BattleView.CursorMode.ATTACK
	if _view != null:
		_view.set_cursor_mode(_cursor_mode)

	_view.set_highlights({}, highlight_attack)

func _compute_attack_highlight(u: BattleState.BattleUnit) -> Dictionary:
	var result: Dictionary = {}
	var adjacent_enemies: Array[Vector2i] = []

	for nb in HexUtils.get_all_neighbors(u.cell, _state.hex_shift_right):
		var enemy := _state.get_unit_at(nb, BattleState.Side.DEFENDER)
		if enemy != null and enemy.is_alive():
			adjacent_enemies.append(nb)

	if u.is_ranged() and adjacent_enemies.is_empty():
		for enemy in _state.get_units_by_side(BattleState.Side.DEFENDER):
			if enemy.is_alive():
				result[enemy.cell] = 1
	else:
		for cell in adjacent_enemies:
			result[cell] = 1

	return result
