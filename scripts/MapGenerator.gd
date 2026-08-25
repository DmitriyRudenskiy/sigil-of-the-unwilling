extends Node2D
class_name MapGenerator
## Координатор карты: модель, рендерер, спавнер, тайлмапы.

const TerrainAtlasMapScript = preload("res://scripts/TerrainAtlasMap.gd")
const _MapModel = preload("res://scripts/map/MapModel.gd")
const _MapRenderer = preload("res://scripts/map/MapRenderer.gd")
const _MapSpawner = preload("res://scripts/map/MapSpawner.gd")

var model
var renderer
var spawner

var _tile_map: TileMapLayer
var _decor_layer: TileMapLayer
var _resource_layer: Node2D

# Публичные свойства — делегирование в модель
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

	model = _MapModel.new()
	model.map_width = _map_width if _map_width > 0 else 60
	model.map_height = _map_height if _map_height > 0 else 60
	model.seed_value = _seed_value
	model.village_count = 8

	renderer = _MapRenderer.new(model)
	spawner = _MapSpawner.new(model)

	HexUtils.calibrate(_tile_map)

	model.generate_noise()
	renderer.paint(_tile_map)
	renderer.diversify(_tile_map)

	spawner.place_villages()
	spawner.place_resources()
	spawner.place_decor()
	spawner.place_enemies()


func _ensure_layers() -> void:
	_tile_map = get_node_or_null("TileMapTerrain")
	if _tile_map == null:
		_tile_map = TileMapLayer.new()
		_tile_map.name = "TileMapTerrain"
		var tileset_path := "res://tilesets/hex_tileset.tres"
		if ResourceLoader.exists(tileset_path):
			_tile_map.tile_set = load(tileset_path)
		else:
			push_error("Tileset not found: %s" % tileset_path)
		add_child(_tile_map)

	_decor_layer = get_node_or_null("TileMapDecor")
	if _decor_layer == null:
		_decor_layer = TileMapLayer.new()
		_decor_layer.name = "TileMapDecor"
		var tileset_path2 := "res://tilesets/hex_tileset.tres"
		if ResourceLoader.exists(tileset_path2):
			_decor_layer.tile_set = load(tileset_path2)
		else:
			push_error("Tileset not found: %s" % tileset_path2)
		add_child(_decor_layer)

	_resource_layer = get_node_or_null("ResourceLayer")
	if _resource_layer == null:
		_resource_layer = Node2D.new()
		_resource_layer.name = "ResourceLayer"
		add_child(_resource_layer)


# Публичный API — делегирование в модель
func is_walkable(cell: Vector2i) -> bool:
	return model.is_walkable(cell) if model != null else false


func get_blocked_cells() -> Dictionary:
	return model.get_blocked_cells() if model != null else {}


# Публичный API — тайлмап
func has_valid_tilemap() -> bool:
	return _tile_map != null and _tile_map.tile_set != null


func local_to_map(world_pos: Vector2) -> Vector2i:
	if not has_valid_tilemap():
		return Vector2i(-1, -1)
	return _tile_map.local_to_map(world_pos)


func map_to_local(cell: Vector2i) -> Vector2:
	if not has_valid_tilemap():
		return Vector2.ZERO
	return _tile_map.map_to_local(cell)
