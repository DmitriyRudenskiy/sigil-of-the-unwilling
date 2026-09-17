extends BaseTest

# map-generation-improvement: верификация генераторов (река/дорога/гора/лес)

const _MOUNTAIN: int = HexUtils.Terrain.MOUNTAIN
const _FOREST: int = HexUtils.Terrain.DENSE_FOREST

func _model(w := 40, h := 40, seed := 42) -> MapModel:
	var m := MapModel.new()
	m.map_width = w
	m.map_height = h
	m.seed_value = seed
	m.generate_noise()
	return m

func test_river_flows_downhill() -> void:
	var m := _model()
	var gen := MapRiverGenerator.new(m)
	gen.generate()
	assert_bool(m.river_grid.size() > 0).override_failure_message("рек нет")
	# каждая река стекает вниз: сосед по течению не выше (за вычетом шума)
	var violations := 0
	for cell in m.river_grid:
		var h0: float = m.height_grid.get(cell, 0.5)
		var lowest := h0
		for nb in HexUtils.get_all_neighbors(cell):
			if m.terrain_grid.get(nb, 0) == HexUtils.Terrain.WATER:
				lowest = minf(lowest, -1.0)
				break
			lowest = minf(lowest, float(m.height_grid.get(nb, 0.5)))
		if lowest > h0 + 0.05:
			violations += 1
	assert_bool(violations <= m.river_grid.size() / 10) \
		.override_failure_message("рек против градиента: %d" % violations)

func test_roads_connect_villages() -> void:
	var m := _model(40, 40, 5)
	m.village_count = 5
	m.village_cells = _place_villages(m)
	var gen := MapRoadGenerator.new(m)
	gen.generate()
	assert_bool(m.road_grid.size() > 0).override_failure_message("дорог нет")
	# BFS по дорогам: все деревни в одном компоненте
	var start: Vector2i = m.village_cells[0]
	var visited: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for nb in HexUtils.get_all_neighbors(cell):
			if visited.has(nb) or not _road_reachable(m, cell, nb):
				continue
			visited[nb] = true
			queue.append(nb)
	for v in m.village_cells:
		assert_bool(visited.has(v)).override_failure_message("деревня не достижима: " + str(v))

func _road_reachable(m: MapModel, a: Vector2i, b: Vector2i) -> bool:
	# по дороге или через узел дороги/деревню
	if m.road_grid.has(a) or m.road_grid.has(b):
		return true
	return false

func _place_villages(m: MapModel) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var step := m.map_width / 6
	for i in m.village_count:
		var cell := Vector2i(step * (i + 1), step * (i % 3 + 1))
		cells.append(cell)
	return cells

func test_mountains_form_chains() -> void:
	var m := _model(40, 40, 9)
	var gen := MapMountainGenerator.new(m)
	gen.generate()
	var mountains: Array = []
	for cell in m.terrain_grid:
		if m.terrain_grid[cell] == _MOUNTAIN:
			mountains.append(cell)
	assert_bool(mountains.size() > 0).override_failure_message("гор нет")
	# не изолированные: хотя бы половина гор имеют горного соседа
	var with_neighbor := 0
	for cell in mountains:
		for nb in HexUtils.get_all_neighbors(cell):
			if m.terrain_grid.get(nb, 0) == _MOUNTAIN:
				with_neighbor += 1
				break
	assert_bool(with_neighbor * 2 >= mountains.size()) \
		.override_failure_message("горы изолированы: %d/%d" % [with_neighbor, mountains.size()])

func test_forest_coverage_near_target() -> void:
	var m := _model(50, 50, 21)
	var gen := MapForestGenerator.new(m)
	gen.generate()
	assert_bool(m.forest_clusters.size() > 0).override_failure_message("лесных кластеров нет")
	var forest_tiles := 0
	for cell in m.terrain_grid:
		if m.terrain_grid[cell] == _FOREST:
			forest_tiles += 1
	var total: int = m.map_width * m.map_height
	var pct: float = 100.0 * float(forest_tiles) / float(total)
	# цель 25%, допускаем 5–45% (зависит от биомов)
	assert_bool(pct >= 5.0 and pct <= 45.0).override_failure_message("покрытие леса: %.1f%%" % pct)

func test_generation_time_under_2s() -> void:
	var t := Time.get_ticks_msec()
	var mg := MapGenerator.new()
	mg.seed_value = 99
	mg.map_width = 60
	mg.map_height = 60
	mg.generate()
	var dt := Time.get_ticks_msec() - t
	assert_bool(dt < 2000).override_failure_message("генерация 60x60: %d мс" % dt)
	mg.free()

func test_river_blocks_without_bridge() -> void:
	var m := _model()
	var cell := Vector2i(20, 20)
	m.terrain_grid[cell] = HexUtils.Terrain.GRASS
	m.river_grid[cell] = 1.0
	assert_bool(not m.is_walkable(cell)).override_failure_message("река без моста проходимая")
	m.road_grid[cell] = 0
	assert_bool(m.is_walkable(cell)).override_failure_message("мост (дорога) не делает реку проходимой")

func test_road_is_cheaper_than_grass() -> void:
	TerrainCostTable.ensure()
	assert_bool(TerrainCostTable.ROAD < TerrainCostTable.GRASS) \
		.override_failure_message("дорога должна быть дешевле травы")
