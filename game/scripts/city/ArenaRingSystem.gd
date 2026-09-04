class_name ArenaRingSystem
extends RefCounted
## Геометрия и множители строительной арены (M3): кольца, прирост клеток,
## бонусы зданий, особенности, zone_multiplier. Перенос из CityArenaModel.

const ArenaBalance := preload("res://scripts/city/ArenaBalance.gd")
const ArenaClusterSystem := preload("res://scripts/city/ArenaClusterSystem.gd")
const ArenaStorm := preload("res://scripts/city/ArenaStorm.gd")
const HexUtils := preload("res://scripts/core/HexUtils.gd")
const City := preload("res://scripts/world/City.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")

## Абсолютный центр арены. Строка чЁТНАЯ: в odd-r offset форма кольца
## зависит от parity строки, и только чётная строка совпадает с
## «стандартным» кольцо вокруг (0,0), на которое рассчитан демо-план.
## Сдвиг вправо, чтобы все клетки имели x >= 0 (City.gd пропускает
## работников с tile.x < 0: is_worker_tile_free / _ensure_exploited_cache).
const ARENA_CENTER := Vector2i(5, 4)

## Порядок ресурсов прирост кольца (совпадает с RING_YIELD).
const YIELD_KEYS: Array = [&"food", &"industry", &"dust", &"science", &"influence"]

## Палитра колец: index = номер кольца (0 = центр).
const RING_COLORS: Array = [
	Color(0.95, 0.8, 0.3),     # 0 — центр (золото)
	Color(0.33, 0.58, 0.33),   # 1 — зелёное
	Color(0.78, 0.66, 0.32),   # 2 — жёлтое
	Color(0.72, 0.42, 0.36),   # 3 — красное
	Color(0.56, 0.42, 0.68),   # 4 — фиолетовое
	Color(0.36, 0.52, 0.78),   # 5 — синее
]


## Центр арены и города.
static func center() -> Vector2i:
	return ARENA_CENTER


## Номер кольца клетки (0 = центр).
static func ring_of(cell: Vector2i) -> int:
	return HexUtils.hex_distance(cell, center())


static func is_in_arena(cell: Vector2i) -> bool:
	return ring_of(cell) <= ArenaBalance.ARENA_RADIUS


## Все клетки арены: центр + кольца 1..R (91 клетка при R=5).
static func cells_in_arena() -> Array[Vector2i]:
	var out: Array[Vector2i] = [center()]
	for ring in range(1, ArenaBalance.ARENA_RADIUS + 1):
		out.append_array(cells_in_ring(ring))
	return out


