class_name DNDElevationSystem

## D&D 5e Battle Elevation System
# Discrete elevation levels per hex cell, 5-foot increments.
# 0 — ground, 1-2 — low rises, 3 — second floor/walls, 4 — towers/cliffs, 5+ — extreme/flying.

const FEET_PER_LEVEL := 5

var width: int = 17
var height: int = 11

# cell (Vector2i) -> level (int)
var elevation: Dictionary = {}


func _init(p_width: int = 17, p_height: int = 11):
	width = p_width
	height = p_height


## Set elevation level for a cell. Levels are clamped to >= 0.
func set_elevation(cell: Vector2i, level: int) -> void:
	elevation[cell] = maxi(level, 0)


## Get elevation level for a cell. Out-of-bounds or unset cells are ground (0).
func get_elevation(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return 0
	return int(elevation.get(cell, 0))


## Height in feet (level * 5).
func height_feet(cell: Vector2i) -> int:
	return get_elevation(cell) * FEET_PER_LEVEL


## True if the cell is on the board.
func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


## "High ground" status: strictly higher than all six neighbors.
func is_high_ground(cell: Vector2i) -> bool:
	var level := get_elevation(cell)
	for nb in HexUtils.get_all_neighbors(cell):
		if get_elevation(nb) >= level:
			return false
	return true


## Fill the whole board with a flat level.
func fill(level: int) -> void:
	elevation.clear()
	for y in height:
		for x in width:
			elevation[Vector2i(x, y)] = maxi(level, 0)


## Serialize for save games.
func to_dict() -> Dictionary:
	var cells: Array = []
	for cell in elevation:
		cells.append([cell.x, cell.y, int(elevation[cell])])
	return {
		"width": width,
		"height": height,
		"cells": cells
	}


## Deserialize from save data.
static func from_dict(data: Dictionary) -> DNDElevationSystem:
	var sys = DNDElevationSystem.new(int(data.get("width", 17)), int(data.get("height", 11)))
	for entry in data.get("cells", []):
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		sys.elevation[cell] = int(entry[2])
	return sys
