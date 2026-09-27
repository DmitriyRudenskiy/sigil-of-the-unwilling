class_name BattleAI
extends RefCounted

const _BattleTerrain = preload("res://scripts/systems/BattleTerrain.gd")

enum Action {
	SKIP,
	MOVE,
	ATTACK,
}

## Доктрина ИИ (tactical-battle-system, фаза 7). Значения — из design.md.
const RETREAT_ARMY_PCT := 0.3     # отступление, когда здоровье армии < 30% (потеряно >70%)
const WOUNDED_THRESHOLD := 0.3    # цель «раненая», если её здоровье < 30%
const WOUNDED_BONUS := 2.0        # бонус к score раненой цели (концентрация огня)
const RANGED_BONUS := 1.5         # бонус к score дальнему юниту
const AGGR_ANIMAL := 1.5          # дикие животные: агрессивны, не отступают
const AGGR_HUMANOID := 1.0        # гуманоиды: баланс
const AGGR_MONSTER := 0.5         # монстры: игнорируют малые потери, но отступают при больших


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
	var target := _pick_target(unit, state, target_side)

	if target == null:
		return result

	# Отступление: армия потеряла >70% и тип юнита не «животное» (они не отступают).
	if _should_retreat(unit, state):
		if _try_retreat(unit, state, blocked, result):
			return result

	var distance := HexUtils.hex_distance(unit.cell, target.cell, state.hex_shift_right)
	var has_adjacent_enemy := _has_adjacent_enemy(unit, state, target_side)

	if unit.is_ranged() and distance > 1 and not has_adjacent_enemy:
		result.action = Action.ATTACK
		result.attack_target = target
		return result

	if distance == 1:
		result.action = Action.ATTACK
		result.attack_target = target
		return result

	if unit.is_flying():
		var fly_cell := _find_flying_landing_cell(unit, target, state, blocked)
		if fly_cell != Vector2i(-1, -1):
			var fly_victim := _find_victim_near(fly_cell, state, target_side)

			result.action = Action.MOVE
			result.move_path = [unit.cell, fly_cell]
			result.target_cell = fly_cell
			result.attack_target = fly_victim
			result.move_victim = fly_victim

		return result

	# Перемещаемся в обход всех, кроме цели. Иначе pathfinding
	# может пройти сквозь клетку цели и юнит окажется не в состоянии
	# атаковать (она занята).
	blocked.erase(target.cell)

	var path: Array[Vector2i] = HexPathfinding.find_path(
		unit.cell, target.cell, blocked, BattleState.BW, BattleState.BH, state.hex_shift_right, "bfs"
	)

	if target.cell != unit.cell:
		blocked[target.cell] = true
	if path.size() <= 1:
		return result

	var steps: int = min(unit.get_speed(), path.size() - 2)
	if steps <= 0:
		return result

	# Укрытия: если под огнём (есть дальний враг), предпочитаем клетку с бонусом
	# защиты, не жертвуя при этом подходом к цели (только строго лучшее укрытие).
	var idx: int = _pick_landing_cell(unit, state, target_side, path, steps)
	var target_cell: Vector2i = path[idx]
	var victim := _find_victim_near(target_cell, state, target_side)

	result.action = Action.MOVE
	var sliced_path: Array = path.slice(0, idx + 1)
	for p in sliced_path:
		result.move_path.append(p)
	result.target_cell = target_cell
	result.attack_target = victim
	result.move_victim = victim

	return result


## Приоритет целей (фаза 7.1/7.3): угрозы → раненые (<30%) → дальние.
## С одним врагом возвращает именно его (совпадает со старым «ближайший»).
func _pick_target(unit: BattleState.BattleUnit, state: BattleState, target_side: BattleState.Side) -> BattleState.BattleUnit:
	var best: BattleState.BattleUnit = null
	var best_score := -1.0
	var best_dist := 999999
	for e in state.get_units_by_side(target_side):
		if not e.is_alive():
			continue
		var score := _score_target(unit, e, state)
		var dist := HexUtils.hex_distance(unit.cell, e.cell, state.hex_shift_right)
		if score > best_score or (score == best_score and dist < best_dist):
			best = e
			best_score = score
			best_dist = dist
	return best


func _score_target(unit: BattleState.BattleUnit, target: BattleState.BattleUnit, state: BattleState) -> float:
	var max_c: int = target.max_count if target.max_count > 0 else 1
	var health_pct: float = float(target.get_count()) / float(max_c)
	var dist: int = max(1, HexUtils.hex_distance(unit.cell, target.cell, state.hex_shift_right))
	# Угроза: сильный, здоровый, близкий враг опаснее.
	var threat: float = float(target.get_attack()) * health_pct * (1.0 / float(dist))
	# Концентрация: раненого (<30%) добиваем — бонус растёт с потерей здоровья.
	var wounded: float = WOUNDED_BONUS * (1.0 - health_pct) if health_pct < WOUNDED_THRESHOLD else 0.0
	# Дальние — приоритет (бьют издалека).
	var ranged: float = RANGED_BONUS if target.is_ranged() else 0.0
	return threat + wounded + ranged


## Агрессивность по типу (фаза 7.5). Тип — по тегам юнита.
func _aggression(unit: BattleState.BattleUnit) -> float:
	if unit.has_tag("beast") or unit.has_tag("animal") or unit.has_tag("wild"):
		return AGGR_ANIMAL
	if unit.has_tag("monster") or unit.has_tag("undead") or unit.has_tag("dragon") or unit.has_tag("elemental"):
		return AGGR_MONSTER
	return AGGR_HUMANOID


