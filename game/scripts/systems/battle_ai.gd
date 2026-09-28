class_name BattleAI
extends RefCounted

## ИИ автобитв (tactical-combat-implementation, фаза 6 — доктрина).
## Приоритеты целей: угрозы (могут атаковать меня) → раненые (<30% HP)
## → дальнобойные → ближайшие. Концентрация огня: в рамках приоритета
## добиваем слабейшего. Тактические юниты используют укрытия (бонусные
## гексы) и отступают при потерях >70%; животные — агрессивны (ближайшая
## цель, без укрытий/отступления); монстры игнорируют потери (не отступают).

enum Action {
	SKIP,
	MOVE,
	ATTACK,
	RETREAT,
}

enum Aggression {
	AGGRESSIVE,  # дикие животные
	TACTICAL,    # гуманоиды
	STUBBORN,    # монстры (игнорируют потери)
}

## Дикие животные (агрессивная доктрина): ключи из UnitRegistry.
const ANIMAL_KEYS: Array[String] = [
	"wolves", "wolf", "boar", "centaur", "unicorn", "war_unicorn", "treant",
	"dryad", "griffin", "royal_griffin", "pegasus", "gargoyle", "harpy",
	"green_dragon", "gold_dragon", "black_dragon", "red_dragon", "rust_dragon",
	"wyvern", "wyvern_monarch", "roc", "thunderbird", "phoenix", "firebird",
	"naga", "naga_queen", "basilisk", "greater_basilisk", "gorgon",
	"mighty_gorgon", "serpent_fly", "dragon_fly", "manticore", "beholder",
	"air_elemental", "fire_elemental", "water_elemental", "earth_elemental",
	"storm_elemental", "ice_elemental", "magma_elemental",
]

## Монстры (игнорируют потери): не отступают даже при >70%.
const MONSTER_KEYS: Array[String] = [
	"troll", "trolls", "ogre", "ogre_mage", "behemoth", "minotaur", "hydra",
	"skeleton", "zombie", "ghost", "wraith", "vampire", "lich", "gremlin",
	"master_gremlin", "stone_golem", "iron_golem", "gold_golem",
	"diamond_golem", "genie", "master_genie", "giant", "cyclops",
	"cyclops_king", "troglodyte", "medusa",
]

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
	var aggression := _aggression(unit)

	# 6.3: отступление при потерях >70% — только тактическая доктрина.
	if (
		aggression == Aggression.TACTICAL
		and _loss_fraction(state, unit.side) > GameNumbersBattle.AI_RETREAT_LOSS_FRACTION
	):
		result.action = Action.RETREAT
		return result

	var enemies := _alive_enemies(state, target_side)
	if enemies.is_empty():
		return result

	# 6.1: приоритеты целей (для животных — всегда ближайшая угроза).
	var target := _pick_target(unit, state, enemies, aggression)
	if target == null:
		return result

	var distance := HexUtils.hex_distance(unit.cell, target.cell, state.hex_shift_right)
	var has_adjacent_enemy := _has_adjacent_enemy(unit, state, target_side)

	# Дальняя атака: LOS + дальность + листва (фаза 4).
	if (
		unit.is_ranged()
		and distance > 1
		and not has_adjacent_enemy
		and BattleLineOfSight.can_target_ranged(state, unit.cell, target)
	):
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

	# Перемещаемся в обход всех, кроме цели. Дублировать всю карту занятости
	# на каждый ход AI дорого (O(N) аллокаций за бой); вместо этого временно
	# снимаем блокировку клетки цели и восстанавливаем её сразу после поиска пути.
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

	# 6.2: выбор клетки высадки — тактика предпочитает укрытия, если
	# атаковать с клетки нельзя; остальные идут максимально к цели.
	var landing: Vector2i = path[steps]
	var victim := _find_victim_near(landing, state, target_side)
	if aggression == Aggression.TACTICAL:
		var best_cell: Vector2i = _pick_landing_cell(
			unit, state, target_side, target, path, steps
		)
		if best_cell != Vector2i(-1, -1):
			landing = best_cell
			victim = _find_victim_near(landing, state, target_side)
			var idx: int = path.find(landing)
			if idx > 0:
				steps = idx

	var sliced_path: Array = path.slice(0, steps + 1)
	for p in sliced_path:
		result.move_path.append(p)

	result.action = Action.MOVE
	result.target_cell = landing
	result.attack_target = victim
	result.move_victim = victim

	return result

# ═══════════════════════════════════════════
#  ДОКТРИНА
# ═══════════════════════════════════════════

## Тип существа: животное / монстр / гуманоид (остальные).
static func _aggression(unit: BattleState.BattleUnit) -> int:
	var key: String = unit.get_key()
	if ANIMAL_KEYS.has(key):
		return Aggression.AGGRESSIVE
	if MONSTER_KEYS.has(key):
		return Aggression.STUBBORN
	return Aggression.TACTICAL


## Доля потерь стороны: 1.0 = все уничтожены.
static func _loss_fraction(state: BattleState, side: int) -> float:
	var units: Array = state.attacker_units if side == BattleState.Side.ATTACKER else state.defender_units
	var initial := 0
	var alive := 0
	for u in units:
		if u == null:
			continue
		initial += maxi(1, u.max_count)
		if u.is_alive():
			alive += u.get_count()
	if initial <= 0:
		return 0.0
	return 1.0 - float(alive) / float(initial)


