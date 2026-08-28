class_name MapRenderer
extends RefCounted
## Покраска TileMapLayer из данных MapModel.

const TerrainAtlasMapScript = preload("res://game/world/TerrainAtlasMap.gd")
const _MapModel = preload("res://game/world/MapModel.gd")

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


## Рисует объекты на декор-слой с вероятностью
func paint_decor(decor_layer: TileMapLayer) -> void:
	if decor_layer == null:
		return
	decor_layer.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = model.seed_value + 9999

	for cell in model.terrain_grid:
		var t: int = model.terrain_grid[cell]
		if not TerrainAtlasMapScript.DECOR_COORDS.has(t):
			continue
		var decor_list: Array = TerrainAtlasMapScript.DECOR_COORDS[t]
		if decor_list.is_empty():
			continue

		# Собираем суммарную вероятность
		var total_prob := 0.0
		for entry in decor_list:
			total_prob += float(entry.get("probability", 0.1))

		# Бросаем кубик: ставим ли объект вообще
		if rng.randf() > total_prob:
			continue

		# Выбираем какой именно объект
		var roll := rng.randf() * total_prob
		var accum := 0.0
		for entry in decor_list:
			accum += float(entry.get("probability", 0.1))
			if roll <= accum:
				var coords: Vector2i = entry["coords"]
				decor_layer.set_cell(cell, TerrainAtlasMapScript.OBJECT_SOURCE_ID, coords)
				break
