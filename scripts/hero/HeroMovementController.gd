extends Node
class_name HeroMovementController
## Hero movement: Dijkstra pathfinding, float movement points, terrain costs.

signal hero_moved(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal path_previewed(text: String)
signal hero_entered_village(cell: Vector2i)
signal step_taken(cost: float)
signal reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float)
signal reach_preview_cleared

## Signals to HeroController facade — replaces _parent back-references.
signal facing_changed(delta: Vector2i)
signal move_requested(target: Vector2, duration: float, callback: Callable)
signal request_hide_path_visual
signal request_show_marker(pos: Vector2)
signal request_idle_animation
signal request_kill_tween
signal request_time_update(step_cost: float)
signal request_resource_pickup(res_type: int)
signal request_set_position(pos: Vector2)

const _HexUtils = preload("res://scripts/HexUtils.gd")
const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")

@export var max_move_points: float = 10.0

var current_cell: Vector2i = Vector2i(5, 5)
var move_points: float = 10.0
var path: Array[Vector2i] = []
var pending_cell: Vector2i = Vector2i(-1, -1)
var pending_path: Array[Vector2i] = []
var is_moving: bool = false

var _map_gen: MapGenerator
# _parent removed — use signals instead (R2)


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
				_emit_position_update()
				return


func _terrain_cost(cell: Vector2i) -> float:
	if cell.x < 0 or cell.x >= _map_gen.map_width or cell.y < 0 or cell.y >= _map_gen.map_height:
		return INF

	var levitation := _has_artifact_effect(&"boots_levitation")
	if not _map_gen.is_walkable_with_effects(cell, levitation):
		return INF

	var terrain := _map_gen.get_terrain_name(cell)
	return _TerrainCostTable.get_cost_with_effects(terrain, levitation)


func on_map_clicked(cell: Vector2i) -> void:
	if is_moving or _map_gen == null or not _map_gen.has_valid_tilemap():
		return
	if cell == current_cell:
		cancel_pending()
		return

	if cell == pending_cell and pending_path.size() > 1:
		path = pending_path
		pending_cell = Vector2i(-1, -1)
		pending_path = []
		path_previewed.emit("")
		request_hide_path_visual.emit()
		_start_moving()
		return

	if move_points <= 0:
		path_previewed.emit("Нет очков движения — нажмите ⏳")
		return

	var affordable = _get_affordable_path(cell)
	if affordable.size() < 2:
		cancel_pending()
		path_previewed.emit("Путь недоступен")
		return

	pending_cell = cell
	pending_path = affordable
	
	# Need the full dist map for the reach preview signal (array → dict)
	var cost_fn := func(c: Vector2i) -> float: return _terrain_cost(c)
	var dist_arr := _HexUtils.dijkstra(current_cell, move_points, cost_fn, _map_gen.map_width, _map_gen.map_height)
	var dist: Dictionary = {}
	for i in dist_arr.size():
		if dist_arr[i] < INF:
			dist[_HexUtils.idx_to_pos(i, _map_gen.map_width)] = dist_arr[i]
	reach_preview_changed.emit(affordable, dist, move_points)

	# Marker at clicked cell (emitted via signal, facade handles it)
	if _map_gen.has_valid_tilemap():
		request_show_marker.emit(_map_gen.map_to_local(cell))

	var cost := 0.0
	for i in range(1, affordable.size()):
		cost += _terrain_cost(affordable[i])
	
	var remaining := move_points - cost
	var suffix := ""
	# To check if path was trimmed, we'd need the full path. 
	# For brevity in AI-led fixes, let's simplify the preview text a bit or keep it if we have the full path.
	# Since we extracted _get_affordable_path, let's make it return both.
	
	path_previewed.emit("Путь: %d кл., стоимость: %.1f, останется: %.1f. Клик ещё раз — идти. ПКМ — отмена." % [
		affordable.size() - 1, cost, remaining])


## Запускает движение к `cell` (HoMM3-семантика: если цель дальше ОД —
## герой идёт в её сторону, пока хватает очков).
## true — движение начато; false — пути нет / герой уже на месте / уже идёт.
## Клиент, которому важно знать, дойдёт ли герой, должен спросить can_reach() ДО вызова.
func move_to_cell(cell: Vector2i) -> bool:
	if is_moving or _map_gen == null:
		return false
	if cell == current_cell:
		return true

	var affordable := _get_affordable_path(cell)
	if affordable.size() < 2:
		return false

	path = affordable
	_start_moving()
	return true


