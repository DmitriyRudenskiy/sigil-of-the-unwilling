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
var _parent: HeroController


func get_map_gen() -> MapGenerator:
	return _map_gen


func setup(map: MapGenerator, hero: HeroController) -> void:
	_map_gen = map
	_parent = hero
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
	if not _map_gen.is_walkable(cell):
		return INF
	var terrain: String = _map_gen.get_terrain_name(cell)
	var levitation: bool = _parent.has_artifact_effect(&"boots_levitation")
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
		_parent._hide_path_visual()
		_start_moving()
		return

	if move_points <= 0:
		path_previewed.emit("Нет очков движения — нажмите ⏳")
		return

	var cost_fn := func(c: Vector2i) -> float: return _terrain_cost(c)
	var dist := _HexUtils.dijkstra(current_cell, move_points, cost_fn)

	if not dist.has(cell):
		# Cell not reachable — check if it's adjacent to a reachable cell (red frontier candidate)
		cancel_pending()
		path_previewed.emit("Путь недоступен")
		return

	var found := _HexUtils.dijkstra_path(current_cell, cell, dist, cost_fn)
	if found.size() < 2:
		cancel_pending()
		path_previewed.emit("Путь недоступен")
		return

	# Trim to affordable prefix: walk path until cumulative cost exceeds MP
	var cumulative: float = 0.0
	var affordable: Array[Vector2i] = [found[0]]
	for i in range(1, found.size()):
		cumulative += _terrain_cost(found[i])
		if cumulative > move_points + 0.001:
			break
		affordable.append(found[i])

	pending_cell = cell
	pending_path = affordable
	reach_preview_changed.emit(affordable, dist, move_points)

	# Marker at clicked cell
	if _map_gen.has_valid_tilemap():
		_parent._show_marker(_map_gen.map_to_local(cell))

	var cost := cumulative
	var remaining := move_points - cost
	var suffix := ""
	if affordable.size() < found.size():
		suffix = " (очков хватит на %d кл.)" % (affordable.size() - 1)
	path_previewed.emit("Путь: %d кл., стоимость: %.1f, останется: %.1f%s. Клик ещё раз — идти. ПКМ — отмена." % [
		affordable.size() - 1, cost, remaining, suffix])


func cancel_pending(clear_text: bool = true) -> void:
	pending_cell = Vector2i(-1, -1)
	pending_path = []
	reach_preview_cleared.emit()
	if clear_text:
		path_previewed.emit("")


func _start_moving() -> void:
	if path.size() < 2:
		return
	is_moving = true
	_move_next_step()


func _move_next_step() -> void:
	if path.size() < 2:
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		_parent._idle_animation()
		return

	var next_cell := path[1]
	path.remove_at(0)

	var step_cost: float = _terrain_cost(next_cell)
	move_points -= step_cost
	movement_points_changed.emit(move_points, get_daily_movement_points())

	# Update time system
	if _parent and _parent.has_method("_on_time_update"):
		_parent._on_time_update(step_cost)
	step_taken.emit(step_cost)

	var delta := next_cell - current_cell
	_parent._set_facing(delta)

	var target_pos: Vector2
	if _map_gen and _map_gen.has_valid_tilemap():
		target_pos = _map_gen.map_to_local(next_cell)
	else:
		target_pos = Vector2(next_cell.x * 64 + 32, next_cell.y * 56 + 28)

	_parent._tween_to(target_pos, 0.35, _on_step_complete.bind(next_cell))


func _on_step_complete(cell: Vector2i) -> void:
	current_cell = cell
	_emit_position_update()
	hero_moved.emit(cell)

	# Pickup resource if present
	if _map_gen and _map_gen.resource_cells.has(cell):
		var res_type: int = _map_gen.resource_cells[cell]
		_parent._on_resource_pickup(res_type)
		_map_gen.resource_cells.erase(cell)

	# Check village entry
	if _map_gen and cell in _map_gen.village_cells:
		hero_entered_village.emit(cell)

	if move_points <= 0:
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		_parent._idle_animation()
		return

	_move_next_step()


func end_turn_movement() -> void:
	is_moving = false
	path.clear()
	cancel_pending()


func force_stop() -> void:
	is_moving = false
	path.clear()
	_parent._kill_tween()
	reach_preview_cleared.emit()
	_parent._idle_animation()


func _emit_position_update() -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		_parent.position = _map_gen.map_to_local(current_cell)
	else:
		_parent.position = Vector2(current_cell.x * 64 + 32, current_cell.y * 56 + 28)


func get_daily_movement_points() -> float:
	var mods := _parent.inventory.get_total_modifiers()
	return max_move_points + float(mods.get("movement", 0))
