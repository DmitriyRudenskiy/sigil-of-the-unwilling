extends BaseTest
## MapRenderer: paint() and apply_fog() against a real TileMapLayer.

class _FakeModel:
	var terrain_grid: Dictionary = {}
	var map_width := 0
	var map_height := 0


class _Flag:
	var value := false


## Псевдо-тайлсет: клетки берутся из манифеста атласа, а не из квадрата 4×2 —
## иначе set_cell на реальной координате листа молча пишет пустоту.
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var all_coords: Array = []
	for biome in TileAtlas.BIOME_NAMES.size():
		all_coords.append_array(TileAtlas.base_coords(biome))
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
