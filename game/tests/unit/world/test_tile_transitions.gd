extends BaseTest
## Замыкание переходов биомов (world-map-art-variety 2.4) — в процедурном
## носителе (**T-344**).
##
## раньше тест читал манифест атласа, а не реестр в скрипте: переходы были
## данными, и гейт обязан был краснеть раньше пикселя. Манифеста больше нет —
## лист строит `HexCellArt`, поэтому проверяется он же: покрытие (биом × сторона),
## жёсткая семантика отсутствия и **геометия полос** — то, чего манифест проверить
## не мог в принципе: декаль обязан лежать у своей стороны, а не у случайной.
##
## Покрываемая пара соседств — любая пара биомов, которые движок может положить
## в соседние клетки (MapRenderer.TERRAIN_TO_BIOME + ил города из city-hex-layout).

## Шесть сторон клетки — тот же порядок бит, что HexUtils.get_neighbor.
const SIDES := ["E", "NE", "NW", "W", "SW", "SE"]
const OPPOSITE := {"E": "W", "W": "E", "NE": "SW", "SW": "NE", "NW": "SE", "SE": "NW"}

## Дельты стороны в offset-сетке: у чётной и нечётной строки они разные, поэтому
## допускается обе — но только из этого множества (урок: порядок бит HexUtils
## [E, NE, NW, W, SW, SE], а не «по алфавиту», и путаница SE/SW молча рисует
## переход не на том крае).
const SIDE_DELTAS := {
	"E": [Vector2i(1, 0)], "W": [Vector2i(-1, 0)],
	"NE": [Vector2i(0, -1), Vector2i(1, -1)], "NW": [Vector2i(-1, -1), Vector2i(0, -1)],
	"SW": [Vector2i(-1, 1), Vector2i(0, 1)], "SE": [Vector2i(0, 1), Vector2i(1, 1)],
}

## Нормаль стороны в пиксельных координатах (y вниз) — та же таблица, что у
## `HexCellArt.SIDE_ANGLES`, но независимая: тест сверяет лист с собственным
## ожиданием, а не со ссылкой на тот же источник.
const SIDE_VECTORS := {
	"E": Vector2(1, 0), "W": Vector2(-1, 0),
	"NE": Vector2(0.5, -0.866), "NW": Vector2(-0.5, -0.866),
	"SE": Vector2(0.5, 0.866), "SW": Vector2(-0.5, 0.866),
}


## В этом GdUnit4 нет fail_test(); падение с текстом — неравное сравнение.
func _fail(message: String) -> void:
	assert_that(message).is_equal("")


## Биомы, которые рендер способен положить на карту (значит, и столкнуть
## соседями). LAVA/DENSE_FOREST в списке HexCellArt есть, но не рисуются —
## переход для них был бы «мёртвым».
func _paintable() -> Array:
	var ids := {}
	for biome in MapRenderer.TERRAIN_TO_BIOME.values():
		ids[int(biome)] = true
	ids[HexCellArt.Biome.MUD] = true  # ядро города
	return ids.keys()


func _tileset() -> TileSet:
	var ts := HexCellArt.build_hex()
	assert_that(ts).is_not_null()
	return ts


## Покрытие: у каждого рисуемого биома есть база и декаль каждой из шести
## сторон, и клетка реально заведена в обоих источниках (основном и туманном) —
## ровно та инвариантность, из-за которой T-168 когда-то показал пустоту в тумане.
func test_every_paintable_biome_has_all_sides() -> void:
	var ts := _tileset()
	var missing: Array[String] = []
	for biome in _paintable():
		var base: Array = HexCellArt.base_coords(int(biome))
		if base.is_empty():
			missing.append("%s: нет базы" % HexCellArt.BIOME_NAMES[int(biome)])
			continue
		for side in SIDES:
			var coords: Vector2i = HexCellArt.edge_coords(
				int(biome), String(side).to_lower())
			if coords.x < 0:
				missing.append("%s/%s: нет клетки перехода" % [
					HexCellArt.BIOME_NAMES[int(biome)], side])
				continue
			for source_id in [HexCellArt.SOURCE_ID, HexCellArt.FOG_SOURCE_ID]:
				var src := ts.get_source(source_id) as TileSetAtlasSource
				if src == null or not src.has_tile(coords):
					missing.append("%s/%s: клетки %s нет в источнике %d" % [
						HexCellArt.BIOME_NAMES[int(biome)], side, str(coords), source_id])
	if not missing.is_empty():
		_fail("переходов не хватает (%d): %s" % [missing.size(), ", ".join(missing)])


