extends RefCounted
class_name VisibilityMap

var visible: Dictionary = {}
var explored: Dictionary = {}

var _map_width: int = 0
var _map_height: int = 0
# TASK_19 2.3: кэш видимости городов — пересчитывается только при смене
# источников/радиуса; перемещение героя на 1 клетку не трогает этот кэш.
var _city_visible: Dictionary = {}
var _cached_sources: Array = []
var _cached_city_sight: int = -1
var _cached_shift_right: bool = true

func set_map_size(width: int, height: int) -> void:
	_map_width = width
	_map_height = height

func recompute(hero_cell: Vector2i, sight_sources: Array, hero_sight: int, city_sight: int, shift_right: bool = true) -> bool:
	if city_sight != _cached_city_sight or shift_right != _cached_shift_right \
			or not _same_sources(sight_sources, _cached_sources):
		_city_visible = {}
		_cached_sources = sight_sources.duplicate()
		_cached_city_sight = city_sight
		_cached_shift_right = shift_right
		for src in _cached_sources:
			if src is Vector2i and is_in_bounds(src):
				_fill_disk(src, city_sight, _city_visible, shift_right)
				_explore(src, city_sight, shift_right)
	var new_visible: Dictionary = _city_visible.duplicate()
	if hero_cell is Vector2i and is_in_bounds(hero_cell):
		_fill_disk(hero_cell, hero_sight, new_visible, shift_right)
		_explore(hero_cell, hero_sight, shift_right)
	var changed := visible.size() != new_visible.size()
	if not changed:
		for cell in new_visible:
			if not visible.has(cell):
				changed = true
				break
	visible = new_visible
	return changed

func _fill_disk(center: Vector2i, radius: int, out: Dictionary, shift_right: bool = true) -> void:
	if radius < 0:
		return
	if is_in_bounds(center):
		out[center] = 1
	for r in range(1, radius + 1):
		for cell in HexUtils.ring(center, r, shift_right):
			if is_in_bounds(cell):
				out[cell] = 1

func _explore(center: Vector2i, radius: int, shift_right: bool = true) -> void:
	if radius < 0:
		return
	if is_in_bounds(center):
		explored[center] = 1
	for r in range(1, radius + 1):
		for cell in HexUtils.ring(center, r, shift_right):
			if is_in_bounds(cell):
				explored[cell] = 1

func _same_sources(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _map_width and cell.y >= 0 and cell.y < _map_height

func is_visible(cell: Vector2i) -> bool:
	return visible.has(cell)

func is_explored(cell: Vector2i) -> bool:
	return explored.has(cell)

func serialize_explored() -> Array:
	var arr: Array = []
	for cell in explored:
		arr.append(SerializationUtils.vec2i_to_dict(cell))
	return arr

func load_explored(arr: Array) -> void:
	for item in arr:
		var cell := SerializationUtils.vec2i_from_dict(item)
		if is_in_bounds(cell):
			explored[cell] = 1
