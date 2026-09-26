class_name MapRiverGenerator
extends RefCounted

const _MapModel = preload("res://scripts/world/map_model.gd")
const _HexUtils = preload("res://scripts/core/hex_utils.gd")

var model: _MapModel
var rng: RandomNumberGenerator

# Configuration
var MIN_ELEVATION: float = 0.75
var SOURCE_SPACING: int = 8
var MERGE_DISTANCE: int = 3
var MIN_LENGTH: int = 5
var BASE_WIDTH: float = 0.8

class River:
	var source: Vector2i
	var path: Array  # ponytail: untyped — literal [source] не инферится как Array[Vector2i]
	var width: float = 1.0
	var tributaries: Array = []

func _init(p_model: _MapModel) -> void:
	model = p_model

func generate() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = model.seed_value + 300
	
	model.river_grid.clear()
	
	var sources = _select_sources()
	var rivers: Array[River] = []
	
	for source in sources:
		var river = _trace_river(source)
		if river.path.size() >= MIN_LENGTH:
			rivers.append(river)
	
	_merge_rivers(rivers)
	_apply_rivers_to_model(rivers)

func _select_sources() -> Array[Vector2i]:
	var sources: Array[Vector2i] = []
	var blocked: Dictionary = {}
	
	for y in model.map_height:
		for x in model.map_width:
			var cell = Vector2i(x, y)
			if blocked.has(cell):
				continue
			
			var height = model.height_grid.get(cell, 0.0)
			var terrain = model.terrain_grid.get(cell, -1)
			
			if height >= MIN_ELEVATION and terrain != _HexUtils.Terrain.WATER:
				if not _is_adjacent_to_water(cell):
					sources.append(cell)
					_block_area(cell, SOURCE_SPACING, blocked)
	
	return sources

func _is_adjacent_to_water(cell: Vector2i) -> bool:
	for neighbor in _HexUtils.get_all_neighbors(cell):
		if model.terrain_grid.get(neighbor, -1) == _HexUtils.Terrain.WATER:
			return true
	return false

func _block_area(center: Vector2i, radius: int, blocked: Dictionary) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var nb = Vector2i(x, y)
			if _HexUtils.hex_distance(center, nb) <= radius:
				blocked[nb] = true

func _trace_river(source: Vector2i) -> River:
	var river = River.new()
	river.source = source
	river.path = [source]
	
	var current = source
	var max_iterations = model.map_width + model.map_height
	var iterations = 0
	
	while iterations < max_iterations:
		var next = _find_downhill_neighbor(current)
		
		if next == null:
			break
		
		var next_terrain = model.terrain_grid.get(next, -1)
		if next_terrain == _HexUtils.Terrain.WATER or next_terrain == _HexUtils.Terrain.RIVER:
			river.path.append(next)
			break
		
		river.path.append(next)
		current = next
		iterations += 1
	
	_calculate_width(river)
	return river

func _find_downhill_neighbor(cell: Vector2i):  # Variant: null = соседа нет
	var current_height = model.height_grid.get(cell, 0.0)
	var best_neighbor: Vector2i = Vector2i(-1, -1)
	var best_height = current_height
	
	for neighbor in _HexUtils.get_all_neighbors(cell):
		if not _is_in_bounds(neighbor):
			continue
		
		var neighbor_height = model.height_grid.get(neighbor, 0.0)
		if neighbor_height < best_height:
			best_height = neighbor_height
			best_neighbor = neighbor
	
	return best_neighbor if best_neighbor.x >= 0 else null

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < model.map_width and cell.y >= 0 and cell.y < model.map_height

func _calculate_width(river: River) -> void:
	var flow_accumulation = river.path.size()
	river.width = BASE_WIDTH + sqrt(flow_accumulation) * 0.15
	river.width = minf(river.width, 3.0)

func _merge_rivers(rivers: Array[River]) -> void:
	for i in range(rivers.size()):
		for j in range(i + 1, rivers.size()):
			if rivers[i].path.size() == 0 or rivers[j].path.size() == 0:
				continue
			
			var end1 = rivers[i].path[-1]
			var end2 = rivers[j].path[-1]
			
			if _HexUtils.hex_distance(end1, end2) <= MERGE_DISTANCE:
				rivers[i].width += rivers[j].width * 0.5
				rivers[i].tributaries.append(rivers[j])

func _apply_rivers_to_model(rivers: Array[River]) -> void:
	for river in rivers:
		for cell in river.path:
			model.river_grid[cell] = river.width
			
			var terrain = model.terrain_grid.get(cell, -1)
			if terrain != _HexUtils.Terrain.WATER:
				model.terrain_grid[cell] = _HexUtils.Terrain.RIVER
	
	model.invalidate_blocked_cache()
