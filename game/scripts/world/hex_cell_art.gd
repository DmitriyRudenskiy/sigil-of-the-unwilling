class_name HexCellArt
extends RefCounted

## Процедурный лист биомов карты (**T-344**). Файла-носителя нет: клетки рисует
## этот скрипт, один раз на процесс, дальше текстура живёт в кэше
## `HexCellArtCache`.
##
## Прежний носитель — `world_map_atlas.{webp,json}` конвейера
## `gen_map_art.py --assemble` — обязывал runtime читать манифест с координатами
## 80 клеток. Именно там жили два дефекта: квадратная клетка 82×82 при решётке
## pointy-top (**T-343**, +7.3% на ряд → ступенчатые стыки) и «клетка значится в
## манифесте, а в листе её нет» (молчаливая подмена чужим материалом). Здесь
## клетка занимает весь свой bounding box, а манифеста нет — читать нечего,
## подменять нечем. Заодно сняты и сами имена былого контракта — `variants()`,
## `coords()`, `cell_id()`: клетку адресуешь (биом, ряд), а не строкой из данных.
##
## Геометрия: pointy-top, `h = w · 2/√3` (1.1547), шаг столбца `w`, шаг ряда
## `0.75·h`, нечётный ряд сдвинут вправо — та же odd-r-схема, что читает
## `HexUtils`. Соотношение не «красивое», а единственное, при котором
## шестиугольники соседей стыкуются без щелей и нахлёста: на квадратной клетке
## щель обязана появиться на каждой второй границе биомов.
##
## Содержание клетки — не заливка. Плоский тон читается как «круги», и именно по
## этой причине кадр карты сходился с демо-полигоном только геометрией, но не
## материалом. Каждый биом несёт: пятно низкочастотного тона (мох, сухая вытоптан
## нина, скальная плита), зерно по пикселю, свой набор деталей (куст, цветы,
## камешки, камыш, трещины льда, рябь воды, барханы, лужи грязи, обломки плит) и
## затемнённую кромку в 3 px у каждой стороны — соты начинают читаться сотами,
## а сосед с той же кромкой даёт на границе двойное затемнение, то есть шов.

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

## Тон биома — УМЕРЕННОЙ яркости и насыщенности: детали (пункт 2 задачи) читаются
## только на среднем тоне, на залитом в ноль или в молоко они либо тонут, либо
## кричат. Порядок обязан совпадать с enum.
const BIOME_COLORS: Array[Color] = [
	Color(0.50, 0.58, 0.32),   # grass
	Color(0.79, 0.71, 0.47),   # sand
	Color(0.87, 0.90, 0.94),   # snow
	Color(0.39, 0.45, 0.32),   # swamp
	Color(0.30, 0.49, 0.64),   # water
	Color(0.44, 0.45, 0.47),   # rock — холодный серый: тёплый камень читался грязью
	Color(0.45, 0.36, 0.27),   # mud
	Color(0.62, 0.53, 0.40),   # road
]

## Акцент детали по биому: цветы у луга, полынья у болота, синь у льда. Индекс =
## enum. Оттенок один на биом, чтобы палитра не рассыпалась на восемь самодеятель-
## ностей: контраст держат тёмный/светлый материалы, а не пёстрый акцент.
const BIOME_ACCENTS: Array[Color] = [
	Color(0.92, 0.88, 0.55),   # grass — полевой цветок
	Color(0.93, 0.87, 0.66),   # sand — светлый песок на гребне бархана
	Color(0.66, 0.82, 0.94),   # snow — лёд в трещине
	Color(0.22, 0.34, 0.30),   # swamp — полынья
	Color(0.63, 0.82, 0.90),   # water — пенный гребень
	Color(0.70, 0.72, 0.68),   # rock — свежий скол
	Color(0.31, 0.25, 0.19),   # mud — лужа
	Color(0.48, 0.40, 0.30),   # road — колея
]

## Стороны гекса: тот же порядок, что биты `HexUtils.get_neighbor(cell, bit)`.
const SIDES := ["e", "ne", "nw", "w", "sw", "se"]

