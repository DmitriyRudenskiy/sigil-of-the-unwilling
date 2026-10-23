extends Node2D
class_name MapGenerator

const _VisibilityMap = preload("res://scripts/core/visibility_map.gd")

var model
var renderer
var spawner
var visibility: _VisibilityMap = null
var reachable_cells: Dictionary = {}

var _tile_map: TileMapLayer
var _decor_layer: TileMapLayer
var _shadow_layer: TileMapLayer

## Подслои перехода (слой 2 «стыки и переходы») — по одному на сторону гекса,
## порядок задаёт TileAtlas.SIDES; MapRenderer.paint_transitions().
var transition_layers: Array = []

## Слой 3 «дороги» (world-map-art-variety 6.2): основная декаль (полоса/
## перекрёсток/мост) и шесть подслоёв кромки — по одному на сторону гекса,
## как у переходов: в одной клетке дороги сходятся разными сторонами, а
## TileMapLayer хранит один тайл в клетке. Красит MapRenderer.paint_roads().
var road_layer: TileMapLayer
var road_edge_layers: Array = []

## Порядок отрисовки (specs/world-map-layer-stack): база → стыки → дороги →
## тени → растительность. Задаёт **этот список**, а не порядок объявления в
## сцене и не порядок создания в `_ensure_layers()`: `map_generator.tscn`
## объявлял `TileMapDecor` вторым, и в игре растительность рисовалась под
## стыками и тенями, хотя тест порядка строил скрипт, а не сцену, и молчал.
## Горного рельефа в списке нет: своей графики у слоя ещё нет (5.1 — пустой
## TileMapLayer под будущую картинку ничего не включает и не выключает).
const LAYER_ORDER := [
	"TileMapTerrain", "TileMapTransitions", "TileMapRoads", "TileMapShadow", "TileMapDecor",
]

## Отладочное отключение слоёв (world-map-layer-stack 5.1): имя слоя → его узел.
## Порядок отрисовки задаёт `LAYER_ORDER` (он же применяется к дереву), этому
## словарю он не равен. Слои, у которых своей графики ещё нет (горный рельеф,
## носители вражеских стеков), заводятся вместе с графикой (7.x, 8.x) — пустой
## TileMapLayer под будущую картинку ничего не включает и не выключает. Носители
## ресурсов и вражеских стеков живут не здесь: `ResourceNodes` у ResourceNodeManager
## и маркеры у ui_manager.marker_layer.
var render_layers: Dictionary = {}


var terrain_grid: Dictionary:
	get: return model.terrain_grid if model != null else {}

var height_grid: Dictionary:
	get: return model.height_grid if model != null else {}

var village_cells: Array[Vector2i]:
	get: return model.village_cells if model != null else []

var resource_cells: Dictionary:
	get: return model.resource_cells if model != null else {}

var decor_cells: Dictionary:
	get: return model.decor_cells if model != null else {}

var enemy_stacks: Dictionary:
	get: return model.enemy_stacks if model != null else {}

var _seed_value: int = 0
var _map_width: int = 0
var _map_height: int = 0
var hex_shift_right: bool = true
## world-map-art-variety 9.3: версия генератора карты мира (SaveData).
## Ставится ДО add_child (генерация идёт в _ready): старый сейв (1) —
## раскладка старым правилом, новая партия (2) — таблица биомов.
var generator_version: int = SaveData.CURRENT_GENERATOR_VERSION

var seed_value: int:
	get:
		return _seed_value
	set(v):
		_seed_value = v
		if model != null:
			model.seed_value = v

var map_width: int:
	get: return model.map_width if model != null else _map_width
	set(v):
		_map_width = v
		if model != null:
			model.map_width = v

var map_height: int:
	get: return model.map_height if model != null else _map_height
	set(v):
		_map_height = v
		if model != null:
			model.map_height = v

func _ready() -> void:
	generate()

