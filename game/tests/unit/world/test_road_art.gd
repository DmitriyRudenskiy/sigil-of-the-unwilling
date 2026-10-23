extends BaseTest
## Слой дорог (world-map-art-variety 6.2/6.3, specs/roads). Три вещи, которые тут
## легко сломать молча: тип декали выбирается по соседям (а не «одна картинка на
## все дороги»), основная дорога отличается от второстепенной **измеримо** (а не
## «на глазок в листе»), и слой только рисует — проходимость, путь и его стоимость
## остаются у модели.


const _HexPathfinding = preload("res://scripts/core/hex_pathfinding.gd")
const _TerrainCostTable = preload("res://scripts/data/terrain_cost_table.gd")
const SCENE_PATH := "res://scenes/world/map_generator.tscn"

const P := MapRoadGenerator.RoadType.PRIMARY
const S := MapRoadGenerator.RoadType.SECONDARY
const T := MapRoadGenerator.RoadType.TRAIL


## Карта с дорожной сетью вместо генератора дорог: геометрия должна быть
## построена тестом, а не «поймана» на сиде, иначе проверка перекрёстка
## превращается в ожидание, что MST-дерево когда-нибудь даст три дороги в клетку.
func _gen() -> MapGenerator:
	var gen: MapGenerator = make_node(MapGenerator)
	gen._seed_value = 7
	gen._map_width = 14
	gen._map_height = 14
	gen.generate()
	return gen


## Ставит сеть в модель и перекрашивает слой. Соседей тест считает ПОСЛЕ
## generate(): HexUtils.get_neighbor берёт калибровку чётности рядов из HexGrid,
## а её ставит именно генерация карты.
func _set_roads(gen: MapGenerator, cells: Dictionary, bridges: Array = []) -> void:
	var model: MapModel = gen.model
	model.road_grid.clear()
	model.bridge_cells.clear()
	for cell in cells:
		model.road_grid[cell] = int(cells[cell])
	for cell in bridges:
		model.bridge_cells[cell] = true
	(gen.renderer as MapRenderer).paint_roads()


## Три клетки вдоль одной оси: запад — центр — восток.
func _straight(center: Vector2i, bit_a: int, bit_b: int, type: int) -> Dictionary:
	return {
		HexUtils.get_neighbor(center, bit_b): type,
		center: type,
		HexUtils.get_neighbor(center, bit_a): type,
	}


func _at(gen: MapGenerator, cell: Vector2i) -> Vector2i:
	return gen.road_layer.get_cell_atlas_coords(cell)


# ------------------------------------------------------------------ типы декали

## Прямой участок — полоса, ориентированная по оси дорог. Оси три (гекс), и они
## обязаны быть разными тайлами: TileMapLayer квад не поворачивает, поэтому
## «повернуть в коде» здесь нечего — выбор клетки и есть поворот.
func test_strip_is_oriented_by_road_axis() -> void:
	var gen := _gen()
	var c := Vector2i(6, 6)
	var seen: Array = []
	for pair in [[0, 3, "ew"], [1, 4, "nesw"], [2, 5, "nwse"]]:
		_set_roads(gen, _straight(c, int(pair[0]), int(pair[1]), P))
		var want := MapRoads.coords_for(MapRoads.strip_id(String(pair[2]), "primary"))
		assert_that(_at(gen, c)).is_equal(want)
		seen.append(_at(gen, c))
	assert_that(seen[0]).is_not_equal(seen[1])
	assert_that(seen[1]).is_not_equal(seen[2])
	assert_that(seen[0]).is_not_equal(seen[2])


## Три и больше соседей-дороги — перекрёсток, а не полоса: полотно в клетке
## разветвляется, и полоса на три клетки оставила бы «обрезанные» ответвления.
func test_intersection_when_three_road_neighbors() -> void:
	var gen := _gen()
	var c := Vector2i(6, 6)
	var cells: Dictionary = {c: P}
	# Лучи берутся через один (e/nw/sw): соседние лучи соседни и друг другу, и
	# средний из них сам оказывался узлом с тремя дорогами — проверка «перекрёсток
	# один» тогда ловила не правило, а геометрию сетки.
	for bit in [0, 2, 4]:
		cells[HexUtils.get_neighbor(c, bit)] = P
	_set_roads(gen, cells)
	assert_that(_at(gen, c)).is_equal(
			MapRoads.coords_for(MapRoads.intersection_id("primary")))
	# Лучи перекрёстка — не перекрёстки: дорог у них по одной (центр), иначе
	# проверка не различала бы «≥3» и «любой сосед».
	for bit in [0, 2, 4]:
		var n: Vector2i = HexUtils.get_neighbor(c, bit)
		assert_that(_at(gen, n)).is_not_equal(
				MapRoads.coords_for(MapRoads.intersection_id("primary")))


