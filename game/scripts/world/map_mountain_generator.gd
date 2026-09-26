class_name MapMountainGenerator
extends RefCounted

const _MapModel = preload("res://scripts/world/map_model.gd")
const _HexUtils = preload("res://scripts/core/hex_utils.gd")

var model: _MapModel
var rng: RandomNumberGenerator

# Configuration
var FAULT_COUNT: int = 5
var UPLIFT_INTENSITY: float = 0.4
var EROSION_PASSES: int = 2
var SNOW_ELEVATION: float = 0.9
var SNOW_TEMP_THRESHOLD: float = 0.3

class FaultLine:
	var path: Array[Vector2i]
	var uplift: float
	var length: int

func _init(p_model: _MapModel) -> void:
	model = p_model

func generate() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = model.seed_value + 100
	
	var faults = _generate_fault_lines(FAULT_COUNT)
	
	for fault in faults:
		_apply_uplift(fault)
	
	_apply_erosion()
	_apply_snow_caps()

func _generate_fault_lines(count: int) -> Array[FaultLine]:
	var faults: Array[FaultLine] = []
	
	for i in count:
		var fault = FaultLine.new()
		fault.uplift = UPLIFT_INTENSITY * (0.8 + rng.randf() * 0.4)
		
		var start = _random_edge_point()
		var direction = Vector2(rng.randf() - 0.5, rng.randf() - 0.5).normalized()
		
		fault.path = _trace_fault_line(start, direction)
		fault.length = fault.path.size()
		
		if fault.length > 5:
			faults.append(fault)
	
	return faults

func _random_edge_point() -> Vector2i:
	var side = rng.randi() % 4
	match side:
		0: return Vector2i(rng.randi() % model.map_width, 0)
		1: return Vector2i(model.map_width - 1, rng.randi() % model.map_height)
		2: return Vector2i(rng.randi() % model.map_width, model.map_height - 1)
		3: return Vector2i(0, rng.randi() % model.map_height)
	return Vector2i(0, 0)

func _trace_fault_line(start: Vector2i, direction: Vector2, length: int = -1) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = start
	var max_length = length if length > 0 else int((model.map_width + model.map_height) * 0.8)
	
	var angle_variance = 0.3
	
	for i in max_length:
		if not _is_in_bounds(current):
			break
		
		path.append(current)
		
		var variance = (rng.randf() - 0.5) * angle_variance
		var new_dir = Vector2(
			direction.x * cos(variance) - direction.y * sin(variance),
			direction.x * sin(variance) + direction.y * cos(variance)
		).normalized()
		
		direction = direction.lerp(new_dir, 0.3)
		current = current + Vector2i(roundi(direction.x * 2), roundi(direction.y * 2))
	
	return path

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < model.map_width and cell.y >= 0 and cell.y < model.map_height

func _apply_uplift(fault: FaultLine) -> void:
	for cell in fault.path:
		if not model.height_grid.has(cell):
			continue
		
		model.height_grid[cell] += fault.uplift
		
		for neighbor in _HexUtils.get_all_neighbors(cell):
			if not model.height_grid.has(neighbor):
				continue
			
			var dist = _hex_distance_to_path(neighbor, fault.path)
			if dist <= 4:
				var influence = fault.uplift * (1.0 - dist / 4.0)
				model.height_grid[neighbor] += influence * 0.5

func _hex_distance_to_path(cell: Vector2i, path: Array[Vector2i]) -> float:
	var min_dist = INF
	for p in path:
		var dist = _HexUtils.hex_distance(cell, p)
		if dist < min_dist:
			min_dist = dist
	return min_dist

func _apply_erosion() -> void:
	for pass_idx in EROSION_PASSES:
		var changes: Dictionary = {}
		
		for cell in model.height_grid:
			var current = model.height_grid[cell]
			var avg = current
			var count = 1
			
			for neighbor in _HexUtils.get_all_neighbors(cell):
				if model.height_grid.has(neighbor):
					avg += model.height_grid[neighbor]
					count += 1
			
			avg /= count
			var smoothed = current * 0.7 + avg * 0.3
			changes[cell] = smoothed
		
		for cell in changes:
			model.height_grid[cell] = changes[cell]

func _apply_snow_caps() -> void:
	var temp_noise = FastNoiseLite.new()
	temp_noise.seed = model.seed_value + 999
	temp_noise.frequency = 0.02
	
	for cell in model.height_grid:
		var height = model.height_grid[cell]
		var temp = (temp_noise.get_noise_2d(cell.x, cell.y) + 1.0) / 2.0
		
		var current_terrain = model.terrain_grid.get(cell, -1)
		
		if height >= SNOW_ELEVATION and temp < SNOW_TEMP_THRESHOLD:
			model.terrain_grid[cell] = _HexUtils.Terrain.SNOW
		elif height >= 0.85:
			if current_terrain != _HexUtils.Terrain.SNOW:
				model.terrain_grid[cell] = _HexUtils.Terrain.MOUNTAIN
