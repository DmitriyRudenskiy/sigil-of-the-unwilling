class_name MapRenderer
extends RefCounted
## Рисует TileMapLayer из данных MapModel (тайлы HoMM3).

const _MapModel = preload("res://world/MapModel.gd")

## Соответствие HexUtils.Terrain -> HoMM3-биом.
## FOREST -> GRASS (в HoMM3 нет отдельного леса), MOUNTAIN -> ROCK.
const TERRAIN_TO_BIOME := {
	HexUtils.Terrain.WATER:    HommAtlas.Biome.WATER,
	HexUtils.Terrain.SWAMP:    HommAtlas.Biome.SWAMP,
	HexUtils.Terrain.SAND:     HommAtlas.Biome.SAND,
	HexUtils.Terrain.GRASS:    HommAtlas.Biome.GRASS,
	HexUtils.Terrain.FOREST:   HommAtlas.Biome.GRASS,
	HexUtils.Terrain.MOUNTAIN: HommAtlas.Biome.ROCK,
	HexUtils.Terrain.SNOW:     HommAtlas.Biome.SNOW,
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
		var coords: Array = HommAtlas.BASE_COORDS[biome]
		tile_map.set_cell(cell, HommAtlas.SOURCE_ID, coords[0])


## В HoMM3 у биома один базовый вариант — диверсификация не нужна.
func diversify(_tile_map: TileMapLayer) -> void:
	pass


## В листе HoMM3 нет декор-объектов — декор-слой остаётся пустым.
func paint_decor(_decor_layer: TileMapLayer) -> void:
	pass