## Переправа: мост ставится в клетку реки (MapRoadGenerator), и декаль обязана
## быть мостом, а не полосой — полоса поверх воды читается как брод.
func test_bridge_cell_uses_bridge_tile() -> void:
	var gen := _gen()
	var c := Vector2i(6, 6)
	var e := HexUtils.get_neighbor(c, 0)
	var w := HexUtils.get_neighbor(c, 3)
	_set_roads(gen, _straight(c, 0, 3, P), [c])
	assert_that(_at(gen, c)).is_equal(
			MapRoads.coords_for(MapRoads.bridge_id("ew", "primary")))
	# Мост идёт по оси дороги, а соседние клетки остаются полосой.
	assert_that(_at(gen, e)).is_equal(
			MapRoads.coords_for(MapRoads.strip_id("ew", "primary")))
	assert_that(_at(gen, w)).is_equal(
			MapRoads.coords_for(MapRoads.strip_id("ew", "primary")))


## Сосед без дороги — кромка на этой стороне (спека: «кромка соответствующего
## направления»). На стороне соседей-дороги кромки быть не может: там полотно.
func test_edge_only_on_non_road_side() -> void:
	var gen := _gen()
	var c := Vector2i(6, 6)
	_set_roads(gen, _straight(c, 0, 3, P))
	var edges: Array = gen.road_edge_layers
	assert_that(edges.size()).is_equal(TileAtlas.SIDES.size())
	for bit in [0, 3]:
		assert_that((edges[bit] as TileMapLayer).get_cell_source_id(c)).is_equal(-1)
	for bit in [1, 2, 4, 5]:
		var layer: TileMapLayer = edges[bit]
		assert_that(layer.get_cell_source_id(c)).is_equal(MapRoads.SOURCE_ID)
		assert_that(layer.get_cell_atlas_coords(c)).is_equal(MapRoads.coords_for(
				MapRoads.edge_id(String(TileAtlas.SIDES[bit]), "primary")))


## Кромка ставится и на краю карты: «соседа» там нет, дороги тоже нет — значит
## граница дороги на месте, а не обрывается без знака.
func test_edge_on_map_border() -> void:
	var gen := _gen()
	var c := Vector2i(0, 0)
	var e := HexUtils.get_neighbor(c, 0)
	_set_roads(gen, {c: P, e: P})
	var edges: Array = gen.road_edge_layers
	var marked: int = 0
	for bit in TileAtlas.SIDES.size():
		if (edges[bit] as TileMapLayer).get_cell_source_id(c) != -1:
			marked += 1
	assert_that(marked).is_greater_equal(3)


# ------------------------------------------------------- поверхности и манифест

## Второстепенная (и тропа — своей картинки у неё нет) идёт вторичной
## поверхностью, иначе «основная отличается от второстепенной» держалось бы на
## одном лишь PRIMARY.
func test_secondary_surface_by_road_type() -> void:
	var gen := _gen()
	var c := Vector2i(6, 6)
	for type in [S, T]:
		_set_roads(gen, _straight(c, 0, 3, int(type)))
		assert_that(_at(gen, c)).is_equal(
				MapRoads.coords_for(MapRoads.strip_id("ew", "secondary")))


## Различие основной и второстепенной — числом, а не мнением: средний тон
## принятой декали должен различаться заметно (замер листа: Δ ≈ 45 по каналу).
func test_primary_and_secondary_are_distinguishable() -> void:
	var img: Image = (load(MapRoads.SHEET_PATH) as Texture2D).get_image()
	assert_that(img).is_not_null()
	for kind in ["strip", "bridge"]:
		var k: String = String(kind)
		var a_id: String = MapRoads.strip_id("ew", "primary") if k == "strip" \
				else MapRoads.bridge_id("ew", "primary")
		var b_id: String = MapRoads.strip_id("ew", "secondary") if k == "strip" \
				else MapRoads.bridge_id("ew", "secondary")
		var a := _mean_color(img, MapRoads.coords_for(a_id))
		var b := _mean_color(img, MapRoads.coords_for(b_id))
		assert_that(a.distance_to(b)).is_greater(20.0)


