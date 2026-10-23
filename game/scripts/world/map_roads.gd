class_name MapRoads
extends RefCounted

## Лист дорожных декалей (world-map-art-variety 6.1, носитель слоя 3 «дороги»).
## Пиксели `world_map_roads.webp` и раскладка `world_map_roads.json` — продукты
## `scripts/gen_map_art.py`; координаты читаются только из манифеста, как в
## `MapObjects` (отдельный реестр в скрипте уже умирал один раз).
##
## `TileMapLayer` рисует клетку тайлом и квад не поворачивает, поэтому повороты
## полосы и стороны кромки — отдельные клетки листа: три оси гекса × две
## поверхности для полосы и моста, шесть сторон × две поверхности для кромки,
## по перекрёстку на поверхность. Итого 26 клеток, и их набор — договорённость
## арта с кодом: тест сверяет её с манифестом.

const SHEET_PATH := "res://assets/objects/world_map_roads.webp"
const FOG_SHEET_PATH := "res://assets/objects/world_map_roads_fog.webp"
const MANIFEST_PATH := "res://assets/objects/world_map_roads.json"
const TILE := GameNumbers.TILE_SIZE
const SOURCE_ID := 0
## Затемнённый побратим листа — тот же приём, что у базы (`TileAtlas.FOG_SOURCE_ID`)
## и у объектов: правило «туман войны по всем слоям» требует той же кратности
## (`GameNumbers.MAP_FOG_DIM`), а не яркой дороги над стёртой базой (дефект T-150).
const FOG_SOURCE_ID := 1

## Три оси гекса. Полоса дороги идёт между двумя соседями, а соседей шесть —
## по три пары на каждую ось, поэтому ориентация декали описывается осью,
## а не направлением: `AXIS_BY_SIDE` переводит сторону (`TileAtlas.SIDES`) в ось.
const AXES := ["ew", "nesw", "nwse"]
const AXIS_BY_SIDE := {
	"e": "ew", "w": "ew",
	"ne": "nesw", "sw": "nesw",
	"nw": "nwse", "se": "nwse",
}
## Две поверхности: основная дорога (MST) обязана отличаться от второстепенной (specs/roads).
const SURFACES := ["primary", "secondary"]

static var _manifest: Dictionary = {}
static var _coords: Dictionary = {}
static var _fog_texes: Dictionary = {}


## Манифест листа: {tile, grid, cells: [{id, kind, surface, axis|side, atlas}]}.
static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		GameLogger.error("MapRoads: манифест не найден: %s" % MANIFEST_PATH)
		return _manifest
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		GameLogger.error("MapRoads: манифест не читается: %s" % MANIFEST_PATH)
		return _manifest
	_manifest = parsed
	for cell in _manifest.get("cells", []):
		var atlas: Array = cell.get("atlas", [0, 0])
		_coords[String(cell.get("id", ""))] = Vector2i(int(atlas[0]), int(atlas[1]))
	return _manifest


## Клетка декали в листе; [-1,-1] — такой декали нет (зовущий обязан сообщить,
## а не молча положить пустоту).
static func coords_for(cell_id: String) -> Vector2i:
	manifest()
	return _coords.get(cell_id, Vector2i(-1, -1))


## Все id листа — тест сверяет с ними то, что раскраивает рендерер.
static func ids() -> Array:
	manifest()
	return _coords.keys()


static func strip_id(axis: String, surface: String) -> String:
	return "road_strip_%s_%s" % [axis, surface]


static func bridge_id(axis: String, surface: String) -> String:
	return "road_bridge_%s_%s" % [axis, surface]


static func intersection_id(surface: String) -> String:
	return "road_intersection_%s" % surface


static func edge_id(side: String, surface: String) -> String:
	return "road_edge_%s_%s" % [side, surface]


## Тайлсет слоя дорог. Геометрия обязана совпадать с базовым слоем (гекс, тот же
## tile_size), иначе декали разъедутся с базой. Обрезка гексом не нужна: декаль —
## сама форма на прозрачном, квадратной клеткой рисовать нечего.
static func build_tileset() -> TileSet:
	manifest()  # пустой _coords = пустой тайлсет, а это молча пустой слой
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		GameLogger.error("MapRoads: не удалось загрузить %s" % SHEET_PATH)
		return null
	var ts := TileSet.new()
	ts.tile_shape = 3 as TileSet.TileShape  # TILE_SHAPE_HEXAGON — как у базы
	ts.tile_size = Vector2i(TILE, TILE)
	_add_source(ts, tex, SOURCE_ID, _coords.values())
	_add_source(ts, fog_sheet_texture(), FOG_SOURCE_ID, _coords.values())
	return ts


## Затемнённый лист печатает `gen_map_art.py --fog-twin`; если файла нет — дорога
## переживёт туман яркой полосой, ровно тот дефект, из-за которого побратим и делан.
static func fog_sheet_texture() -> Texture2D:
	if _fog_texes.has("roads"):
		return _fog_texes["roads"]
	var tex := load(FOG_SHEET_PATH)
	if not (tex is Texture2D):
		GameLogger.error("MapRoads: нет %s — пересобрать `gen_map_art.py --fog-twin`" % FOG_SHEET_PATH)
		return load(SHEET_PATH)
	_fog_texes["roads"] = tex
	return tex


static func _add_source(ts: TileSet, tex: Texture2D, source_id: int, tiles: Array) -> void:
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	for coords in tiles:
		src.create_tile(coords)
	ts.add_source(src, source_id)


static func clear_cache() -> void:
	_manifest = {}
	_coords = {}
	_fog_texes = {}
