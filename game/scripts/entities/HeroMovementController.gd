extends Node
class_name HeroMovementController

signal hero_moved(cell: Vector2i)
signal movement_finished(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal path_previewed(text: String)
signal hero_entered_village(cell: Vector2i)
signal step_taken(cost: float)
signal reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float)
signal reach_preview_cleared
signal planned_route_changed(committed: bool)

signal facing_changed(delta: Vector2i)
signal move_requested(target: Vector2, duration: float, callback: Callable)
signal request_hide_path_visual
signal request_show_marker(pos: Vector2)
signal request_idle_animation
signal request_kill_tween
signal request_time_update(step_cost: float)
signal request_resource_pickup(res_type: int)
signal request_set_position(pos: Vector2)

const _HexUtils = preload("res://scripts/core/HexUtils.gd")
const _HexPathfinding = preload("res://scripts/core/HexPathfinding.gd")
const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")

@export var max_move_points: float = 10.0

var current_cell: Vector2i = Vector2i(5, 5)
var previous_cell: Vector2i = Vector2i(-1, -1)
var move_points: float = 10.0
var path: Array[Vector2i] = []
var pending_cell: Vector2i = Vector2i(-1, -1)
var pending_path: Array[Vector2i] = []
var is_moving: bool = false

var planned_path: Array[Vector2i] = []

var _map_gen: MapGenerator

func get_map_gen() -> MapGenerator:
	return _map_gen

func setup(map: MapGenerator) -> void:
	_map_gen = map
	_place_hero_on_map()
	move_points = get_daily_movement_points()

func _place_hero_on_map() -> void:
	for y in _map_gen.map_height:
		for x in _map_gen.map_width:
			var cell := Vector2i(x, y)
			if _map_gen.is_walkable(cell):
				current_cell = cell
				previous_cell = cell
				_emit_position_update()
				return

func _terrain_cost(cell: Vector2i, levitation: bool = false) -> float:
	if cell.x < 0 or cell.x >= _map_gen.map_width or cell.y < 0 or cell.y >= _map_gen.map_height:
		return INF

	var vis_fog := _map_gen.visibility
	if vis_fog != null and not vis_fog.is_explored(cell):
		return INF

	if not _map_gen.is_walkable_with_effects(cell, levitation):
		return INF

	var terrain_id := _map_gen.get_terrain_id(cell)
	return _TerrainCostTable.get_cost_with_effects_by_id(terrain_id, levitation)

func on_map_clicked(cell: Vector2i) -> void:
	if is_moving or _map_gen == null or not _map_gen.has_valid_tilemap():
		return
	if cell == current_cell:
		cancel_pending()
		return

	if cell == pending_cell and pending_path.size() > 1:
		if planned_path.is_empty():
			var full: Array[Vector2i] = _full_path(cell)
			if full.size() >= 2:
				planned_path = full
				planned_route_changed.emit(true)
			return
		else:
			path = planned_path.duplicate()
			pending_cell = Vector2i(-1, -1)
			pending_path = []
			path_previewed.emit("")
			request_hide_path_visual.emit()
			_start_moving()
			return

	if move_points <= 0:
		if _is_contact_position(cell):
			hero_moved.emit(current_cell)
			path_previewed.emit("⚔️ Контакт с врагом — начинается бой")
			return
		path_previewed.emit("Нет очков движения — нажмите ⏳")
		return

	var affordable = _get_affordable_path(cell)
	if affordable.size() < 2:
		if _is_contact_position(cell):
			hero_moved.emit(current_cell)
			path_previewed.emit("⚔️ Контакт с врагом — начинается бой")
			return
		cancel_pending()
		path_previewed.emit("Путь недоступен")
		return

	pending_cell = cell
	pending_path = affordable

	var levitation := _has_artifact_effect(&"boots_levitation")
	var cost_fn := func(c: Vector2i) -> float: return _terrain_cost(c, levitation)
	var dist_arr := _HexPathfinding.dijkstra(current_cell, move_points, cost_fn, _map_gen.map_width, _map_gen.map_height)
	var dist: Dictionary = {}
	for i in dist_arr.size():
		if dist_arr[i] < INF:
			dist[_HexUtils.idx_to_pos(i, _map_gen.map_width)] = dist_arr[i]
	reach_preview_changed.emit(affordable, dist, move_points)

	if _map_gen.has_valid_tilemap():
		request_show_marker.emit(_map_gen.map_to_local(cell))

	var cost := 0.0
	for i in range(1, affordable.size()):
		cost += _terrain_cost(affordable[i], levitation)

	var remaining := move_points - cost
	var suffix := ""

	path_previewed.emit("Путь: %d кл., стоимость: %.1f, останется: %.1f. Клик ещё раз — идти. ПКМ — отмена." % [
		affordable.size() - 1, cost, remaining])

