class_name MapRoadGenerator
extends RefCounted

const _MapModel = preload("res://scripts/world/MapModel.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")
const _HexPathfinding = preload("res://scripts/core/HexPathfinding.gd")

var model: _MapModel
var rng: RandomNumberGenerator

enum RoadType { PRIMARY, SECONDARY, TRAIL }

# Configuration
var AVOID_SWAMP: bool = true
var BRIDGE_ON_RIVER: bool = true
var MAX_PATH_COST: float = 50.0

const TERRAIN_COSTS = {
	_HexUtils.Terrain.GRASS: 1.0,
	_HexUtils.Terrain.SAND: 1.2,
	_HexUtils.Terrain.FOREST: 1.5,
	_HexUtils.Terrain.SWAMP: 3.0,
	_HexUtils.Terrain.MOUNTAIN: 999.0,
	_HexUtils.Terrain.SNOW: 1.3,
	_HexUtils.Terrain.RIVER: 2.0,
	_HexUtils.Terrain.WATER: 999.0,
}

class RoadSegment:
	var start: Vector2i
	var end: Vector2i
	var type: RoadType
	var path: Array[Vector2i]
	var bridges: Array[Vector2i] = []

func _init(p_model: _MapModel) -> void:
	model = p_model

func generate() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = model.seed_value + 400
	
	model.road_grid.clear()
	
	if model.village_cells.size() > 0:
		_connect_villages()
	
	if model.resource_cells.size() > 0:
		_connect_resources()

func _connect_villages() -> void:
	var villages = model.village_cells.duplicate()
	if villages.size() < 2:
		return
	
	var mst = _build_minimum_spanning_tree(villages)
	
	for edge in mst:
		var path = _find_path(edge[0], edge[1])
		if path.size() > 0:
			var segment = RoadSegment.new()
			segment.start = edge[0]
			segment.end = edge[1]
			segment.type = RoadType.PRIMARY
			segment.path = path
			_detect_bridges(segment)
			_paint_road(segment)
			_persist_bridges(segment)

func _build_minimum_spanning_tree(villages: Array[Vector2i]) -> Array:
	var mst: Array = []
	var connected: Dictionary = {villages[0]: true}
	var unconnected: Array[Vector2i] = []
	
	for i in range(1, villages.size()):
		unconnected.append(villages[i])
	
	while unconnected.size() > 0:
		var best_edge: Array = []
		var best_dist = INF
		
		for connected_cell in connected:
			for i in range(unconnected.size()):
				var unconnected_cell = unconnected[i]
				var dist = _HexUtils.hex_distance(connected_cell, unconnected_cell)
				if dist < best_dist:
					best_dist = dist
					best_edge = [connected_cell, unconnected_cell]
		
		if best_edge.size() > 0:
			mst.append(best_edge)
			connected[best_edge[1]] = true
			unconnected.remove_at(unconnected.find(best_edge[1]))
		else:
			break
	
	return mst

func _connect_resources() -> void:
	for resource_cell in model.resource_cells:
		var nearest = _find_nearest_village(resource_cell)
		if nearest != null:
			var path = _find_path(resource_cell, nearest)
			if path.size() > 0:
				var segment = RoadSegment.new()
				segment.start = resource_cell
				segment.end = nearest
				segment.type = RoadType.SECONDARY
				segment.path = path
				_detect_bridges(segment)
				_paint_road(segment)
				_persist_bridges(segment)

func _find_nearest_village(cell: Vector2i) -> Vector2i:
	var nearest: Vector2i = Vector2i(-1, -1)
	var best_dist = INF
	
	for village in model.village_cells:
		var dist = _HexUtils.hex_distance(cell, village)
		if dist < best_dist:
			best_dist = dist
			nearest = village
	
	return nearest if nearest.x >= 0 else null

func _find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var blocked = model.get_blocked_cells()
	
	var cost_func = func(cell: Vector2i) -> float:
		var terrain = model.terrain_grid.get(cell, _HexUtils.Terrain.GRASS)
		var cost = TERRAIN_COSTS.get(terrain, 1.0)
		if AVOID_SWAMP and terrain == _HexUtils.Terrain.SWAMP:
			cost *= 2.0
		return cost
	
	var path = _HexPathfinding.astar(start, end, blocked, cost_func, model.map_width, model.map_height)
	return path if path != null else []

func _detect_bridges(segment: RoadSegment) -> void:
	segment.bridges.clear()
	
	for cell in segment.path:
		if model.river_grid.has(cell):
			segment.bridges.append(cell)

func _persist_bridges(segment: RoadSegment) -> void:
	if segment.bridges.is_empty():
		return
	for cell in segment.bridges:
		model.bridge_cells[cell] = true
	model.invalidate_blocked_cache()

func _paint_road(segment: RoadSegment) -> void:
	for cell in segment.path:
		model.road_grid[cell] = segment.type
		
		var current_terrain = model.terrain_grid.get(cell, -1)
		if current_terrain != _HexUtils.Terrain.RIVER and current_terrain != _HexUtils.Terrain.WATER:
			if current_terrain == _HexUtils.Terrain.MOUNTAIN or current_terrain == _HexUtils.Terrain.SNOW:
				continue
			model.terrain_grid[cell] = _HexUtils.Terrain.ROAD
	
	model.invalidate_blocked_cache()
