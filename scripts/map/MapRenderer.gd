class_name MapRenderer
extends RefCounted
## Покраска TileMapLayer из данных MapModel.

const TerrainAtlasMapScript = preload("res://scripts/TerrainAtlasMap.gd")
const _MapModel = preload("res://scripts/map/MapModel.gd")

var model


func _init(p_model) -> void:
	model = p_model


func paint(tile_map: TileMapLayer) -> void:
	tile_map.clear()
	for cell in model.terrain_grid:
		var terrain_id: int = model.terrain_grid[cell]
		if not TerrainAtlasMapScript.CENTER_COORDS.has(terrain_id):
			continue
		var atlas_coords: Vector2i = TerrainAtlasMapScript.CENTER_COORDS[terrain_id]
		tile_map.set_cell(cell, TerrainAtlasMapScript.SOURCE_ID, atlas_coords)


func diversify(tile_map: TileMapLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 1234
	for cell in model.terrain_grid:
		var t: int = model.terrain_grid[cell]
		if not TerrainAtlasMapScript.VARIANTS.has(t):
			continue
		var vars: Array = TerrainAtlasMapScript.VARIANTS[t]
		if vars.is_empty():
			continue
		if tile_map.get_cell_atlas_coords(cell) == TerrainAtlasMapScript.CENTER_COORDS[t]:
			var pick: Vector2i = vars[rng.randi_range(0, vars.size() - 1)]
			tile_map.set_cell(cell, TerrainAtlasMapScript.SOURCE_ID, pick)
