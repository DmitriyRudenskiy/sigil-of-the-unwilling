class_name TileAtlas
extends RefCounted
## TileAtlas — тайлсет 5x5 листа (82 px).
##
## Лист: res://assets/tiles/world_tiles.jpeg (410x410 = 5x5 ячеек по 82 px).
##
## База (9 шт.), каждая — ровно один вариант:
##   (0,0) трава   (1,0) песок   (2,0) снег   (3,0) болото  (4,0) вода
##   (0,1) камень  (1,1) грязь   (2,1) лава   (3,1) дорога
##
## Переходы (14 шт.):
##   (4,1) трава|песок  diag    (0,2) трава|снег   diag
##   (1,2) трава|вода   diag    (2,2) песок|вода   diag
##   (3,2) снег|камень  diag    (4,2) болото|грязь diag
##   (0,3) лава|камень  diag    (2,3) песок|трава  diag
##   (3,3) снег|трава   diag    (0,4) вода|песок   diag
##   (1,4) камень|снег  edge    (3,4) камень|лава  diag
##   (4,3) вода|трава   edge    (2,4) болото|грязь edge
##
## Каждая запись TRANSITION_ART описывает ориг. ориентацию тайла:
##   a — «свой» биом (доминирующий, рисуется под клеткой),
##   b — «чужой» биом, shape — "diag" (угол) | "edge" (сторона),
##   at — где на тайле нарисован биом b (угол или сторона), coord — позиция.
## pick() ищет запись, где a == биом клетки; при повороте доминирование
## не меняется — поэтому вопрос «сплит/уголок» на выбор не влияет.
## Вращённые варианты (90/180/270 CW) — альтернативы тайла, отдельной
## текстуры не нужно. Дорога — (3,1): alt 0 = полоса NW-SE, alt 1 = NE-SW.

const SHEET_PATH := "res://assets/tiles/world_tiles.jpeg"
const TILE := 82
const SOURCE_ID := 0
## fog-of-war: тот же лист, но затемнённый — для клеток «разведено, но не
## видно» (у TileMapLayer нет per-cell modulate — только modulate всего
## слоя, поэтому затемнение — отдельным источником тайлсета).
const FOG_SOURCE_ID := 1

enum Biome { GRASS, SAND, SNOW, SWAMP, WATER, ROCK, MUD, LAVA, ROAD }

## База: биом -> список координат вариантов в листе (по одному).
const BASE_COORDS := {
	Biome.GRASS: [Vector2i(0, 0)],
	Biome.SAND: [Vector2i(1, 0)],
	Biome.SNOW: [Vector2i(2, 0)],
	Biome.SWAMP: [Vector2i(3, 0)],
	Biome.WATER: [Vector2i(4, 0)],
	Biome.ROCK: [Vector2i(0, 1)],
	Biome.MUD: [Vector2i(1, 1)],
	Biome.LAVA: [Vector2i(2, 1)],
	Biome.ROAD: [Vector2i(3, 1)],
}

const TRANSITION_ART := [
	{ "a": Biome.GRASS, "b": Biome.SAND,  "shape": "diag", "at": "SE", "coord": Vector2i(4, 1) },
	{ "a": Biome.GRASS, "b": Biome.SNOW,  "shape": "diag", "at": "SE", "coord": Vector2i(0, 2) },
	{ "a": Biome.GRASS, "b": Biome.SNOW,  "shape": "diag", "at": "NW", "coord": Vector2i(3, 3) },
	{ "a": Biome.GRASS, "b": Biome.WATER, "shape": "diag", "at": "SE", "coord": Vector2i(1, 2) },
	{ "a": Biome.SAND,  "b": Biome.WATER, "shape": "diag", "at": "SE", "coord": Vector2i(2, 2) },
	{ "a": Biome.SAND,  "b": Biome.GRASS, "shape": "diag", "at": "SE", "coord": Vector2i(2, 3) },
	{ "a": Biome.SNOW,  "b": Biome.ROCK,  "shape": "diag", "at": "SE", "coord": Vector2i(3, 2) },
	{ "a": Biome.SNOW,  "b": Biome.ROCK,  "shape": "edge", "at": "W",  "coord": Vector2i(1, 4) },
	{ "a": Biome.SWAMP, "b": Biome.MUD,   "shape": "diag", "at": "SE", "coord": Vector2i(4, 2) },
	{ "a": Biome.LAVA,  "b": Biome.ROCK,  "shape": "diag", "at": "SE", "coord": Vector2i(0, 3) },
	{ "a": Biome.LAVA,  "b": Biome.ROCK,  "shape": "diag", "at": "NW", "coord": Vector2i(3, 4) },
	{ "a": Biome.WATER, "b": Biome.SAND,  "shape": "diag", "at": "SE", "coord": Vector2i(0, 4) },
	{ "a": Biome.WATER, "b": Biome.GRASS, "shape": "edge", "at": "E",  "coord": Vector2i(4, 3) },
	{ "a": Biome.MUD,   "b": Biome.SWAMP, "shape": "edge", "at": "E",  "coord": Vector2i(2, 4) },
]

