extends Node
## Тестовый фейк: HeroMovementController для WorldBattleCoordinator.
## Фиксирует вызовы teleport() и отдаёт current/previous клетку.

var current_cell: Vector2i = Vector2i(0, 0)
var previous_cell: Vector2i = Vector2i(0, 0)
var teleport_calls: Array[Vector2i] = []
var blocked_cells: Dictionary = {}  # cell -> true — для teleport-проверок


func teleport(cell: Vector2i) -> void:
	if blocked_cells.has(cell):
		return
	teleport_calls.append(cell)
	current_cell = cell
	previous_cell = cell
