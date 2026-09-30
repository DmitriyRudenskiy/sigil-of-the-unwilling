extends BaseTest
## Генераторы карты: реки, дороги, горы, лес + pathfinding-стоимости.
## Критерии из openspec/changes/map-generation-improvement (Tasks 3–10, 11).

const _HexUtils = preload("res://scripts/core/hex_utils.gd")
const _HexPathfinding = preload("res://scripts/core/hex_pathfinding.gd")
const _TerrainCostTable = preload("res://scripts/data/terrain_cost_table.gd")

const MAP_SIZE := 60

func _gen_map(seed: int) -> MapGenerator:
	var gen: MapGenerator = make_node(MapGenerator)
	gen._seed_value = seed
	gen._map_width = MAP_SIZE
	gen._map_height = MAP_SIZE
	gen.generate()
	return gen

# --- Task 3: направление течения рек (только вниз по градиенту) ---

func test_rivers_flow_downhill() -> void:
	for seed in [42, 7, 2024]:
		var model: MapModel = _gen_map(seed).model
		if model.river_grid.is_empty():
			continue
		var components: Array[Dictionary] = []
		var seen: Dictionary = {}
		for cell in model.river_grid:
			if seen.has(cell):
				continue
			var comp: Array[Vector2i] = []
			var queue: Array[Vector2i] = [cell]
			seen[cell] = true
			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				comp.append(cur)
				for nb in _HexUtils.get_all_neighbors(cur):
					if model.river_grid.has(nb) and not seen.has(nb):
						seen[nb] = true
						queue.append(nb)
			components.append({ "tiles": comp, "min_h": _min_height(model, comp) })
		var bad := 0
		for cell in model.river_grid:
			var h: float = model.height_grid[cell]
			var has_lower_river_nb := false
			for nb in _HexUtils.get_all_neighbors(cell):
				if model.river_grid.has(nb) and model.height_grid[nb] < h:
					has_lower_river_nb = true
					break
			if has_lower_river_nb:
				continue
			# Яма компонента: допустимо только для самой низкой точки
			for c in components:
				if (c.tiles as Array).has(cell):
					if h > (c.min_h as float) + 0.0001:
						bad += 1
					break
		assert_that(bad).is_equal(0)

func _min_height(model: MapModel, tiles: Array) -> float:
	var m := INF
	for t in tiles:
		m = minf(m, model.height_grid[t])
	return m

# --- Task 4: все деревни соединены дорогами ---

func test_villages_connected_by_roads() -> void:
	for seed in [42, 7]:
		var model: MapModel = _gen_map(seed).model
		assert_that(model.village_cells.size()).is_greater(1)
		assert_that(model.road_grid.is_empty()).is_false()
		var start: Vector2i = model.village_cells[0]
		var reached: Dictionary = { start: true }
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for nb in _HexUtils.get_all_neighbors(cur):
				if model.is_road(nb) and not reached.has(nb):
					reached[nb] = true
					queue.append(nb)
		for v in model.village_cells:
			assert_that(reached.has(v)).is_true()

# --- Task 5: горы образуют связные хребты, не одиночные тайлы ---

func test_mountain_ranges_form_chains() -> void:
	var model: MapModel = _gen_map(42).model
	var mountain_tiles: Array[Vector2i] = []
	for cell in model.terrain_grid:
		var t: int = model.terrain_grid[cell]
		if t == _HexUtils.Terrain.MOUNTAIN or t == _HexUtils.Terrain.SNOW:
			mountain_tiles.append(cell)
	assert_that(mountain_tiles.size()).is_greater(0)
	var seen: Dictionary = {}
	var largest := 0
	var isolated := 0
	for cell in mountain_tiles:
		if seen.has(cell):
			continue
		var comp: Array[Vector2i] = [cell]
		var queue: Array[Vector2i] = [cell]
		seen[cell] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for nb in _HexUtils.get_all_neighbors(cur):
				if mountain_tiles.has(nb) and not seen.has(nb):
					seen[nb] = true
					comp.append(nb)
					queue.append(nb)
		largest = max(largest, comp.size())
		if comp.size() == 1:
			isolated += 1
	var total := mountain_tiles.size()
	assert_that(isolated * 100 / total).is_less(25)
	assert_that(largest * 100 / total).is_greater_equal(30)