## Каждый выбор, который делает рендерер, обязан существовать в листе: 26 клеток
## — договорённость арта с кодом, и молча вырезать из листа поворот тест ловит
## здесь, а не пустым слоем на карте.
func test_manifest_covers_every_choice() -> void:
	assert_that(MapRoads.ids().size()).is_equal(26)
	for surface in MapRoads.SURFACES:
		var s: String = String(surface)
		var missing: Array[String] = []
		if MapRoads.coords_for(MapRoads.intersection_id(s)).x < 0:
			missing.append(MapRoads.intersection_id(s))
		for axis in MapRoads.AXES:
			var a: String = String(axis)
			if MapRoads.coords_for(MapRoads.strip_id(a, s)).x < 0:
				missing.append(MapRoads.strip_id(a, s))
			if MapRoads.coords_for(MapRoads.bridge_id(a, s)).x < 0:
				missing.append(MapRoads.bridge_id(a, s))
		for side in TileAtlas.SIDES:
			var d: String = String(side)
			if MapRoads.coords_for(MapRoads.edge_id(d, s)).x < 0:
				missing.append(MapRoads.edge_id(d, s))
		assert_that(missing).is_empty()


## Пустой тайлсет = молча пустой слой: тест на то, что у слоя есть и тайлсет, и
## обе пары источников (обычный и туманный), не даёт этому провалиться незамеченным.
func test_road_layer_has_road_tileset() -> void:
	var gen := _gen()
	var ts: TileSet = gen.road_layer.tile_set
	assert_that(ts).is_not_null()
	assert_that(ts.tile_shape).is_equal(TileSet.TileShape.TILE_SHAPE_HEXAGON)
	# Два источника — обычный и туманный (тот же лист ×MAP_FOG_DIM): правило
	# «туман по всем слоям» не работает, если затемнять нечем.
	assert_that(ts.get_source_count()).is_equal(2)
	for index in ts.get_source_count():
		var src: TileSetAtlasSource = ts.get_source(index) as TileSetAtlasSource
		assert_that(src).is_not_null()
		# 26 клеток листа = 6 полос + 6 мостов + 2 перекрёстка + 12 кромок.
		assert_that(src.get_tiles_count()).is_equal(26)


# ------------------------------------------------------------------- слой и модель

## Порядок отрисовки по **сцене**, а не по скрипту: `map_generator.tscn` объявлял
## TileMapDecor вторым, и в игре растительность рисовалась под стыками и тенями,
## тогда как тест порядка строил скрипт и молчал. Дорога по спеке — после стыков,
## до горного рельефа и растительности.
func test_road_layer_sits_between_transitions_and_vegetation() -> void:
	var gen: MapGenerator = make_node(load(SCENE_PATH))
	var names: Array[String] = []
	for child in gen.get_children():
		names.append(String(child.name))
	var found: Array[String] = []
	for layer in MapGenerator.LAYER_ORDER:
		if String(layer) in names:
			found.append(String(layer))
	assert_that(found).is_equal([
		"TileMapTerrain", "TileMapTransitions", "TileMapRoads",
		"TileMapShadow", "TileMapDecor",
	])
	var sides: Array[String] = []
	for side in TileAtlas.SIDES:
		sides.append("TileMapRoadEdge_" + String(side))
	var child_names: Array[String] = []
	for child in gen.get_node("TileMapRoads").get_children():
		child_names.append(String(child.name))
	assert_that(child_names).is_equal(["TileMapRoad"] + sides)


## Выключенный слой дорог не имеет права менять логику (спека «Слои не влияют на
## логику», задача 6.3 «стоимость движения не изменилась после включения слоя»).
func test_road_layer_toggle_does_not_change_paths() -> void:
	var gen := _gen()
	var model: MapModel = gen.model
	var start := Vector2i.ZERO
	var goal := Vector2i.ZERO
	for cell in model.terrain_grid:
		if not model.is_walkable(cell):
			continue
		if cell.x < 5 and start == Vector2i.ZERO:
			start = cell
		elif cell.x > model.map_width - 6:
			goal = cell
	assert_that(goal).is_not_equal(Vector2i.ZERO)

	var before: Array = _paths_and_cost(model, start, goal)
	assert_that(before[1]).is_not_equal("0")  # пустой путь сделал бы проверку пустой
	gen.set_layer_enabled("roads", false)
	assert_that(gen.get_node("TileMapRoads").visible).is_false()
	assert_that(_paths_and_cost(model, start, goal)).is_equal(before)
	# И обратно: включение слоя тоже ничего не меняет.
	gen.set_layer_enabled("roads", true)
	assert_that(_paths_and_cost(model, start, goal)).is_equal(before)


