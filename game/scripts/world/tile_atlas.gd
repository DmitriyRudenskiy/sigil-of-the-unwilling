class_name TileAtlas
extends RefCounted

## Процедурный лист биомов карты (**T-344**). Файла-носителя нет: клетки рисует
## этот скрипт, один раз на процесс, дальше текстура живёт в кэше
## `TileAtlasCache`.
##
## Прежний носитель — `world_map_atlas.{webp,json}` конвейера
## `gen_map_art.py --assemble` — обязывал runtime читать манифест с координатами
## 80 клеток. Именно там жили два дефекта: квадратная клетка 82×82 при решётке
## pointy-top (**T-343**, +7.3% на ряд → ступенчатые стыки) и «клетка значится в
## манифесте, а в листе её нет» (молчаливая подмена чужим материалом). Здесь
## клетка занимает весь свой bounding box, а манифеста нет — читать нечего,
## подменять нечем.
##
## Геометрия: pointy-top, `h = w · 2/√3` (1.1547), шаг столбца `w`, шаг ряда
## `0.75·h`, нечётный ряд сдвинут вправо — та же odd-r-схема, что читает
## `HexUtils`. Соотношение не «красивое», а единственное, при котором шестиугольники
## соседей стыкуются без щелей и нахлёста: на квадратной клетке щель обязана
## появиться на каждой второй границе биомов.

const TILE := GameNumbers.TILE_SIZE
## Размер клетки = bounding box гекса. НЕ квадрат: высота выведена из ширины.
const HEX_SIZE := Vector2i(TILE, int(round(TILE * 2.0 / sqrt(3.0))))

const SOURCE_ID := 0
const FOG_SOURCE_ID := 1

enum Biome { GRASS, SAND, SNOW, SWAMP, WATER, ROCK, MUD, ROAD }

## Имена биомов: индекс = значение enum Biome. Тот же порядок, что у BIOME_COLORS.
const BIOME_NAMES := [
	"grass", "sand", "snow", "swamp", "water",
	"rock", "mud", "road",
]

## Тон биома. Палитра — наша, а не донорская: донорский кадр под эту задачу
## снимался (T-341) и ушёл вместе с резачком. Порядок обязан совпадать с enum.
const BIOME_COLORS: Array[Color] = [
	Color(0.52, 0.60, 0.33),   # grass
	Color(0.83, 0.75, 0.50),   # sand
	Color(0.90, 0.93, 0.96),   # snow
	Color(0.40, 0.47, 0.34),   # swamp
	Color(0.32, 0.52, 0.68),   # water
	Color(0.53, 0.52, 0.50),   # rock
	Color(0.47, 0.37, 0.28),   # mud
	Color(0.65, 0.55, 0.41),   # road
]

## Стороны гекса: тот же порядок, что биты `HexUtils.get_neighbor(cell, bit)`.
const SIDES := ["e", "ne", "nw", "w", "sw", "se"]

## Внешняя нормаль стороны, градусы в экранных координатах (y вниз): восток — 0°,
## дальше по 60°. Для pointy-top нормали сторон стоят на 0°/60°/…, вершины — на
## 30°/90°/…; перепутать их — значит повернуть лист на 30° и разъесть все швы.
const SIDE_ANGLES := {
	"e": 0.0, "se": 60.0, "sw": 120.0, "w": 180.0, "nw": 240.0, "ne": 300.0,
}

## Раскладка листа: столбец — биом, строка 0 — база, строки 1…6 — декаль
## «материал биома наедает сторону SIDES[строка−1]».
const COLS := 8
const ROWS := 7
## Ободок базы (доля апотемы) и полоса декали: от `BAND_FROM` прозрачно, к
## `BAND_TO` — полный тон. Полоса начинается до края, чтобы граница биомов была
## градиентом, а не линией, и кончалась до центра, чтобы не съесть свою клетку.
const RIM := 0.90
const BAND_FROM := 0.42
const BAND_TO := 0.86
const BAND_ALPHA := 0.75

