class_name MapModel
extends RefCounted
## Данные карты: шум, биомы, проходимость.

var map_width: int = 60
var map_height: int = 60
var seed_value: int = 12345
var village_count: int = 8

var water_threshold: float = 0.35
var sand_threshold: float = 0.40
var grass_threshold: float = 0.65
var forest_threshold: float = 0.75
var mountain_threshold: float = 0.85
var swamp_threshold: float = 0.42

var terrain_grid: Dictionary = {}
var height_grid: Dictionary = {}

var village_cells: Array[Vector2i] = []
var resource_cells: Dictionary = {}
var decor_cells: Dictionary = {}
var enemy_stacks: Dictionary[Vector2i, Array[UnitStack]] = {}


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

	for y in map_height:
		for x in map_width:
			var cell := Vector2i(x, y)
			var h := (hn.get_noise_2d(x, y) + 1.0) / 2.0
			var t := (tn.get_noise_2d(x, y) + 1.0) / 2.0
			var m := (mn.get_noise_2d(x, y) + 1.0) / 2.0
			height_grid[cell] = h
			terrain_grid[cell] = get_biome_terrain_id(h, t, m)


func get_biome_terrain_id(height: float, temp: float, moist: float) -> int:
	if height < water_threshold:
		return HexUtils.Terrain.WATER
	elif height < swamp_threshold and moist > 0.55:
		return HexUtils.Terrain.SWAMP
	elif height < sand_threshold:
		return HexUtils.Terrain.SAND
	elif height > mountain_threshold:
		return HexUtils.Terrain.SNOW if temp < 0.3 else HexUtils.Terrain.MOUNTAIN
	elif height > forest_threshold:
		if moist > 0.4:
			return HexUtils.Terrain.FOREST
		return HexUtils.Terrain.SNOW if temp < 0.3 else HexUtils.Terrain.MOUNTAIN
	else:
		if moist < 0.25:
			return HexUtils.Terrain.SAND
		return HexUtils.Terrain.SNOW if temp < 0.2 else HexUtils.Terrain.GRASS


func is_walkable(cell: Vector2i) -> bool:
	if not terrain_grid.has(cell):
		return false
	return terrain_grid[cell] not in [HexUtils.Terrain.WATER, HexUtils.Terrain.MOUNTAIN]


func get_blocked_cells() -> Dictionary:
	var b: Dictionary = {}
	for cell in terrain_grid:
		if not is_walkable(cell):
			b[cell] = true
	return b
