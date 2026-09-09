class_name CityArenaModel
extends RefCounted

const ArenaRingSystem := preload("res://scripts/city/ArenaRingSystem.gd")
const ArenaClusterSystem := preload("res://scripts/city/ArenaClusterSystem.gd")
const ArenaStorm := preload("res://scripts/city/ArenaStorm.gd")
const ArenaTurnRunner := preload("res://scripts/city/ArenaTurnRunner.gd")
const City := preload("res://scripts/world/City.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")

const ARENA_RADIUS := GameNumbers.ARENA_RADIUS
const ARENA_CENTER := ArenaRingSystem.ARENA_CENTER

static func center() -> Vector2i:
	return ArenaRingSystem.center()

static func ring_of(cell: Vector2i) -> int:
	return ArenaRingSystem.ring_of(cell)

static func is_in_arena(cell: Vector2i) -> bool:
	return ArenaRingSystem.is_in_arena(cell)

static func cells_in_arena() -> Array[Vector2i]:
	return ArenaRingSystem.cells_in_arena()

static func cells_in_ring(ring: int) -> Array[Vector2i]:
	return ArenaRingSystem.cells_in_ring(ring)

static func ring_color(ring: int) -> Color:
	return ArenaRingSystem.ring_color(ring)

static func tile_yield(cell: Vector2i, overrides: Dictionary = {}) -> Dictionary:
	return ArenaRingSystem.tile_yield(cell, overrides)

static func ring_bonus(def_id: StringName, ring: int, overrides: Dictionary = {}) -> float:
	return ArenaRingSystem.ring_bonus(def_id, ring, overrides)

static func building_mult(city: City, b: UniqueBuilding,
		overrides: Dictionary = {}, turn: int = -1) -> float:
	return ArenaRingSystem.building_mult(city, b, overrides, turn)

static func apply_ring_multipliers(city: City, overrides: Dictionary = {},
		turn: int = -1) -> int:
	return ArenaRingSystem.apply_ring_multipliers(city, overrides, turn)

static func cell_feature(city: City, cell: Vector2i) -> StringName:
	return ArenaRingSystem.cell_feature(city, cell)

static func feature_mult(city: City, def_id: StringName, cell: Vector2i) -> float:
	return ArenaRingSystem.feature_mult(city, def_id, cell)

static func feature_glyph(feature: StringName) -> String:
	return ArenaRingSystem.feature_glyph(feature)

static func feature_name(feature: StringName) -> String:
	return ArenaRingSystem.feature_name(feature)

static func clusters(city: City) -> Array:
	return ArenaClusterSystem.clusters(city)

static func cluster_uids(city: City) -> Dictionary:
	return ArenaClusterSystem.cluster_uids(city)

static func cluster_worker_housing(city: City) -> int:
	return ArenaClusterSystem.cluster_worker_housing(city)

static func is_storm_turn(turn: int) -> bool:
	return ArenaStorm.is_storm_turn(turn)

static func storm_production_mult(city: City, turn: int) -> float:
	return ArenaStorm.storm_production_mult(city, turn)

static func storm_food_penalty(city: City, turn: int) -> float:
	return ArenaStorm.storm_food_penalty(city, turn)

static func make_city(overrides: Dictionary = {}) -> City:
	return ArenaTurnRunner.make_city(overrides)

static func run_turn(city: City, turn: int, overrides: Dictionary = {}) -> Dictionary:
	return ArenaTurnRunner.run_turn(city, turn, overrides)

static func place_building(
	city: City, def: UniqueBuilding.Def, cell: Vector2i,
	overrides: Dictionary = {}) -> CityCheck:
	return ArenaTurnRunner.place_building(city, def, cell, overrides)

static func arena_tile_free(city: City, tile: Vector2i, except_uid: int = -1) -> bool:
	return ArenaTurnRunner.arena_tile_free(city, tile, except_uid)

static func seat_workers(city: City) -> int:
	return ArenaTurnRunner.seat_workers(city)

static func hire_worker(city: City) -> int:
	return ArenaTurnRunner.hire_worker(city)

static func score(city: City, starve_days: int) -> float:
	return ArenaDemoScenario.score(city, starve_days)

static func run_demo_plan(turns: int = 48, overrides: Dictionary = {}) -> Dictionary:
	return ArenaDemoScenario.run_demo_plan(turns, overrides)
