class_name MapRenderer
extends RefCounted
## Рисует TileMapLayer из данных MapModel (hex-тайлы мира) + fog-of-war.

const _MapModel = preload("res://scripts/world/MapModel.gd")
const _VisibilityMap = preload("res://scripts/core/VisibilityMap.gd")

signal fog_refreshed()

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


## Fog-of-war: непроходимые по факту клетки рисуются всегда; «видимые» —
## полностью, «разведённые но невидимые» — затемнены, «не разведённые» —
## стираются (карта пустая, без деталей). Перерисует разведённую сетку.
## ponytail: перерисовка всей разведённой сетки на ходу — O(разведённое),
## а не «перерисовка только изменённых клеток»; клеточно-точечный апгрейд,
## если перериса на каждый клик станет заметна.
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
			# Разведено, но не видно — затемнённый вариант того же тайла
			# (пер-клеточный modulate у TileMapLayer отсутствует).
			tile_map.set_cell(cell, TileAtlas.FOG_SOURCE_ID, coords[0])
		else:
			tile_map.set_cell(cell, TileAtlas.SOURCE_ID, coords[0])
	fog_refreshed.emit()

## У биома один базовый вариант — диверсификация не нужна.
func diversify(_tile_map: TileMapLayer) -> void:
	pass


## В листе нет декор-объектов — декор-слой остаётся пустым.
func paint_decor(_decor_layer: TileMapLayer) -> void:
	pass
