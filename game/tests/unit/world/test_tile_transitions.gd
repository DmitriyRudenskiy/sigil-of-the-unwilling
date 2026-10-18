extends BaseTest
## Замыкание переходов биомов (world-map-art-variety, задача 2.4).
##
## Тест читает манифест атласа, а не реестр в скрипте: переходы — данные, и
## проверка обязана краснеть до того, как появится код, который их рисует
## (урок инициативы: сначала гейт, потом пиксель).
##
## Покрываемая пара соседств — любая пара биомов, которые движок может положить
## в соседние клетки (MapRenderer.TERRAIN_TO_BIOME + ил города из city-hex-layout).
## Для такой пары и любого из шести направлений у обеих сторон обязан найтись
## переход: иначе на границе остаётся голый шов. Направление берётся из
## HexUtils (bit 0..5 = E, NE, NW, W, SE, SW), «напротив» — его же зеркало.

const MANIFEST := "res://assets/tiles/world_map_atlas.json"

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




## В этом GdUnit4 нет fail_test(); падение с текстом — неравное сравнение.
func _fail(message: String) -> void:
	assert_that(message).is_equal("")


func _manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		_fail(
			"манифеста атласа нет: %s — переходы нечем замыкать (задача 4.1)" % MANIFEST)
		return {}
	var file := FileAccess.open(MANIFEST, FileAccess.READ)
	if file == null:
		_fail("манифест атласа не читается: %s" % MANIFEST)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("манифест атласа — не объект JSON: %s" % MANIFEST)
		return {}
	return parsed


## Клетки манифеста, сгруппированные переходов: {biome: {side: id}}.
func _edges(manifest: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cell in manifest.get("cells", []):
		if String(cell.get("kind", "")) != "edge":
			continue
		var biome := String(cell.get("biome", ""))
		if not out.has(biome):
			out[biome] = {}
		# Манифест — данные, и имя стороны в нём строчное (оно входит в id клетки:
		# edge_grass_e). Контракт направления — верхний регистр SIDES, поэтому
		# нормализуем здесь, а не в генераторе.
		out[biome][String(cell.get("side", "")).to_upper()] = String(cell.get("id", ""))
	return out


## Биомы, которые рендер способен положить на карту (значит, и столкнуть
## соседями). LAVA/DENSE_FOREST в списке TileAtlas есть, но не рисуются —
## переход для них был бы «мёртвым».
func _paintable() -> Array:
	var names := {}
	for biome in MapRenderer.TERRAIN_TO_BIOME.values():
		names[TileAtlas.BIOME_NAMES[biome]] = true
	names[TileAtlas.BIOME_NAMES[TileAtlas.Biome.MUD]] = true  # ядро города
	return names.keys()


func test_manifest_present() -> void:
	var manifest := _manifest()
	assert_that(manifest.is_empty()).is_false()
	assert_that(manifest.get("cells", [])).is_not_empty()


func test_every_paintable_biome_has_all_sides() -> void:
	var edges := _edges(_manifest())
	var missing: Array[String] = []
	for biome in _paintable():
		if not edges.has(biome):
			missing.append("%s: ни одного перехода" % biome)
			continue
		for side in SIDES:
			if not (edges[biome] as Dictionary).has(side):
				missing.append("%s/%s" % [biome, side])
	if not missing.is_empty():
		_fail("переходов не хватает (%d): %s" % [missing.size(), ", ".join(missing)])


func test_no_dead_transition() -> void:
	var paintable := _paintable()
	var dead: Array[String] = []
	for biome in _edges(_manifest()).keys():
		if not paintable.has(biome):
			dead.append(biome)
	if not dead.is_empty():
		_fail(
			"переходы для биомов, которых на карте не бывает: %s "
			% ", ".join(dead))


## Замыкание по паре: для любой допустимой пары и любого направления переход
## есть с обеих сторон, причём смотрят они друг на друга.
func test_pairs_close_in_both_directions() -> void:
	var edges := _edges(_manifest())
	var open_pairs: Array[String] = []
	for a in _paintable():
		for b in _paintable():
			if a == b or not edges.has(a) or not edges.has(b):
				continue
			for side in SIDES:
				var there := (edges[a] as Dictionary).has(side)
				var back := (edges[b] as Dictionary).has(OPPOSITE[side])
				if there != back:
					open_pairs.append("%s:%s ↔ %s:%s" % [a, side, b, OPPOSITE[side]])
	if not open_pairs.is_empty():
		_fail("переход открыт с одной стороны (%d): %s"
			% [open_pairs.size(), ", ".join(open_pairs.slice(0, 6))])



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
