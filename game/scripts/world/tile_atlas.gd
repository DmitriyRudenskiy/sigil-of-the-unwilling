class_name TileAtlas
extends RefCounted

## Лист тайлов карты и его манифест. Оба продукта конвейера
## `scripts/gen_map_art.py --assemble`: пиксели `world_map_atlas.webp`, раскладка
## `world_map_atlas.json`.
##
## Координаты в листе НЕ дублируются в скрипте: единственный источник — манифест.
## Прежний `const BASE_COORDS` прожил отдельную жизнь и пережил три пересборки
## листа молча (тест пути тайлсета ловил только отсутствие файла), а `TRANSITION_ART`
## с 14 записями и `pick()` не вызывались никем — мёртвый реестр указывал на клетки
## листа, которого больше нет (снимается по задаче 4.2).

const SHEET_PATH := "res://assets/tiles/world_map_atlas.webp"
const MANIFEST_PATH := "res://assets/tiles/world_map_atlas.json"
const TILE := GameNumbers.TILE_SIZE
const SOURCE_ID := 0
const FOG_SOURCE_ID := 1

enum Biome { GRASS, SAND, SNOW, SWAMP, WATER, ROCK, MUD, ROAD }

## Имена биомов — они же значения `biome` в манифесте атласа. Порядок обязан
## совпадать с enum Biome (индекс = значение enum). LAVA и DENSE_FOREST из enum
## сняты: ни генератор, ни рендер их не рисуют (MapRenderer.TERRAIN_TO_BIOME),
## а атлас их не содержит — переход для них был бы «мёртвым».
const BIOME_NAMES := [
	"grass", "sand", "snow", "swamp", "water",
	"rock", "mud", "road",
]

## Стороны гекса: тот же порядок, что биты `HexUtils.get_neighbor(cell, bit)` и
## поле `side` в манифесте (восток, северо-восток, северо-запад, запад,...).
const SIDES := ["e", "ne", "nw", "w", "sw", "se"]

static var _manifest: Dictionary = {}
static var _fog_tex: ImageTexture

var _tileset: TileSet
var _src: TileSetAtlasSource
var _fog_src: TileSetAtlasSource


## Манифест листа: {tile, grid, cells: [{id, kind, biome, variant|side, atlas}]}.
static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		GameLogger.error("TileAtlas: манифест не найден: %s" % MANIFEST_PATH)
		return _manifest
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		GameLogger.error("TileAtlas: манифест не читается: %s" % MANIFEST_PATH)
		return _manifest
	_manifest = parsed
	return _manifest


## Индекс манифеста: {biome: [координата...]}, {"biome:side": координата}.
## Строится один раз: `_base()` и `paint_transitions()` зовут эти функции на каждую
## клетку карты, а скан списка клеток на каждый вызов — это 3600 × 80 операций
## на один paint (и на каждое обновление тумана).
static var _index: Dictionary = {}


static func _ensure_index() -> void:
	if not _index.is_empty():
		return
	var groups: Dictionary = {}
	var edges: Dictionary = {}
	var all: Array = []
	for cell in manifest().get("cells", []):
		var atlas: Array = cell.get("atlas", [0, 0])
		var coords := Vector2i(int(atlas[0]), int(atlas[1]))
		all.append(coords)
		var biome := String(cell.get("biome", ""))
		if String(cell.get("kind", "")) == "base":
			if not groups.has(biome):
				groups[biome] = []
			(groups[biome] as Array).append([int(cell.get("variant", 0)), coords])
		else:
			edges["%s:%s" % [biome, cell.get("side", "")]] = coords
	var base: Dictionary = {}
	for biome in groups:
		var rows: Array = groups[biome]
		rows.sort_custom(func(a, b): return a[0] < b[0])
		var coords_list: Array = []
		for pair in rows:
			coords_list.append(pair[1])
		base[biome] = coords_list
	_index = {"base": base, "edge": edges, "all": all}


## Варианты базы биома — координаты в листе, в порядке возрастания variant.
## Массив общий на всех вызывающего: не править его на месте.
static func base_coords(biome: int) -> Array:
	_ensure_index()
	return (_index["base"] as Dictionary).get(BIOME_NAMES[biome], []) as Array


## Клетка декаля «материал биома наедает сторону side» (слой стыков).
## [-1,-1] — перехода в атласе нет; по spec world-map-tile-atlas это провал
## приёмки, молчаливого фолбэка на базу нет намеренно.
static func edge_coords(biome: int, side: String) -> Vector2i:
	_ensure_index()
	return (_index["edge"] as Dictionary).get(
		"%s:%s" % [BIOME_NAMES[biome], side], Vector2i(-1, -1))


## Номер варианта базы для клетки — хэш от клетки и сида карты. Детерминизм
## обязателен: тайлмап перекрашивается целиком при каждом paint() и тумане, вариант
## обязан пережить это неизменным (в модель и сейв состояние тайлов не пишется).
static func variant_for(cell: Vector2i, seed_value: int, count: int) -> int:
	if count <= 1:
		return 0
	return int(hash("%d:%d:%d" % [cell.x, cell.y, seed_value])) % count


static func all_coords() -> Array:
	"""Все клетки листа (база + переходы) — для псевдо-тайлсетов в тестах."""
	_ensure_index()
	return _index["all"] as Array


func build() -> bool:
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		GameLogger.error("TileAtlas: не удалось загрузить %s" % SHEET_PATH)
		return false
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(TILE, TILE)
	_src = TileSetAtlasSource.new()
	_src.texture = tex
	_src.texture_region_size = Vector2i(TILE, TILE)
	_tileset.add_source(_src, SOURCE_ID)
	_build_fog_source(tex)
	for coords in all_coords():
		_src.create_tile(coords)
	return true


## Затемнённый лист для тумана войны: тот же тайлсет, второй источник, те же
## координаты — иначе `apply_fog` не сможет класть туман в ту же клетку.
func _build_fog_source(tex: Texture2D) -> void:
	var img: Image = tex.get_image().duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, c.a))
	_fog_tex = ImageTexture.create_from_image(img)
	_fog_src = TileSetAtlasSource.new()
	_fog_src.texture = _fog_tex
	_fog_src.texture_region_size = Vector2i(TILE, TILE)
	_tileset.add_source(_fog_src, FOG_SOURCE_ID)
	for coords in all_coords():
		_fog_src.create_tile(coords)


func tileset() -> TileSet:
	return _tileset


func build_hex() -> TileSet:
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		return null
	var ts := TileSet.new()
	ts.tile_shape = 3 as TileSet.TileShape
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, SOURCE_ID)
	for coords in all_coords():
		src.create_tile(coords)
	return ts


static func build_hex_tileset() -> TileSet:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
		if cache != null and cache.has_method("build_hex_tileset"):
			return cache.call("build_hex_tileset")
	return TileAtlas.new().build_hex()


static func clear_cache() -> void:
	_manifest = {}
	_index = {}
	_fog_tex = null
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
		if cache != null and cache.has_method("clear_cache"):
			cache.call("clear_cache")
