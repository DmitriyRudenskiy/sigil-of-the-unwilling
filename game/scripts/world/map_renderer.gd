class_name MapRenderer
extends RefCounted

const _MapModel = preload("res://scripts/world/map_model.gd")
const _VisibilityMap = preload("res://scripts/core/visibility_map.gd")

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

## Слой 2 «стыки и переходы» (world-map-layer-stack): по подслою на сторону гекса.
## В одной клетке может сходиться до пяти чужих биомов, а TileMapLayer хранит один
## тайл в клетке, поэтому направлений в одном подслое не помещается. Задаёт
## MapGenerator; пусто — переходы не рисуются (юнит-тесты базы рисуют только слой 1).
var transition_layers: Array = []

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
		# D6: кольца вокруг ядра (ромб 2×2), не вокруг одной center
		for r in range(1, GameNumbers.CITY_RING_MAX + 1):
			for cell in HexUtils.cells_in_core_ring(city.center, r):
				if not city_zones.has(cell):
					city_zones[cell] = {"city": city, "ring": r}

## city-hex-layout 4.2: окраска ядра и колец 1–3 (палитра TileAtlas, без новых
## текстур); палитра — _zone_biome.
func paint_city_zones(tile_map: TileMapLayer) -> void:
	if tile_map == null:
		return
	for cell in city_zones:
		var zone: Dictionary = city_zones[cell]
		tile_map.set_cell(cell, TileAtlas.SOURCE_ID, _base(cell, _zone_biome(int(zone.ring))))
	paint_transitions()


## Палитра города (city-hex-layout 4.2): ядро — MUD, кольцо 1 — ROAD, кольца 2–3 — SAND.
func _zone_biome(r: int) -> int:
	if r == 0:
		return TileAtlas.Biome.MUD
	return TileAtlas.Biome.ROAD if r == 1 else TileAtlas.Biome.SAND


## Биом клетки так, как он нарисован: ил/дорога города перекрывают рельеф, и
## переходы обязаны считать соседство по картинке, а не по terrain_grid.
## -1 — клетки на карте нет (или рельеф не рисуется).
func _biome_at(cell: Vector2i) -> int:
	if city_zones.has(cell):
		return _zone_biome(int(city_zones[cell].ring))
	return TERRAIN_TO_BIOME.get(model.terrain_grid.get(cell, -1), -1)


## Переходы биомов (задача 4.4): декаль соседа кладётся на клетку со стороны
## соседа, поэтому граница не «рубится», а наедает в чужую клетку градиентом.
## Красит только «старший» биом пары (порядок — enum TileAtlas.Biome): если бы
## красили обе клетки границы, цвета просто поменялись бы местами и твёрдый стык
## остался бы на месте. Детерминировано по клетке, как и варианты базы.
func paint_transitions(visibility = null) -> void:
	for layer in transition_layers:
		if layer is TileMapLayer:
			layer.clear()
	if transition_layers.is_empty():
		return
	for cell in model.terrain_grid:
		var biome: int = _biome_at(cell)
		if biome < 0:
			continue
		if visibility != null and not visibility.is_explored(cell):
			continue
		var source: int = TileAtlas.SOURCE_ID
		if visibility != null and not visibility.is_visible(cell):
			source = TileAtlas.FOG_SOURCE_ID
		for bit in TileAtlas.SIDES.size():
			var neighbor: Vector2i = HexUtils.get_neighbor(cell, bit)
			# Декаль выдал бы биом за краем тумана: сосед, которого игрок ещё
			# не видел, не имеет права подкрашивать соседнюю клетку.
			if visibility != null and not visibility.is_explored(neighbor):
				continue
			var other: int = _biome_at(neighbor)
			# Молчит, когда сосед тот же, когда его нет (-1) и когда очередь
			# красить — у него (он видит нас «старшим» и красит в свою клетку).
			if other <= biome:
				continue
			var side: String = TileAtlas.SIDES[bit]
			var coords: Vector2i = TileAtlas.edge_coords(other, side)
			if coords.x < 0:
				push_error("TileAtlas: нет перехода %s→%s на стороне %s" % [
					TileAtlas.BIOME_NAMES[biome], TileAtlas.BIOME_NAMES[other], side])
				continue
			(transition_layers[bit] as TileMapLayer).set_cell(cell, source, coords)

