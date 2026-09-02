class_name EnemyGrowthSystem
extends TurnPhaseProcessor
## Рост врагов (enemy-world-ai):
## 1) уничтоженный стек через N ходов возрождается на той же клетке
##    ослабленным на 1 ярус (число юнитов / 2, минимум 1);
## 2) на смене сезона новые стеки спавнятся на границе карты,
##    пока их не MAP_ENEMY_COUNT.
## Состояние живёт в world_delta.enemy_growth_state (сериализуется в сейв).

const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")

var _map_gen: MapGenerator = null
var _spawner: Node = null
var _cities_mgr: CityManager = null
var _world_delta: WorldStateDelta = null
var _faction_sets: Array = []
var _rng := RandomNumberGenerator.new()
var _last_season: int = -1


func get_phase_id() -> StringName:
	return &"enemy_growth"


func get_priority() -> int:
	return 30


func setup_growth(
	p_map_gen: MapGenerator,
	p_spawner: Node,
	p_cities_mgr: CityManager,
	p_world_delta: WorldStateDelta,
	p_world_seed: int
) -> void:
	_map_gen = p_map_gen
	_spawner = p_spawner
	_cities_mgr = p_cities_mgr
	_world_delta = p_world_delta
	_rng.seed = p_world_seed + 9000
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	if units_reg != null and "FACTION_SETS" in units_reg:
		_faction_sets = units_reg.FACTION_SETS


## Уничтожен стек — планируем ослабленное возрождение на той же клетке.
func on_stack_defeated(cell: Vector2i, army: Array) -> void:
	if _world_delta == null:
		return
	var units: Array = []
	for s in army:
		if s == null:
			continue
		units.append({"key": s.get_key(), "count": maxi(1, int(s.count / 2))})
	if units.is_empty():
		return
	var q: Array = _queue()
	q.append({
		"x": cell.x,
		"y": cell.y,
		"units": units,
		"turns_left": GameSettings.ENEMY_RESPAWN_TURNS,
	})
	GameLogger.world("Enemy stack at %s will respawn in %d turns" % [str(cell), GameSettings.ENEMY_RESPAWN_TURNS])


func process(ctx: TurnContext) -> Dictionary:
	var report := {"respawns": 0, "season_spawns": 0}
	if _map_gen == null or _world_delta == null:
		return report
	_process_respawns(report)
	_process_season(ctx.season, report)
	return report


# ==================== Внутреннее ====================

func _process_respawns(report: Dictionary) -> void:
	var q: Array = _queue()
	var i := q.size() - 1
	while i >= 0:
		q[i]["turns_left"] = int(q[i].get("turns_left", 0)) - 1
		if int(q[i].get("turns_left", 0)) <= 0:
			var cell := Vector2i(int(q[i].get("x", 0)), int(q[i].get("y", 0)))
			var army := _build_army(q[i].get("units", []))
			if not army.is_empty() and _stack_count() < GameSettings.MAP_ENEMY_COUNT and _can_spawn_at(cell):
				_map_gen.enemy_stacks[cell] = army
				_world_delta.defeated_enemies.erase(cell)
				if _spawner != null and _spawner.has_method("spawn_enemy_visual"):
					_spawner.spawn_enemy_visual(cell, army)
				report["respawns"] = int(report.get("respawns", 0)) + 1
				GameLogger.world("Enemy stack respawned at %s (weakened)" % str(cell))
			q.remove_at(i)
		i -= 1


func _process_season(season: int, report: Dictionary) -> void:
	if _last_season == -1:
		_last_season = season
		return
	if season == _last_season:
		return
	_last_season = season
	var rng_units: Node = ServiceLocator.resolve(null, &"units")
	if rng_units == null or _faction_sets.is_empty():
		return
	while _stack_count() < GameSettings.MAP_ENEMY_COUNT:
		var cell := _find_frontier_cell()
		if cell == Vector2i(-1, -1):
			break
		var army := _random_army(rng_units)
		if army.is_empty():
			continue
		_map_gen.enemy_stacks[cell] = army
		report["season_spawns"] = int(report.get("season_spawns", 0)) + 1
		if _spawner != null and _spawner.has_method("spawn_enemy_visual"):
			_spawner.spawn_enemy_visual(cell, army)
	GameLogger.world("New season: enemy stacks = %d / %d" % [_stack_count(), GameSettings.MAP_ENEMY_COUNT])


func _queue() -> Array:
	var q: Variant = _world_delta.enemy_growth_state.get("respawn_queue", null)
	if q == null:
		q = []
		_world_delta.enemy_growth_state["respawn_queue"] = q
	return q


func _stack_count() -> int:
	return _map_gen.enemy_stacks.size()


func _can_spawn_at(cell: Vector2i) -> bool:
	if _map_gen == null or not _map_gen.is_walkable(cell):
		return false
	if _map_gen.enemy_stacks.has(cell) or _map_gen.resource_cells.has(cell) or _map_gen.village_cells.has(cell):
		return false
	if _cities_mgr != null and _cities_mgr.city_at(cell) != null:
		return false
	return true


## Граница карты: рамка SPAWN_ENEMY_MIN_BORDER, как в MapSpawner.place_enemies.
func _find_frontier_cell() -> Vector2i:
	var border: int = GameSettings.SPAWN_ENEMY_MIN_BORDER
	for attempt in 200:
		var cell := Vector2i(
			_rng.randi_range(border, _map_gen.map_width - border - 1),
			_rng.randi_range(border, _map_gen.map_height - border - 1)
		)
		if _can_spawn_at(cell):
			return cell
	return Vector2i(-1, -1)


func _random_army(units_reg: Node) -> Array:
	var faction: Array = _faction_sets[_rng.randi() % _faction_sets.size()]
	var n: int = _rng.randi_range(1, mini(3, faction.size()))
	var army: Array = []
	var picked: Array = []
	for i in faction.size():
		if picked.size() >= n:
			break
		picked.append(i)
	for i in picked:
		var stack = units_reg.make_stack(String(faction[i]), _rng)
		if stack != null:
			army.append(stack)
	return army


func _build_army(units: Array) -> Array:
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	if units_reg == null:
		return []
	var army: Array = []
	for u in units:
		var stack = units_reg.make_fixed_stack(String(u.get("key", "")), int(u.get("count", 1)))
		if stack != null:
			army.append(stack)
	return army