## Жёсткая семантика отсутствия: несуществующая сторона или биом — [-1,-1], а не
## ближайшая подходящая клетка. Молчаливая подмена и есть тот дефект, из-за
## которого «дорога стала травой» (T-341).
func test_unknown_side_or_biome_is_not_silently_substituted() -> void:
	assert_that(HexCellArt.edge_coords(HexCellArt.Biome.GRASS, "up")) \
		.is_equal(Vector2i(-1, -1))
	assert_that(HexCellArt.edge_coords(-1, "e")).is_equal(Vector2i(-1, -1))
	assert_that(HexCellArt.base_coords(-1)).is_empty()
	assert_that(HexCellArt.base_coords(HexCellArt.BIOME_NAMES.size())).is_empty()


## Переход открыт с обеих сторон: структура (столбец = биом, строка = сторона)
## даёт его автоматически, так что проверяется обратное — что декали разных
## сторон не свалились в одну клетку.
func test_pairs_close_in_both_directions() -> void:
	var seen := {}
	var clash: Array[String] = []
	for biome in _paintable():
		for side in SIDES:
			var coords: Vector2i = HexCellArt.edge_coords(
				int(biome), String(side).to_lower())
			var key := "%s:%s" % [str(coords), side]
			if seen.has(str(coords)):
				clash.append("%s и %s" % [String(seen[str(coords)]), key])
			seen[str(coords)] = "%s:%s" % [
				HexCellArt.BIOME_NAMES[int(biome)], side]
	if not clash.is_empty():
		_fail("разные переходы лежат в одной клетке (%d): %s"
			% [clash.size(), ", ".join(clash.slice(0, 6))])


## Геометрия полосы: декаль стороны обязан лежать у своей стороны клетки. Ловит
## то, что не ловила проверка манифеста, — поворот листа на 30° (перепутаны
## нормали сторон и вершины) или перестановку SIDES относительно бит: координаты
## остаются валидными, а переходы рисуются не на том крае.
func test_decal_band_sits_on_its_own_side() -> void:
	var sheet := HexCellArt.sheet()
	assert_that(sheet).is_not_null()
	var img := sheet.get_image()
	var hex := HexCellArt.HEX_SIZE
	var wrong: Array[String] = []
	for biome in [HexCellArt.Biome.GRASS, HexCellArt.Biome.WATER]:
		for side in SIDES:
			var coords: Vector2i = HexCellArt.edge_coords(
				biome, String(side).to_lower())
			var mean := _mean_opaque(img, coords, hex)
			var normal: Vector2 = SIDE_VECTORS[side]
			if mean.length() < 0.05:
				wrong.append("%s/%s: полоса не найдена" % [
					HexCellArt.BIOME_NAMES[biome], side])
				continue
			if mean.normalized().dot(normal) < 0.6:
				wrong.append("%s/%s: полоса смотрит на %s" % [
					HexCellArt.BIOME_NAMES[biome], side, str(mean.normalized())])
	if not wrong.is_empty():
		_fail("декаль не у своей стороны (%d): %s" % [wrong.size(), ", ".join(wrong)])


## Среднее положение непрозрачных пикселей клетки в координатах −1…1 от центра.
func _mean_opaque(img: Image, coords: Vector2i, hex: Vector2i) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for y in hex.y:
		for x in hex.x:
			if img.get_pixel(coords.x * hex.x + x, coords.y * hex.y + y).a > 0.1:
				sum += Vector2((x + 0.5) / hex.x * 2.0 - 1.0, (y + 0.5) / hex.y * 2.0 - 1.0)
				n += 1
	return sum / n if n > 0 else Vector2.ZERO


## Имя стороны обязано соответствовать биту HexUtils: иначе переход рисуется
## не на том крае.
func test_side_names_match_hex_utils() -> void:
	for shift_right in [true, false]:
		for row in [4, 5]:  # чётная и нечётная строки offset-сетки
			var center := Vector2i(4, row)
			for bit in SIDES.size():
				var side: String = SIDES[bit]
				var delta: Vector2i = HexUtils.get_neighbor(center, bit, shift_right) - center
				if not SIDE_DELTAS[side].has(delta):
					_fail("бит %d назван %s, а его дельта %s (строка %d, сдвиг %s)"
						% [bit, side, str(delta), row, str(shift_right)])


## «Напротив» обязано быть инволюцией решётки: шаг в сторону и шаг обратно —
## та же клетка, при любой чётности строки и любом сдвиге.
func test_opposite_side_returns_to_cell() -> void:
	for shift_right in [true, false]:
		for row in [4, 5]:
			var center := Vector2i(4, row)
			for bit in SIDES.size():
				var there: Vector2i = HexUtils.get_neighbor(center, bit, shift_right)
				var back: Vector2i = HexUtils.get_neighbor(
					there, SIDES.find(OPPOSITE[SIDES[bit]]), shift_right)
				if back != center:
					_fail("%s/%s: %s → %s → %s, ожидался %s" % [
						str(center), SIDES[bit], str(there), str(back), str(center),
						str(center)])
