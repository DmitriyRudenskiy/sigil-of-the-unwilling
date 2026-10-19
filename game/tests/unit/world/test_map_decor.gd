extends BaseTest
## Растительность мира (world-map-art-variety, задача 7.4). Слой только читает
## модель: id объектов обязаны существовать в листе объектов, расстановка —
## детерминироваться сидом, а лес — не зарастать деревню и не расти там, где
## растительности быть не может.


class _FakeModel:
	var terrain_grid: Dictionary = {}
	var decor_cells: Dictionary = {}
	var village_cells: Array = []
	var resource_cells: Dictionary = {}
	var seed_value := 0
	var map_width := 8
	var map_height := 4


## Поле: слева плотный лес, в середине лес, справа луг; `extra` — что добавить.
func _field(extra := {}) -> _FakeModel:
	var m := _FakeModel.new()
	for y in m.map_height:
		for x in range(0, 2):
			m.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.DENSE_FOREST
		for x in range(2, 4):
			m.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.FOREST
		for x in range(4, m.map_width):
			m.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	for cell in extra:
		m.terrain_grid[cell] = extra[cell]
	return m


func _place(m, seed_value: int = 1) -> Dictionary:
	m.seed_value = seed_value
	MapSpawner.new(m).place_decor()
	return m.decor_cells


## Каждый выставленный id есть в манифесте листа объектов. Именно этого теста
## не хватало «palm»/«cactus»: слой рисовался, клеток в нём не было, и молчал.
func test_decor_ids_exist_in_object_sheet() -> void:
	var ids: Array = MapObjects.ids()
	assert_that(ids.size()).is_greater_equal(15)
	var seen := 0
	for seed_value in [1, 2, 3]:
		var decor := _place(_field(), seed_value)
		assert_that(decor.size()).is_greater(0)
		for cell in decor:
			assert_that(ids).contains(String(decor[cell]))
			seen += 1
	assert_that(seen).is_greater(0)


## Детерминизм по сиду: один сид — одна и та же растительность клетка-в-клетку,
## другой сид — другая (иначе перекраска слоя после тумана меняла бы лес).
func test_vegetation_is_deterministic_by_seed() -> void:
	var a := _place(_field(), 77)
	var b := _place(_field(), 77)
	var c := _place(_field(), 78)
	assert_that(str(b)).is_equal(str(a))
	assert_that(str(c)).is_not_equal(str(a))


## Правила по биомам: плотный лес и лес не пустые, вода/камень/дорога — пустые,
## деревня не зарастает, у кромки кустов больше, чем в глубине лугов.
func test_vegetation_follows_biome_rules() -> void:
	var water := Vector2i(6, 0)
	var mountain := Vector2i(6, 1)
	var road := Vector2i(6, 2)
	var village := Vector2i(5, 3)
	var m := _field({
		water: HexUtils.Terrain.WATER,
		mountain: HexUtils.Terrain.MOUNTAIN,
		road: HexUtils.Terrain.ROAD,
	})
	m.village_cells = [village]
	var decor := _place(m)
	for cell in [water, mountain, road, village]:
		assert_that(decor.has(cell)).is_false()
	var forest_cells := 0
	var forest_green := 0
	var deep_grass := 0
	var deep_grass_green := 0
	for cell in m.terrain_grid:
		var t: int = m.terrain_grid[cell]
		if t == HexUtils.Terrain.FOREST or t == HexUtils.Terrain.DENSE_FOREST:
			forest_cells += 1
			forest_green += 1 if decor.has(cell) else 0
		elif t == HexUtils.Terrain.GRASS and cell.x >= 7:
			deep_grass += 1
			deep_grass_green += 1 if decor.has(cell) else 0
	assert_that(forest_green).is_greater(int(forest_cells * 0.5))
	# Кромка (x=4) против глубины лугов (x>=7): тот же куст, разная частота.
	var edge := 0
	var edge_green := 0
	for cell in m.terrain_grid:
		if m.terrain_grid[cell] == HexUtils.Terrain.GRASS and cell.x == 4:
			edge += 1
			edge_green += 1 if decor.has(cell) else 0
	assert_that(float(edge_green) / maxf(edge, 1)) \
		.is_greater(float(deep_grass_green) / maxf(deep_grass, 1))


## Тайлсет слоя — лист объектов: клетка растительности обязана существовать в
## своём тайлсете, а неизвестный id не должен молча писать пустоту.
func test_paint_decor_writes_only_known_objects() -> void:
	var m := _field()
	m.decor_cells = {
		Vector2i(0, 0): "obj_conifer",
		Vector2i(1, 0): "obj_palm_of_the_dead",
	}
	var layer := TileMapLayer.new()
	# Тайлсет строится из пустого кэша: иначе тест проходит на манифесте,
	# который по зову выше уже прочитан, а не на том, что слой реально построен.
	MapObjects.clear_cache()
	var ts := MapObjects.build_tileset()
	assert_that(ts).is_not_null()
	# Число тайлов в источнике, а не «клетка записана»: set_cell пишет клетку
	# и в пустом тайлсете, поэтому слой без тайлов выглядит нарисованным.
	var src := ts.get_source(MapObjects.SOURCE_ID) as TileSetAtlasSource
	assert_int(src.get_tiles_count()).is_equal(MapObjects.ids().size())
	layer.tile_set = ts
	add_child(layer)
	assert_that(layer.tile_set).is_not_null()
	MapRenderer.new(m).paint_decor(layer)
	assert_that(layer.get_cell_source_id(Vector2i(0, 0))).is_equal(MapObjects.SOURCE_ID)
	assert_that(layer.get_cell_source_id(Vector2i(1, 0))).is_equal(-1)