# --- Task 6: лесная покрываемость ~ 25% ---

func test_forest_coverage_near_target() -> void:
	var model: MapModel = _gen_map(42).model
	var placed := 0
	for cluster in model.forest_clusters:
		placed += (cluster.tiles as Array).size()
	var total := MAP_SIZE * MAP_SIZE
	var ratio: float = float(placed) / float(total)
	assert_that(ratio).is_between(0.15, 0.32)

# --- Task 7: время генерации 60x60 < 2 сек ---

func test_generation_time_under_2s() -> void:
	var t0 := Time.get_ticks_msec()
	_gen_map(42)
	var ms := Time.get_ticks_msec() - t0
	assert_that(ms).is_less(2000)

# --- Task 8/9: рендер и тайлсет не падают на новых типах ---

func test_renderer_paints_new_terrain() -> void:
	var gen: MapGenerator = _gen_map(42)
	assert_that(gen.has_valid_tilemap()).is_true()
	assert_that(gen._tile_map.get_used_cells().size()).is_greater(0)

# --- Task 10: юниты предпочитают дороги ---

func test_pathfinding_prefers_road() -> void:
	_TerrainCostTable.ensure()
	var w := 10
	var h := 6
	var terrain: Dictionary = {}
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var t := _HexUtils.Terrain.SWAMP
			if y == 0 or x == w - 1:
				t = _HexUtils.Terrain.ROAD
			terrain[cell] = t
	var start := Vector2i(0, 0)
	var goal := Vector2i(w - 1, 4)
	var cost := func(cell: Vector2i) -> float:
		return _TerrainCostTable.get_cost_with_effects_by_id(terrain[cell], false)
	var path: Array = _HexPathfinding.astar(start, goal, {}, cost, w, h)
	assert_that(path.size()).is_greater(0)
	var on_road := 0
	for c in path:
		if terrain[c] == _HexUtils.Terrain.ROAD:
			on_road += 1
	assert_that(on_road).is_greater(path.size() / 2)

# --- Task 10: река — препятствие без моста, проходима с мостом ---

func test_river_blocks_without_bridge() -> void:
	var w := 7
	var h := 5
	var terrain: Dictionary = {}
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			terrain[cell] = _HexUtils.Terrain.RIVER if x == 3 else _HexUtils.Terrain.GRASS
	var start := Vector2i(1, 2)
	var goal := Vector2i(5, 2)

	var model_no_bridge := _make_model(w, h, terrain, {})
	assert_that(model_no_bridge.is_walkable(Vector2i(3, 2))).is_false()
	var path: Array = _HexPathfinding.astar_path(start, goal, model_no_bridge.get_blocked_cells(), w, h)
	assert_that(path.size()).is_equal(0)

	var model_bridge := _make_model(w, h, terrain, { Vector2i(3, 2): true })
	assert_that(model_bridge.is_walkable(Vector2i(3, 2))).is_true()
	var path2: Array = _HexPathfinding.astar_path(start, goal, model_bridge.get_blocked_cells(), w, h)
	assert_that(path2.size()).is_greater(0)
	assert_that(path2.has(Vector2i(3, 2))).is_true()

func _make_model(w: int, h: int, terrain: Dictionary, bridges: Dictionary) -> MapModel:
	var m := MapModel.new()
	m.map_width = w
	m.map_height = h
	m.terrain_grid = terrain
	m.bridge_cells = bridges
	return m

# --- Task 10: мосты сгенерированных карт согласованы (дорога + река) ---

func test_generated_bridges_consistent() -> void:
	for seed in [42, 7, 2024]:
		var model: MapModel = _gen_map(seed).model
		for b in model.bridge_cells:
			assert_that(model.river_grid.has(b)).is_true()
			assert_that(model.road_grid.has(b)).is_true()