## Внешняя нормаль стороны, градусы в экранных координатах (y вниз): восток — 0°,
## дальше по 60°. Для pointy-top нормали сторон стоят на 0°/60°/…, вершины — на
## 30°/90°/…; перепутать их — значит повернуть лист на 30° и разъесть все швы.
const SIDE_ANGLES := {
	"e": 0.0, "se": 60.0, "sw": 120.0, "w": 180.0, "nw": 240.0, "ne": 300.0,
}

## Варианты базы на биом. Четыре — не «много», а минимум, при котором соседние
## клетки луга не выглядят копией: плотность и набор деталей различается, и
## глаз перестаёт читать поле как текстуру-кирпич. Декали вариантов не имеют:
## это узкая полоса у стороны, различать её глазу нечем.
const VARIANTS := 4

## Раскладка листа: столбец — биом, строки `0..VARIANTS-1` — варианты базы,
## строки `VARIANTS + i` — декаль «материал биома наедает сторону SIDES[i]».
const COLS := 8
const ROWS := VARIANTS + 6

## Кромка клетки (пункт 3): последние `EDGE_PX` пикселей перед стороной затемнены
## до `EDGE_DARK` от тона. 3 px — не украшение: это ширина, при которой шов виден
## на кадре 100 %, но не превращает поле в решётку. Двойное затемнение на общей
## стороне и есть «граница биомов», поэтому отдельной линии границы нет ни в листе,
## ни в отрисовке.
const EDGE_PX := 3.0
const EDGE_DARK := 0.30
## Зерно по пикселю (доля тона) и амплитуда низкочастотного пятна. Пятно крупное
## (шаг сетки `PATCH_STEP` px) — оно и есть «мох/плита/вытоптанное», зерно —
## только чтобы заливка не осталась заливкой.
const GRAIN := 0.05
const PATCH := 0.075
const PATCH_STEP := 6.0
## Сглаживание границы гекса в единицах `tmax` (1 = сторона). Без него край клетки
## — лесенка в 1 px, а поле кампании и тайлмап растягивают её до заметной пилы.
const AA := 0.055

## Декаль: полоса от `BAND_FROM` (до — прозрачно) до `BAND_TO` (полный тон).
## `BAND_TO < 1` обязателен: полоса обязана дойти до самой стороны залитой, иначе
## между биомами остаётся светлая щель моей собственной базой.
const BAND_FROM := 0.52
const BAND_TO := 0.95
const BAND_ALPHA := 0.92

static var _sheet: ImageTexture
static var _fog_sheet: ImageTexture


## Текстурный лист: 8 столбцов × (4 варианта + 6 декалей) строк. Строится один раз
## и переиспользуется всеми тайлсетами (база карты, бой, поле кампании) и его
## побратимом тумана.
static func sheet() -> ImageTexture:
	if _sheet != null:
		return _sheet
	if BIOME_NAMES.size() != COLS or BIOME_COLORS.size() != COLS \
			or BIOME_ACCENTS.size() != COLS or ROWS != VARIANTS + SIDES.size():
		push_error("HexCellArt: раскладка листа %d×%d не совпадает с %d биомами и %d сторонами" % [
			COLS, ROWS, BIOME_NAMES.size(), SIDES.size()])
		return null
	var img := Image.create(COLS * HEX_SIZE.x, ROWS * HEX_SIZE.y, false, Image.FORMAT_RGBA8)
	var geom := _geometry()
	for biome in COLS:
		for row in ROWS:
			_paint_cell(img, biome, row, geom)
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


## Клетки базы биома — по одной на вариант. Порядок = номер варианта; выбор
## варианта у вызывающего (`variant_for`), чтобы он оставался детерминированным.
static func base_coords(biome: int) -> Array:
	if biome < 0 or biome >= COLS:
		return []
	var out: Array = []
	for v in VARIANTS:
		out.append(Vector2i(biome, v))
	return out


## Клетка декаля «материал биома наедает сторону side» (слой стыков).
## [-1,-1] — такой стороны/биома нет; молчаливого фолбэка на базу нет намеренно
## (тот же смысл, что был у отсутствия перехода в манифесте).
static func edge_coords(biome: int, side: String) -> Vector2i:
	var s := SIDES.find(side)
	if biome < 0 or biome >= COLS or s < 0:
		return Vector2i(-1, -1)
	return Vector2i(biome, VARIANTS + s)


