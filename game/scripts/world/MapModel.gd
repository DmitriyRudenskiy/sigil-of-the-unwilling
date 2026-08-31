class_name MapModel
extends RefCounted
## Данные карты: шум, биомы, проходимость.

const _UnitStack = preload("res://scripts/entities/UnitStack.gd")

var map_width: int = 60
var map_height: int = 60
var seed_value: int = 12345
var village_count: int = 8

# Пороги биомов — в одном месте для балансировки
var WATER_THRESHOLD: float = 0.35
var SAND_THRESHOLD: float = 0.40
var GRASS_THRESHOLD: float = 0.65
var FOREST_THRESHOLD: float = 0.75
var MOUNTAIN_THRESHOLD: float = 0.85
var SWAMP_THRESHOLD: float = 0.42
var TEMP_SNOW_MOUNTAIN: float = 0.3
var TEMP_SNOW_GRASS: float = 0.2
var TEMP_SNOW_FOREST: float = 0.3

var terrain_grid: Dictionary = {}
var height_grid: Dictionary = {}

var village_cells: Array[Vector2i] = []
var resource_cells: Dictionary = {}
var decor_cells: Dictionary = {}
var enemy_stacks: Dictionary = {}
var chest_cells: Array[Vector2i] = []

var _blocked_cache: Dictionary = {}
var _blocked_cache_dirty: bool = true


func generate_noise() -> void:
	var hn := FastNoiseLite.new()
	hn.seed = seed_value
	hn.frequency = 0.03
	hn.fractal_octaves = 5

	var tn := FastNoiseLite.new()
	tn.seed = seed_value + 100
	tn.frequency = 0.02
	tn.fractal_octaves = 3

	var mn := FastNoiseLite.new()
	mn.seed = seed_value + 200
	mn.frequency = 0.025
	mn.fractal_octaves = 3

	terrain_grid.clear()
	height_grid.clear()
	invalidate_blocked_cache()

	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			var h := (hn.get_noise_2d(x, y) + 1.0) / 2.0
			var t := (tn.get_noise_2d(x, y) + 1.0) / 2.0
			var m := (mn.get_noise_2d(x, y) + 1.0) / 2.0
			height_grid[cell] = h
			terrain_grid[cell] = get_biome_terrain_id(h, t, m)


func get_biome_terrain_id(height: float, temp: float, moist: float) -> int:
	if height < WATER_THRESHOLD:
		return HexUtils.Terrain.WATER
	elif height < SWAMP_THRESHOLD and moist > 0.55:
		return HexUtils.Terrain.SWAMP
	elif height < SAND_THRESHOLD:
		return HexUtils.Terrain.SAND
	elif height > MOUNTAIN_THRESHOLD:
		return HexUtils.Terrain.SNOW if temp < TEMP_SNOW_MOUNTAIN else HexUtils.Terrain.MOUNTAIN
	elif height > FOREST_THRESHOLD:
		if moist > 0.4:
			return HexUtils.Terrain.FOREST
		return HexUtils.Terrain.SNOW if temp < TEMP_SNOW_FOREST else HexUtils.Terrain.MOUNTAIN
	else:
		if moist < 0.25:
			return HexUtils.Terrain.SAND
		return HexUtils.Terrain.SNOW if temp < TEMP_SNOW_GRASS else HexUtils.Terrain.GRASS


func is_walkable(cell: Vector2i) -> bool:
	if not terrain_grid.has(cell):
		return false
	# Без `in [a, b]`: не аллоцирует Array на каждом вызове (hot path)
	var t: int = terrain_grid[cell]
	return t != HexUtils.Terrain.WATER and t != HexUtils.Terrain.MOUNTAIN


func is_walkable_with_effects(cell: Vector2i, has_levitation: bool = false) -> bool:
	if not terrain_grid.has(cell):
		return false

	var t: int = terrain_grid[cell]
	if t == HexUtils.Terrain.WATER:
		return has_levitation

	return t != HexUtils.Terrain.MOUNTAIN


func get_terrain_name(cell: Vector2i) -> String:
	var tid: int = terrain_grid.get(cell, HexUtils.Terrain.GRASS)
	return HexUtils.TERRAIN_NAMES[tid] if tid < HexUtils.TERRAIN_NAMES.size() else "grass"


func get_terrain_id(cell: Vector2i) -> int:
	return terrain_grid.get(cell, HexUtils.Terrain.GRASS)


func get_blocked_cells() -> Dictionary:
	if _blocked_cache_dirty:
		_rebuild_blocked_cache()

	return _blocked_cache

func _rebuild_blocked_cache() -> void:
	_blocked_cache.clear()

	for cell in terrain_grid:
		if not is_walkable(cell):
			_blocked_cache[cell] = true

	_blocked_cache_dirty = false

func invalidate_blocked_cache() -> void:
	_blocked_cache_dirty = true

func set_terrain(cell: Vector2i, terrain_id: int) -> void:
	terrain_grid[cell] = terrain_id
	invalidate_blocked_cache()


# Port: ForlornU/HexagonalMapGodot tile_factory.gd invalidate_ocean_hill_neighbors (MIT)
# Голые горы не могут стоять вплотную к воде — вставляем песчаную кромку.
func smooth_invalid_adjacencies() -> void:
	var to_change: Array[Vector2i] = []
	for cell in terrain_grid:
		var t2: int = terrain_grid[cell]
		if t2 != HexUtils.Terrain.MOUNTAIN and t2 != HexUtils.Terrain.SNOW:
			continue
		for nb in HexUtils.get_all_neighbors(cell):
			if terrain_grid.get(nb, -1) == HexUtils.Terrain.WATER:
				to_change.append(cell)
				break
	for cell in to_change:
		terrain_grid[cell] = HexUtils.Terrain.SAND
	if to_change.size() > 0:
		invalidate_blocked_cache()