static var _sheet: ImageTexture
static var _fog_sheet: ImageTexture


## Текстурный лист: 8×7 клеток. Строится один раз и переиспользуется всеми
## тайлсетами (база карты, бой, поле кампании) и его побратимом тумана.
static func sheet() -> ImageTexture:
	if _sheet != null:
		return _sheet
	if BIOME_NAMES.size() != COLS or BIOME_COLORS.size() != COLS or ROWS != 1 + SIDES.size():
		push_error("TileAtlas: раскладка листа %d×%d не совпадает с %d биомами и %d сторонами" % [
			COLS, ROWS, BIOME_NAMES.size(), SIDES.size()])
		return null
	var img := Image.create(COLS * HEX_SIZE.x, ROWS * HEX_SIZE.y, false, Image.FORMAT_RGBA8)
	var geom := _geometry()
	for biome in COLS:
		var color: Color = BIOME_COLORS[biome]
		_paint_cell(img, biome, 0, color, geom)
		for side in SIDES.size():
			_paint_cell(img, biome, 1 + side, color, geom)
	_sheet = ImageTexture.create_from_image(img)
	return _sheet


## Побратим тумана: тот же лист, RGB затемнён (`GameNumbers.MAP_FOG_DIM`), альфа
## нетронута. Вторым *источником*, а не `modulate` слоя: туман различает клетки,
## слой затемнял бы и то, что в поле зрения.
static func fog_sheet() -> ImageTexture:
	if _fog_sheet != null:
		return _fog_sheet
	var src := sheet()
	if src == null:
		return null
	_fog_sheet = ImageTexture.create_from_image(_dimmed_image(src.get_image()))
	return _fog_sheet


## Клетка базы биома. Массив из одной клетки: вариантов у биома ровно один
## (`variant_for` остаётся вызывающим кодам на будущее, count ≤ 1 → 0).
static func base_coords(biome: int) -> Array:
	if biome < 0 or biome >= COLS:
		return []
	return [Vector2i(biome, 0)]


## Клетка декаля «материал биома наедает сторону side» (слой стыков).
## [-1,-1] — такой стороны/биома нет; молчаливого фолбэка на базу нет намеренно
## (тот же смысл, что был у отсутствия перехода в манифесте).
static func edge_coords(biome: int, side: String) -> Vector2i:
	var s := SIDES.find(side)
	if biome < 0 or biome >= COLS or s < 0:
		return Vector2i(-1, -1)
	return Vector2i(biome, 1 + s)


## Все клетки листа (база + переходы) — для псевдо-тайлсетов в тестах.
static func all_coords() -> Array:
	var out: Array = []
	for row in ROWS:
		for col in COLS:
			out.append(Vector2i(col, row))
	return out


## Номер варианта базы для клетки — хэш от клетки и сида карты. Детерминизм
## обязателен: тайлмап перекрашивается целиком при каждом paint() и тумане, вариант
## обязан пережить это неизменным (в модель и сейв состояние тайлов не пишется).
static func variant_for(cell: Vector2i, seed_value: int, count: int) -> int:
	if count <= 1:
		return 0
	return int(hash("%d:%d:%d" % [cell.x, cell.y, seed_value])) % count


static func build_hex() -> TileSet:
	var ts := TileSet.new()
	## Ориентация — в коде, а не в дефолтах Godot: и `TILE_SHAPE_HEXAGON`, и
	## `TILE_LAYOUT_STACKED`, и `TILE_OFFSET_AXIS_HORIZONTAL` обязаны быть названы,
	## иначе смена умолчания движком молча поворачивает сетку на 90°, а
	## `HexGrid.calibrate` меряет только сдвиг ряда (`shift_right`) — ось он назад
	## не повернёт. STACKED + HORIZONTAL = pointy-top с нечётными рядами вправо.
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_layout = TileSet.TILE_LAYOUT_STACKED
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	ts.tile_size = HEX_SIZE
	_add_source(ts, SOURCE_ID, sheet())
	# Побратим тумана объявляется здесь, а не только в старом квадратном билдере
	# (T-168): `MapRenderer.apply_fog` и `paint_transitions` кладут «исследовано,
	# но не видно» в `FOG_SOURCE_ID`, а `TileMapLayer` на ссылку в несуществующий
	# источник не ругается — он рисует пустоту.
	_add_source(ts, FOG_SOURCE_ID, fog_sheet())
	return ts


