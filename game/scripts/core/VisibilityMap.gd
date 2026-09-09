extends RefCounted
class_name VisibilityMap

var visible: Dictionary = {}
var explored: Dictionary = {}

var _map_width: int = 0
var _map_height: int = 0

func set_map_size(width: int, height: int) -> void:
	_map_width = width
	_map_height = height

func recompute(hero_cell: Vector2i, sight_sources: Array, hero_sight: int, city_sight: int) -> bool:
	var new_visible: Dictionary = {}
	if hero_cell is Vector2i and is_in_bounds(hero_cell):
		_fill_disk(hero_cell, hero_sight, new_visible)
		_explore(hero_cell, hero_sight)
	for src in sight_sources:
		if src is Vector2i and is_in_bounds(src) and src != hero_cell:
			_fill_disk(src, city_sight, new_visible)
			_explore(src, city_sight)
	var changed := visible.size() != new_visible.size()
	if not changed:
		for c in new_visible:
			if not visible.has(c):
				changed = true
				break
	visible = new_visible
	return changed

func _fill_disk(center: Vector2i, radius: int, out: Dictionary) -> void:
	if radius < 0:
		return
	if is_in_bounds(center):
		out[center] = 1
	for r in range(1, radius + 1):
		for cell in HexUtils.ring(center, r):
			if is_in_bounds(cell):
				out[cell] = 1

func _explore(center: Vector2i, radius: int) -> void:
	if radius < 0:
		return
	if is_in_bounds(center):
		explored[center] = 1
	for r in range(1, radius + 1):
		for cell in HexUtils.ring(center, r):
			if is_in_bounds(cell):
				explored[cell] = 1

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _map_width and cell.y >= 0 and cell.y < _map_height

func is_visible(cell: Vector2i) -> bool:
	return visible.has(cell)

func is_explored(cell: Vector2i) -> bool:
	return explored.has(cell)

func serialize_explored() -> Array:
	var arr: Array = []
	for cell in explored:
		arr.append({"x": cell.x, "y": cell.y})
	return arr

func load_explored(arr: Array) -> void:
	for item in arr:
		var cell := Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
		if is_in_bounds(cell):
			explored[cell] = 1
