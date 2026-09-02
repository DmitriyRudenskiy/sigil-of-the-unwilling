extends RefCounted
class_name VisibilityMap
## Fog-of-war: `visible` (освещённые клетки) + `explored` (разведённые).
##
## visible = объединение дисков обзора (odd-r гексы) вокруг героя и союзных
## городов. explored — монотонный аккумулятор: только добавляет клетки,
## никогда не стирает (то, что герой уже видел, остаётся на карте всегда).

var visible: Dictionary = {}   # Vector2i -> 1
var explored: Dictionary = {}  # Vector2i -> 1

var _map_width: int = 0
var _map_height: int = 0

func set_map_size(width: int, height: int) -> void:
	_map_width = width
	_map_height = height

## Пересчёт видимости по дискам радиуса. `sight_sources` — клетки городов
## (радиус city_sight). `hero_cell` + каждый источник расширяют `explored`.
## Возвращает true, если `visible` изменилось (для ленивого перериса).
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
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nb := Vector2i(center.x + dx, center.y + dy)
			if HexUtils.hex_distance(center, nb) <= radius and is_in_bounds(nb):
				out[nb] = 1

func _explore(center: Vector2i, radius: int) -> void:
	if radius < 0:
		return
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var nb := Vector2i(center.x + dx, center.y + dy)
			if HexUtils.hex_distance(center, nb) <= radius and is_in_bounds(nb):
				explored[nb] = 1

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _map_width and cell.y >= 0 and cell.y < _map_height

func is_visible(cell: Vector2i) -> bool:
	return visible.has(cell)

func is_explored(cell: Vector2i) -> bool:
	return explored.has(cell)

## Сериализация разведённой сетки (массив {x,y}) — для save/load.
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
