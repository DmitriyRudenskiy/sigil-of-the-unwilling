class_name MapRenderer
extends RefCounted

const _MapModel = preload("res://scripts/world/MapModel.gd")
const _VisibilityMap = preload("res://scripts/core/VisibilityMap.gd")

signal fog_refreshed()

const TERRAIN_TO_BIOME := {
	HexUtils.Terrain.WATER:    TileAtlas.Biome.WATER,
	HexUtils.Terrain.SWAMP:    TileAtlas.Biome.SWAMP,
	HexUtils.Terrain.SAND:     TileAtlas.Biome.SAND,
	HexUtils.Terrain.GRASS:    TileAtlas.Biome.GRASS,
	HexUtils.Terrain.FOREST:   TileAtlas.Biome.GRASS,
	HexUtils.Terrain.DENSE_FOREST: TileAtlas.Biome.GRASS,
	HexUtils.Terrain.MOUNTAIN: TileAtlas.Biome.ROCK,
	HexUtils.Terrain.SNOW:     TileAtlas.Biome.SNOW,
	HexUtils.Terrain.RIVER:    TileAtlas.Biome.WATER,
	HexUtils.Terrain.ROAD:     TileAtlas.Biome.ROAD,
}

var model

## city-hex-layout 4.1: кэш "тайл → город" (ядро/кольцо N); пересчёт при cities_changed.
## cell -> {city, ring} (0 = ядро)
var city_zones: Dictionary = {}

func _init(p_model) -> void:
	model = p_model

func rebuild_city_zones(cities: Array) -> void:
	city_zones.clear()
	for city in cities:
		if city == null:
			continue
		for cc in city.core_cells:
			city_zones[cc] = {"city": city, "ring": 0}
		for r in range(1, GameNumbers.CITY_RING_MAX + 1):
			for cell in HexUtils.ring(city.center, r):
				if not city_zones.has(cell):
					city_zones[cell] = {"city": city, "ring": r}

## city-hex-layout 4.2: окраска ядра и колец 1–3 (палитра TileAtlas, без новых текстур).
## Ядро — MUD, кольцо 1 — ROAD, кольца 2–3 — SAND.
func paint_city_zones(tile_map: TileMapLayer) -> void:
	if tile_map == null:
		return
	for cell in city_zones:
		var zone: Dictionary = city_zones[cell]
		var r: int = int(zone.ring)
		var biome: int = TileAtlas.Biome.MUD if r == 0 else (TileAtlas.Biome.ROAD if r == 1 else TileAtlas.Biome.SAND)
		var coords: Array = TileAtlas.BASE_COORDS[biome]
		tile_map.set_cell(cell, TileAtlas.SOURCE_ID, coords[0])

func paint(tile_map: TileMapLayer) -> void:
	tile_map.clear()
	for cell in model.terrain_grid:
		var terrain_id: int = model.terrain_grid[cell]
		if not TERRAIN_TO_BIOME.has(terrain_id):
			continue
		var biome: int = TERRAIN_TO_BIOME[terrain_id]
		var coords: Array = TileAtlas.BASE_COORDS[biome]
		tile_map.set_cell(cell, TileAtlas.SOURCE_ID, coords[0])

func apply_fog(tile_map: TileMapLayer, visibility: _VisibilityMap) -> void:
	if visibility == null or tile_map == null:
		return
	for cell in model.terrain_grid:
		if not visibility.is_explored(cell):
			tile_map.erase_cell(cell)
			continue
		var terrain_id: int = model.terrain_grid[cell]
		if not TERRAIN_TO_BIOME.has(terrain_id):
			continue
		var biome: int = TERRAIN_TO_BIOME[terrain_id]
		var coords: Array = TileAtlas.BASE_COORDS[biome]
		if not visibility.is_visible(cell):
			tile_map.set_cell(cell, TileAtlas.FOG_SOURCE_ID, coords[0])
		else:
			tile_map.set_cell(cell, TileAtlas.SOURCE_ID, coords[0])
	fog_refreshed.emit()

func paint_decor(_decor_layer: TileMapLayer) -> void:
	pass

func clear_city_zones(tile_map: TileMapLayer) -> void:
	if tile_map == null:
		return
	for cell in city_zones:
		tile_map.erase_cell(cell)