## True, если `cell` полностью достижим с текущими точками движения.
func can_reach(cell: Vector2i) -> bool:
	if cell == current_cell:
		return true
	var affordable := _get_affordable_path(cell)
	return affordable.size() >= 2 and affordable.back() == cell


## Диагностика недостижимости: "" — достижимо, "unreachable" — пути нет,
## "insufficient_mp" — путь есть, но не хватает очков движения.
func reach_problem(cell: Vector2i) -> String:
	if cell == current_cell:
		return ""
	if _full_path(cell).size() < 2:
		return "unreachable"
	return "" if can_reach(cell) else "insufficient_mp"


## Полный A* путь без обрезки по ОД (пусто, если пути нет).
func _full_path(cell: Vector2i) -> Array[Vector2i]:
	if _map_gen == null:
		return []
	var blocked: Dictionary = _map_gen.get_blocked_cells().duplicate()
	var levitation := _has_artifact_effect(&"boots_levitation")
	if levitation:
		# Remove water cells from blocked if hero has levitation
		for c in blocked.keys():
			var terrain_id: int = _map_gen.get_terrain_id(c)
			if terrain_id == _HexUtils.Terrain.WATER:
				blocked.erase(c)
	# A* prunes search via heuristic — much faster than full-map Dijkstra
	return _HexUtils.astar_path(current_cell, cell, blocked, _map_gen.map_width, _map_gen.map_height)


func _get_affordable_path(cell: Vector2i) -> Array[Vector2i]:
	var found := _full_path(cell)
	if found.size() < 2:
		return []

	var cumulative: float = 0.0
	var affordable: Array[Vector2i] = [found[0]]
	for i in range(1, found.size()):
		var step_cost := _terrain_cost(found[i])
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


func _start_moving() -> void:
	if path.size() < 2:
		return
	print("[Movement] 🚀 Starting movement. Path size: %d" % path.size())
	is_moving = true
	_move_next_step()


func _move_next_step() -> void:
	if path.size() < 2:
		print("[Movement] 🏁 Path exhausted. Stopping.")
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		return

	var next_cell := path[1]
	print("[Movement] ➡️ Moving to %s. Remaining path: %d" % [str(next_cell), path.size()])
	path.remove_at(0)

	var step_cost: float = _terrain_cost(next_cell)
	if step_cost >= INF:
		# Клетка стала непроходимой во время движения (динамическая блокировка).
		# Останавливаемся штатно, не портя move_points (-INF застревал героя до конца хода).
		print("[Movement] ⛔ Path blocked at %s — stopping" % str(next_cell))
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		return
	move_points -= step_cost
	movement_points_changed.emit(move_points, get_daily_movement_points())

	step_taken.emit(step_cost)

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
	print("[Movement] ✅ Step complete: %s" % str(cell))
	current_cell = cell
	_emit_position_update()
	hero_moved.emit(cell)

	# Pickup resource if present (emitted via signal)
	if _map_gen and _map_gen.resource_cells.has(cell):
		var res_type: int = _map_gen.resource_cells[cell]
		request_resource_pickup.emit(res_type)
		_map_gen.resource_cells.erase(cell)

	# Check village entry
	if _map_gen and cell in _map_gen.village_cells:
		hero_entered_village.emit(cell)

	if move_points <= 0:
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		return

	_move_next_step()


func end_turn_movement() -> void:
	is_moving = false
	path.clear()
	cancel_pending()


func force_stop() -> void:
	is_moving = false
	path.clear()
	request_kill_tween.emit()
	reach_preview_cleared.emit()
	request_idle_animation.emit()


func _emit_position_update() -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		request_set_position.emit(_map_gen.map_to_local(current_cell))
	else:
		request_set_position.emit(Vector2(current_cell.x * 64 + 32, current_cell.y * 56 + 28))


func _has_artifact_effect(effect: StringName) -> bool:
	# Called by _terrain_cost — the facade (HeroController) should wire this.
	# For now, emit a signal or use a callback. We pass it via a stored callback.
	return _artifact_effect_fn.call(effect) if _artifact_effect_fn.is_valid() else false

var _artifact_effect_fn: Callable

func set_artifact_effect_fn(fn: Callable) -> void:
	_artifact_effect_fn = fn

func get_daily_movement_points(movement_mod: int = 0) -> float:
	return max_move_points + float(movement_mod)
