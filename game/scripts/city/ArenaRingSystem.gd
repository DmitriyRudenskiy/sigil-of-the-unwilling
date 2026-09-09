class_name ArenaRingSystem
extends RefCounted

const ArenaClusterSystem := preload("res://scripts/city/ArenaClusterSystem.gd")
const ArenaStorm := preload("res://scripts/city/ArenaStorm.gd")
const HexUtils := preload("res://scripts/core/HexUtils.gd")
const City := preload("res://scripts/world/City.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")

const ARENA_CENTER := Vector2i(5, 4)

const YIELD_KEYS: Array = [&"food", &"industry", &"dust", &"science", &"influence"]

const RING_COLORS: Array = [
	ThemeConfig.C_ARENA_RING0, ThemeConfig.C_ARENA_RING1, ThemeConfig.C_ARENA_RING2,
	ThemeConfig.C_ARENA_RING3, ThemeConfig.C_ARENA_RING4, ThemeConfig.C_ARENA_RING5,
]

static func center() -> Vector2i:
	return ARENA_CENTER

static func ring_of(cell: Vector2i) -> int:
	return HexUtils.hex_distance(cell, center())

static func is_in_arena(cell: Vector2i) -> bool:
	return ring_of(cell) <= GameNumbers.ARENA_RADIUS

static func cells_in_arena() -> Array[Vector2i]:
	var out: Array[Vector2i] = [center()]
	for ring in range(1, GameNumbers.ARENA_RADIUS + 1):
		out.append_array(cells_in_ring(ring))
	return out

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

static func ring_color(ring: int) -> Color:
	var i := clampi(ring, 0, GameNumbers.ARENA_RADIUS)
	return RING_COLORS[i]

static func tile_yield(cell: Vector2i, overrides: Dictionary = {}) -> Dictionary:
	var ring := ring_of(cell)
	if overrides.has(&"ring_yield"):
		return GameNumbers.ring_yield(ring, overrides[&"ring_yield"])
	return GameNumbers.ring_yield(ring)

static func ring_yield_label(ring: int) -> String:
	var y: Dictionary = GameNumbers.ring_yield(ring)
	var parts: Array[String] = []
	for key in [&"food", &"industry"]:
		var v: float = float(y.get(key, 0.0))
		if v > 0.0:
			var icon := "🌾" if key == &"food" else "🏭"
			parts.append(icon + ("%.1f" % v))
	return ", ".join(parts)

static func ring_bonus(def_id: StringName, ring: int, overrides: Dictionary = {}) -> float:
	if overrides.has(&"ring_bonus"):
		return GameNumbers.ring_bonus(def_id, ring, overrides[&"ring_bonus"])
	return GameNumbers.ring_bonus(def_id, ring)

static func building_mult(city: City, b: UniqueBuilding,
		overrides: Dictionary = {}, turn: int = -1) -> float:
	var clm: Dictionary = ArenaClusterSystem.cluster_uids(city)
	var m: float = 1.0 + ring_bonus(b.def.id, ring_of(b.cell), overrides)
	m *= float(clm.get(b.uid, 1.0))
	m *= feature_mult(city, b.def.id, b.cell)
	m *= ArenaStorm.storm_production_mult(city, turn)
	return m

static func apply_ring_multipliers(city: City, overrides: Dictionary = {},
		turn: int = -1) -> int:
	var clm: Dictionary = ArenaClusterSystem.cluster_uids(city)
	var storm: float = ArenaStorm.storm_production_mult(city, turn)
	var n := 0
	for building in city.buildings:
		if building == null or building.def == null:
			continue
		var m: float = 1.0 + ring_bonus(building.def.id, ring_of(building.cell), overrides)
		m *= float(clm.get(building.uid, 1.0))
		m *= feature_mult(city, building.def.id, building.cell)
		if storm < 1.0:
			m *= storm
		building.zone_multiplier = m
		n += 1
	return n

static func cell_feature(city: City, cell: Vector2i) -> StringName:
	var ring := ring_of(cell)
	if ring < 2 or ring > 4:
		return &""
	var h: int = hash("%d:%d:%d" % [city.uid, cell.x, cell.y])
	var v: int = absi(h)
	if float(v % 1000) / 1000.0 >= GameNumbers.ARENA_FEATURE_CHANCE:
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

static func feature_mult(city: City, def_id: StringName, cell: Vector2i) -> float:
	var f: StringName = cell_feature(city, cell)
	match f:
		&"quarry":
			return GameNumbers.ARENA_FEATURE_QUARRY if def_id == &"mine" else 1.0
		&"spring":
			return GameNumbers.ARENA_FEATURE_SPRING if def_id == &"farm" else 1.0
		&"river":
			return GameNumbers.ARENA_FEATURE_RIVER
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
			return "Карьер: рудник ×%.1f" % GameNumbers.ARENA_FEATURE_QUARRY
		&"spring":
			return "Родник: ферма ×%.1f" % GameNumbers.ARENA_FEATURE_SPRING
		&"river":
			return "Река: любое здание ×%.2f" % GameNumbers.ARENA_FEATURE_RIVER
		&"ruins":
			return "Руины: +%.0f золота при постройке" % GameNumbers.ARENA_FEATURE_RUINS_GOLD
		_:
			return ""
	return ""
