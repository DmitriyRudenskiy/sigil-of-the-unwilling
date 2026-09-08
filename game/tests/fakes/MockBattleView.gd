class_name MockBattleView
extends BattleView
# TASK_09: лёгкий фейк BattleView для тестов BattleInput.
# Не требует сцены/TileMap — записывает подсветку в поля.

var move_cells: Dictionary = {}
var atk_cells: Dictionary = {}
var unreachable_cells: Dictionary = {}
var cursor_mode: int = CursorMode.DEFAULT


func set_cursor_mode(mode: int) -> void:
	cursor_mode = mode


func set_cursor_visible(_visible: bool) -> void:
	pass


func set_highlights(move: Dictionary, attack: Dictionary) -> void:
	move_cells = move.duplicate()
	atk_cells = attack.duplicate()


func set_unreachable_highlights(cells: Dictionary) -> void:
	unreachable_cells = cells.duplicate()


func clear_highlights() -> void:
	move_cells.clear()
	atk_cells.clear()
	unreachable_cells.clear()


func create_unit_sprite(_unit: BattleState.BattleUnit) -> void:
	pass


func remove_unit(_unit: BattleState.BattleUnit) -> void:
	pass


func animate_move(_unit: BattleState.BattleUnit, _path: Array[Vector2i]) -> Tween:
	return null


func show_floating_text(_cell: Vector2i, _text: String, _color: Color) -> void:
	pass


func show_damage_number(_unit: BattleState.BattleUnit, _damage: int) -> void:
	pass


func _find_node(_unit: BattleState.BattleUnit) -> Node2D:
	return null