## Все клетки листа (база + декали) — для псевдо-тайлсетов в тестах и для
## `TileSetAtlasSource.create_tile`.
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
		push_error("HexCellArt: источник %d строится без текстуры" % id)
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
		var cache := tree.root.get_node_or_null("/root/HexCellArtCache")
		if cache != null and cache.has_method("build_hex_tileset"):
			return cache.call("build_hex_tileset")
	return HexCellArt.build_hex()


static func clear_cache() -> void:
	_sheet = null
	_fog_sheet = null
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/HexCellArtCache")
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
## нормализованных координат по всем сторонам (`> 1` — вне гекса), максимум по
## *знаковым* координатам (`emax` — насколько близко к ближайшей стороне, 1 = на
## стороне) и шесть массивов `t_side` ∈ [−1,1] (1 — середина стороны). Клетки
## различаются тоном и рядом, поэтому пиксельные циклы идут один раз.
static func _geometry() -> Array:
	var w := HEX_SIZE.x
	var h := HEX_SIZE.y
	var a := w * 0.5                      # апотема = половина ширины гекса
	var center := Vector2(w * 0.5, h * 0.5)
	var edges := _normals()
	var tmax := PackedFloat32Array()
	tmax.resize(w * h)
	var emax := PackedFloat32Array()
	emax.resize(w * h)
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
			var near := -1.0
			for side in edges.size():
				var t := p.dot(edges[side]) / a
				bands[side][i] = t
				m = maxf(m, absf(t))
				near = maxf(near, t)
			tmax[i] = m
			emax[i] = near
	return [tmax, bands, emax, a]


## Внешние нормали сторон в порядке `SIDES` — вычислены из угла стороны, а не
## из порядка битов: порядок бит у `HexUtils`, порядок направления у листа.
static func _normals() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for side in SIDES:
		var angle := deg_to_rad(float(SIDE_ANGLES[String(side)]))
		out.append(Vector2(cos(angle), sin(angle)))
	return out
## Одна клетка листа. `row < VARIANTS` — база биома `row`-го варианта;
## `row ≥ VARIANTS` — декаль стороны `row - VARIANTS`.
##
## Клетка рисуется на своём изображении и только потом вставляется в лист:
## координаты деталей остаются локальными, и деталь не может уехать в чужую клетку
## от ошибки на один TILE.
##
## Два прохода. Первый — тон по пикселю: пятно + зерно + затемнение кромки + альфа
## (маска гекса у базы, нарастание полосы у декали). Второй — детали: набор фигур у
## биома свой (пункт 2), и они обязаны пережить ту же маску, что и заливка, иначе
## куст полезет за сторону гекса — ровно тот дефект «шва», из-за которого лист и
## был отправлен в процедуру.
static func _paint_cell(img: Image, biome: int, row: int, geom: Array) -> void:
	var w := HEX_SIZE.x
	var h := HEX_SIZE.y
	var tmax: PackedFloat32Array = geom[0]
	var bands: Array = geom[1]
	var emax: PackedFloat32Array = geom[2]
	var apothem: float = geom[3]
	var variant := row if row < VARIANTS else 0
	var side := row - VARIANTS
	var color: Color = BIOME_COLORS[biome]
	var dark: Color = color.darkened(0.26).lerp(Color(0.15, 0.16, 0.18), 0.25)
	var light: Color = color.lightened(0.22).lerp(Color(0.95, 0.95, 0.90), 0.25)
	var patches := _patch_field(biome, variant)
	# Кромка в единицах tmax: EDGE_PX пикселей апотемы — это сколько от 1.0.
	var edge_n := clampf(EDGE_PX / apothem, 0.02, 0.4)
	var cell := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var i := y * w + x
			var t := tmax[i]
			if t > 1.0 + AA:
				continue
			# Пятно (низкие частоты) и зерно (пиксельное). Оба — про материал:
			# у пятна шаг сетки PATCH_STEP пикселей, у зерна шага нет вовсе.
			var patch := _patch_at(patches, x, y)
			var c: Color = color.lightened(PATCH * patch) if patch > 0.0 \
					else color.darkened(-PATCH * patch)
			c = c.lightened(GRAIN * (_hash2i(x, y, biome * 31 + variant) - 0.5))
			# Затемнение кромки (пункт 3): от нуля внутри до EDGE_DARK на стороне.
			# Работает и у базы, и у декали: шов обязана давать граница, а не
			# нарисованная линия, — тогда два сосеня дают двойное затемнение.
			var near := clampf((emax[i] - (1.0 - edge_n)) / edge_n, 0.0, 1.0)
			if near > 0.0:
				c = c.darkened(EDGE_DARK * smoothstep(0.0, 1.0, near))
			var alpha := clampf((1.0 + AA - t) / (2.0 * AA), 0.0, 1.0)
			if side >= 0:
				var ramp := clampf(
						(bands[side][i] - BAND_FROM) / (BAND_TO - BAND_FROM), 0.0, 1.0)
				if ramp <= 0.0:
					continue
				alpha *= BAND_ALPHA * smoothstep(0.0, 1.0, ramp)
			cell.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	_stamp_details(cell, biome, variant, side, tmax, bands, dark, light)
	img.blit_rect(cell, Rect2i(0, 0, w, h), Vector2i(biome * w, row * h))