## База биома для клетки: вариант выбирается по клетке и сиду карты (задача 4.3),
## поэтому картина не зависит от порядка обхода словаря и переживает save/load.
func _base(cell: Vector2i, biome: int) -> Vector2i:
	var variants: Array = TileAtlas.base_coords(biome)
	if variants.is_empty():
		push_error("TileAtlas: у биома %s нет базовых тайлов" % TileAtlas.BIOME_NAMES[biome])
		return Vector2i.ZERO
	return variants[TileAtlas.variant_for(cell, int(_seed()), variants.size())]


func _seed() -> int:
	return int(model.seed_value) if model != null and "seed_value" in model else 0


func paint(tile_map: TileMapLayer) -> void:
	tile_map.clear()
	for cell in model.terrain_grid:
		var terrain_id: int = model.terrain_grid[cell]
		if not TERRAIN_TO_BIOME.has(terrain_id):
			continue
		var biome: int = TERRAIN_TO_BIOME[terrain_id]
		tile_map.set_cell(cell, TileAtlas.SOURCE_ID, _base(cell, biome))
	paint_transitions()

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
		var coords: Vector2i = _base(cell, biome)
		if not visibility.is_visible(cell):
			tile_map.set_cell(cell, TileAtlas.FOG_SOURCE_ID, coords)
		else:
			tile_map.set_cell(cell, TileAtlas.SOURCE_ID, coords)
	paint_transitions(visibility)
	fog_refreshed.emit()

## Слой 5 «растительность» (7.2): объект из листа объектов в свою клетку.
## Источника у слоя свой (лист объектов), а не атлас биомов, поэтому и тайлсет
## на слое обязан быть свой — `MapObjects.build_tileset()`.
## Тень (7.1) — отдельным слоем под объектом: та же клетка, другой источник того
## же тайлсета. Запечённая в спрайт тень не гасится туманом и не перекрашивается
## вместе с объектом, поэтому она элемент, а не пиксели силуэта.
## `visibility` (дефект T-150, кадр `fog-decor-t145.png`): без фильтра объект переживал
## туман — база под деревом стиралась, а дерево оставалось висеть на сером поле.
## Правило спеки «Туман войны по всем слоям»: не открыта — пусто, открыта и не видима —
## затемнено **той же кратности**, что база (`GameNumbers.MAP_FOG_DIM`), а не спрятано.
func paint_decor(
	decor_layer: TileMapLayer,
	shadow_layer: TileMapLayer = null,
	visibility: VisibilityMap = null
) -> void:
	if decor_layer == null:
		return
	decor_layer.clear()
	if shadow_layer != null:
		shadow_layer.clear()
	for cell in model.decor_cells:
		var object_id := String(model.decor_cells[cell])
		var coords := MapObjects.coords_for(object_id)
		if coords.x < 0:
			push_error("MapRenderer: объект %s не в манифесте листа объектов" % object_id)
			continue
		var in_fog := false
		if visibility != null:
			if not visibility.is_explored(cell):
				continue
			in_fog = not visibility.is_visible(cell)
		decor_layer.set_cell(cell,
				MapObjects.FOG_SOURCE_ID if in_fog else MapObjects.SOURCE_ID, coords)
		if shadow_layer != null:
			shadow_layer.set_cell(cell,
				MapObjects.SHADOW_FOG_SOURCE_ID if in_fog else MapObjects.SHADOW_SOURCE_ID,
				MapObjects.SHADOW_TILE)

func clear_city_zones(tile_map: TileMapLayer) -> void:
	if tile_map == null:
		return
	for cell in city_zones:
		tile_map.erase_cell(cell)
