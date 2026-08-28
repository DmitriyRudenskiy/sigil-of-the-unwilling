class_name MapSpawner
extends RefCounted
## Размещение объектов: деревни, ресурсы, декор, враги.

const _MapModel = preload("res://world/MapModel.gd")

var model
var _units_registry: Node = null

func setup_registry(units_registry: Node) -> void:
	_units_registry = units_registry


func _init(p_model) -> void:
	model = p_model


func place_villages() -> void:
	model.village_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 500

	# Port: ForlornU/HexagonalMapGodot object_placer.gd (MIT)
	# Poisson-disc placement: shuffle candidates, single pass, ring-distance guard.
	var candidates: Array[Vector2i] = []
	for cell in model.terrain_grid:
		if model.is_walkable(cell):
			candidates.append(cell)
	for i in candidates.size():
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var spacing: int = 4
	var blocked: Dictionary = {}

	for cell in candidates:
		if model.village_cells.size() >= model.village_count:
			break
		if blocked.has(cell):
			continue
		# O(n) вместо O(n²): помечаем всё кольцо spacing=4 сразу
		model.village_cells.append(cell)
		for y in range(cell.y - spacing, cell.y + spacing + 1):
			for x in range(cell.x - spacing, cell.x + spacing + 1):
				var nb := Vector2i(x, y)
				if HexUtils.hex_distance(cell, nb) <= spacing:
					blocked[nb] = true


func place_resources(reachable = null) -> void:
	model.resource_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 700
	
	if reachable == null:
		reachable = _get_reachable_cells()
	var target := GameSettings.MAP_RESOURCE_COUNT  # РФ7-3
	var attempts := 0
	while model.resource_cells.size() < target and attempts < 5000:
		attempts += 1
		var cell := Vector2i(rng.randi_range(0, model.map_width - 1), rng.randi_range(0, model.map_height - 1))
		if not reachable.has(cell):
			continue
		if model.terrain_grid[cell] in [HexUtils.Terrain.WATER, HexUtils.Terrain.MOUNTAIN]:
			continue
		if model.resource_cells.has(cell) or cell in model.village_cells:
			continue
		model.resource_cells[cell] = rng.randi_range(0, 6)


func place_decor() -> void:
	model.decor_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 900
	for cell in model.terrain_grid:
		if model.terrain_grid[cell] == HexUtils.Terrain.SAND and rng.randf() < 0.04:
			model.decor_cells[cell] = "palm" if rng.randf() > 0.5 else "cactus"


func place_enemies(reachable = null) -> void:
	model.enemy_stacks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 777
	
	if reachable == null:
		reachable = _get_reachable_cells()
	var placed := 0
	var attempts := 0
	while placed < GameSettings.MAP_ENEMY_COUNT and attempts < 5000:  # РФ7-3
		attempts += 1
		var cell := Vector2i(rng.randi_range(3, model.map_width - 4), rng.randi_range(3, model.map_height - 4))
		if not reachable.has(cell) or model.enemy_stacks.has(cell) or cell in model.village_cells or model.resource_cells.has(cell):
			continue

		var reg: Node = ServiceLocator.resolve(_units_registry, &"units")
		var faction_idx: int = rng.randi_range(0, reg.FACTION_SETS.size() - 1)
		var faction_pool: Array = reg.FACTION_SETS[faction_idx]
		var army: Array[UnitStack] = []
		for i in rng.randi_range(1, 3):
			var unit_key: String = faction_pool[rng.randi_range(0, faction_pool.size() - 1)]
			var stack = reg.make_stack(unit_key, rng)
			if stack != null and stack.is_alive():
				army.append(stack)

		if army.size() > 0:
			model.enemy_stacks[cell] = army
			placed += 1



func _get_reachable_cells() -> Dictionary:
	var start_cell := Vector2i(-1, -1)
	for y in model.map_height:
		for x in model.map_width:
			var cell := Vector2i(x, y)
			if model.is_walkable(cell):
				start_cell = cell
				break
		if start_cell.x >= 0: break
	if start_cell.x < 0:
		return {}
	# Переиспользуем кэшированную BFS из HexUtils
	return HexUtils.bfs_reachable(start_cell, model.map_width + model.map_height,
		model.get_blocked_cells(), model.map_width, model.map_height)