## Низкочастотное поле пятна клетки: узлы через PATCH_STEP пикселей, билинейная
## выборка. Значение ∈ [-1,1]: >0 — светлее (лысина, гребень, свежий скол), <0 —
## темнее (мох, топь, плита в тени). Поле держим на клетку, а не на весь лист:
## продолжение пятна через границу читалось бы как одна текстура на две клетки.
static func _patch_field(biome: int, variant: int) -> Array:
	var cols := int(ceilf(float(HEX_SIZE.x) / PATCH_STEP)) + 2
	var rows := int(ceilf(float(HEX_SIZE.y) / PATCH_STEP)) + 2
	var field := PackedFloat32Array()
	field.resize(cols * rows)
	for j in rows:
		for i in cols:
			field[j * cols + i] = _hash2i(i, j, biome * 131 + variant * 977) * 2.0 - 1.0
	return [field, cols, rows]


static func _patch_at(field: Array, x: int, y: int) -> float:
	var values: PackedFloat32Array = field[0]
	var cols: int = field[1]
	var fx := float(x) / PATCH_STEP
	var fy := float(y) / PATCH_STEP
	var ix := int(floorf(fx))
	var iy := int(floorf(fy))
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	var a00 := values[iy * cols + ix]
	var a10 := values[iy * cols + ix + 1]
	var a01 := values[(iy + 1) * cols + ix]
	var a11 := values[(iy + 1) * cols + ix + 1]
	return lerpf(lerpf(a00, a10, tx), lerpf(a01, a11, tx), ty)


## Детерминированный хэш координат → [0,1]. Свой, а не `hash()`: вызывается на
## каждый пиксель листа, а это шестьсот тысяч вызовов на сборку.
static func _hash2i(x: int, y: int, seed: int) -> float:
	var h := x * 0x1F1F1F1 + y * 0x2545F49 + seed * 0x27D4EB2F
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	return float((h ^ (h >> 15)) & 0xFFFFFF) / 16777215.0


