class_name MapObjects
extends RefCounted

## Лист изолированных объектов карты (растительность, валуны, плашки добычи).
## Пиксели `world_map_objects.webp` и раскладка `world_map_objects.json` —
## продукты `scripts/gen_map_art.py`. Координаты читаются только из манифеста:
## отдельный реестр в скрипте уже умирал один раз (`const BASE_COORDS` в
## `tile_atlas.gd`), поэтому его здесь не заводим вторым экземпляром.

const SHEET_PATH := "res://assets/objects/world_map_objects.webp"
const MANIFEST_PATH := "res://assets/objects/world_map_objects.json"
const TILE := GameNumbers.TILE_SIZE
const SOURCE_ID := 0

static var _manifest: Dictionary = {}
static var _coords: Dictionary = {}


## Манифест листа: {tile, grid, cells: [{id, atlas}]}.
static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		GameLogger.error("MapObjects: манифест не найден: %s" % MANIFEST_PATH)
		return _manifest
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary):
		GameLogger.error("MapObjects: манифест не читается: %s" % MANIFEST_PATH)
		return _manifest
	_manifest = parsed
	for cell in _manifest.get("cells", []):
		var atlas: Array = cell.get("atlas", [0, 0])
		_coords[String(cell.get("id", ""))] = Vector2i(int(atlas[0]), int(atlas[1]))
	return _manifest


## Клетка объекта в листе; [-1,-1] — объекта там нет (зовущий обязан сообщить,
## а не молча положить пустоту: «palm»/«cactus» жили в decor_cells ровно так).
static func coords_for(object_id: String) -> Vector2i:
	manifest()
	return _coords.get(object_id, Vector2i(-1, -1))


## Все id листа — тест сверяет с ними то, что расставляет спавнер.
static func ids() -> Array:
	manifest()
	return _coords.keys()


## Тайлсет слоя растительности. Геометрия обязана совпадать с базовым слоем
## (гекс, тот же tile_size), иначе клетки растительности разъедутся с базой.
## Обрезка гексом не нужна: объект — силуэт на прозрачном, квадратной клеткой
## рисовать нечего.
static func build_tileset() -> TileSet:
	manifest()  # пустой _coords = пустой тайлсет, а это молча пустой слой
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		GameLogger.error("MapObjects: не удалось загрузить %s" % SHEET_PATH)
		return null
	var ts := TileSet.new()
	ts.tile_shape = 3 as TileSet.TileShape  # TILE_SHAPE_HEXAGON — как у базы
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, SOURCE_ID)
	for coords in _coords.values():
		src.create_tile(coords)
	return ts


static func clear_cache() -> void:
	_manifest = {}
	_coords = {}
