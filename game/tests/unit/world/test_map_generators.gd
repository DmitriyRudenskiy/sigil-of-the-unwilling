extends BaseTest
## Контракт генераторов рельефа, рек и лесов (T-227 С-4).
##
## Три генератора (`MapMountainGenerator`, `MapRiverGenerator`,
## `MapForestGenerator`) — часть живого пайплайна `MapGenerator.generate()`, но
## тестов у них не было: проверяли только то, что слои отрисованы и проходимость
## не сломалась (`test_map_layers.gd`). Дыра стоила того: генераторы пишут в одну
## модель в фиксированном порядке, и порядок этот никем не скреплён.
##
## Что закрепляется (и почему именно это):
## — детерминированность по seed: мир обязан восстанавливаться из зерна, иначе
##   сохранение игры молча рисует другую карту;
## — «высота ≥ 0.85 ⇒ СНЕГ или ГОРА» — правило `_apply_snow_caps`, перестановка
##   порогов меняет проходимость и расстановку;
## — реки текут вниз: источник обязан стоять на возвышенности (`MIN_ELEVATION`),
##   короткая цепочка (длиннее `MIN_LENGTH` не набралась) отбрасывается, а не
##   рисуется ручьём-в-одну-клетку;
## — лес: плотность кластера диктует закрашивание (`_apply_forest_terrain`),
##   кластеры расставлены с шагом `min_spacing`, а суммарное число клеток кластеров
##   ограничено `FOREST_COVERAGE` (иначе цикл `generate()` не имеет смысла).
##
## Намеренно НЕ закрепляется: «сколько именно процентов карты станет лесом».
## Закрашивается примерно вдвое меньше клеток, чем набирают кластеры (`_apply_forest_terrain`
## не красит кластеры с плотностью ≤ 0.4) — расхождение настройки и результата заведено
## отдельным тикетом, а не узаконено числом в тесте.

const _Hex = preload("res://scripts/core/hex_utils.gd")


# ── фикстуры ──────────────────────────────────────────────────────────────

func _model(seed_value: int, w: int = 40, h: int = 40) -> MapModel:
	var m := MapModel.new()
	m.map_width = w
	m.map_height = h
	m.seed_value = seed_value
	m.generate_noise()
	m.smooth_invalid_adjacencies()
	return m


## Однородный мир без шума: единственная честная фикстура для правил, которые
## зависят от рельефа, а не от удачи.
func _flat(w: int, h: int, height: float, terrain: int) -> MapModel:
	var m := MapModel.new()
	m.map_width = w
	m.map_height = h
	m.seed_value = 7
	for y in h:
		for x in w:
			m.height_grid[Vector2i(x, y)] = height
			m.terrain_grid[Vector2i(x, y)] = terrain
	return m


## Пологий уклон на восток: единственный способ заставить воду течь детерминированно.
func _slope(w: int, h: int, terrain: int) -> MapModel:
	var m := MapModel.new()
	m.map_width = w
	m.map_height = h
	m.seed_value = 3
	for y in h:
		for x in w:
			m.height_grid[Vector2i(x, y)] = 0.95 - 0.02 * float(x)
			m.terrain_grid[Vector2i(x, y)] = terrain
	return m


func _pipeline(seed_value: int, w: int = 40, h: int = 40) -> Dictionary:
	var m := _model(seed_value, w, h)
	MapMountainGenerator.new(m).generate()
	MapRiverGenerator.new(m).generate()
	var before_forest: Dictionary = m.terrain_grid.duplicate()
	MapForestGenerator.new(m).generate()
	return {"model": m, "before_forest": before_forest}


func _sources(m: MapModel) -> Array[Vector2i]:
	# Источник реки — клетка, у которой нет соседней речной клетки строго выше.
	var out: Array[Vector2i] = []
	for cell in m.river_grid:
		var higher := false
		for n in _Hex.get_all_neighbors(cell):
			# .get(), а не []: мутант «реки уходят за край карты» обязан
			# покраснеть на проверке границ, а не уронить тест ключом словаря.
			if m.river_grid.has(n) and float(m.height_grid.get(n, 0.0)) > float(m.height_grid.get(cell, 0.0)):
				higher = true
				break
		if not higher:
			out.append(cell)
	return out


# ── детерминированность ───────────────────────────────────────────────────

func test_same_seed_reproduces_the_same_world() -> void:
	var a: Dictionary = _pipeline(4242)
	var b: Dictionary = _pipeline(4242)
	var ma: MapModel = a["model"]
	var mb: MapModel = b["model"]
	assert_that(ma.terrain_grid).is_equal(mb.terrain_grid)
	assert_that(ma.river_grid).is_equal(mb.river_grid)
	assert_that(ma.forest_clusters.size()).is_equal(mb.forest_clusters.size())


func test_different_seed_changes_the_world() -> void:
	var ma: MapModel = (_pipeline(1))["model"]
	var mb: MapModel = (_pipeline(2))["model"]
	assert_that(ma.terrain_grid != mb.terrain_grid).is_true()


# ── горы ──────────────────────────────────────────────────────────────────

