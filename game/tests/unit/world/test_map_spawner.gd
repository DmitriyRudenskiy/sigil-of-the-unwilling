extends GdUnitTestSuite

func _make_grass_model(w: int, h: int) -> MapModel:
	var model := MapModel.new()
	model.map_width = w
	model.map_height = h
	for y in h:
		for x in w:
			model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	return model

func test_place_villages_respects_count() -> void:
	var model := _make_grass_model(24, 24)
	model.village_count = 4
	var spawner := MapSpawner.new(model)
	spawner.place_villages()
	assert_int(model.village_cells.size()).is_equal(4)

func test_place_villages_enforces_spacing() -> void:
	var model := _make_grass_model(24, 24)
	model.village_count = 6
	var spawner := MapSpawner.new(model)
	spawner.place_villages()
	for i in model.village_cells.size():
		for j in range(i + 1, model.village_cells.size()):
			assert_int(HexUtils.hex_distance(model.village_cells[i], model.village_cells[j])).is_greater(3)

func test_place_villages_walkable_only() -> void:
	var model := _make_grass_model(24, 24)
	for y in 24:
		model.terrain_grid[Vector2i(12, y)] = HexUtils.Terrain.WATER
	model.village_count = 3
	var spawner := MapSpawner.new(model)
	spawner.place_villages()
	for cell in model.village_cells:
		assert_bool(model.is_walkable(cell)).is_true()

func test_place_villages_clears_previous() -> void:
	var model := _make_grass_model(24, 24)
	model.village_count = 2
	var spawner := MapSpawner.new(model)
	spawner.place_villages()
	var first := model.village_cells.duplicate()
	assert_int(first.size()).is_equal(2)
	spawner.place_villages()
	assert_int(model.village_cells.size()).is_equal(2)
