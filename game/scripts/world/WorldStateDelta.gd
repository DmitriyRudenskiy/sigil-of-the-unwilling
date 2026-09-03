extends RefCounted
class_name WorldStateDelta
## Tracks world state changes for save/load: villages, enemies, resources, chests.

var captured_villages: Array[Vector2i] = []
var defeated_enemies: Array[Vector2i] = []
var removed_resources: Array[Vector2i] = []
var opened_chests: Array[Vector2i] = []
var removed_scrolls: Array[Vector2i] = []
var discovered_nodes: Array[Vector2i] = []
var exhausted_nodes: Array[Vector2i] = []
# terrain-resources: истощённые точки добычи (лес/гора). Персистентность
# истощения между ходами/сохранениями.
var terrain_exhausted_cells: Array[Vector2i] = []
# enemy-world-ai: состояние роста врагов (очередь респауна, гарнизоны).
var enemy_growth_state: Dictionary = {}
# fog-of-war: разведённая сетка (массив {x,y}) — сохраняется вместе с миром.
var fog_explored: Array = []


func serialize() -> Dictionary:
	return {
		"captured_villages": _cells_to_array(captured_villages),
		"defeated_enemies": _cells_to_array(defeated_enemies),
		"removed_resources": _cells_to_array(removed_resources),
		"opened_chests": _cells_to_array(opened_chests),
		"removed_scrolls": _cells_to_array(removed_scrolls),
		"discovered_nodes": _cells_to_array(discovered_nodes),
		"exhausted_nodes": _cells_to_array(exhausted_nodes),
		"terrain_exhausted_cells": _cells_to_array(terrain_exhausted_cells),
		"enemy_growth_state": enemy_growth_state.duplicate(true),
		"fog_explored": fog_explored.duplicate(true),
	}


## Fog-of-war: подставить текущую разведённую сетку из VisibilityMap перед
## сериализацией (сетка хранится в VisibilityMap, а не в дельте).
func set_fog_explored(arr: Array) -> void:
	fog_explored = arr.duplicate(true)


func deserialize(data: Dictionary) -> void:
	captured_villages = _array_to_cells(data.get("captured_villages", []))
	defeated_enemies = _array_to_cells(data.get("defeated_enemies", []))
	removed_resources = _array_to_cells(data.get("removed_resources", []))
	opened_chests = _array_to_cells(data.get("opened_chests", []))
	removed_scrolls = _array_to_cells(data.get("removed_scrolls", []))
	discovered_nodes = _array_to_cells(data.get("discovered_nodes", []))
	exhausted_nodes = _array_to_cells(data.get("exhausted_nodes", []))
	terrain_exhausted_cells = _array_to_cells(data.get("terrain_exhausted_cells", []))
	var growth_raw: Variant = data.get("enemy_growth_state", {})
	enemy_growth_state = growth_raw.duplicate(true) if growth_raw is Dictionary else {}
	fog_explored = data.get("fog_explored", [])


func add_village(cell: Vector2i) -> void:
	if not captured_villages.has(cell):
		captured_villages.append(cell)


func add_defeated_enemy(cell: Vector2i) -> void:
	if not defeated_enemies.has(cell):
		defeated_enemies.append(cell)


func add_removed_resource(cell: Vector2i) -> void:
	if not removed_resources.has(cell):
		removed_resources.append(cell)


func add_opened_chest(cell: Vector2i) -> void:
	if not opened_chests.has(cell):
		opened_chests.append(cell)


func add_removed_scroll(cell: Vector2i) -> void:
	if not removed_scrolls.has(cell):
		removed_scrolls.append(cell)


func add_discovered_node(cell: Vector2i) -> void:
	if not discovered_nodes.has(cell):
		discovered_nodes.append(cell)

## terrain-resources: истощённая точка добычи (запись в момент добычи).
func add_terrain_exhausted(cell: Vector2i) -> void:
	if not terrain_exhausted_cells.has(cell):
		terrain_exhausted_cells.append(cell)


func add_exhausted_node(cell: Vector2i) -> void:
	if not exhausted_nodes.has(cell):
		exhausted_nodes.append(cell)


func _cells_to_array(cells: Array[Vector2i]) -> Array:
	var result: Array = []
	for cell in cells:
		result.append({"x": cell.x, "y": cell.y})
	return result


func _array_to_cells(arr: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for item in arr:
		result.append(Vector2i(int(item.get("x", 0)), int(item.get("y", 0))))
	return result