func move_to_cell(cell: Vector2i) -> bool:
	if is_moving or _map_gen == null:
		return false
	if cell == current_cell:
		return true

	var affordable := _get_affordable_path(cell)
	if affordable.size() < 2:
		if _is_contact_position(cell):
			hero_moved.emit(current_cell)
			return true
		return false

	path = affordable
	_start_moving()
	return true

func can_reach(cell: Vector2i) -> bool:
	if cell == current_cell:
		return true
	var goal := _resolve_enemy_goal(cell)
	if goal == Vector2i(-1, -1):
		return false
	if goal == current_cell:
		return true
	var affordable := _get_affordable_path(cell)
	return affordable.size() >= 2 and affordable.back() == goal

func reach_problem(cell: Vector2i) -> String:
	if cell == current_cell:
		return ""
	var goal := _resolve_enemy_goal(cell)
	if goal == Vector2i(-1, -1):
		return "unreachable"
	if goal == current_cell:
		return ""
	if _full_path_to(goal).size() < 2:
		return "unreachable"
	return "" if can_reach(cell) else "insufficient_mp"

func _full_path(cell: Vector2i) -> Array[Vector2i]:
	if _map_gen == null:
		return []
	var goal := _resolve_enemy_goal(cell)
	if goal == Vector2i(-1, -1):
		return []
	if goal == current_cell:
		return [goal]
	var base := _base_blocked() if _map_gen.enemy_stacks.has(cell) else {}
	return _full_path_to(goal, base)

func _enemy_aura_blocked(exempt: Vector2i) -> Dictionary:
	var blocked: Dictionary = {}
	var stacks := _map_gen.enemy_stacks
	for c in stacks:
		blocked[c] = true
		for nb in _HexUtils.get_all_neighbors(c):
			if nb != exempt:
				blocked[nb] = true
	return blocked

func _contacts_only_with(cell: Vector2i, enemy_cell: Vector2i) -> bool:
	var stacks := _map_gen.enemy_stacks
	for nb in _HexUtils.get_all_neighbors(cell):
		if nb != enemy_cell and stacks.has(nb):
			return false
	return true

func _base_blocked() -> Dictionary:
	var blocked: Dictionary = _map_gen.get_blocked_cells().duplicate()
	var levitation := _has_artifact_effect(&"boots_levitation")
	if levitation:
		for c in blocked.keys():
			var terrain_id: int = _map_gen.get_terrain_id(c)
			if terrain_id == _HexUtils.Terrain.WATER:
				blocked.erase(c)
	var vis := _map_gen.visibility
	if vis != null:
		for cell in _map_gen.terrain_grid:
			if not vis.is_explored(cell):
				blocked[cell] = true
	return blocked

func _full_path_to(goal: Vector2i, base: Dictionary = {}) -> Array[Vector2i]:
	var blocked: Dictionary = base.duplicate() if not base.is_empty() else _base_blocked()
	blocked.merge(_enemy_aura_blocked(goal))
	return _HexPathfinding.find_path(current_cell, goal, blocked, _map_gen.map_width, _map_gen.map_height, "astar")

func _resolve_enemy_goal(goal: Vector2i) -> Vector2i:
	var stacks := _map_gen.enemy_stacks
	if not stacks.has(goal):
		return goal
	var levitation := _has_artifact_effect(&"boots_levitation")
	var base := _base_blocked()
	var best := Vector2i(-1, -1)
	var best_cost := INF
	for nb in _HexUtils.get_all_neighbors(goal):
		if not _map_gen.is_walkable_with_effects(nb, levitation) or stacks.has(nb):
			continue
		if not _contacts_only_with(nb, goal):
			continue
		var c: float
		if nb == current_cell:
			c = 0.0
		else:
			var p := _full_path_to(nb, base)
			if p.size() < 2:
				continue
			c = _path_cost(p, levitation)
		if c < best_cost:
			best_cost = c
			best = nb
	return best

func _path_cost(path: Array[Vector2i], levitation: bool = false) -> float:
	var c := 0.0
	for i in range(1, path.size()):
		c += _terrain_cost(path[i], levitation)
	return c

func _is_contact_position(cell: Vector2i) -> bool:
	if _map_gen == null:
		return false
	var stacks := _map_gen.enemy_stacks
	if not stacks.has(cell):
		return false
	for nb in _HexUtils.get_all_neighbors(current_cell):
		if nb == cell:
			return true
	return false

func teleport(cell: Vector2i) -> void:
	if _map_gen == null or not _map_gen.is_walkable(cell):
		return
	_set_moving(false)
	path.clear()
	current_cell = cell
	previous_cell = cell
	_emit_position_update()
	hero_moved.emit(cell)