func test_uplift_raises_a_flat_heightmap() -> void:
	var m := _flat(30, 30, 0.5, _Hex.Terrain.GRASS)
	MapMountainGenerator.new(m).generate()
	var highest: float = 0.0
	for cell in m.height_grid:
		highest = maxf(highest, float(m.height_grid[cell]))
	# Разлом обязан поднять рельеф на величину порядка UPLIFT_INTENSITY (0.4 ± 40%),
	# а не на «чуть-чуть от соседей»: при выключенном прямом поднятии остаётся
	# только окрестный вклад (≤ 0.5 × uplift), и порог 0.8 не берётся.
	assert_that(highest >= 0.8).is_true()


func test_high_ground_is_snow_or_mountain() -> void:
	# Проверяем по горячим следам: река, пересекающая вершину, перекрашивает её
	# в RIVER, а лес — в FOREST. Инвариант принадлежит генератору гор, а не
	# готовой карте.
	var m := _model(777)
	MapMountainGenerator.new(m).generate()
	var unclassified: Array = []
	for cell in m.height_grid:
		if float(m.height_grid[cell]) < 0.85:
			continue
		var terrain: int = m.terrain_grid.get(cell, -1)
		if terrain != _Hex.Terrain.SNOW and terrain != _Hex.Terrain.MOUNTAIN:
			unclassified.append(cell)
	# Правило `_apply_snow_caps`: всё, что поднялось выше 0.85, обязано получить
	# вершинную территорию. Пороги 0.85/0.9 переставлены — красным.
	assert_that(unclassified).is_empty()


func test_mountains_do_not_drown_the_map() -> void:
	var m: MapModel = (_pipeline(42))["model"]
	var lowest: float = 9.0
	for cell in m.height_grid:
		lowest = minf(lowest, float(m.height_grid[cell]))
	assert_that(lowest > 0.0).is_true()


# ── реки ──────────────────────────────────────────────────────────────────

func test_river_cells_are_painted_and_inside_the_map() -> void:
	var m: MapModel = (_pipeline(4242))["model"]
	assert_that(m.river_grid.size() > 0).is_true()
	var bad: Array = []
	for cell in m.river_grid:
		var outside: bool = cell.x < 0 or cell.y < 0 or cell.x >= m.map_width or cell.y >= m.map_height
		var terrain: int = m.terrain_grid.get(cell, -1)
		var painted: bool = terrain == _Hex.Terrain.RIVER or terrain == _Hex.Terrain.WATER
		if outside or not painted or float(m.river_grid[cell]) <= 0.0:
			bad.append(cell)
	assert_that(bad).is_empty()


func test_river_sources_stand_on_high_ground() -> void:
	for seed_value in [1, 42, 777]:
		var m: MapModel = (_pipeline(seed_value))["model"]
		var sources: Array[Vector2i] = _sources(m)
		assert_that(sources.size() > 0).is_true()
		for cell in sources:
			# MIN_ELEVATION = 0.75 — источник не может родиться в низине.
			assert_that(float(m.height_grid[cell]) >= 0.75).is_true()


func test_no_rivers_without_elevation() -> void:
	var m := _flat(30, 30, 0.5, _Hex.Terrain.GRASS)
	MapRiverGenerator.new(m).generate()
	assert_that(m.river_grid.size()).is_equal(0)


func test_no_rivers_on_a_water_world() -> void:
	# Уклон обязателен: на плоском водном мире реки не появилось бы и без
	# запрета источников в воде — проверка должна ловить именно запрет.
	var m := _slope(30, 12, _Hex.Terrain.WATER)
	MapRiverGenerator.new(m).generate()
	assert_that(m.river_grid.size()).is_equal(0)


func test_river_shorter_than_min_length_is_dropped() -> void:
	# Плоское плоскогорье: источники есть, но спускаться реке некуда — цепочка
	# из одной клетки не обязана появляться на карте ручьём.
	var m := _flat(30, 30, 0.9, _Hex.Terrain.GRASS)
	MapRiverGenerator.new(m).generate()
	assert_that(m.river_grid.size()).is_equal(0)


func test_sources_stay_away_from_the_shore() -> void:
	# Берег на западе, возвышенность — сразу за ним: источник не имеет права
	# родиться в прибрежной клетке, иначе река начинается в озере.
	var m := _slope(30, 12, _Hex.Terrain.GRASS)
	for y in 12:
		for x in 3:
			m.terrain_grid[Vector2i(x, y)] = _Hex.Terrain.WATER
	MapRiverGenerator.new(m).generate()
	var sources: Array[Vector2i] = _sources(m)
	assert_that(sources.size() > 0).is_true()
	for cell in sources:
		assert_that(cell.x >= 4).is_true()


