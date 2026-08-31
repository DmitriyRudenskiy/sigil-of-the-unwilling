class_name MapRenderer
extends RefCounted
## Рисует TileMapLayer из данных MapModel (hex-тайлы мира).

const _MapModel = preload("res://scripts/world/MapModel.gd")

## Соответствие HexUtils.Terrain -> биом тайлсета.
## FOREST -> GRASS (в листе нет отдельного леса), MOUNTAIN -> ROCK.
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


## У биома один базовый вариант — диверсификация не нужна.
func diversify(_tile_map: TileMapLayer) -> void:
	pass


## В листе нет декор-объектов — декор-слой остаётся пустым.
func paint_decor(_decor_layer: TileMapLayer) -> void:
	pass