const _BIOME_ORDER := [Biome.GRASS, Biome.SAND, Biome.SNOW, Biome.SWAMP, Biome.WATER,
	Biome.ROCK, Biome.MUD, Biome.LAVA, Biome.ROAD]

var _tileset: TileSet
var _src: TileSetAtlasSource


## Собирает TileSet поверх оригинального листа. Возвращает false, если
## текстура недоступна (например, в отчуждённом проекте).
var _fog_src: TileSetAtlasSource


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
	for biome in _BIOME_ORDER:
		var coords: Array = BASE_COORDS[biome]
		for ci in coords.size():
			_src.create_tile(coords[ci])
	for e in TRANSITION_ART:
		var c: Vector2i = e["coord"]
		_src.create_tile(c)
		for k in 3:
			_src.create_alternative_tile(c, k + 1)
			_apply_rotation(_src.get_tile_data(c, k + 1), k + 1)
	return true


## fog-of-war: дубликат листа с умножением яркости на 0.45 — те же коорд.
## ponytail: по пикселю один раз на старте (410x410), не Image.adjust_colors
## (смысл value-аргумента неочевиден — лучше явное умножение).
func _build_fog_source(tex: Texture2D) -> void:
	var img: Image = tex.get_image().duplicate()
	var h := img.get_height()
	var w := img.get_width()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, c.a))
	_fog_src = TileSetAtlasSource.new()
	_fog_src.texture = ImageTexture.create_from_image(img)
	_fog_src.texture_region_size = Vector2i(TILE, TILE)
	_tileset.add_source(_fog_src, FOG_SOURCE_ID)
	for biome in _BIOME_ORDER:
		var coords: Array = BASE_COORDS[biome]
		for ci in coords.size():
			_fog_src.create_tile(coords[ci])


func tileset() -> TileSet:
	return _tileset


## Координата базового тайла биома (alt 0); варианты выбираются случайно.
func base_coords(biome: int, rng: RandomNumberGenerator) -> Vector2i:
	var options: Array = BASE_COORDS[biome]
	return options[rng.randi() % options.size()]


## TileSet для ГЛАВНОЙ карты и боя: hex-раскладка (tile_shape=3 — Hexagon),
## базовые тайлы всех 9 биомов (по одному на биом, без переходов —
## главная карта рисует плоские тайлы, без автотайлинга). Тайлы — квадраты
## 82×82, раскладываются гекс-паттерном. Возвращает null, если текстуру
## не удалось загрузить.
static func build_hex_tileset() -> TileSet:
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		return null
	var ts := TileSet.new()
	ts.tile_shape = 3  # Hexagon (как у прежнего hex_tileset.tres)
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, SOURCE_ID)
	for biome in _BIOME_ORDER:
		var coords: Array = BASE_COORDS[biome]
		for ci in coords.size():
			src.create_tile(coords[ci])
	return ts


## Возвращает { "atlas": Vector2i, "alt": int } или {} — если пары нет.
## `base` — биом клетки, `other` — биом соседа, `shape` — "edge" | "diag",
## `at` — сторона/угол, куда смотрит чужой биом.
static func pick(base: int, other: int, shape: String, at: String) -> Dictionary:
	for e in TRANSITION_ART:
		if e["a"] != base or e["b"] != other or e["shape"] != shape:
			continue
		return { "atlas": e["coord"], "alt": rotation_count(shape, e["at"], at) }
	return {}


## На сколько поворотов (0..3) повернуть тайл, чтобы `from` совпал с `to`.
static func rotation_count(shape: String, from: String, to: String) -> int:
	var order: Array = _SIDES if shape == "edge" else _CORNERS
	var f := order.find(from)
	var t := order.find(to)
	if f < 0 or t < 0:
		return 0
	return (t - f + 4) % 4


## Противоположная сторона/угол.
static func opposite(shape: String, name: String) -> String:
	if shape == "edge":
		return _OPP_SIDE[name]
	return _OPP_CORNER[name]


const _SIDES := ["N", "E", "S", "W"]
const _CORNERS := ["NW", "NE", "SE", "SW"]
const _OPP_SIDE := { "N": "S", "S": "N", "E": "W", "W": "E" }
const _OPP_CORNER := { "NW": "SE", "SE": "NW", "NE": "SW", "SW": "NE" }


## Флаги TileData для поворота на k*90 CW (направление 90/270
## верифицировано рендером по шейлеру canvas.glsl 4.7:
## uv = src + abs(size)*(transpose ? vb.yx : vb.xy), зеркалирование
## вершин при отрицательном src-size):
##  90 CW  = transpose + flip_h,  180 = flip_h + flip_v,  270 CW = transpose + flip_v.
func _apply_rotation(td: TileData, k: int) -> void:
	match k:
		1:
			td.transpose = true
			td.flip_h = true
		2:
			td.flip_h = true
			td.flip_v = true
		3:
			td.transpose = true
			td.flip_v = true
