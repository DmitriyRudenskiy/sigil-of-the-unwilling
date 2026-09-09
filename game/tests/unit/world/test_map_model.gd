extends GdUnitTestSuite

const MapModelScript = preload("res://scripts/world/MapModel.gd")

func test_generation() -> void:
	var model: RefCounted = MapModelScript.new()
	model.map_width = 20
	model.map_height = 20
	model.seed_value = 42
	model.generate_noise()

	assert_int(model.terrain_grid.size()).is_equal(400).override_failure_message("terrain_grid should contain 400 cells")
	assert_int(model.height_grid.size()).is_equal(400).override_failure_message("height_grid should contain 400 cells")

func test_determinism() -> void:
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

	assert_bool(a.terrain_grid == b.terrain_grid).is_true().override_failure_message("same seed should produce same terrain_grid")

	var c: RefCounted = MapModelScript.new()
	c.map_width = 16
	c.map_height = 16
	c.seed_value = 999
	c.generate_noise()

	assert_bool(a.terrain_grid == c.terrain_grid).is_false().override_failure_message("different seeds should usually produce different terrain")

func test_biome_logic() -> void:
	var model: RefCounted = MapModelScript.new()

	assert_int(model.get_biome_terrain_id(0.10, 0.5, 0.5)).is_equal(HexUtils.Terrain.WATER).override_failure_message("low height should be water")
	assert_int(model.get_biome_terrain_id(0.36, 0.5, 0.7)).is_equal(HexUtils.Terrain.SWAMP).override_failure_message("low land + high moisture should be swamp")
	assert_int(model.get_biome_terrain_id(0.38, 0.5, 0.3)).is_equal(HexUtils.Terrain.SAND).override_failure_message("dry low land should be sand")
	assert_int(model.get_biome_terrain_id(0.50, 0.5, 0.5)).is_equal(HexUtils.Terrain.GRASS).override_failure_message("normal land should be grass")
	assert_int(model.get_biome_terrain_id(0.80, 0.5, 0.5)).is_equal(HexUtils.Terrain.FOREST).override_failure_message("high moist highland should be forest")
	assert_int(model.get_biome_terrain_id(0.90, 0.6, 0.5)).is_equal(HexUtils.Terrain.MOUNTAIN).override_failure_message("very high warm terrain should be mountain")
	assert_int(model.get_biome_terrain_id(0.90, 0.1, 0.5)).is_equal(HexUtils.Terrain.SNOW).override_failure_message("very high cold terrain should be snow")

func test_walkability() -> void:
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
			assert_bool(terrain_id != HexUtils.Terrain.WATER and terrain_id != HexUtils.Terrain.MOUNTAIN).is_true().override_failure_message("walkable cell cannot be water or mountain")
		else:
			assert_bool(terrain_id == HexUtils.Terrain.WATER or terrain_id == HexUtils.Terrain.MOUNTAIN).is_true().override_failure_message("blocked cell should be water or mountain")

	assert_int(walkable).is_greater(0).override_failure_message("map should have at least one walkable cell")

	var blocked: Dictionary = model.get_blocked_cells()
	assert_int(blocked.size()).is_equal(model.terrain_grid.size() - walkable).override_failure_message("blocked cells count mismatch")
