class_name MapSpawner
extends RefCounted
## Размещение объектов: деревни, ресурсы, декор, враги.

const _MapModel = preload("res://scripts/map/MapModel.gd")

var model


func _init(p_model) -> void:
	model = p_model


func place_villages() -> void:
	model.village_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 500
	var attempts := 0
	while model.village_cells.size() < model.village_count and attempts < 1000:
		attempts += 1
		var cell := Vector2i(rng.randi_range(2, model.map_width - 3), rng.randi_range(2, model.map_height - 3))
		if _is_valid_village_location(cell):
			model.village_cells.append(cell)


func place_resources() -> void:
	model.resource_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 700
	var target := int(float(model.map_width * model.map_height) / 70.0)
	var attempts := 0
	while model.resource_cells.size() < target and attempts < 5000:
		attempts += 1
		var cell := Vector2i(rng.randi_range(0, model.map_width - 1), rng.randi_range(0, model.map_height - 1))
		if not model.terrain_grid.has(cell):
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


func place_enemies() -> void:
	model.enemy_stacks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 777
	var placed := 0
	var attempts := 0
	while placed < 15 and attempts < 5000:
		attempts += 1
		var cell := Vector2i(rng.randi_range(3, model.map_width - 4), rng.randi_range(3, model.map_height - 4))
		if not model.is_walkable(cell) or model.enemy_stacks.has(cell) or cell in model.village_cells or model.resource_cells.has(cell):
			continue

				var faction_idx: int = rng.randi_range(0, UnitRegistry.FACTION_SETS.size() - 1)
		var faction_pool: Array = UnitRegistry.FACTION_SETS[faction_idx]
		var army: Array[UnitStack] = []
		for i in rng.randi_range(1, 3):
			var unit_key: String = faction_pool[rng.randi_range(0, faction_pool.size() - 1)]
			var stack = UnitRegistry.make_stack(unit_key, rng)
			if stack != null and stack.is_alive():
				army.append(stack)

		if army.size() > 0:
			model.enemy_stacks[cell] = army
			placed += 1


func _is_valid_village_location(cell: Vector2i) -> bool:
	if not model.terrain_grid.has(cell):
		return false
	if model.terrain_grid[cell] in [HexUtils.Terrain.WATER, HexUtils.Terrain.MOUNTAIN]:
		return false
	for v in model.village_cells:
		if HexUtils.hex_distance(cell, v) <= 2:
			return false
	return true