## Здоровье армии стороны юнита: sum(count) / sum(max_count).
func _army_health_pct(unit: BattleState.BattleUnit, state: BattleState) -> float:
	var units: Array[BattleState.BattleUnit] = state.get_units_by_side(unit.side)
	var army_max := 0
	var army_now := 0
	for u in units:
		army_max += u.max_count
		if u.is_alive():
			army_now += u.get_count()
	if army_max <= 0:
		return 1.0
	return float(army_now) / float(army_max)


func _should_retreat(unit: BattleState.BattleUnit, state: BattleState) -> bool:
	# Отступают только гуманоиды (тактичны). Дикие животные агрессивны,
	# монстры игнорируют потери — оба типа держатся и не отступают (spec 7.5).
	if _aggression(unit) != AGGR_HUMANOID:
		return false
	return _army_health_pct(unit, state) < RETREAT_ARMY_PCT


## Путь к ближайшему краю доски. Возвращает true, если отступление выполнено.
func _try_retreat(unit: BattleState.BattleUnit, state: BattleState, blocked: Dictionary, result: AIResult) -> bool:
	var edge := _nearest_edge_cell(unit, state)
	var path: Array[Vector2i] = HexPathfinding.find_path(
		unit.cell, edge, blocked, BattleState.BW, BattleState.BH, state.hex_shift_right, "bfs"
	)
	if path.size() <= 1:
		return false
	var steps: int = min(unit.get_speed(), path.size() - 1)
	result.action = Action.MOVE
	for i in range(steps + 1):
		result.move_path.append(path[i])
	result.target_cell = path[steps]
	return true


func _nearest_edge_cell(unit: BattleState.BattleUnit, state: BattleState) -> Vector2i:
	var c: Vector2i = unit.cell
	var candidates: Array[Vector2i] = [
		Vector2i(0, c.y),
		Vector2i(BattleState.BW - 1, c.y),
		Vector2i(c.x, 0),
		Vector2i(c.x, BattleState.BH - 1),
	]
	var best: Vector2i = candidates[0]
	var best_d := 999999
	for e in candidates:
		var d := HexUtils.hex_distance(c, e, state.hex_shift_right)
		if d < best_d:
			best_d = d
			best = e
	return best


## Под огнём? Есть ли живой дальний враг (может бить издалека).
func _is_under_fire(unit: BattleState.BattleUnit, state: BattleState, target_side: BattleState.Side) -> bool:
	for e in state.get_units_by_side(target_side):
		if e.is_alive() and e.is_ranged():
			return true
	return false


## Бонус защиты местности в клетке (>1.0 = укрытие).
func _defense_bonus_at(cell: Vector2i, state: BattleState) -> float:
	return _BattleTerrain.defense_multiplier(state.get_hex_terrain(cell))


## Выбор клетки для остановки (1..steps). По умолчанию — ближе всех к цели
## (path[steps]); под огнём — только если раньше по пути строго лучшее укрытие.
func _pick_landing_cell(unit: BattleState.BattleUnit, state: BattleState, target_side: BattleState.Side, path: Array[Vector2i], steps: int) -> int:
	var best_idx: int = steps
	var best_def: float = _defense_bonus_at(path[steps], state)
	if _is_under_fire(unit, state, target_side):
		for i in range(1, steps):
			var d: float = _defense_bonus_at(path[i], state)
			if d > best_def:
				best_def = d
				best_idx = i
	return best_idx


func _find_flying_landing_cell(
	unit: BattleState.BattleUnit,
	target: BattleState.BattleUnit,
	state: BattleState,
	blocked: Dictionary
) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := GameSettings.INF
	var speed := unit.get_speed()
	var min_x := maxi(0, unit.cell.x - speed)
	var max_x := mini(BattleState.BW - 1, unit.cell.x + speed)
	var min_y := maxi(0, unit.cell.y - speed)
	var max_y := mini(BattleState.BH - 1, unit.cell.y + speed)

	var is_melee := not unit.is_ranged()

	var fallback_best := Vector2i(-1, -1)
	var fallback_best_score := GameSettings.INF

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var cell := Vector2i(x, y)

			if cell == unit.cell:
				continue

			if blocked.has(cell):
				continue

			var dist_to_unit := HexUtils.hex_distance(unit.cell, cell, state.hex_shift_right)
			if dist_to_unit > speed:
				continue

			var dist_to_target := HexUtils.hex_distance(cell, target.cell, state.hex_shift_right)
			if dist_to_target < fallback_best_score:
				fallback_best_score = dist_to_target
				fallback_best = cell

			var can_attack := (dist_to_target == 1) if is_melee else true

			if can_attack and dist_to_target < best_score:
				best_score = dist_to_target
				best = cell

	return best if best != Vector2i(-1, -1) else fallback_best


func _has_adjacent_enemy(
	unit: BattleState.BattleUnit,
	state: BattleState,
	target_side: BattleState.Side
) -> bool:
	for nb in HexUtils.get_all_neighbors(unit.cell, state.hex_shift_right):
		var u := state.get_unit_at(nb, target_side)
		if u != null and u.is_alive():
			return true

	return false


func _find_victim_near(cell: Vector2i, state: BattleState, target_side: BattleState.Side) -> BattleState.BattleUnit:
	for neighbor in HexUtils.get_all_neighbors(cell, state.hex_shift_right):
		var u := state.get_unit_at(neighbor, target_side)
		if u != null and u.is_alive():
			return u

	return null
