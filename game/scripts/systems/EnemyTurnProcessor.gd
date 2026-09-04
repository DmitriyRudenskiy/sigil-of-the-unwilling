class_name EnemyTurnProcessor
extends TurnPhaseProcessor
## Ход врагов (enemy-world-ai): каждый неггарнизонный стек сам выбирает
## цель (деревня/ресурс/герой — по весам EnemyAIProfile), идёт по Dijkstra
## и действует: атакует героя при контакте, захватывает деревни игрока.
## Детерминирован при данном seed мира: стабильный порядок итерации
## (клетки по (x, y)) + один seeded-RNG.

const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")
const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")

## Атака: враг (army на enemy_cell) бьёт по герою — роли в бою поменяны.
signal enemy_attack_requested(army: Array, enemy_cell: Vector2i)
signal enemy_village_captured(city: City)
signal enemy_turn_reported(report: Dictionary)

var _map_gen: MapGenerator = null
var _hero: Node = null
var _spawner: Node = null
var _cities_mgr: CityManager = null
var _world_delta: WorldStateDelta = null
var _faction_sets: Array = []
var _rng := RandomNumberGenerator.new()


func get_phase_id() -> StringName:
	return &"enemy_turn"


func get_priority() -> int:
	return 25


func setup_world(
	p_map_gen: MapGenerator,
	p_hero: Node,
	p_spawner: Node,
	p_cities_mgr: CityManager,
	p_world_delta: WorldStateDelta,
	p_world_seed: int
) -> void:
	_map_gen = p_map_gen
	_hero = p_hero
	_spawner = p_spawner
	_cities_mgr = p_cities_mgr
	_world_delta = p_world_delta
	_rng.seed = p_world_seed + 777
	# FACTION_SETS из реестра — профиль ИИ не хардкодит юнитов.
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	if units_reg != null and "FACTION_SETS" in units_reg:
		_faction_sets = units_reg.FACTION_SETS


func process(_ctx: TurnContext) -> Dictionary:
	var report := {"moved": 0, "attacks": 0, "captures": 0}
	if _map_gen == null or _hero == null:
		return report
	# Аудит #10: одно Dijkstra на (cell, mp) за ход — повторяющийся запрос
	# берёт готовое поле. ponytail: ключ уникален при текущей итерации (одна
	# армия на клетку), кэш — защита от будущих повторных запросов; cost_fn
	# зависит от состояния stacks, поэтому переиспользование только внутри
	# одного process().
	var dist_cache: Dictionary = {}
	var stacks: Dictionary = _map_gen.enemy_stacks
	if not (stacks is Dictionary) or stacks.is_empty():
		return report

	var garrisoned := _garrisoned_set()

	# Детерминированный порядок: клетки по (x, y).
	var cells: Array = stacks.keys()
	cells.sort_custom(_cell_a_before_b)

	for start_cell in cells:
		var cell: Vector2i = start_cell
		if not stacks.has(cell) or garrisoned.has(cell):
			continue
		var army: Array = stacks[cell]
		var profile: Dictionary = EnemyAIProfile.for_stack(army, _faction_sets)
		var hero_cell := _hero_pos()
		var aggro: int = int(profile.get("aggro_radius", 8))
		var attacked := false

		# Герой уже в радиусе атаки — бьём сразу, не тратя ход.
		if hero_cell != Vector2i(-1, -1) and HexUtils.hex_distance(cell, hero_cell) <= 1:
			enemy_attack_requested.emit(army, cell)
			report["attacks"] += 1
			attacked = true

		if not attacked:
			var goals := _candidate_goals(cell, hero_cell, aggro, profile)
			if not goals.is_empty():
				var goal: Vector2i = _pick_goal(goals)
				var cost_fn := _cost_fn(stacks, cell)
				var mp: float = float(profile.get("mp", 5.0))
				var dist := _dist_field(cell, mp, cost_fn, dist_cache)
				var path: Array[Vector2i] = HexUtils.dijkstra_path(cell, goal, dist, cost_fn, _map_gen.map_width, _map_gen.map_height)

				var cur := cell
				var spent := 0.0
				var mp_budget: float = mp
				for i in range(1, path.size()):
					var nxt: Vector2i = path[i]
					var step_cost := _enter_cost(nxt)
					if spent + step_cost > mp_budget + 0.0001:
						break
					spent += step_cost
					_move_stack(stacks, cur, nxt, army)
					cur = nxt
					report["moved"] += 1

					hero_cell = _hero_pos()
					if hero_cell != Vector2i(-1, -1) and (hero_cell == cur or HexUtils.hex_distance(cur, hero_cell) <= 1):
						enemy_attack_requested.emit(army, cur)
						report["attacks"] += 1
						attacked = true
						break
					# Деревня игрока: захват и гарнизон.
					var city := _city_at(cur)
					if city != null and city.owner == &"player":
						_capture_city(city, cur)
						report["captures"] += 1
						break

				# Герой оказался в радиусе атаки после хода.
				if not attacked:
					hero_cell = _hero_pos()
					if hero_cell != Vector2i(-1, -1) and HexUtils.hex_distance(cur, hero_cell) <= 1:
						enemy_attack_requested.emit(army, cur)
						report["attacks"] += 1
						attacked = true

		if attacked:
			break  # один бой за ход врагов (BattleFlow._active)

	enemy_turn_reported.emit(report)
	return report


