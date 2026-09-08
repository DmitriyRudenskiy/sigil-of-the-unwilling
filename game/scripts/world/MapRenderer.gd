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
	HexUtils.Terrain.MOUNTAIN: TileAtlas.Biome.ROCK,
	HexUtils.Terrain.SNOW:     TileAtlas.Biome.SNOW,
}

var model


func _init(p_model) -> void:
	model = p_model


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