## Детали клетки — пункт 2 задачи: не «подцветка», а узнаваемый набор фигур.
## Плотность обязана быть разной на вариант («разной густоты»), иначе поле читается
## плиткой: один ряд густой, соседний редкий.
## Деталь не перекрывает материал, а лежит полупрозрачно: клетка обязана остаться
## биомом, а не мозаикой.
static func _stamp_details(
		cell: Image, biome: int, variant: int, side: int, tmax: PackedFloat32Array,
		bands: Array, dark: Color, light: Color
) -> void:
	var accent: Color = BIOME_ACCENTS[biome]
	var mid := BIOME_COLORS[biome].darkened(0.14)
	# variant 0 → ~4 детали, variant 3 → ~9. Разброс заметен глазу на ряду из
	# двадцати клеток, а не только под лупой.
	var count := 5 + int(round(2.0 * float(variant)))
	if biome == Biome.WATER:
		count += 3  # волна мелкая, на ряд из четырёх штук её не разобрать
	if biome == Biome.SNOW:
		count += 2  # по белому полю редкий знак сливается: снегу нужно больше штрихов
	var seed := biome * 4093 + variant * 7717 + side * 131071
	for k in count:
		var fu := 0.20 + 0.60 * _hash2i(k, 11, seed)
		var fv := 0.16 + 0.68 * _hash2i(k, 23, seed)
		match biome:
			Biome.GRASS:
				if k % 3 == 0:
					_stamp_bush(cell, variant, k, tmax, bands, side, fu, fv, dark, mid)
				elif k % 3 == 1:
					_stamp_dot(cell, tmax, bands, side, fu, fv, accent, 1.6)
				else:
					_stamp_dot(cell, tmax, bands, side, fu, fv, light.darkened(0.14), 1.1)
			Biome.SWAMP:
				if k % 2 == 0:
					_stamp_reed(cell, biome, variant, tmax, bands, side, fu, fv,
							dark.darkened(0.10))
				else:
					_stamp_blob(cell, tmax, bands, side, fu, fv, accent, 3.4, 2.0)
			Biome.SNOW:
				# Трещина обязана быть темной: голубоватый акцент на белом поле не
				# читался вовсе (кадр T344-demo2). Акцент оставили для льда в самой
				# трещине, теневой край — серый, он и даёт узнаваемость узора.
				if k % 3 == 0:
					_stamp_crack(cell, variant, tmax, bands, side, fu, fv,
							Color(0.46, 0.56, 0.70))
				elif k % 3 == 1:
					_stamp_ripple(cell, tmax, bands, side, fu, fv,
							dark.lightened(0.16), 8.0 + 4.0 * float(k % 3))
				else:
					_stamp_dot(cell, tmax, bands, side, fu, fv, accent, 1.4)
			Biome.SAND:
				_stamp_ripple(cell, tmax, bands, side, fu, fv,
						light if k % 2 == 0 else dark.lightened(0.22), 7.0 + 3.0 * float(k % 3))
			Biome.WATER:
				_stamp_ripple(cell, tmax, bands, side, fu, fv,
						accent if k % 3 == 0 else light.darkened(0.12), 6.0 + 4.0 * float(k % 3))
			Biome.ROCK:
				if k % 2 == 0:
					_stamp_plate(cell, variant, biome, tmax, bands, side, fu, fv,
							(light if k % 4 == 0 else dark.lightened(0.14)))
				else:
					# Редкая растительность и мелкие камни на скале — прямо из
					# пункта 2: плита без них остаётся серым полигоном.
					_stamp_dot(cell, tmax, bands, side, fu, fv,
							BIOME_COLORS[biome].darkened(0.45), 1.2)
			Biome.MUD:
				if k % 2 == 0:
					_stamp_blob(cell, tmax, bands, side, fu, fv, accent, 3.0, 1.8)
				else:
					_stamp_dot(cell, tmax, bands, side, fu, fv, light.darkened(0.16), 1.0)
			Biome.ROAD:
				if k % 3 == 0:
					_stamp_ripple(cell, tmax, bands, side, fu, fv, accent, 9.0)
				else:
					_stamp_dot(cell, tmax, bands, side, fu, fv, light.darkened(0.20), 1.1)


## ——— примитивы деталей ———
##
## Фигуры пишут пиксели только там, где клетка уже имеет право на краску: внутри
## гекса (`tmax ≤ _DETAIL_INSIDE` — деталь не должна лезть на сторону и размазывать
## шов) и, у декали, там, где полоса достаточно непрозрачна. Иначе деталь
## переходила бы границу биомов раньше самого перехода.

## Деталь не должна касаться стороны гекса: 0.97 от апотемы — это ~1 px до края.
const _DETAIL_INSIDE := 0.94