## Слой читает модель, а не пишет в неё: перекраска дорог не трогает рельеф,
## сеть дорог и мосты.
func test_painting_roads_does_not_touch_the_model() -> void:
	var gen := _gen()
	var model: MapModel = gen.model
	var terrain_before: Dictionary = model.terrain_grid.duplicate()
	var roads_before: Dictionary = model.road_grid.duplicate()
	var bridges_before: Dictionary = model.bridge_cells.duplicate()
	(gen.renderer as MapRenderer).paint_roads()
	assert_that(model.terrain_grid).is_equal(terrain_before)
	assert_that(model.road_grid).is_equal(roads_before)
	assert_that(model.bridge_cells).is_equal(bridges_before)


## Реальная сгенерированная карта: у каждой дороги есть декаль, и ни одна клетка
## без дороги её не получила (иначе «слой дорог» рисовал бы дороги, которых нет).
func test_real_map_paints_exactly_road_cells() -> void:
	var gen := _gen()
	var used: Array = gen.road_layer.get_used_cells()
	assert_that(used.size()).is_greater(0)
	for cell in used:
		assert_that(gen.model.road_grid.has(cell)).is_true()
	assert_that(used.size()).is_equal(gen.model.road_grid.size())


## Туман войны по всем слоям: не открыта — пусто, открыта и не видима — затемнена
## (`MapRoads.FOG_SOURCE_ID`), а не светится яркой полосой над стёртой базой.
func test_roads_follow_fog() -> void:
	var gen := _gen()
	var c := Vector2i(6, 6)
	var cells := _straight(c, 0, 3, P)
	_set_roads(gen, cells)
	var keys: Array = cells.keys()
	var hidden: Vector2i = keys[0]
	var explored: Vector2i = c
	var visible: Vector2i = keys[2]
	var vis := VisibilityMap.new()
	vis.set_map_size(14, 14)
	vis.explored = {explored: true, visible: true}
	vis.visible = {visible: true}
	gen.apply_fog(vis)

	assert_that(gen.road_layer.get_cell_tile_data(hidden)).is_null()
	assert_that(gen.road_layer.get_cell_source_id(visible)).is_equal(MapRoads.SOURCE_ID)
	assert_that(gen.road_layer.get_cell_source_id(explored)).is_equal(MapRoads.FOG_SOURCE_ID)
	# Кромки гасятся вместе с полотном, а не остаются яркими.
	for bit in TileAtlas.SIDES.size():
		var layer: TileMapLayer = gen.road_edge_layers[bit]
		assert_that(layer.get_cell_tile_data(hidden)).is_null()
		if layer.get_cell_source_id(explored) != -1:
			assert_that(layer.get_cell_source_id(explored)).is_equal(MapRoads.FOG_SOURCE_ID)


# ------------------------------------------------------------------------ меры

## Средний тон клетки листа по непрозрачным пикселям (пустые углы тайла тон не
## должны тянуть к чёрному), в каналах 0..255 — той же мерой, что и замеры листа.
func _mean_color(img: Image, coords: Vector2i) -> Vector3:
	var tile := GameNumbers.TILE_SIZE
	var sum := Vector3.ZERO
	var n := 0
	for y in tile:
		for x in tile:
			var p: Color = img.get_pixel(coords.x * tile + x, coords.y * tile + y)
			if p.a <= 0.2:
				continue
			sum += Vector3(p.r, p.g, p.b) * 255.0
			n += 1
	assert_that(n).is_greater(0)
	return sum / float(n)


## Путь, его стоимость и проходимость — то, что слой мог бы испортить, если бы
## писал в модель вместо того чтобы читать.
func _paths_and_cost(model: MapModel, start: Vector2i, goal: Vector2i) -> Array:
	var cost := func(cell: Vector2i) -> float:
		return _TerrainCostTable.get_cost_with_effects_by_id(
				int(model.terrain_grid.get(cell, -1)), false)
	var path: Array = _HexPathfinding.astar(
			start, goal, model.get_blocked_cells(), cost,
			model.map_width, model.map_height)
	var total := 0.0
	var cells: Array[String] = []
	for cell in path:
		total += cost.call(cell)
		cells.append("%s=%s" % [str(cell), str(model.is_walkable(cell))])
	return ["%f" % total, str(path.size()), str(cells)]
