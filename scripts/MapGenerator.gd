extends Node2D
class_name MapGenerator

@export var map_width: int = 60
@export var map_height: int = 60
@export var seed_value: int = 12345
@export var village_count: int = 8
@export var water_threshold: float = 0.35
@export var sand_threshold: float = 0.40
@export var grass_threshold: float = 0.65
@export var forest_threshold: float = 0.75
@export var mountain_threshold: float = 0.85

var terrain_grid: Dictionary = {}
var height_grid: Dictionary = {}
var village_cells: Array[Vector2i] = []
var resource_cells: Dictionary = {}
var decor_cells: Dictionary = {}
var _tile_map: TileMapLayer
var _decor_layer: TileMapLayer
var _resource_layer: Node2D

func _ready() -> void:
    generate()

func generate() -> void:
    _ensure_layers()
    _generate_noise()
    _paint_tilemap()
    _place_villages()
    _place_resources()
    _place_decor()

func _ensure_layers() -> void:
    _tile_map = get_node_or_null("TileMapTerrain")
    if _tile_map == null:
        _tile_map = TileMapLayer.new()
        _tile_map.name = "TileMapTerrain"
        add_child(_tile_map)
    _decor_layer = get_node_or_null("TileMapDecor")
    if _decor_layer == null:
        _decor_layer = TileMapLayer.new()
        _decor_layer.name = "TileMapDecor"
        add_child(_decor_layer)
    _resource_layer = get_node_or_null("ResourceLayer")
    if _resource_layer == null:
        _resource_layer = Node2D.new()
        _resource_layer.name = "ResourceLayer"
        add_child(_resource_layer)

func _generate_noise() -> void:
    var hn := FastNoiseLite.new(); hn.seed = seed_value; hn.frequency = 0.03; hn.fractal_octaves = 5
    var tn := FastNoiseLite.new(); tn.seed = seed_value+100; tn.frequency = 0.02; tn.fractal_octaves = 3
    var mn := FastNoiseLite.new(); mn.seed = seed_value+200; mn.frequency = 0.025; mn.fractal_octaves = 3
    terrain_grid.clear(); height_grid.clear()
    for y in map_height:
        for x in map_width:
            var cell := Vector2i(x, y)
            var h := (hn.get_noise_2d(x,y)+1.0)/2.0
            var t := (tn.get_noise_2d(x,y)+1.0)/2.0
            var m := (mn.get_noise_2d(x,y)+1.0)/2.0
            height_grid[cell] = h
            terrain_grid[cell] = get_biome_terrain_id(h, t, m)

func get_biome_terrain_id(height: float, temp: float, moist: float) -> int:
    if height < water_threshold: return HexUtils.Terrain.WATER
    elif height < sand_threshold: return HexUtils.Terrain.SAND
    elif height > mountain_threshold:
        return HexUtils.Terrain.SNOW if temp < 0.3 else HexUtils.Terrain.MOUNTAIN
    elif height > forest_threshold:
        if moist > 0.4: return HexUtils.Terrain.FOREST
        return HexUtils.Terrain.SNOW if temp < 0.3 else HexUtils.Terrain.MOUNTAIN
    else:
        if moist < 0.25: return HexUtils.Terrain.SAND
        return HexUtils.Terrain.SNOW if temp < 0.2 else HexUtils.Terrain.GRASS

func _paint_tilemap() -> void:
    _tile_map.clear()
    for cell in terrain_grid:
        _tile_map.set_cell(cell, TerrainAtlasMap.SOURCE_ID, TerrainAtlasMap.CENTER_COORDS[terrain_grid[cell]])
    _tile_map.update_terrain()

func _place_villages() -> void:
    village_cells.clear()
    var rng := RandomNumberGenerator.new(); rng.seed = seed_value + 500
    var attempts := 0
    while village_cells.size() < village_count and attempts < 1000:
        attempts += 1
        var cell := Vector2i(rng.randi_range(2, map_width-3), rng.randi_range(2, map_height-3))
        if is_valid_village_location(cell): village_cells.append(cell)

func is_valid_village_location(cell: Vector2i) -> bool:
    if not terrain_grid.has(cell): return false
    if terrain_grid[cell] in [HexUtils.Terrain.WATER, HexUtils.Terrain.MOUNTAIN]: return false
    for v in village_cells:
        if HexUtils.hex_distance(cell, v) <= 2: return false
    return true

func _place_resources() -> void:
    resource_cells.clear()
    var rng := RandomNumberGenerator.new(); rng.seed = seed_value + 700
    var target := int(float(map_width * map_height) / 70.0)
    var attempts := 0
    while resource_cells.size() < target and attempts < 5000:
        attempts += 1
        var cell := Vector2i(rng.randi_range(0, map_width-1), rng.randi_range(0, map_height-1))
        if not terrain_grid.has(cell): continue
        if terrain_grid[cell] in [HexUtils.Terrain.WATER, HexUtils.Terrain.MOUNTAIN]: continue
        if resource_cells.has(cell) or cell in village_cells: continue
        resource_cells[cell] = rng.randi_range(0, 6)

func _place_decor() -> void:
    decor_cells.clear()
    var rng := RandomNumberGenerator.new(); rng.seed = seed_value + 900
    for cell in terrain_grid:
        if terrain_grid[cell] == HexUtils.Terrain.SAND and rng.randf() < 0.04:
            decor_cells[cell] = "palm" if rng.randf() > 0.5 else "cactus"

func is_walkable(cell: Vector2i) -> bool:
    if not terrain_grid.has(cell): return false
    return terrain_grid[cell] not in [HexUtils.Terrain.WATER, HexUtils.Terrain.MOUNTAIN]

func get_blocked_cells() -> Dictionary:
    var b: Dictionary = {}
    for cell in terrain_grid:
        if not is_walkable(cell): b[cell] = true
    return b