static func _stamp_ok(tmax: PackedFloat32Array, bands: Array, side: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= HEX_SIZE.x or y >= HEX_SIZE.y:
		return false
	var i := y * HEX_SIZE.x + x
	if tmax[i] > _DETAIL_INSIDE:
		return false
	if side >= 0:
		var band: PackedFloat32Array = bands[side]
		return band[i] > BAND_FROM + 0.14
	return true


## Точка-клякса с мягким краем (камень, цветок, блик, щебень).
static func _stamp_dot(
		cell: Image, tmax: PackedFloat32Array, bands: Array, side: int,
		u: float, v: float, color: Color, radius: float
) -> void:
	var cx := int(round(u * HEX_SIZE.x))
	var cy := int(round(v * HEX_SIZE.y))
	var r := int(ceilf(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := float(dx * dx + dy * dy)
			if d > (radius + 0.5) * (radius + 0.5):
				continue
			if not _stamp_ok(tmax, bands, side, cx + dx, cy + dy):
				continue
			var a := clampf(radius + 0.5 - sqrt(d), 0.0, 1.0)
			_blend(cell, cx + dx, cy + dy, color, a)


## Куст: несколько вертикальных штрихов разной высоты — читаемая «кустистость»,
## а не тёмная клякса.
static func _stamp_bush(
		cell: Image, variant: int, index: int, tmax: PackedFloat32Array,
		bands: Array, side: int, u: float, v: float, dark: Color, mid: Color
) -> void:
	var cx := int(round(u * HEX_SIZE.x))
	var cy := int(round(v * HEX_SIZE.y))
	var twigs := 2 + index % 2
	for t in twigs:
		var height := 3 + int(_hash2i(t, variant, index) * 3.0)
		var ox := int(round((float(t) - float(twigs - 1) * 0.5) * 2.2))
		for dy in range(-height, 2):
			_blend(cell, cx + ox, cy + dy, dark if dy < -1 else mid, 0.9)
	_blend(cell, cx, cy + 1, dark.darkened(0.30), 0.7)


## Камыш: тонкий наклонный стебель с макушкой.
static func _stamp_reed(
		cell: Image, biome: int, variant: int, tmax: PackedFloat32Array,
		bands: Array, side: int, u: float, v: float, color: Color
) -> void:
	var cx := int(round(u * HEX_SIZE.x))
	var cy := int(round(v * HEX_SIZE.y))
	var height := 4 + int(_hash2i(cx, variant, biome) * 3.0)
	var lean := -1 if _hash2i(cx, variant, biome + 7) > 0.5 else 1
	for dy in height:
		var x := cx + (dy * lean) / maxi(height, 1)
		_blend(cell, x, cy - dy, color, 0.9)
		_blend(cell, x + 1, cy - dy, color, 0.35)
	_blend(cell, cx + lean, cy - height, color.darkened(0.20), 1.0)


## Пятно-эллипс (полынья, лужа, маслянистая клякса).
static func _stamp_blob(
		cell: Image, tmax: PackedFloat32Array, bands: Array, side: int,
		u: float, v: float, color: Color, rx: float, ry: float
) -> void:
	var cx := int(round(u * HEX_SIZE.x))
	var cy := int(round(v * HEX_SIZE.y))
	for dy in range(-int(ry) - 1, int(ry) + 2):
		for dx in range(-int(rx) - 1, int(rx) + 2):
			if not _stamp_ok(tmax, bands, side, cx + dx, cy + dy):
				continue
			var e := pow(float(dx) / rx, 2.0) + pow(float(dy) / ry, 2.0)
			if e > 1.35:
				continue
			_blend(cell, cx + dx, cy + dy, color, clampf(1.25 - e, 0.0, 1.0) * 0.85)


## Трещина льда: ломаная из трёх звеньев со светлой обводкой — иначе на белом
## снегу она не видна ни при каком тоне.
static func _stamp_crack(
		cell: Image, variant: int, tmax: PackedFloat32Array, bands: Array,
		side: int, u: float, v: float, color: Color
) -> void:
	var px := u * HEX_SIZE.x
	var py := v * HEX_SIZE.y
	var dir := -1.0 if _hash2i(int(u * 71.0), variant, 5) > 0.5 else 1.0
	for seg in 3:
		for step in 4:
			var x := int(px + float(step) * dir)
			var y := int(py + float(seg) * 2.0 + float(step) * 0.4 * dir)
			if _stamp_ok(tmax, bands, side, x, y):
				_blend(cell, x, y, color, 0.8)
			if _stamp_ok(tmax, bands, side, x, y + 1):
				_blend(cell, x, y + 1, color.lightened(0.30), 0.35)
		px += 3.0 * dir
		py += 1.4


## Ряпь воды и барханы: пологая синусоида. Светлая — гребень, тёмная — подветренная
## сторона; одна и та же фигура у двух типов биомов оставлена поэтому, что
## различается только тоном.
## только тоном.
static func _stamp_ripple(
		cell: Image, tmax: PackedFloat32Array, bands: Array, side: int,
		u: float, v: float, color: Color, length: float
) -> void:
	var x0 := int(u * HEX_SIZE.x - length * 0.5)
	var y0 := int(v * HEX_SIZE.y)
	for s in int(length):
		var ph := float(s) / maxf(length, 1.0) * TAU
		var y := y0 + int(round(sin(ph) * 1.2))
		if _stamp_ok(tmax, bands, side, x0 + s, y):
			_blend(cell, x0 + s, y, color, 0.75)
		if _stamp_ok(tmax, bands, side, x0 + s, y + 1):
			_blend(cell, x0 + s, y + 1, color.darkened(0.20), 0.30)


## Скальная плита: обломок со светлой гранью и тёмной обводкой — «обломки плит»
## из пункта 2, а не просто более светлое пятно.
static func _stamp_plate(
		cell: Image, variant: int, biome: int, tmax: PackedFloat32Array,
		bands: Array, side: int, u: float, v: float, color: Color
) -> void:
	var c := Vector2(u * HEX_SIZE.x, v * HEX_SIZE.y)
	var r := 3.0 + 2.0 * _hash2i(int(u * 31.0), variant, biome)
	for ang in 10:
		var a0 := float(ang) / 10.0 * TAU
		var a1 := float(ang + 1) / 10.0 * TAU
		var rr := r * (0.75 + 0.40 * _hash2i(ang, variant, biome))
		_segment(cell, tmax, bands, side,
				c + Vector2(cos(a0), sin(a0) * 0.72) * rr,
				c + Vector2(cos(a1), sin(a1) * 0.72) * rr, color.darkened(0.45), 0.95)
	for dy in range(-int(r * 0.5), 1):
		for dx in range(-int(r * 0.8), int(r * 0.8)):
			if _stamp_ok(tmax, bands, side, int(c.x) + dx, int(c.y) + dy):
				_blend(cell, int(c.x) + dx, int(c.y) + dy, color.lightened(0.22), 0.5)


static func _segment(
		cell: Image, tmax: PackedFloat32Array, bands: Array, side: int,
		a: Vector2, b: Vector2, color: Color, alpha: float
) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		var x := int(round(p.x))
		var y := int(round(p.y))
		if _stamp_ok(tmax, bands, side, x, y):
			_blend(cell, x, y, color, alpha)


## Source-over поверх того, что уже нарисовано в клетке. Альфа клетки (кромка
## гекса, полоса декали) обязана пережить деталь: иначе точка, попавшая на
## полупрозрачный край, сделала бы его непрозрачным — и декаль показала бы
## прямоугольник клетки вместо полосы.
static func _blend(cell: Image, x: int, y: int, color: Color, alpha: float) -> void:
	if x < 0 or y < 0 or x >= HEX_SIZE.x or y >= HEX_SIZE.y:
		return
	var d: Color = cell.get_pixel(x, y)
	var a := clampf(alpha, 0.0, 1.0)
	var out_a := a + d.a * (1.0 - a)
	if out_a <= 0.0:
		return
	var r := (color.r * a + d.r * d.a * (1.0 - a)) / out_a
	var g := (color.g * a + d.g * d.a * (1.0 - a)) / out_a
	var b := (color.b * a + d.b * d.a * (1.0 - a)) / out_a
	cell.set_pixel(x, y, Color(r, g, b, out_a))
