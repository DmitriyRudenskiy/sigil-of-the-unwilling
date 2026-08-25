class_name BattleAI
extends RefCounted
## Чистая логика AI: принимает решения на основе BattleState и данных.
## Без await, без узлов, без спрайтов, без таймеров.

enum Action {
	SKIP,
	MOVE,
	ATTACK,
}

class AIResult extends RefCounted:
	var action: int = Action.SKIP
	var move_path: Array[Vector2i] = []
	var target_cell: Vector2i = Vector2i(-1, -1)
	var attack_target: BattleState.BattleUnit = null
	var move_victim: BattleState.BattleUnit = null


func decide_turn(unit: BattleState.BattleUnit, state: BattleState, blocked: Dictionary) -> AIResult:
	var result := AIResult.new()

	if unit == null or state.battle_over:
		return result

	var nearest := _find_nearest(unit, state, "attacker")
	if nearest == null:
		return result

	var distance := HexUtils.hex_distance(unit.cell, nearest.cell)

	# Атака в соседней клетке
	if distance == 1:
		result.action = Action.ATTACK
		result.attack_target = nearest
		return result

	# Движение к ближайшей цели
	# Убираем цель из blocked, чтобы BFS мог построить путь к ней.
	var path_blocked := blocked.duplicate()
	path_blocked.erase(nearest.cell)

	var path := HexUtils.bfs_path(unit.cell, nearest.cell, path_blocked, BattleState.BW, BattleState.BH)
	if path.size() <= 1:
		return result

	# path.size() - 2, чтобы никогда не шагнуть в клетку цели.
	var steps := mini(unit.get_speed(), path.size() - 2)
	if steps <= 0:
		return result

	var target_cell: Vector2i = path[steps]
	var victim := _find_victim_near(target_cell, state, "attacker")

	result.action = Action.MOVE
	result.move_path = path.slice(0, steps + 1)
	result.target_cell = target_cell
	result.attack_target = victim
	result.move_victim = victim

	return result


func _find_nearest(unit: BattleState.BattleUnit, state: BattleState, target_side: String) -> BattleState.BattleUnit:
	var nearest: BattleState.BattleUnit = null
	var nearest_distance := 999

	for u in state.get_units_by_side(target_side):
		if u.is_alive():
			var d := HexUtils.hex_distance(unit.cell, u.cell)
			if d < nearest_distance:
				nearest_distance = d
				nearest = u

	return nearest


func _find_victim_near(cell: Vector2i, state: BattleState, target_side: String) -> BattleState.BattleUnit:
	for neighbor in HexUtils.get_all_neighbors(cell):
		var u := state.get_unit_at(neighbor, target_side)
		if u != null and u.is_alive():
			return u

	return null
