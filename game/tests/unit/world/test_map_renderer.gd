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
	# Псевдо-текстура — по факту манифеста: квадрат 4×2 на 80 клеток не тянет,
	# Godot ругался «tile is outside the texture» и тайлы не создавались вовсе.
	var last := Vector2i(0, 0)
	for coords in all_coords:
		last = Vector2i(max(last.x, coords.x + 1), max(last.y, coords.y + 1))
	for sid in [TileAtlas.SOURCE_ID, TileAtlas.FOG_SOURCE_ID]:
		var src := TileSetAtlasSource.new()
		src.texture = ImageTexture.create_from_image(
			Image.create_empty(last.x * 16, last.y * 16, false, Image.FORMAT_RGBA8))
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


## ── Варианты на реальной карте (задача 4.5) ──────────────────────────────────

## Карта 40×40, окрашенная штатным генератором: клетка → координата в листе,
## плюс террейн клетки. Сейв карту не хранит — при загрузке она пересоздаётся из
## seed_value (world_bootstrap берёт его из run_seed), поэтому «вариант пережил
## save/load» = «второй генератор с тем же сидом красится клетка в клетку».
func _gen_painted(seed_value: int) -> Dictionary:
	var gen: MapGenerator = make_node(MapGenerator)
	gen._seed_value = seed_value
	gen._map_width = 40
	gen._map_height = 40
	gen.generate()
	var layer := _make_layer()
	MapRenderer.new(gen.model).paint(layer)
	var painted: Dictionary = {}
	for cell in layer.get_used_cells():
		painted[cell] = layer.get_cell_atlas_coords(cell)
	layer.queue_free()
	return {"painted": painted, "terrain": gen.model.terrain_grid}


func test_variants_survive_map_rebuild() -> void:
	var first: Dictionary = _gen_painted(4242)
	var again: Dictionary = _gen_painted(4242)
	var other: Dictionary = _gen_painted(777)
	var a: Dictionary = first["painted"]
	var b: Dictionary = again["painted"]
	assert_that(b.size()).is_equal(a.size())
	var changed := 0
	for cell in a:
		if b.get(cell) != a[cell]:
			changed += 1
	assert_that(changed).is_equal(0)
	# Другой сид — другая раскраска: иначе variant_for не зависит от сида.
	var o: Dictionary = other["painted"]
	var foreign := 0
	for cell in a:
		if o.has(cell) and o[cell] == a[cell]:
			foreign += 1
	assert_that(foreign < a.size()).is_true()


## Разнообразие обязано быть видно в кадре: у каждого биома, которого в кадре
## 40×40 не меньше 20 клеток, встречаются все четыре варианта базы. У редкого
## биома четырёх не бывает по арифметике хэша, поэтому порог и счёт по факту.
func test_generated_frame_shows_all_four_variants() -> void:
	var generated: Dictionary = _gen_painted(4242)
	var painted: Dictionary = generated["painted"]
	var terrain: Dictionary = generated["terrain"]
	var seen: Dictionary = {}
	var cells: Dictionary = {}
	for cell in painted:
		var terrain_id: int = int(terrain.get(cell, -1))
		if not MapRenderer.TERRAIN_TO_BIOME.has(terrain_id):
			continue
		var biome: int = MapRenderer.TERRAIN_TO_BIOME[terrain_id]
		if not seen.has(biome):
			seen[biome] = {}
		(seen[biome] as Dictionary)[painted[cell]] = true
		cells[biome] = int(cells.get(biome, 0)) + 1
	var roomy := 0
	var full := 0
	for biome in seen:
		if int(cells[biome]) < 20:
			continue
		roomy += 1
		if (seen[biome] as Dictionary).size() == TileAtlas.base_coords(biome).size():
			full += 1
	assert_that(roomy).is_greater(0)
	assert_that(full).is_equal(roomy)
