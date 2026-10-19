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
## Тень — отдельный элемент партии 7.1: не запечена в спрайт объекта, а кладётся
## своей клеткой в слой под растительностью. Рисуется процедурно (мягкий эллипс),
## потому что модель на «тень» рисует тёмное пятно с краем, а гейт листа требует от
## объекта силуэта и прозрачной опоры — тень им не является.
## ponytail: эллипс по формуле; если глаз попросит живописную тень — кадр в лист
## объектов со своим гейтом, слой и вызов останутся теми же.
const SHADOW_SOURCE_ID := 1
const SHADOW_TILE := Vector2i(0, 0)
const SHADOW_ALPHA := 0.5
const SHADOW_RX := 0.40   # доли тайла
const SHADOW_RY := 0.18

static var _manifest: Dictionary = {}
static var _coords: Dictionary = {}
static var _shadow_tex: ImageTexture


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
	var shadow := TileSetAtlasSource.new()
	shadow.texture = shadow_texture()
	shadow.texture_region_size = Vector2i(TILE, TILE)
	shadow.create_tile(SHADOW_TILE)
	ts.add_source(shadow, SHADOW_SOURCE_ID)
	return ts


## Мягкий тёмный эллипс с опорой у нижней кромки клетки — туда, где у объекта
## основание (якорь манифеста `[TILE/2, TILE-2]`).
static func shadow_texture() -> ImageTexture:
	if _shadow_tex != null:
		return _shadow_tex
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var cx := TILE * 0.5
	var cy := float(TILE) - 8.0
	for y in TILE:
		for x in TILE:
			var nx := (x + 0.5 - cx) / (TILE * SHADOW_RX)
			var ny := (y + 0.5 - cy) / (TILE * SHADOW_RY)
			var r2 := nx * nx + ny * ny
			var a := 0.0 if r2 >= 1.0 else SHADOW_ALPHA * pow(1.0 - r2, 1.5)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


static func clear_cache() -> void:
	_manifest = {}
	_coords = {}