static func _add_source(ts: TileSet, id: int, tex: Texture2D) -> void:
	if tex == null:
		push_error("TileAtlas: источник %d строится без текстуры" % id)
		return
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = HEX_SIZE
	ts.add_source(src, id)
	for coords in all_coords():
		src.create_tile(coords)


static func build_hex_tileset() -> TileSet:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
		if cache != null and cache.has_method("build_hex_tileset"):
			return cache.call("build_hex_tileset")
	return TileAtlas.build_hex()


static func clear_cache() -> void:
	_sheet = null
	_fog_sheet = null
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
		if cache != null and cache.has_method("clear_cache"):
			cache.call("clear_cache")


## Затемнённый побратим изображения (общий для листа и любых резервов).
static func _dimmed_image(src: Image) -> Image:
	var img: Image = src.duplicate()
	var dim := float(GameNumbers.MAP_FOG_DIM)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * dim, c.g * dim, c.b * dim, c.a))
	return img


## Геометрия клетки, посчитанная один раз: для каждого пикселя — максимум
## нормализованных координат по всем сторонам (`> 1` — вне гекса) и по шесть
## массивов `t_side` ∈ [−1,1] (1 — середина стороны). Клетки различаются только
## цветом, поэтому пиксельные циклы над сотней тысяч точек идут один раз.
static func _geometry() -> Array:
	var w := HEX_SIZE.x
	var h := HEX_SIZE.y
	var a := w * 0.5                      # апотема = половина ширины гекса
	var center := Vector2(w * 0.5, h * 0.5)
	var edges := _normals()
	var tmax := PackedFloat32Array()
	tmax.resize(w * h)
	var bands: Array[PackedFloat32Array] = []
	for side in edges.size():
		var band := PackedFloat32Array()
		band.resize(w * h)
		bands.append(band)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var i := y * w + x
			var m := 0.0
			for side in edges.size():
				var t := p.dot(edges[side]) / a
				bands[side][i] = t
				m = maxf(m, absf(t))
			tmax[i] = m
	return [tmax, bands]


## Внешние нормали сторон в порядке `SIDES` — вычислены из угла стороны, а не
## из порядка битов: порядок бит у `HexUtils`, порядок направления у листа.
static func _normals() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for side in SIDES:
		var angle := deg_to_rad(float(SIDE_ANGLES[String(side)]))
		out.append(Vector2(cos(angle), sin(angle)))
	return out


## Одна клетка листа: база (row 0) — залитый гекс с ободком; декаль (row ≥ 1) —
## тон биома, наедающий полосу у своей стороны с прозрачным краем.
static func _paint_cell(img: Image, col: int, row: int, color: Color, geom: Array) -> void:
	var w := HEX_SIZE.x
	var h := HEX_SIZE.y
	var tmax: PackedFloat32Array = geom[0]
	var bands: Array = geom[1]
	var side := row - 1
	for y in h:
		for x in w:
			var i := y * w + x
			if tmax[i] > 1.0:
				continue
			var alpha := 1.0
			var c := color
			if side < 0:
				if tmax[i] > RIM:
					c = c.darkened(0.22)
			else:
				alpha = clampf(
					(bands[side][i] - BAND_FROM) / (BAND_TO - BAND_FROM), 0.0, 1.0)
				if alpha <= 0.0:
					continue
				alpha *= BAND_ALPHA
			img.set_pixel(col * w + x, row * h + y, Color(c.r, c.g, c.b, alpha))
