extends Node

var current_cell: Vector2i = Vector2i(0, 0)
var previous_cell: Vector2i = Vector2i(0, 0)
var teleport_calls: Array[Vector2i] = []
var blocked_cells: Dictionary = {}  


func teleport(cell: Vector2i) -> void:
	if blocked_cells.has(cell):
		return
	teleport_calls.append(cell)
	current_cell = cell
	previous_cell = cell