## 6.1: угрозы → раненые <30% → дальнобойные → ближайшие.
## 6.3: в рамках приоритета — слабейший (концентрация огня).
func _pick_target(
	unit: BattleState.BattleUnit,
	state: BattleState,
	enemies: Array,
	aggression: int
) -> BattleState.BattleUnit:
	if enemies.is_empty():
		return null
	if aggression == Aggression.AGGRESSIVE:
		return _nearest(unit, state, enemies)

	var best: BattleState.BattleUnit = null
	var best_score := INF
	for e in enemies:
		if e == null or not e.is_alive():
			continue
		var primary: int
		if _can_attack_me(unit, state, e):
			primary = 0
		elif _is_wounded(e):
			primary = 1
		elif e.is_ranged():
			primary = 2
		else:
			primary = 3
		var hp_frac: float = float(e.get_count()) / float(maxi(1, e.max_count))
		var dist := HexUtils.hex_distance(unit.cell, e.cell, state.hex_shift_right)
		var total: float = float(primary) * 10000.0 + (1.0 - hp_frac) * -1000.0 + float(dist)
		if total < best_score:
			best_score = total
			best = e
	return best


## Юнит считается раненым, если осталось <30% стека.
static func _is_wounded(unit: BattleState.BattleUnit) -> bool:
	if unit == null or not unit.is_alive():
		return false
	return unit.get_count() < float(maxi(1, unit.max_count)) * GameNumbersBattle.AI_WOUNDED_FRACTION


## Может ли `e` атаковать `unit` в свой ход (угроза).
static func _can_attack_me(unit: BattleState.BattleUnit, state: BattleState, e: BattleState.BattleUnit) -> bool:
	var d := HexUtils.hex_distance(unit.cell, e.cell, state.hex_shift_right)
	if d <= 0:
		return false
	if e.is_ranged() and BattleLineOfSight.can_target_ranged(state, e.cell, unit):
		return true
	return d == 1


## 6.2: лучшая клетка высадки вдоль пути. Атака с клетки всегда лучше;
## иначе тактик берёт максимум бонуса укрытия, затем — близость к цели.
func _pick_landing_cell(
	unit: BattleState.BattleUnit,
	state: BattleState,
	target_side: int,
	target: BattleState.BattleUnit,
	path: Array[Vector2i],
	steps: int
) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_score := INF
	for i in range(1, mini(steps + 1, path.size())):
		var cell: Vector2i = path[i]
		var dist_to_target := HexUtils.hex_distance(cell, target.cell, state.hex_shift_right)
		var can_attack: bool = false
		if unit.is_ranged():
			can_attack = _has_targetable_enemy_from(cell, state, target_side)
		else:
			can_attack = _find_victim_near(cell, state, target_side) != null

		var score: float
		if can_attack:
			# Добиваем: слабейшая жертва рядом.
			var victim := _best_victim_from(cell, state, target_side, unit)
			var weak := 0.0
			if victim != null:
				weak = (1.0 - float(victim.get_count()) / float(maxi(1, victim.max_count))) * -500.0
			score = -10000.0 + weak + float(dist_to_target) * 0.1
		else:
			var cover: float = BattleTerrain.defense_bonus(state.get_terrain_at(cell))
			score = cover * -1000.0 + float(dist_to_target)

		if score < best_score:
			best_score = score
			best_cell = cell
	return best_cell


## Лучшая жертва рядом с клеткой (слабейшая).
func _best_victim_from(
	cell: Vector2i,
	state: BattleState,
	target_side: int,
	_unit: BattleState.BattleUnit
) -> BattleState.BattleUnit:
	var best: BattleState.BattleUnit = null
	var best_frac := INF
	for nb in HexUtils.get_all_neighbors(cell, state.hex_shift_right):
		var u := state.get_unit_at(nb, target_side)
		if u == null or not u.is_alive():
			continue
		var frac: float = float(u.get_count()) / float(maxi(1, u.max_count))
		if frac < best_frac:
			best_frac = frac
			best = u
	return best


## Есть ли поразимая дальняя цель из клетки (LOS + дальность + листва).
func _has_targetable_enemy_from(cell: Vector2i, state: BattleState, target_side: int) -> bool:
	for u in state.get_units_by_side(target_side):
		if u != null and u.is_alive() and BattleLineOfSight.can_target_ranged(state, cell, u):
			return true
	return false


func _alive_enemies(state: BattleState, target_side: int) -> Array:
	var out: Array = []
	for u in state.get_units_by_side(target_side):
		if u != null and u.is_alive():
			out.append(u)
	return out


func _nearest(unit: BattleState.BattleUnit, state: BattleState, enemies: Array) -> BattleState.BattleUnit:
	var nearest: BattleState.BattleUnit = null
	var nearest_distance := GameSettings.INF
	for u in enemies:
		if u == null or not u.is_alive():
			continue
		var d := HexUtils.hex_distance(unit.cell, u.cell, state.hex_shift_right)
		if d < nearest_distance:
			nearest_distance = d
			nearest = u
	return nearest

# ═══════════════════════════════════════════
#  БАЗОВЫЕ ПОИСКИ (без изменений из legacy)
# ═══════════════════════════════════════════

func _find_victim_near(cell: Vector2i, state: BattleState, target_side: BattleState.Side) -> BattleState.BattleUnit:
	for neighbor in HexUtils.get_all_neighbors(cell, state.hex_shift_right):
		var u := state.get_unit_at(neighbor, target_side)
		if u != null and u.is_alive():
			return u

	return null

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