func generate() -> void:
	_ensure_layers()

	model = MapModel.new()
	model.map_width = _map_width if _map_width > 0 else 60
	model.map_height = _map_height if _map_height > 0 else 60
	model.seed_value = _seed_value
	model.village_count = GameNumbers.MAP_VILLAGE_COUNT

	renderer = MapRenderer.new(model)
	renderer.transition_layers = transition_layers
	renderer.road_layer = road_layer
	renderer.road_edge_layers = road_edge_layers
	spawner = MapSpawner.new(model)
	var units_reg: Node = Services.resolve(&"units")
	if units_reg != null:
		spawner.setup_registry(units_reg)

	hex_shift_right = HexGrid.calibrate(_tile_map)

	# Generate enhanced terrain with mountains, rivers, forests
	model.generate_noise()
	model.smooth_invalid_adjacencies()

	var mountain_gen = MapMountainGenerator.new(model)
	mountain_gen.generate()

	var river_gen = MapRiverGenerator.new(model)
	river_gen.generate()

	var forest_gen = MapForestGenerator.new(model)
	forest_gen.generate()

	renderer.paint(_tile_map)

	spawner.place_villages()
	reachable_cells = _compute_reachable_cells()
	spawner.place_resources(reachable_cells, -1, generator_version)
	spawner.place_decor()
	# Растительность рисуется ПОСЛЕ расстановки: до неё decor_cells пуст, и
	# прежний порядок (paint до place) рисовал пустой слой, где данных ещё нет.
	renderer.paint_decor(_decor_layer, _shadow_layer)
	spawner.place_enemies(reachable_cells)

	# Generate roads after villages and resources are placed
	var road_gen = MapRoadGenerator.new(model)
	road_gen.generate()

	# Re-render to include roads
	renderer.paint(_tile_map)
	# Слой дорог — после генератора дорог: до него road_grid пуст, и слой молчал
	# бы там, где дорога уже есть (тот же порядок, что с растительностью).
	renderer.paint_roads()

func _compute_reachable_cells() -> Dictionary:
	var start_cell: Vector2i = model.find_spawn_cell(hex_shift_right)
	if start_cell.x < 0:
		return {}
	return HexPathfinding.bfs_reachable(
		start_cell,
		model.map_width + model.map_height,
		model.get_blocked_cells(),
		model.map_width,
		model.map_height,
		hex_shift_right
	)

func _ensure_layers() -> void:
	var tileset := TileAtlas.build_hex_tileset()

	_tile_map = get_node_or_null("TileMapTerrain")
	if _tile_map == null:
		_tile_map = TileMapLayer.new()
		_tile_map.name = "TileMapTerrain"
		add_child(_tile_map)
	if tileset == null:
		push_error("TileAtlas: failed to build hex tileset (missing %s)" % TileAtlas.SHEET_PATH)
	else:
		_tile_map.tile_set = tileset

	transition_layers.clear()
	var root: Node2D = get_node_or_null("TileMapTransitions")
	if root == null:
		# Один узел на все шесть подслоёв: отключается слой 2 целиком (5.1),
		# а порядок внутри него задаётся порядком обхода SIDES.
		root = Node2D.new()
		root.name = "TileMapTransitions"
		add_child(root)
	for side: String in TileAtlas.SIDES:
		var tname := "TileMapTransition_" + side
		var tlayer: TileMapLayer = root.get_node_or_null(tname)
		if tlayer == null:
			tlayer = TileMapLayer.new()
			tlayer.name = tname
			root.add_child(tlayer)
		if tileset != null:
			tlayer.tile_set = tileset
		transition_layers.append(tlayer)

	# Слой 3 «дороги» (6.2) — между стыками и тенями/растительностью: декаль
	# покрытия лежит поверх базы, но не перекрывает носители объектов. Свой тайлсет:
	# дороги живут на отдельном листе, геометрия та же (гекс, tile_size 82),
	# поэтому клетки не разъезжаются с базой.
	road_edge_layers.clear()
	var roads_root: Node2D = get_node_or_null("TileMapRoads")
	if roads_root == null:
		roads_root = Node2D.new()
		roads_root.name = "TileMapRoads"
		add_child(roads_root)
	road_layer = roads_root.get_node_or_null("TileMapRoad")
	if road_layer == null:
		road_layer = TileMapLayer.new()
		road_layer.name = "TileMapRoad"
		roads_root.add_child(road_layer)
	for side: String in TileAtlas.SIDES:
		var rname := "TileMapRoadEdge_" + side
		var rlayer: TileMapLayer = roads_root.get_node_or_null(rname)
		if rlayer == null:
			rlayer = TileMapLayer.new()
			rlayer.name = rname
			roads_root.add_child(rlayer)
		road_edge_layers.append(rlayer)
	if road_layer.tile_set == null:
		var road_tileset := MapRoads.build_tileset()
		if road_tileset == null:
			push_error("MapRoads: failed to build road tileset (missing %s)" % MapRoads.SHEET_PATH)
		else:
			for rlayer in [road_layer] + road_edge_layers:
				(rlayer as TileMapLayer).tile_set = road_tileset

	_shadow_layer = get_node_or_null("TileMapShadow")
	if _shadow_layer == null:
		_shadow_layer = TileMapLayer.new()
		_shadow_layer.name = "TileMapShadow"
		add_child(_shadow_layer)

	_decor_layer = get_node_or_null("TileMapDecor")
	if _decor_layer == null:
		_decor_layer = TileMapLayer.new()
		_decor_layer.name = "TileMapDecor"
		add_child(_decor_layer)
	if _decor_layer.tile_set == null:
		# Свой тайлсет: растительность живёт на листе объектов, а не в атласе
		# биомов. Геометрия та же (гекс, tile_size 82), поэтому клетки слоя
		# не разъезжаются с базой.
		_decor_layer.tile_set = MapObjects.build_tileset()
	# Тени — под растительностью и в том же тайлсете (источник `SHADOW_SOURCE_ID`),
	# отдельный тайлсет значил бы вторую текстуру ради одного тайла.
	_shadow_layer.tile_set = _decor_layer.tile_set
	# Растительность не участвует во вводе (вердикт владельца по Q-M94, D-213): юнит
	# к северу от кроны перекрывается деревом, и единственное, чего это не имеет
	# права делать, — лишать клика. Держится на двух фактах: у тайлсета слоя нет
	# физических слоёв (а `input_pickable` в Godot 4.7 есть только у
	# CollisionObject2D/Control, так что ставить нечего), и клик мира идёт через
	# `WorldInput._unhandled_input`, куда `TileMapLayer` не вмешивается. Первый
	# факт — под проверкой `test_vegetation_never_blocks_clicks`.
	# Мёртвый `ResourceLayer` (создавался, никто в него не писал — носители живут
	# в `ResourceNodes` у ResourceNodeManager) снят в 5.1.

	render_layers = {
		"terrain": _tile_map,
		"transitions": root,
		"roads": roads_root,
		"vegetation": _decor_layer,
	}
	_apply_layer_order()


