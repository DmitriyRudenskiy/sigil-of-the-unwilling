extends BaseTest
## MapRenderer: paint() and apply_fog() against a real TileMapLayer.

class _FakeModel:
	var terrain_grid: Dictionary = {}
	var map_width := 0
	var map_height := 0
	var seed_value := 0


class _Flag:
	var value := false


## Псевдо-тайлсет: клетки берутся из манифеста атласа, а не из квадрата 4×2 —
## иначе set_cell на реальной координате листа молча пишет пустоту.
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var all_coords: Array = TileAtlas.all_coords()
	for sid in [TileAtlas.SOURCE_ID, TileAtlas.FOG_SOURCE_ID]:
		var src := TileSetAtlasSource.new()
		src.texture = ImageTexture.create_from_image(Image.create_empty(64, 32, false, Image.FORMAT_RGBA8))
		src.texture_region_size = Vector2i(16, 16)
		for coords in all_coords:
			src.create_tile(coords)
		ts.add_source(src, sid)
	return ts




func _make_layer() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = _make_tileset()
	add_child(layer)
	return layer


func test_paint_uses_biome_source_per_terrain() -> void:
	var model := _FakeModel.new()
	var grass: Vector2i = Vector2i(0, 0)
	var water: Vector2i = Vector2i(1, 0)
	var mountain: Vector2i = Vector2i(2, 0)
	model.terrain_grid = {
		grass: HexUtils.Terrain.GRASS,
		water: HexUtils.Terrain.WATER,
		mountain: HexUtils.Terrain.MOUNTAIN,
	}
	var layer := _make_layer()
	MapRenderer.new(model).paint(layer)

	assert_that(layer.get_cell_source_id(grass)).is_equal(TileAtlas.SOURCE_ID)
	assert_that(layer.get_cell_source_id(water)).is_equal(TileAtlas.SOURCE_ID)
	assert_that(layer.get_cell_source_id(mountain)).is_equal(TileAtlas.SOURCE_ID)
	# Вариант клетки выбирается по клетке и сиду, поэтому проверяется принадлежность
	# множеству вариантов биома, а не конкретная клетка листа.
	var outside: Array[String] = []
	for pair in [[grass, TileAtlas.Biome.GRASS], [water, TileAtlas.Biome.WATER],
			[mountain, TileAtlas.Biome.ROCK]]:
		var cell: Vector2i = pair[0]
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		if not TileAtlas.base_coords(pair[1]).has(coords):
			outside.append("%s=%s не вариант %s" % [
				str(cell), str(coords), TileAtlas.BIOME_NAMES[pair[1]]])
	assert_array(outside).is_empty()
	layer.queue_free()


## Один и тот же тайлмап, перекрашенный дважды (paint → туман → paint), обязан
## дать те же варианты: выбор детерминирован по клетке, а не по порядку обхода.
func test_variant_choice_is_deterministic() -> void:
	var model := _FakeModel.new()
	model.terrain_grid = {
		Vector2i(0, 0): HexUtils.Terrain.GRASS, Vector2i(1, 0): HexUtils.Terrain.GRASS,
		Vector2i(2, 0): HexUtils.Terrain.WATER, Vector2i(3, 0): HexUtils.Terrain.WATER,
		Vector2i(4, 0): HexUtils.Terrain.SNOW, Vector2i(5, 0): HexUtils.Terrain.ROAD,
	}
	var layer := _make_layer()
	var renderer := MapRenderer.new(model)
	renderer.paint(layer)
	var before: Array[String] = []
	for cell in model.terrain_grid:
		before.append(str(layer.get_cell_atlas_coords(cell)))
	renderer.paint(layer)
	var after: Array[String] = []
	for cell in model.terrain_grid:
		after.append(str(layer.get_cell_atlas_coords(cell)))
	assert_array(after).is_equal(before)
	layer.queue_free()


func test_paint_skips_unknown_terrain() -> void:
	var model := _FakeModel.new()
	var cell := Vector2i(0, 0)
	model.terrain_grid = {cell: 9999}
	var layer := _make_layer()
	MapRenderer.new(model).paint(layer)
	assert_that(layer.get_cell_tile_data(cell)).is_null()
	layer.queue_free()


func test_apply_fog_three_states() -> void:
	var model := _FakeModel.new()
	var hidden: Vector2i = Vector2i(0, 0)
	var explored: Vector2i = Vector2i(1, 0)
	var visible: Vector2i = Vector2i(2, 0)
	model.terrain_grid = {
		hidden: HexUtils.Terrain.GRASS,
		explored: HexUtils.Terrain.GRASS,
		visible: HexUtils.Terrain.GRASS,
	}
	var layer := _make_layer()
	var vis := VisibilityMap.new()
	vis.set_map_size(10, 10)
	vis.explored = {explored: true, visible: true}
	vis.visible = {visible: true}

	var renderer := MapRenderer.new(model)
	var flag := _Flag.new()
	renderer.fog_refreshed.connect(func(): flag.value = true)
	renderer.apply_fog(layer, vis)

	assert_bool(flag.value).is_true()
	# Unexplored cell has no tile data at all.
	assert_that(layer.get_cell_tile_data(hidden)).is_null()
	# Explored-but-not-visible cell shows the fog source.
	assert_that(layer.get_cell_tile_data(explored)).is_not_null()
	assert_that(layer.get_cell_source_id(explored)).is_equal(TileAtlas.FOG_SOURCE_ID)
	# Visible cell keeps the normal source.
	assert_that(layer.get_cell_tile_data(visible)).is_not_null()
	assert_that(layer.get_cell_source_id(visible)).is_equal(TileAtlas.SOURCE_ID)
	layer.queue_free()


