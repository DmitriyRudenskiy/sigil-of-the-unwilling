class_name EnemyTurnProcessor
extends TurnPhaseProcessor

const _TerrainCostTable = preload("res://scripts/data/TerrainCostTable.gd")

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

var _pf_stacks: Dictionary
var _pf_self_cell: Vector2i
var _hero_dist_field: PackedFloat32Array = PackedFloat32Array()
var _hero_dist_field_valid: bool = false

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
	var units_reg: Node = Services.resolve(&"units")
	if units_reg != null and "FACTION_SETS" in units_reg:
		_faction_sets = units_reg.FACTION_SETS

func process(_ctx: TurnContext) -> Dictionary:
	var report := {"moved": 0, "attacks": 0, "captures": 0}
	if _map_gen == null or _hero == null:
		return report
	_rebuild_hero_dist_field()
	var dist_cache: Dictionary = {}
	var stacks: Dictionary = _map_gen.enemy_stacks
	if not (stacks is Dictionary) or stacks.is_empty():
		return report

	var garrisoned := _garrisoned_set()

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

		if hero_cell != Vector2i(-1, -1) and HexUtils.hex_distance(cell, hero_cell) <= 1:
			enemy_attack_requested.emit(army, cell)
			report["attacks"] += 1
			attacked = true

		if not attacked:
			var goals := _candidate_goals(cell, hero_cell, aggro, profile)
			if not goals.is_empty():
				var goal: Vector2i = _pick_goal(goals)
				_pf_stacks = stacks
				_pf_self_cell = cell
				var cost_fn: Callable = _pf_cost_fn
				var mp: float = float(profile.get("mp", 5.0))
				var goal_idx := HexUtils.pos_to_idx(goal, _map_gen.map_width)
				if _hero_dist_field_valid and _hero_dist_field[goal_idx] >= INF:
					continue
				var dist := _dist_field(cell, mp, cost_fn, dist_cache)
				var path: Array[Vector2i] = HexPathfinding.dijkstra_path(cell, goal, dist, cost_fn, _map_gen.map_width, _map_gen.map_height)

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
					var city := _city_at(cur)
					if city != null and city.owner == &"player":
						_capture_city(city, cur)
						report["captures"] += 1
						break

				if not attacked:
					hero_cell = _hero_pos()
					if hero_cell != Vector2i(-1, -1) and HexUtils.hex_distance(cur, hero_cell) <= 1:
						enemy_attack_requested.emit(army, cur)
						report["attacks"] += 1
						attacked = true

		if attacked:
			break

	enemy_turn_reported.emit(report)
	return report

func _rebuild_hero_dist_field() -> void:
	_hero_dist_field_valid = false
	var hero_cell := _hero_pos()
	if hero_cell == Vector2i(-1, -1) or _map_gen == null:
		return
	var cost_fn: Callable = _pf_cost_fn_global
	_hero_dist_field = HexPathfinding.dijkstra(hero_cell, 9999.0, cost_fn, _map_gen.map_width, _map_gen.map_height)
	_hero_dist_field_valid = true

func _dist_field(cell: Vector2i, mp: float, cost_fn: Callable, cache: Dictionary) -> PackedFloat32Array:
	var key := Vector3i(cell.x, cell.y, int(mp * 1000.0))
	if cache.has(key):
		return cache[key]
	var field := HexPathfinding.dijkstra(cell, mp, cost_fn, _map_gen.map_width, _map_gen.map_height)
	cache[key] = field
	return field

func _pf_cost_fn_global(nxt: Vector2i) -> float:
	if _map_gen == null:
		return INF
	if not _map_gen.is_walkable(nxt):
		return INF
	var tid: int = _map_gen.get_terrain_id(nxt)
	return _TerrainCostTable.get_cost_with_effects_by_id(tid, false)

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
	if _cities_mgr != null:
		for city in _cities_mgr.cities:
			if city.owner != &"player":
				continue
			var d := HexUtils.hex_distance(cell, city.center)
			if d <= aggro:
				goals[city.center] = {"weight": float(weights.get("village", 1.0)), "dist": d}
	if _map_gen != null:
		for rc in _map_gen.resource_cells:
			var d := HexUtils.hex_distance(cell, rc)
			if d <= aggro:
				goals[rc] = {"weight": float(weights.get("resource", 0.6)), "dist": d}
	if hero_cell != Vector2i(-1, -1):
		var d := HexUtils.hex_distance(cell, hero_cell)
		if d <= aggro:
			goals[hero_cell] = {"weight": float(weights.get("hero", 0.8)), "dist": d}
	return goals

func _pick_goal(goals: Dictionary) -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score := -1.0

	for cell in goals.keys():
		var info: Dictionary = goals[cell]
		var score := float(info["weight"]) / (float(int(info["dist"])) + 1.0)

		if score > best_score + 0.000001:
			best_score = score
			best_cell = cell
		elif score > best_score - 0.000001 and score < best_score + 0.000001:

			if cell.x < best_cell.x or (cell.x == best_cell.x and cell.y < best_cell.y):
				best_cell = cell

	return best_cell

func _pf_cost_fn(nxt: Vector2i) -> float:
	if _map_gen == null:
		return INF
	if not _map_gen.is_walkable(nxt):
		return INF
	if _pf_stacks.has(nxt) and nxt != _pf_self_cell:
		return INF
	var tid: int = _map_gen.get_terrain_id(nxt)
	return _TerrainCostTable.get_cost_with_effects_by_id(tid, false)

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