## Ставит детей в порядок `LAYER_ORDER`. Нужен именно он, а не «кто раньше
## создан»: `world.tscn` приносит готовые узлы из `map_generator.tscn`, и их
## объявленный в сцене порядок перебивал намерение кода.
func _apply_layer_order() -> void:
	for i in LAYER_ORDER.size():
		var node: Node = get_node_or_null(LAYER_ORDER[i])
		if node != null:
			move_child(node, i)


## Снять/вернуть слой по имени. Только отрисовка: модель, проходимость и
## стоимость движения слоя не знают (спека «Слои не влияют на логику»).
func set_layer_enabled(layer: String, enabled: bool) -> void:
	var node: Node = render_layers.get(layer)
	if node == null:
		push_error("MapGenerator: нет отлаживаемого слоя %s" % layer)
		return
	node.visible = enabled

func apply_fog(visibility_) -> void:
	if visibility_ == null or renderer == null:
		return
	renderer.apply_fog(_tile_map, visibility_)
	# Дороги — тоже слой (правило «туман войны по всем слоям»), иначе над стёртой
	# базой висит яркая полоса (дефект T-150 в чистом виде).
	renderer.paint_roads(visibility_)
	# Объектные слои туман находит сам (T-150): перекраска идёт от модели, поэтому
	# отступивший туман возвращает растительность, а не стирает её навсегда.
	renderer.paint_decor(_decor_layer, _shadow_layer, visibility_)

func is_walkable(cell: Vector2i) -> bool:
	return model.is_walkable(cell) if model != null else false

func is_walkable_with_effects(cell: Vector2i, has_levitation: bool = false) -> bool:
	return model.is_walkable_with_effects(cell, has_levitation) if model != null else false

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < map_width and cell.y >= 0 and cell.y < map_height

func get_terrain_name(cell: Vector2i) -> String:
	return model.get_terrain_name(cell) if model != null else "grass"

func get_terrain_id(cell: Vector2i) -> int:
	return model.get_terrain_id(cell) if model != null else HexUtils.Terrain.GRASS

func get_blocked_cells() -> Dictionary:
	return model.get_blocked_cells() if model != null else {}

func has_valid_tilemap() -> bool:
	return _tile_map != null and _tile_map.tile_set != null

func get_tile_size() -> Vector2i:
	if has_valid_tilemap():
		return _tile_map.tile_set.tile_size
	return Vector2i(82, 82)

func world_to_map(world_pos: Vector2) -> Vector2i:
	if not has_valid_tilemap():
		return Vector2i(-1, -1)
	return _tile_map.local_to_map(_tile_map.to_local(world_pos))

func local_to_map(world_pos: Vector2) -> Vector2i:
	if not has_valid_tilemap():
		return Vector2i(-1, -1)
	return _tile_map.local_to_map(world_pos)

func map_to_local(cell: Vector2i) -> Vector2:
	if not has_valid_tilemap():
		return Vector2.ZERO
	return _tile_map.map_to_local(cell)

func get_map_world_rect() -> Rect2:
	if not has_valid_tilemap():
		return Rect2(0, 0, 10000, 10000)
	var used := _tile_map.get_used_rect()
	var pos := _tile_map.map_to_local(used.position)
	var end := _tile_map.map_to_local(used.end)
	return Rect2(pos, end - pos)