func test_apply_fog_null_safety() -> void:
	var model := _FakeModel.new()
	var layer := _make_layer()
	MapRenderer.new(model).apply_fog(layer, null)
	MapRenderer.new(model).apply_fog(null, VisibilityMap.new())
	layer.queue_free()


## ── Переходы биомов (слой 2, задача 4.4) ─────────────────────────────────────

func _make_transition_layers() -> Array:
	var layers: Array = []
	for side in TileAtlas.SIDES:
		layers.append(_make_layer())
	return layers


## Граница трава|вода в одной строке: (1,0) трава, (2,0) вода — восток первой
## клетки и запад второй. Вода «старше» травы (enum Biome), поэтому декаль воды
## лежит на травяной клетке со стороны E, а травяная сторона молчит: если бы
## красили обе, цвета просто поменялись бы местами и стык остался бы твёрдым.
func test_transition_paints_on_stronger_biom_neighbor_side() -> void:
	var model := _FakeModel.new()
	var grass: Vector2i = Vector2i(1, 0)
	var water: Vector2i = Vector2i(2, 0)
	model.terrain_grid = {grass: HexUtils.Terrain.GRASS, water: HexUtils.Terrain.WATER}
	var layer := _make_layer()
	var layers := _make_transition_layers()
	var renderer := MapRenderer.new(model)
	renderer.transition_layers = layers
	renderer.paint(layer)

	var east: TileMapLayer = layers[TileAtlas.SIDES.find("e")]
	var west: TileMapLayer = layers[TileAtlas.SIDES.find("w")]
	assert_that(east.get_cell_atlas_coords(grass)).is_equal(
		TileAtlas.edge_coords(TileAtlas.Biome.WATER, "e"))
	assert_that(east.get_cell_source_id(grass)).is_equal(TileAtlas.SOURCE_ID)
	# Обратно — пусто: вода свою границу с травой не красит.
	assert_that(west.get_cell_tile_data(water)).is_null()
	layer.queue_free()
	for l in layers:
		l.queue_free()


## Клетка в окружении своего биома не имеет перехода ни на одной стороне.
func test_transition_quiet_inside_one_biome() -> void:
	var model := _FakeModel.new()
	for cell in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(3, 4),
			Vector2i(4, 3), Vector2i(5, 5), Vector2i(3, 5), Vector2i(5, 3)]:
		model.terrain_grid[cell] = HexUtils.Terrain.GRASS
	var layer := _make_layer()
	var layers := _make_transition_layers()
	var renderer := MapRenderer.new(model)
	renderer.transition_layers = layers
	renderer.paint(layer)
	var painted := 0
	for l in layers:
		painted += l.get_used_cells().size()
	assert_that(painted).is_equal(0)
	layer.queue_free()
	for l in layers:
		l.queue_free()


## Туман затемняет и переходы, и не даёт декалю выдать биом за краем тумана:
## исследованная, но не видимая клетка берёт туманный источник; если сосед не
## открыт вовсе — декаля нет; если не открыта сама клетка — тоже.
func test_transition_follows_fog() -> void:
	var model := _FakeModel.new()
	var grass: Vector2i = Vector2i(1, 0)
	var water: Vector2i = Vector2i(2, 0)
	model.terrain_grid = {grass: HexUtils.Terrain.GRASS, water: HexUtils.Terrain.WATER}
	var layer := _make_layer()
	var layers := _make_transition_layers()
	var renderer := MapRenderer.new(model)
	renderer.transition_layers = layers
	var vis := VisibilityMap.new()
	vis.set_map_size(10, 10)
	vis.explored = {grass: true, water: true}
	renderer.apply_fog(layer, vis)
	var east: TileMapLayer = layers[TileAtlas.SIDES.find("e")]
	assert_that(east.get_cell_source_id(grass)).is_equal(TileAtlas.FOG_SOURCE_ID)

	# Сосед за краем тумана: трава исследована, вода — нет → декаль молчит.
	vis.explored = {grass: true}
	renderer.apply_fog(layer, vis)
	assert_that(east.get_cell_tile_data(grass)).is_null()

	vis.explored = {}
	renderer.apply_fog(layer, vis)
	assert_that(east.get_cell_tile_data(grass)).is_null()
	layer.queue_free()
	for l in layers:
		l.queue_free()


## Переходы перекрашиваются целиком (paint, туман, город) — набор тайлов обязан
## быть одним и тем же при повторном проходе.
func test_transitions_are_deterministic() -> void:
	var model := _FakeModel.new()
	model.seed_value = 7
	for y in range(4):
		for x in range(4):
			model.terrain_grid[Vector2i(x, y)] = (
				HexUtils.Terrain.WATER if x > y else HexUtils.Terrain.GRASS)
	var layer := _make_layer()
	var layers := _make_transition_layers()
	var renderer := MapRenderer.new(model)
	renderer.transition_layers = layers
	renderer.paint(layer)
	var before: Array[String] = []
	for l in layers:
		for cell in l.get_used_cells():
			before.append("%s=%s:%s" % [str(cell), str(l.get_cell_source_id(cell)),
				str(l.get_cell_atlas_coords(cell))])
	renderer.paint(layer)
	var after: Array[String] = []
	for l in layers:
		for cell in l.get_used_cells():
			after.append("%s=%s:%s" % [str(cell), str(l.get_cell_source_id(cell)),
				str(l.get_cell_atlas_coords(cell))])
	assert_array(after).is_equal(before)
	assert_that(before.size()).is_greater(0)
	layer.queue_free()
	for l in layers:
		l.queue_free()
