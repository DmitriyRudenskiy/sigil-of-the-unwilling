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

	var target_side := BattleState.Side.DEFENDER if unit.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER
	var nearest := _find_nearest(unit, state, target_side)

	if nearest == null:
		return result

	var distance := HexUtils.hex_distance(unit.cell, nearest.cell)
	var has_adjacent_enemy := _has_adjacent_enemy(unit, state, target_side)

	# Ranged AI shoots if not blocked by adjacent enemy.
	if unit.is_ranged() and distance > 1 and not has_adjacent_enemy:
		result.action = Action.ATTACK
		result.attack_target = nearest
		return result

	# Melee adjacent attack.
	if distance == 1:
		result.action = Action.ATTACK
		result.attack_target = nearest
		return result

	# Flying movement.
	if unit.is_flying():
		var target_cell := _find_flying_landing_cell(unit, nearest, state, blocked)
		if target_cell != Vector2i(-1, -1):
			var victim := _find_victim_near(target_cell, state, target_side)

			result.action = Action.MOVE
			result.move_path = [unit.cell, target_cell]
			result.target_cell = target_cell
			result.attack_target = victim
			result.move_victim = victim

		return result

	# Ground movement.
	var path_blocked := blocked.duplicate()
	path_blocked.erase(nearest.cell)

	var path: Array[Vector2i] = HexPathfinding.find_path(
		unit.cell, nearest.cell, path_blocked, BattleState.BW, BattleState.BH, "bfs"
	)
	if path.size() <= 1:
		return result

	var steps: int = min(unit.get_speed(), path.size() - 2)
	if steps <= 0:
		return result

	var target_cell: Vector2i = path[steps]
	var victim := _find_victim_near(target_cell, state, target_side)

	result.action = Action.MOVE
	var sliced_path: Array = path.slice(0, steps + 1)
	for p in sliced_path:
		result.move_path.append(p)
	result.target_cell = target_cell
	result.attack_target = victim
	result.move_victim = victim

	return result


func _find_nearest(unit: BattleState.BattleUnit, state: BattleState, target_side: BattleState.Side) -> BattleState.BattleUnit:
	var nearest: BattleState.BattleUnit = null
	var nearest_distance := GameSettings.INF

	for u in state.get_units_by_side(target_side):
		if u.is_alive():
			var d := HexUtils.hex_distance(unit.cell, u.cell)
			if d < nearest_distance:
				nearest_distance = d
				nearest = u

	return nearest


func _find_victim_near(cell: Vector2i, state: BattleState, target_side: BattleState.Side) -> BattleState.BattleUnit:
	for neighbor in HexUtils.get_all_neighbors(cell):
		var u := state.get_unit_at(neighbor, target_side)
		if u != null and u.is_alive():
			return u

	return null


func _has_adjacent_enemy(
	unit: BattleState.BattleUnit,
	state: BattleState,
	target_side: BattleState.Side
) -> bool:
	for nb in HexUtils.get_all_neighbors(unit.cell):
		var u := state.get_unit_at(nb, target_side)
		if u != null and u.is_alive():
			return true

	return false


func _find_flying_landing_cell(
	unit: BattleState.BattleUnit,
	target: BattleState.BattleUnit,
	state: BattleState,
	blocked: Dictionary
) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := GameSettings.INF
	var speed := unit.get_speed()
	# Limit search to bounding box of radius speed around the unit
	var min_x := maxi(0, unit.cell.x - speed)
	var max_x := mini(BattleState.BW - 1, unit.cell.x + speed)
	var min_y := maxi(0, unit.cell.y - speed)
	var max_y := mini(BattleState.BH - 1, unit.cell.y + speed)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)

			if cell == unit.cell:
				continue

			if blocked.has(cell):
				continue

			var dist_to_unit := HexUtils.hex_distance(unit.cell, cell)
			if dist_to_unit > speed:
				continue

			var dist_to_target := HexUtils.hex_distance(cell, target.cell)
			if dist_to_target < best_score:
				best_score = dist_to_target
				best = cell

	return best