## Все клетки заданного кольца (6*ring клеток). Клетки в АБСОЛЮТНЫХ
## координатах арены. Offset-координаты не инвариантны к сдвигу (parity),
## поэтому кольцо генерируется прямым сканом окрестности центра с точной
## проверкой hex_distance — детерминированно (по строкам).
static func cells_in_ring(ring: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ring < 1:
		return out
	var c: Vector2i = center()
	for y in range(-ring - 1, ring + 2):
		for x in range(-ring - 1, ring + 2):
			var cell := c + Vector2i(x, y)
			if HexUtils.hex_distance(cell, c) == ring:
				out.append(cell)
	return out


## Цвет кольца (для представления и легенды).
static func ring_color(ring: int) -> Color:
	var i := clampi(ring, 0, ArenaBalance.ARENA_RADIUS)
	return RING_COLORS[i]


## Прирост ресурсов на клетке (для City.tile_yield_fn).
static func tile_yield(cell: Vector2i, overrides: Dictionary = {}) -> Dictionary:
	var ring := ring_of(cell)
	if overrides.has(&"ring_yield"):
		return ArenaBalance.ring_yield(ring, overrides[&"ring_yield"])
	return ArenaBalance.ring_yield(ring)


## Бонус здания на кольце (с учётом опциональных переопределений —
## их использует тюнер).
static func ring_bonus(def_id: StringName, ring: int, overrides: Dictionary = {}) -> float:
	if overrides.has(&"ring_bonus"):
		return ArenaBalance.ring_bonus(def_id, ring, overrides[&"ring_bonus"])
	return ArenaBalance.ring_bonus(def_id, ring)


## Полный множитель здания: кольцо × кластер × особенность × шторм.
## `turn` — для шторма (−1 или 0 = шторма нет).
static func building_mult(city: City, b: UniqueBuilding,
		overrides: Dictionary = {}, turn: int = -1) -> float:
	var clm: Dictionary = ArenaClusterSystem.cluster_uids(city)
	var m: float = 1.0 + ring_bonus(b.def.id, ring_of(b.cell), overrides)
	m *= float(clm.get(b.uid, 1.0))
	m *= feature_mult(city, b.def.id, b.cell)
	m *= ArenaStorm.storm_production_mult(city, turn)
	return m


## Применить множители: zone_multiplier = кольцо × кластер × особенность
## × шторм. Вызывается ПОСЛЕ фазы города (она сбрасывает множитель) и
## ПЕРЕД экономикой (она его читает). Возвращает число затронутых зданий.
static func apply_ring_multipliers(city: City, overrides: Dictionary = {},
		turn: int = -1) -> int:
	var clm: Dictionary = ArenaClusterSystem.cluster_uids(city)
	var storm: float = ArenaStorm.storm_production_mult(city, turn)
	var n := 0
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		var m: float = 1.0 + ring_bonus(b.def.id, ring_of(b.cell), overrides)
		m *= float(clm.get(b.uid, 1.0))
		m *= feature_mult(city, b.def.id, b.cell)
		if storm < 1.0:
			m *= storm
		b.zone_multiplier = m
		n += 1
	return n


## ==================== ОСОБЕННОСТИ КЛЕТОК ====================

## Детерминированная особенность клетки (хэш uid города + координаты).
## Только кольца 2..4; &"" — обычная клетка. Виды: quarry (рудник ×),
## spring (ферма ×), river (всё ×), ruins (+золото при постройке).
static func cell_feature(city: City, cell: Vector2i) -> StringName:
	var ring := ring_of(cell)
	if ring < 2 or ring > 4:
		return &""
	var h: int = hash("%d:%d:%d" % [city.uid, cell.x, cell.y])
	var v: int = absi(h)
	if float(v % 1000) / 1000.0 >= ArenaBalance.FEATURE_CHANCE:
		return &""
	match v % 4:
		0:
			return &"quarry"
		1:
			return &"spring"
		2:
			return &"river"
		_:
			return &"ruins"
	return &""


## Множитель производства на особенности (1.0 = нет). Карьер и родник —
## только для своего здания, река — для любого.
static func feature_mult(city: City, def_id: StringName, cell: Vector2i) -> float:
	var f: StringName = cell_feature(city, cell)
	match f:
		&"quarry":
			return ArenaBalance.FEATURE_QUARRY_MULT if def_id == &"mine" else 1.0
		&"spring":
			return ArenaBalance.FEATURE_SPRING_MULT if def_id == &"farm" else 1.0
		&"river":
			return ArenaBalance.FEATURE_RIVER_MULT
		_:
			return 1.0
	return 1.0


static func feature_glyph(feature: StringName) -> String:
	match feature:
		&"quarry":
			return "⛏"
		&"spring":
			return "💧"
		&"river":
			return "🌊"
		&"ruins":
			return "🏛"
		_:
			return ""
	return ""


static func feature_name(feature: StringName) -> String:
	match feature:
		&"quarry":
			return "Карьер: рудник ×%.1f" % ArenaBalance.FEATURE_QUARRY_MULT
		&"spring":
			return "Родник: ферма ×%.1f" % ArenaBalance.FEATURE_SPRING_MULT
		&"river":
			return "Река: любое здание ×%.2f" % ArenaBalance.FEATURE_RIVER_MULT
		&"ruins":
			return "Руины: +%.0f золота при постройке" % ArenaBalance.FEATURE_RUINS_GOLD
		_:
			return ""
	return ""
