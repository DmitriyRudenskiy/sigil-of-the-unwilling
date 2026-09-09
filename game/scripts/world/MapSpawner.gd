class_name MapSpawner
extends RefCounted

const _MapModel = preload("res://scripts/world/MapModel.gd")

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
		model.village_cells.append(cell)
		for y in range(cell.y - spacing, cell.y + spacing + 1):
			for x in range(cell.x - spacing, cell.x + spacing + 1):
				var nb := Vector2i(x, y)
				if HexUtils.hex_distance(cell, nb) <= spacing:
					blocked[nb] = true

func place_resources(reachable = null, spacing := -1) -> void:
	model.resource_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 700
	if spacing < 0:
		spacing = clampi(
			int(float(model.map_width) / GameNumbers.MAP_RESOURCE_SPACING_DIVISOR),
			GameNumbers.MAP_RESOURCE_SPACING_MIN, GameNumbers.MAP_RESOURCE_SPACING_MAX)

	if reachable == null:
		reachable = _get_reachable_cells()

	var candidates: Array[Vector2i] = []
	for cell in model.terrain_grid:
		if not reachable.has(cell):
			continue
		var t: int = model.terrain_grid[cell]
		if t == HexUtils.Terrain.WATER or t == HexUtils.Terrain.MOUNTAIN:
			continue
		if model.village_cells.has(cell):
			continue
		candidates.append(cell)

	for i in candidates.size():
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var blocked: Dictionary = {}
	var target := GameNumbers.MAP_RESOURCE_COUNT
	for cell in candidates:
		if model.resource_cells.size() >= target:
			break
		if blocked.has(cell):
			continue
		model.resource_cells[cell] = rng.randi_range(0, 6)
		for y in range(cell.y - spacing, cell.y + spacing + 1):
			for x in range(cell.x - spacing, cell.x + spacing + 1):
				var nb := Vector2i(x, y)
				if HexUtils.hex_distance(cell, nb) <= spacing:
					blocked[nb] = true

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

	var candidates: Array[Vector2i] = []
	for cell in reachable:
		if cell in model.village_cells or model.resource_cells.has(cell):
			continue

		if cell.x < 3 or cell.x >= model.map_width - 4 or cell.y < 3 or cell.y >= model.map_height - 4:
			continue
		candidates.append(cell)

	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var placed := 0

	var reg: Node = Services.resolve(&"units")
	for cell in candidates:
		if placed >= GameNumbers.MAP_ENEMY_COUNT:
			break

		var faction_idx: int = rng.randi_range(0, reg.FACTION_SETS.size() - 1)
		var faction_pool: Array = reg.FACTION_SETS[faction_idx]
		var army: Array[UnitStack] = []

		var unit_count := rng.randi_range(1, 3)
		for i in unit_count:
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
	return HexPathfinding.bfs_reachable(start_cell, model.map_width + model.map_height,
		model.get_blocked_cells(), model.map_width, model.map_height)
