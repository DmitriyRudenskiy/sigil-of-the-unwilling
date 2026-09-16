class_name MapForestGenerator
extends RefCounted

const _MapModel = preload("res://scripts/world/MapModel.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")

var model: _MapModel
var rng: RandomNumberGenerator

# Configuration
var FOREST_COVERAGE: float = 0.25
var CLUSTER_SIZE_MIN: int = 5
var CLUSTER_SIZE_MAX: int = 20
var CLEARING_RATIO: float = 0.15

const FOREST_SUITABILITY = {
	_HexUtils.Terrain.GRASS: 0.6,
	_HexUtils.Terrain.SAND: 0.0,
	_HexUtils.Terrain.SWAMP: 0.3,
	_HexUtils.Terrain.SNOW: 0.1,
	_HexUtils.Terrain.MOUNTAIN: 0.0,
	_HexUtils.Terrain.FOREST: 1.0,
}

class ForestCluster:
	var center: Vector2i
	var tiles: Array = []  # ponytail: untyped — literal [seed] не инферится как Array[Vector2i]
	var density: float = 1.0
	var type: String = "dense"

func _init(p_model: _MapModel) -> void:
	model = p_model

func generate() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = model.seed_value + 500
	
	model.forest_clusters.clear()
	
	var target_forest_tiles = int(model.map_width * model.map_height * FOREST_COVERAGE)
	var placed_tiles = 0
	
	var seeds = _select_cluster_seeds()
	
	for seed in seeds:
		if placed_tiles >= target_forest_tiles:
			break
		
		var cluster_size = rng.randi_range(CLUSTER_SIZE_MIN, CLUSTER_SIZE_MAX)
		var cluster = _grow_forest_cluster(seed, cluster_size)
		
		if cluster.tiles.size() > 0:
			model.forest_clusters.append(cluster)
			placed_tiles += cluster.tiles.size()
	
	_apply_forest_terrain()

func _select_cluster_seeds() -> Array[Vector2i]:
	var seeds: Array[Vector2i] = []
	var min_spacing = 8
	
	for y in model.map_height:
		for x in model.map_width:
			var cell = Vector2i(x, y)
			var terrain = model.terrain_grid.get(cell, -1)
			
			if terrain != _HexUtils.Terrain.FOREST:
				continue
			
			var suitability = FOREST_SUITABILITY.get(terrain, 0.0)
			if suitability < 0.3:
				continue
			
			if rng.randf() < suitability * 0.5:
				var too_close = false
				for existing in seeds:
					if _HexUtils.hex_distance(cell, existing) < min_spacing:
						too_close = true
						break
				
				if not too_close:
					seeds.append(cell)
	
	return seeds

func _grow_forest_cluster(seed: Vector2i, target_size: int) -> ForestCluster:
	var cluster = ForestCluster.new()
	cluster.center = seed
	cluster.tiles = [seed]
	
	var frontier: Array[Vector2i] = []
	for neighbor in _HexUtils.get_all_neighbors(seed):
		if _is_suitable_for_forest(neighbor):
			frontier.append(neighbor)
	
	var max_attempts = target_size * 3
	var attempts = 0
	
	while cluster.tiles.size() < target_size and frontier.size() > 0 and attempts < max_attempts:
		attempts += 1
		
		var idx = rng.randi() % frontier.size()
		var candidate = frontier[idx]
		frontier.remove_at(idx)
		
		if cluster.tiles.has(candidate):
			continue
		
		if _is_suitable_for_forest(candidate):
			cluster.tiles.append(candidate)
			
			for neighbor in _HexUtils.get_all_neighbors(candidate):
				if not cluster.tiles.has(neighbor) and not frontier.has(neighbor):
					if _is_suitable_for_forest(neighbor):
						frontier.append(neighbor)
	
	_create_clearings(cluster)
	_calculate_density(cluster)
	
	return cluster

func _is_suitable_for_forest(cell: Vector2i) -> bool:
	if not model.height_grid.has(cell):
		return false
	
	var terrain = model.terrain_grid.get(cell, -1)
	var suitability = FOREST_SUITABILITY.get(terrain, 0.0)
	
	if suitability <= 0.0:
		return false
	
	var height = model.height_grid.get(cell, 0.0)
	if height > 0.8:
		return false
	
	return rng.randf() < suitability

func _create_clearings(cluster: ForestCluster) -> void:
	var clearing_count = int(cluster.tiles.size() * CLEARING_RATIO)
	
	for i in clearing_count:
		if cluster.tiles.size() <= 3:
			break
		
		var idx = rng.randi() % cluster.tiles.size()
		var tile = cluster.tiles[idx]
		
		if cluster.tiles.has(tile):
			cluster.tiles.remove_at(idx)

func _calculate_density(cluster: ForestCluster) -> void:
	var center_dist_sum = 0
	
	for tile in cluster.tiles:
		center_dist_sum += _HexUtils.hex_distance(cluster.center, tile)
	
	var avg_dist = float(center_dist_sum) / cluster.tiles.size() if cluster.tiles.size() > 0 else 0
	var max_dist = sqrt(cluster.tiles.size())
	
	cluster.density = clampf(1.0 - (avg_dist / max_dist), 0.3, 1.0)
	
	if cluster.density > 0.7:
		cluster.type = "dense"
	elif cluster.density > 0.5:
		cluster.type = "normal"
	else:
		cluster.type = "sparse"

func _apply_forest_terrain() -> void:
	for cluster in model.forest_clusters:
		for tile in cluster.tiles:
			var current_terrain = model.terrain_grid.get(tile, -1)
			
			if current_terrain == _HexUtils.Terrain.MOUNTAIN or current_terrain == _HexUtils.Terrain.SNOW:
				continue
			
			if cluster.density > 0.7:
				model.terrain_grid[tile] = _HexUtils.Terrain.DENSE_FOREST
			elif cluster.density > 0.4:
				model.terrain_grid[tile] = _HexUtils.Terrain.FOREST