func _get_affordable_path(cell: Vector2i) -> Array[Vector2i]:
	var found := _full_path(cell)
	if found.size() < 2:
		return []

	var cumulative: float = 0.0
	var affordable: Array[Vector2i] = [found[0]]
	var levitation := _has_artifact_effect(&"boots_levitation")
	for i in range(1, found.size()):
		var step_cost := _terrain_cost(found[i], levitation)
		if cumulative + step_cost > move_points + 0.001:
			break
		cumulative += step_cost
		affordable.append(found[i])
	return affordable

func cancel_pending(clear_text: bool = true) -> void:
	pending_cell = Vector2i(-1, -1)
	pending_path = []
	reach_preview_cleared.emit()
	if clear_text:
		path_previewed.emit("")

func cancel_planned_path() -> void:
	if planned_path.is_empty():
		return
	planned_path.clear()
	planned_route_changed.emit(false)

func _set_moving(moving: bool) -> void:
	is_moving = moving
	GameEventBus.hero_moving_changed.emit(moving)

func _start_moving() -> void:
	if path.size() < 2:
		return
	GameLogger.trace("🚀 Starting movement. Path size: %d" % path.size(), "Movement")
	_set_moving(true)
	_move_next_step()

func _move_next_step() -> void:
	if path.size() < 2:
		GameLogger.trace("🏁 Path exhausted. Stopping.", "Movement")
		_set_moving(false)
		if not planned_path.is_empty():
			planned_path.clear()
			planned_route_changed.emit(false)
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		movement_finished.emit(current_cell)
		return

	var next_cell := path[1]
	GameLogger.trace("➡️ Moving to %s. Remaining path: %d" % [str(next_cell), path.size()], "Movement")
	path.remove_at(0)

	var levitation := _has_artifact_effect(&"boots_levitation")
	var step_cost: float = _terrain_cost(next_cell, levitation)
	if step_cost >= INF:
		GameLogger.trace("⛔ Path blocked at %s — stopping" % str(next_cell), "Movement")
		_set_moving(false)
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		movement_finished.emit(current_cell)
		return
	move_points -= step_cost
	movement_points_changed.emit(move_points, get_daily_movement_points())

	step_taken.emit(step_cost)
	SoundManager.play_sfx_cue(&"hero_step")

	var delta := next_cell - current_cell
	facing_changed.emit(delta)
	request_time_update.emit(step_cost)

	var target_pos: Vector2
	if _map_gen and _map_gen.has_valid_tilemap():
		target_pos = _map_gen.map_to_local(next_cell)
	else:
		target_pos = Vector2(next_cell.x * 64 + 32, next_cell.y * 56 + 28)

	move_requested.emit(target_pos, 0.35, _on_step_complete.bind(next_cell))

func _on_step_complete(cell: Vector2i) -> void:
	GameLogger.trace("✅ Step complete: %s" % str(cell), "Movement")
	previous_cell = current_cell
	current_cell = cell
	_emit_position_update()
	hero_moved.emit(cell)

	if _map_gen and _map_gen.resource_cells.has(cell):
		var res_type: int = _map_gen.resource_cells[cell]
		request_resource_pickup.emit(res_type)
		_map_gen.resource_cells.erase(cell)

	if _map_gen and cell in _map_gen.village_cells:
		hero_entered_village.emit(cell)

	if move_points <= 0:
		_set_moving(false)
		if not planned_path.is_empty():
			planned_path = path.duplicate()
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		movement_finished.emit(current_cell)
		return

	_move_next_step()

func end_turn_movement() -> void:
	_set_moving(false)
	if not planned_path.is_empty():
		return
	path.clear()
	cancel_pending()

func auto_follow_at_turn_start() -> void:
	if planned_path.size() < 2:
		return
	var goal: Vector2i = planned_path.back()
	if current_cell == goal:
		planned_path.clear()
		planned_route_changed.emit(false)
		return
	if _full_path(goal).size() < 2:
		return
	path = planned_path.duplicate()
	_start_moving()

func force_stop() -> void:
	var was_moving := is_moving
	_set_moving(false)
	path.clear()
	request_kill_tween.emit()
	reach_preview_cleared.emit()
	request_idle_animation.emit()
	if was_moving:
		movement_finished.emit(current_cell)

func _emit_position_update() -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		request_set_position.emit(_map_gen.map_to_local(current_cell))
	else:
		request_set_position.emit(Vector2(current_cell.x * 64 + 32, current_cell.y * 56 + 28))

func _has_artifact_effect(effect: StringName) -> bool:
	return _artifact_effect_fn.call(effect) if _artifact_effect_fn.is_valid() else false

var _artifact_effect_fn: Callable

func set_artifact_effect_fn(fn: Callable) -> void:
	_artifact_effect_fn = fn

func get_daily_movement_points(movement_mod: int = 0) -> float:
	return max_move_points + float(movement_mod)
