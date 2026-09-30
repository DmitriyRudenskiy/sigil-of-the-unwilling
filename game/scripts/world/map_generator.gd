extends Node2D
class_name MapGenerator

const _VisibilityMap = preload("res://scripts/core/visibility_map.gd")

var model
var renderer
var spawner
var visibility: _VisibilityMap = null
var reachable_cells: Dictionary = {}

var _tile_map: TileMapLayer
var _decor_layer: TileMapLayer
var _resource_layer: Node2D

var terrain_grid: Dictionary:
	get: return model.terrain_grid if model != null else {}

var height_grid: Dictionary:
	get: return model.height_grid if model != null else {}

var village_cells: Array[Vector2i]:
	get: return model.village_cells if model != null else []

var resource_cells: Dictionary:
	get: return model.resource_cells if model != null else {}

var decor_cells: Dictionary:
	get: return model.decor_cells if model != null else {}

var enemy_stacks: Dictionary:
	get: return model.enemy_stacks if model != null else {}

var _seed_value: int = 0
var _map_width: int = 0
var _map_height: int = 0
var hex_shift_right: bool = true

var seed_value: int:
	get:
		return _seed_value
	set(v):
		_seed_value = v
		if model != null:
			model.seed_value = v

var map_width: int:
	get: return model.map_width if model != null else _map_width
	set(v):
		_map_width = v
		if model != null:
			model.map_width = v

var map_height: int:
	get: return model.map_height if model != null else _map_height
	set(v):
		_map_height = v
		if model != null:
			model.map_height = v

func _ready() -> void:
	generate()

func generate() -> void:
	_ensure_layers()

	model = MapModel.new()
	model.map_width = _map_width if _map_width > 0 else 60
	model.map_height = _map_height if _map_height > 0 else 60
	model.seed_value = _seed_value
	model.village_count = GameNumbers.MAP_VILLAGE_COUNT

	renderer = MapRenderer.new(model)
	spawner = MapSpawner.new(model)
	var units_reg: Node = Services.resolve(&"units")
	if units_reg != null:
		spawner.setup_registry(units_reg)

	hex_shift_right = HexGrid.calibrate(_tile_map)

	# Generate enhanced terrain with mountains, rivers, forests
	model.generate_noise()
	model.smooth_invalid_adjacencies()
	
	var mountain_gen = MapMountainGenerator.new(model)
	mountain_gen.generate()
	
	var river_gen = MapRiverGenerator.new(model)
	river_gen.generate()
	
	var forest_gen = MapForestGenerator.new(model)
	forest_gen.generate()
	
	renderer.paint(_tile_map)
	renderer.paint_decor(_decor_layer)

	spawner.place_villages()
	reachable_cells = _compute_reachable_cells()
	spawner.place_resources(reachable_cells)
	spawner.place_decor()
	spawner.place_enemies(reachable_cells)
	
	# Generate roads after villages and resources are placed
	var road_gen = MapRoadGenerator.new(model)
	road_gen.generate()
	
	# Re-render to include roads
	renderer.paint(_tile_map)

func _compute_reachable_cells() -> Dictionary:
	var start_cell := Vector2i(-1, -1)
	for y in model.map_height:
		for x in model.map_width:
			var cell := Vector2i(x, y)
			if model.is_walkable(cell):
				start_cell = cell
				break
		if start_cell.x >= 0:
			break
	if start_cell.x < 0:
		return {}
	return HexPathfinding.bfs_reachable(
		start_cell,
		model.map_width + model.map_height,
		model.get_blocked_cells(),
		model.map_width,
		model.map_height,
		hex_shift_right
	)

func _ensure_layers() -> void:
	var tileset := TileAtlas.build_hex_tileset()

	_tile_map = get_node_or_null("TileMapTerrain")
	if _tile_map == null:
		_tile_map = TileMapLayer.new()
		_tile_map.name = "TileMapTerrain"
		add_child(_tile_map)
	if tileset == null:
		push_error("TileAtlas: failed to build hex tileset (missing %s)" % TileAtlas.SHEET_PATH)
	else:
		_tile_map.tile_set = tileset

	_decor_layer = get_node_or_null("TileMapDecor")
	if _decor_layer == null:
		_decor_layer = TileMapLayer.new()
		_decor_layer.name = "TileMapDecor"
		add_child(_decor_layer)
	if tileset != null:
		_decor_layer.tile_set = tileset

	_resource_layer = get_node_or_null("ResourceLayer")
	if _resource_layer == null:
		_resource_layer = Node2D.new()
		_resource_layer.name = "ResourceLayer"
		add_child(_resource_layer)

func apply_fog(visibility_) -> void:
	if visibility_ == null or renderer == null:
		return
	renderer.apply_fog(_tile_map, visibility_)

func is_walkable(cell: Vector2i) -> bool:
	return model.is_walkable(cell) if model != null else false

func is_walkable_with_effects(cell: Vector2i, has_levitation: bool = false) -> bool:
	return model.is_walkable_with_effects(cell, has_levitation) if model != null else false

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < map_width and cell.y >= 0 and cell.y < map_height

func get_terrain_name(cell: Vector2i) -> String:
	return model.get_terrain_name(cell) if model != null else "grass"

func get_terrain_id(cell: Vector2i) -> int:
	return model.get_terrain_id(cell) if model != null else HexUtils.Terrain.GRASS

func get_blocked_cells() -> Dictionary:
	return model.get_blocked_cells() if model != null else {}

func has_valid_tilemap() -> bool:
	return _tile_map != null and _tile_map.tile_set != null

func get_tile_size() -> Vector2i:
	if has_valid_tilemap():
		return _tile_map.tile_set.tile_size
	return Vector2i(82, 82)

func world_to_map(world_pos: Vector2) -> Vector2i:
	if not has_valid_tilemap():
		return Vector2i(-1, -1)
	return _tile_map.local_to_map(_tile_map.to_local(world_pos))

func local_to_map(world_pos: Vector2) -> Vector2i:
	if not has_valid_tilemap():
		return Vector2i(-1, -1)
	return _tile_map.local_to_map(world_pos)

func map_to_local(cell: Vector2i) -> Vector2:
	if not has_valid_tilemap():
		return Vector2.ZERO
	return _tile_map.map_to_local(cell)

func get_map_world_rect() -> Rect2:
	if not has_valid_tilemap():
		return Rect2(0, 0, 10000, 10000)
	var used := _tile_map.get_used_rect()
	var pos := _tile_map.map_to_local(used.position)
	var end := _tile_map.map_to_local(used.end)
	return Rect2(pos, end - pos)
