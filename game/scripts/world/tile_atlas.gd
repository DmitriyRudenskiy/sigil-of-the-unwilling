class_name TileAtlas
extends RefCounted

const SHEET_PATH := "res://assets/tiles/world_tiles.jpeg"
const TILE := 82
const SOURCE_ID := 0
const FOG_SOURCE_ID := 1

enum Biome { GRASS, SAND, SNOW, SWAMP, WATER, ROCK, MUD, LAVA, ROAD }

const BASE_COORDS := {
	Biome.GRASS: [Vector2i(0, 0)],
	Biome.SAND: [Vector2i(1, 0)],
	Biome.SNOW: [Vector2i(2, 0)],
	Biome.SWAMP: [Vector2i(3, 0)],
	Biome.WATER: [Vector2i(4, 0)],
	Biome.ROCK: [Vector2i(0, 1)],
	Biome.MUD: [Vector2i(1, 1)],
	Biome.LAVA: [Vector2i(2, 1)],
	Biome.ROAD: [Vector2i(3, 1)],
}

const TRANSITION_ART := [
	{ "a": Biome.GRASS, "b": Biome.SAND,  "shape": "diag", "at": "SE", "coord": Vector2i(4, 1) },
	{ "a": Biome.GRASS, "b": Biome.SNOW,  "shape": "diag", "at": "SE", "coord": Vector2i(0, 2) },
	{ "a": Biome.GRASS, "b": Biome.SNOW,  "shape": "diag", "at": "NW", "coord": Vector2i(3, 3) },
	{ "a": Biome.GRASS, "b": Biome.WATER, "shape": "diag", "at": "SE", "coord": Vector2i(1, 2) },
	{ "a": Biome.SAND,  "b": Biome.WATER, "shape": "diag", "at": "SE", "coord": Vector2i(2, 2) },
	{ "a": Biome.SAND,  "b": Biome.GRASS, "shape": "diag", "at": "SE", "coord": Vector2i(2, 3) },
	{ "a": Biome.SNOW,  "b": Biome.ROCK,  "shape": "diag", "at": "SE", "coord": Vector2i(3, 2) },
	{ "a": Biome.SNOW,  "b": Biome.ROCK,  "shape": "edge", "at": "W",  "coord": Vector2i(1, 4) },
	{ "a": Biome.SWAMP, "b": Biome.MUD,   "shape": "diag", "at": "SE", "coord": Vector2i(4, 2) },
	{ "a": Biome.LAVA,  "b": Biome.ROCK,  "shape": "diag", "at": "SE", "coord": Vector2i(0, 3) },
	{ "a": Biome.LAVA,  "b": Biome.ROCK,  "shape": "diag", "at": "NW", "coord": Vector2i(3, 4) },
	{ "a": Biome.WATER, "b": Biome.SAND,  "shape": "diag", "at": "SE", "coord": Vector2i(0, 4) },
	{ "a": Biome.WATER, "b": Biome.GRASS, "shape": "edge", "at": "E",  "coord": Vector2i(4, 3) },
	{ "a": Biome.MUD,   "b": Biome.SWAMP, "shape": "edge", "at": "E",  "coord": Vector2i(2, 4) },
]

const _BIOME_ORDER := [Biome.GRASS, Biome.SAND, Biome.SNOW, Biome.SWAMP, Biome.WATER,
	Biome.ROCK, Biome.MUD, Biome.LAVA, Biome.ROAD]

var _tileset: TileSet
var _src: TileSetAtlasSource

var _fog_src: TileSetAtlasSource

func build() -> bool:
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		GameLogger.error("TileAtlas: не удалось загрузить %s" % SHEET_PATH)
		return false
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(TILE, TILE)
	_src = TileSetAtlasSource.new()
	_src.texture = tex
	_src.texture_region_size = Vector2i(TILE, TILE)
	_tileset.add_source(_src, SOURCE_ID)
	_build_fog_source(tex)
	for biome in _BIOME_ORDER:
		var coords: Array = BASE_COORDS[biome]
		for ci in coords.size():
			_src.create_tile(coords[ci])
	for e in TRANSITION_ART:
		var c: Vector2i = e["coord"]
		_src.create_tile(c)
		for k in 3:
			_src.create_alternative_tile(c, k + 1)
			_apply_rotation(_src.get_tile_data(c, k + 1), k + 1)
	return true

func _build_fog_source(tex: Texture2D) -> void:
	var img: Image = tex.get_image().duplicate()
	var h := img.get_height()
	var w := img.get_width()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * 0.45, c.g * 0.45, c.b * 0.45, c.a))
	_fog_src = TileSetAtlasSource.new()
	_fog_src.texture = ImageTexture.create_from_image(img)
	_fog_src.texture_region_size = Vector2i(TILE, TILE)
	_tileset.add_source(_fog_src, FOG_SOURCE_ID)
	for biome in _BIOME_ORDER:
		var coords: Array = BASE_COORDS[biome]
		for ci in coords.size():
			_fog_src.create_tile(coords[ci])

func tileset() -> TileSet:
	return _tileset

func base_coords(biome: int, rng: RandomNumberGenerator) -> Vector2i:
	var options: Array = BASE_COORDS[biome]
	return options[rng.randi() % options.size()]

func build_hex() -> TileSet:
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		return null
	var ts := TileSet.new()
	ts.tile_shape = 3
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, SOURCE_ID)
	for biome in _BIOME_ORDER:
		var coords: Array = BASE_COORDS[biome]
		for ci in coords.size():
			src.create_tile(coords[ci])
	return ts

func get_tileset() -> TileSet:
	return _tileset

static func build_hex_tileset() -> TileSet:

	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
		if cache != null and cache.has_method("build_hex_tileset"):
			return cache.call("build_hex_tileset")

	return TileAtlas.new().build_hex()

static func clear_cache() -> void:

	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree := main_loop as SceneTree
		var cache := tree.root.get_node_or_null("/root/TileAtlasCache")
		if cache != null and cache.has_method("clear_cache"):
			cache.call("clear_cache")

static func pick(base: int, other: int, shape: String, at: String) -> Dictionary:
	for e in TRANSITION_ART:
		if e["a"] != base or e["b"] != other or e["shape"] != shape:
			continue
		return { "atlas": e["coord"], "alt": rotation_count(shape, e["at"], at) }
	return {}

static func rotation_count(shape: String, from: String, to: String) -> int:
	var order: Array = _SIDES if shape == "edge" else _CORNERS
	var f := order.find(from)
	var t := order.find(to)
	if f < 0 or t < 0:
		return 0
	return (t - f + 4) % 4

static func opposite(shape: String, name: String) -> String:
	if shape == "edge":
		return _OPP_SIDE[name]
	return _OPP_CORNER[name]

const _SIDES := ["N", "E", "S", "W"]
const _CORNERS := ["NW", "NE", "SE", "SW"]
const _OPP_SIDE := { "N": "S", "S": "N", "E": "W", "W": "E" }
const _OPP_CORNER := { "NW": "SE", "SE": "NW", "NE": "SW", "SW": "NE" }

func _apply_rotation(td: TileData, k: int) -> void:
	match k:
		1:
			td.transpose = true
			td.flip_h = true
		2:
			td.flip_h = true
			td.flip_v = true
		3:
			td.transpose = true
			td.flip_v = true
