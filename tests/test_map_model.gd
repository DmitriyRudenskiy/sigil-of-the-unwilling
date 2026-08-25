extends SceneTree
## Тесты MapModel: генерация, детерминизм, биомы, проходимость.

const MapModelScript = preload("res://scripts/map/MapModel.gd")

func _init() -> void:
	var failed := 0
	failed += _test_generation()
	failed += _test_determinism()
	failed += _test_biome_logic()
	failed += _test_walkability()

	if failed == 0:
		print("MapModel tests passed")
	else:
		printerr("MapModel tests failed: ", failed)
	quit(1 if failed > 0 else 0)


func _test_generation() -> int:
	var errors := 0
	var model: RefCounted = MapModelScript.new()
	model.map_width = 20
	model.map_height = 20
	model.seed_value = 42
	model.generate_noise()

	if model.terrain_grid.size() != 400:
		printerr("terrain_grid should contain 400 cells")
		errors += 1
	if model.height_grid.size() != 400:
		printerr("height_grid should contain 400 cells")
		errors += 1
	return errors


func _test_determinism() -> int:
	var errors := 0
	var a: RefCounted = MapModelScript.new()
	a.map_width = 16
	a.map_height = 16
	a.seed_value = 123
	a.generate_noise()

	var b: RefCounted = MapModelScript.new()
	b.map_width = 16
	b.map_height = 16
	b.seed_value = 123
	b.generate_noise()

	if a.terrain_grid != b.terrain_grid:
		printerr("same seed should produce same terrain_grid")
		errors += 1

	var c: RefCounted = MapModelScript.new()
	c.map_width = 16
	c.map_height = 16
	c.seed_value = 999
	c.generate_noise()

	if a.terrain_grid == c.terrain_grid:
		printerr("different seeds should usually produce different terrain")
		errors += 1
	return errors


func _test_biome_logic() -> int:
	var errors := 0
	var model: RefCounted = MapModelScript.new()

	if model.get_biome_terrain_id(0.10, 0.5, 0.5) != HexUtils.Terrain.WATER:
		printerr("low height should be water")
		errors += 1
	if model.get_biome_terrain_id(0.36, 0.5, 0.7) != HexUtils.Terrain.SWAMP:
		printerr("low land + high moisture should be swamp")
		errors += 1
	if model.get_biome_terrain_id(0.38, 0.5, 0.3) != HexUtils.Terrain.SAND:
		printerr("dry low land should be sand")
		errors += 1
	if model.get_biome_terrain_id(0.50, 0.5, 0.5) != HexUtils.Terrain.GRASS:
		printerr("normal land should be grass")
		errors += 1
	if model.get_biome_terrain_id(0.80, 0.5, 0.5) != HexUtils.Terrain.FOREST:
		printerr("high moist highland should be forest")
		errors += 1
	if model.get_biome_terrain_id(0.90, 0.6, 0.5) != HexUtils.Terrain.MOUNTAIN:
		printerr("very high warm terrain should be mountain")
		errors += 1
	if model.get_biome_terrain_id(0.90, 0.1, 0.5) != HexUtils.Terrain.SNOW:
		printerr("very high cold terrain should be snow")
		errors += 1
	return errors


func _test_walkability() -> int:
	var errors := 0
	var model: RefCounted = MapModelScript.new()
	model.map_width = 10
	model.map_height = 10
	model.seed_value = 7
	model.generate_noise()

	var walkable := 0
	for cell in model.terrain_grid:
		var terrain_id: int = model.terrain_grid[cell]
		if model.is_walkable(cell):
			walkable += 1
			if terrain_id == HexUtils.Terrain.WATER or terrain_id == HexUtils.Terrain.MOUNTAIN:
				printerr("walkable cell cannot be water or mountain")
				errors += 1
		else:
			if terrain_id != HexUtils.Terrain.WATER and terrain_id != HexUtils.Terrain.MOUNTAIN:
				printerr("blocked cell should be water or mountain")
				errors += 1

	if walkable == 0:
		printerr("map should have at least one walkable cell")
		errors += 1

	var blocked: Dictionary = model.get_blocked_cells()
	if blocked.size() != model.terrain_grid.size() - walkable:
		printerr("blocked cells count mismatch")
		errors += 1
	return errors
