extends RefCounted
class_name WorldStateDelta
## Tracks world state changes for save/load: villages, enemies, resources, chests.

var captured_villages: Array[Vector2i] = []
var defeated_enemies: Array[Vector2i] = []
var removed_resources: Array[Vector2i] = []
var opened_chests: Array[Vector2i] = []


func serialize() -> Dictionary:
	return {
		"captured_villages": _cells_to_array(captured_villages),
		"defeated_enemies": _cells_to_array(defeated_enemies),
		"removed_resources": _cells_to_array(removed_resources),
		"opened_chests": _cells_to_array(opened_chests),
	}


func deserialize(data: Dictionary) -> void:
	captured_villages = _array_to_cells(data.get("captured_villages", []))
	defeated_enemies = _array_to_cells(data.get("defeated_enemies", []))
	removed_resources = _array_to_cells(data.get("removed_resources", []))
	opened_chests = _array_to_cells(data.get("opened_chests", []))


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