# ==================== Вспомогательное ====================


## Поле расстояний Dijkstra с per-turn кэшем по (cell, mp).
func _dist_field(cell: Vector2i, mp: float, cost_fn: Callable, cache: Dictionary) -> PackedFloat32Array:
	var key := "%d;%d;%.4f" % [cell.x, cell.y, mp]
	if not cache.has(key):
		cache[key] = HexUtils.dijkstra(cell, mp, cost_fn, _map_gen.map_width, _map_gen.map_height)
	return cache[key]


func _garrisoned_set() -> Dictionary:
	var out := {}
	if _world_delta == null:
		return out
	for item in _world_delta.enemy_growth_state.get("garrisoned", []):
		out[Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))] = true
	return out


func _capture_city(city: City, cell: Vector2i) -> void:
	city.owner = &"enemy"
	if _world_delta != null:
		var garrisoned: Variant = _world_delta.enemy_growth_state.get("garrisoned", null)
		if garrisoned == null:
			garrisoned = []
			_world_delta.enemy_growth_state["garrisoned"] = garrisoned
		if not _garrisoned_set().has(cell):
			garrisoned.append({"x": cell.x, "y": cell.y})
	GameLogger.world("Enemy captured %s at %s" % [city.display_name, str(cell)])
	enemy_village_captured.emit(city)


func _city_at(cell: Vector2i) -> City:
	if _cities_mgr == null:
		return null
	return _cities_mgr.city_at(cell)


func _move_stack(stacks: Dictionary, from: Vector2i, to: Vector2i, army: Array) -> void:
	stacks.erase(from)
	stacks[to] = army
	if _spawner != null and _spawner.has_method("move_enemy_visual"):
		_spawner.move_enemy_visual(from, to)


func _hero_pos() -> Vector2i:
	var raw: Variant = _hero.get("current_cell")
	return raw if raw is Vector2i else Vector2i(-1, -1)


func _candidate_goals(cell: Vector2i, hero_cell: Vector2i, aggro: int, profile: Dictionary) -> Dictionary:
	var goals := {}
	var weights: Dictionary = profile.get("weights", {})
	# Деревни: только города игрока.
	if _cities_mgr != null:
		for c in _cities_mgr.cities:
			if c.owner != &"player":
				continue
			var d := HexUtils.hex_distance(cell, c.center)
			if d <= aggro:
				goals[c.center] = {"weight": float(weights.get("village", 1.0)), "dist": d}
	# Ресурсы.
	if _map_gen != null:
		for rc in _map_gen.resource_cells:
			var d := HexUtils.hex_distance(cell, rc)
			if d <= aggro:
				goals[rc] = {"weight": float(weights.get("resource", 0.6)), "dist": d}
	# Герой (цель атаки).
	if hero_cell != Vector2i(-1, -1):
		var d := HexUtils.hex_distance(cell, hero_cell)
		if d <= aggro:
			goals[hero_cell] = {"weight": float(weights.get("hero", 0.8)), "dist": d}
	return goals


## Лучшая цель: вес/дальность, детерминированный tie-break по (x, y).
func _pick_goal(goals: Dictionary) -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score := -1.0
	var cells: Array = goals.keys()
	cells.sort_custom(_cell_a_before_b)
	for c in cells:
		var info: Dictionary = goals[c]
		var score := float(info["weight"]) / (float(int(info["dist"])) + 1.0)
		if score > best_score + 0.000001:
			best_score = score
			best_cell = c
	return best_cell


func _cost_fn(stacks: Dictionary, self_cell: Vector2i) -> Callable:
	return func(nxt: Vector2i) -> float:
		return _enter_cost_blocked(nxt, stacks, self_cell)


func _enter_cost(nxt: Vector2i) -> float:
	return _enter_cost_blocked(nxt, {}, Vector2i(-1, -1))


func _enter_cost_blocked(nxt: Vector2i, stacks: Dictionary, self_cell: Vector2i) -> float:
	if _map_gen == null:
		return INF
	if not _map_gen.is_walkable(nxt):
		return INF
	if stacks.has(nxt) and nxt != self_cell:
		return INF
	var tid: int = _map_gen.get_terrain_id(nxt)
	return _TerrainCostTable.get_cost_with_effects_by_id(tid, false)


static func _cell_a_before_b(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y