func test_river_flows_downhill_to_the_low_edge() -> void:
	var m := _slope(30, 12, _Hex.Terrain.GRASS)
	MapRiverGenerator.new(m).generate()
	assert_that(m.river_grid.size() > 0).is_true()
	var sources: Array[Vector2i] = _sources(m)
	assert_that(sources.size() > 0).is_true()
	var farthest: int = 0
	for cell in m.river_grid:
		farthest = maxi(farthest, cell.x)
		if cell.x == 0:
			continue
		# Каждая клетка реки обязана быть ниже хотя бы одной соседней речной —
		# иначе вода течёт вверх или «прыгает» через водораздел.
		var higher: bool = false
		for n in _Hex.get_all_neighbors(cell):
			if m.river_grid.has(n) and float(m.height_grid.get(n, 0.0)) > float(m.height_grid.get(cell, 0.0)):
				higher = true
				break
		assert_that(higher).is_true()
	# Исток — на самом высоком краю, река — доходит до самого низкого.
	for cell in sources:
		assert_that(cell.x).is_equal(0)
	assert_that(farthest).is_equal(m.map_width - 1)


# ── леса ──────────────────────────────────────────────────────────────────

func test_forest_needs_suitable_terrain() -> void:
	# Песок и скалы имеют пригодность 0.0 — кластерам не откуда расти.
	var m := _flat(30, 30, 0.5, _Hex.Terrain.SAND)
	MapForestGenerator.new(m).generate()
	assert_that(m.forest_clusters.size()).is_equal(0)


func test_forest_clusters_keep_their_distance() -> void:
	var m: MapModel = (_pipeline(4242))["model"]
	assert_that(m.forest_clusters.size() > 0).is_true()
	var closest: int = 999
	for i in m.forest_clusters.size():
		for j in range(i + 1, m.forest_clusters.size()):
			closest = mini(closest, _Hex.hex_distance(m.forest_clusters[i].center, m.forest_clusters[j].center))
	# min_spacing = 4 в `_select_cluster_seeds`; шаг меньше — кластеры сливаются
	# в один лес и density считается по чужому центру.
	assert_that(closest >= 4).is_true()


func test_forest_coverage_knob_bounds_the_cluster_tiles() -> void:
	var m: MapModel = (_pipeline(1))["model"]
	var tiles: int = 0
	for cluster in m.forest_clusters:
		tiles += cluster.tiles.size()
	var target: int = int(m.map_width * m.map_height * 0.25)
	# Цикл `generate()` останавливается по достижении цели; перерост ограничен
	# размером последнего кластера (CLUSTER_SIZE_MAX = 20).
	assert_that(tiles > 0).is_true()
	assert_that(tiles <= target + 20).is_true()


func test_forest_density_and_type_agree() -> void:
	var m: MapModel = (_pipeline(777))["model"]
	var wrong: Array = []
	for cluster in m.forest_clusters:
		var want: String = "sparse"
		if cluster.density > 0.7:
			want = "dense"
		elif cluster.density > 0.5:
			want = "normal"
		if cluster.type != want or cluster.density < 0.3 or cluster.density > 1.0:
			wrong.append("%s/%f" % [cluster.type, cluster.density])
	assert_that(wrong).is_empty()


func test_forest_never_grows_on_water_or_rock() -> void:
	var run: Dictionary = _pipeline(42)
	var m: MapModel = run["model"]
	var before: Dictionary = run["before_forest"]
	var bad: Array = []
	for cluster in m.forest_clusters:
		for tile in cluster.tiles:
			var was: int = before.get(tile, -1)
			if was == _Hex.Terrain.WATER or was == _Hex.Terrain.MOUNTAIN or was == _Hex.Terrain.SAND:
				bad.append(tile)
	assert_that(bad).is_empty()


func test_forest_paint_follows_cluster_density() -> void:
	var run: Dictionary = _pipeline(4242)
	var m: MapModel = run["model"]
	var before: Dictionary = run["before_forest"]
	# Клетка может попасть в два кластера — красит тот, что плотнее.
	var densest: Dictionary = {}
	for cluster in m.forest_clusters:
		for tile in cluster.tiles:
			densest[tile] = maxf(float(densest.get(tile, 0.0)), float(cluster.density))
	var wrong: Array = []
	for tile in densest:
		var was: int = before.get(tile, -1)
		var now: int = m.terrain_grid.get(tile, -1)
		if was == _Hex.Terrain.MOUNTAIN or was == _Hex.Terrain.SNOW:
			continue  # эти территории `_apply_forest_terrain` не трогает
		var d: float = densest[tile]
		if d > 0.7:
			if now != _Hex.Terrain.DENSE_FOREST:
				wrong.append("%s %f -> %d" % [str(tile), d, now])
		elif d > 0.4:
			if now != _Hex.Terrain.FOREST and now != _Hex.Terrain.DENSE_FOREST:
				wrong.append("%s %f -> %d" % [str(tile), d, now])
		elif now != was:
			wrong.append("%s %f тронут редкий кластер" % [str(tile), d])
	assert_that(wrong).is_empty()


func test_forest_generator_is_a_noop_without_a_heightmap() -> void:
	# Модель без height_grid — это не «пустой мир», а сломанный пайплайн:
	# генератор обязан не выдумывать лес на пустоте.
	var m := MapModel.new()
	m.map_width = 10
	m.map_height = 10
	m.seed_value = 5
	MapForestGenerator.new(m).generate()
	assert_that(m.forest_clusters.size()).is_equal(0)
