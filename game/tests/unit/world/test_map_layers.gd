extends BaseTest
## Состав, порядок и отладочное отключение слоёв карты (world-map-layer-stack,
## задача 5.4). Спека «Слои не влияют на логику»: слой только читает модель мира,
## поэтому выключенный рендер не имеет права менять проходимость, путь и стоимость.

const _HexPathfinding = preload("res://scripts/core/hex_pathfinding.gd")
const _TerrainCostTable = preload("res://scripts/data/terrain_cost_table.gd")

## Порядок отрисовки: база → стыки → растительность. Задаётся одним местом —
## порядком создания в MapGenerator._ensure_layers(). Мёртвый `ResourceLayer`
## снят в 5.1 (носители живут в `ResourceNodes` у ResourceNodeManager, не здесь).
const EXPECTED := ["TileMapTerrain", "TileMapTransitions", "TileMapDecor"]


func _gen(seed_value: int) -> MapGenerator:
	var gen: MapGenerator = make_node(MapGenerator)
	gen._seed_value = seed_value
	gen._map_width = 40
	gen._map_height = 40
	gen.generate()
	return gen


func _child_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	for child in node.get_children():
		names.append(String(child.name))
	return names


## Порядок слоёв не зависит от порядка генераторов: у генераторов террейна нет
## доступа к дереву, а список детей диктует _ensure_layers().
func test_layer_order_is_fixed() -> void:
	var gen := _gen(4242)
	var found: Array[String] = []
	for cname in _child_names(gen):
		if cname in EXPECTED:
			found.append(cname)
	assert_that(found).is_equal(EXPECTED)
	var sides: Array[String] = []
	for side in TileAtlas.SIDES:
		sides.append("TileMapTransition_" + side)
	assert_that(_child_names(gen.get_node("TileMapTransitions"))).is_equal(sides)


## Все слои отключены — проходимость, путь и его стоимость совпадают с включённым
## рендером. Отключается и слой 2 целиком: шесть подслоёв висят на одном узле.
func test_disabled_layers_do_not_change_paths() -> void:
	var gen := _gen(4242)
	var model: MapModel = gen.model
	var w: int = model.map_width
	var h: int = model.map_height
	var start := Vector2i.ZERO
	var goal := Vector2i.ZERO
	for cell in model.terrain_grid:
		if not model.is_walkable(cell):
			continue
		if cell.x < 5 and start == Vector2i.ZERO:
			start = cell
		elif cell.x > w - 6:
			goal = cell
	assert_that(goal).is_not_equal(Vector2i.ZERO)

	var before: Array = _paths_and_cost(model, start, goal, w, h)
	assert_that(before[1]).is_not_equal("0")  # пустой путь сделал бы проверку пустой
	for layer in gen.render_layers:
		gen.set_layer_enabled(String(layer), false)
	assert_that(gen.get_node("TileMapTerrain").visible).is_false()
	assert_that(gen.get_node("TileMapTransitions").visible).is_false()
	assert_that(_paths_and_cost(model, start, goal, w, h)).is_equal(before)


## Вертикальная сортировка объектного слоя (5.2, D-205): носители добычи живут
## в y-сортируемом контейнере (`ResourceNodes`, `world_bootstrap._create_resource_nodes`),
## поэтому южный объект перекрывает северный при пересечении по вертикали. Носитель
## стоит основанием в центре клетки, так что y узла = нижний край; проверка на паре
## «север/юг»: южный носитель имеет бо́льшую глобальную y и рисуется поверх.
func test_object_layer_y_sorts_south_over_north() -> void:
	var container := Node2D.new()
	container.y_sort_enabled = true  # как в world_bootstrap._create_resource_nodes
	add_child(container)
	var mgr := ResourceNodeManager.new()
	add_child(mgr)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# map_to_local: клетка → позиция, y растёт на юг (как у гекс-тайлмапа).
	var map_to_local := func(cell: Vector2i) -> Vector2:
		return Vector2(cell.x * 73.0, cell.y * 82.0)
	mgr.setup(container, rng, Resources, map_to_local)
	var north := Vector2i(3, 2)
	var south := Vector2i(3, 3)
	var n_node: ResourceNode = mgr._spawn_node(north, &"oak", 3)
	var s_node: ResourceNode = mgr._spawn_node(south, &"oak", 3)
	n_node.discover()
	s_node.discover()
	assert_that(container.y_sort_enabled).is_true()
	# Оба носителя в контейнере, южный ниже по y → рисуется поверх северного.
	assert_that(n_node.get_parent()).is_equal(container)
	assert_that(s_node.get_parent()).is_equal(container)
	assert_that(s_node.global_position.y).is_greater(n_node.global_position.y)
	# Якорь — низ-центр: основание носителя в центре клетки, спрайт смещён вверх.
	assert_that(s_node.sprite.position.y).is_less(0.0)


## Путь, его стоимость и проходимость клеток — то, что слой мог бы испортить,
## если бы писал в модель вместо того чтобы читать.
func _paths_and_cost(model: MapModel, start: Vector2i, goal: Vector2i,
		w: int, h: int) -> Array:
	var cost := func(cell: Vector2i) -> float:
		return _TerrainCostTable.get_cost_with_effects_by_id(
			int(model.terrain_grid.get(cell, -1)), false)
	var path: Array = _HexPathfinding.astar(start, goal, model.get_blocked_cells(), cost, w, h)
	var total := 0.0
	var cells: Array[String] = []
	for cell in path:
		total += cost.call(cell)
		cells.append("%s=%s" % [str(cell), str(model.is_walkable(cell))])
	return ["%f" % total, str(path.size()), str(cells)]
