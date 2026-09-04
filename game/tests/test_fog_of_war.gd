extends "res://tests/gut_base.gd"
## fog-of-war: VisibilityMap (видимое/разведённое, монотонность, сериализация),
## блокировка неразведённых клеток в pathfinding и действиях, сохранение fog.

const _Vis = preload("res://scripts/core/VisibilityMap.gd")
const _MapGen = preload("res://scripts/world/MapGenerator.gd")
const _MapModel = preload("res://scripts/world/MapModel.gd")
const _Delta = preload("res://scripts/world/WorldStateDelta.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")


# ==================== VisibilityMap ====================

func test_visible_disk_around_hero() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	var changed := v.recompute(Vector2i(5, 5), [], 3, 4)
	assert_true(changed, "first recompute reports change")
	assert_true(v.is_visible(Vector2i(5, 5)), "hero cell visible")
	assert_true(v.is_visible(Vector2i(6, 5)), "adjacent visible (sight=3)")
	# клетка на расстоянии 4 за пределами диска обзора героя — не visible
	assert_false(v.is_visible(Vector2i(9, 5)), "cell at dist 4 not visible")
	assert_false(v.is_explored(Vector2i(9, 5)), "cell at dist 4 not explored")
	assert_true(v.is_explored(Vector2i(6, 5)), "adjacent explored")


func test_sight_sources_are_cities() -> void:
	var v := _Vis.new()
	v.set_map_size(21, 21)
	# город в (15,15) с sight=4; герой в (5,5) далеко.
	var changed := v.recompute(Vector2i(5, 5), [Vector2i(15, 15)], 3, 4)
	assert_true(changed, "city adds new visible cells")
	assert_true(v.is_visible(Vector2i(15, 15)), "city center visible from city sight")
	# герой — тоже источник: его клетка видна.
	assert_true(v.is_visible(Vector2i(5, 5)), "hero cell visible (hero is a sight source)")
	# (10,10) — 5 от героя (sight 3) и 5 от города (sight 4) → не видно.
	assert_false(v.is_visible(Vector2i(10, 10)), "cell far from both not visible")
	assert_true(v.is_explored(Vector2i(15, 15)), "city explored")


func test_explored_is_monotonic() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	var explored_before := v.serialize_explored().size()
	# перемещаем героя в угол — старые клетки разведёнными остаются.
	var changed := v.recompute(Vector2i(0, 0), [], 3, 4)
	assert_true(changed, "recompute after move reports change")
	var explored_after := v.serialize_explored().size()
	assert_gt(explored_after, explored_before, "explored grows, never shrinks")
#	old explored cells still explored
	assert_true(v.is_explored(Vector2i(5, 5)), "previously explored cell stays explored")


func test_serialize_and_load_roundtrip() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	var arr := v.serialize_explored()
	assert_not_empty(arr, "serialized explored is non-empty")
	assert_true(arr[0] is Dictionary and arr[0].has("x") and arr[0].has("y"),
		"serialized cells are {x,y} dicts")

	var v2 := _Vis.new()
	v2.set_map_size(11, 11)
	v2.load_explored(arr)
	assert_eq(v2.serialize_explored().size(), arr.size(), "load restores explored count")
#	roundtrip: same set of cells
	for item in arr:
		assert_true(v2.is_explored(Vector2i(int(item["x"]), int(item["y"]))),
			"loaded explored contains original cell")


func test_is_visible_requires_explored() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
#	ни одного источника — ничего не видно и не разведено.
	v.recompute(Vector2i(5, 5), [], 3, 4)
	assert_false(v.is_visible(Vector2i(0, 0)), "far empty cell not visible")
	assert_false(v.is_explored(Vector2i(0, 0)), "far empty cell not explored")


# ==================== HeroMovementController gating ====================

class _MapGenStub:
	extends MapGenerator
	# terrain_grid/map_width — getter-ы на model, поэтому модель настоящая.
	func get_terrain_id(cell: Vector2i) -> int:
		return model.terrain_grid.get(cell, HexUtils.Terrain.GRASS)
	func is_walkable_with_effects(cell: Vector2i, _lev: bool = false) -> bool:
		return true
	func get_blocked_cells() -> Dictionary:
		return {}


func _make_map_gen_stub(size: int) -> MapGenerator:
	var g := _MapGenStub.new()
	var mm := MapModel.new()
	mm.map_width = size
	mm.map_height = size
	for x in size:
		for y in size:
			mm.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	g.model = mm
	g.map_width = size
	g.map_height = size
	return g


func _make_movement(map_stub: MapGenerator) -> HeroMovementController:
	var m = preload("res://scripts/entities/HeroMovementController.gd").new()
	m._map_gen = map_stub
	return m


func test_terrain_cost_blocked_unexplored() -> void:
	# Dijkstra-reach: неразведённые клетки имеют бесконечную стоимость
	# (иначе предпросмотр reach рисовал бы точки в тумане).
	var g := _make_map_gen_stub(11)
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	g.visibility = v
	var m := _make_movement(g)
	assert_true(m._terrain_cost(Vector2i(6, 5)) < INF, "explored adjacent has finite cost")
	assert_true(m._terrain_cost(Vector2i(0, 0)) == INF, "unexplored corner has INF cost")
	g.free()
	m.free()


func test_base_blocked_contains_unexplored() -> void:
	# A*: неразведённые клетки в base-blocked (единый гейт пути).
	var g := _make_map_gen_stub(11)
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	g.visibility = v
	var m := _make_movement(g)
	var blocked := m._base_blocked()
	assert_true(blocked.has(Vector2i(0, 0)), "unexplored corner blocked")
	assert_false(blocked.has(Vector2i(6, 5)), "explored adjacent not blocked")
	g.free()
	m.free()


class _SpawnerStub:
	extends WorldSpawner
	var _resources: Dictionary = {}
	func remove_resource_at(cell: Vector2i) -> bool:
		if _resources.has(cell):
			_resources.erase(cell)
			return true
		return false
	func get_chest_at(cell: Vector2i) -> ArtifactChest:
		return null
	func capture_village(cell: Vector2i) -> bool:
		return false


class _HeroStub:
	extends HeroController


func test_explored_reachable_marker() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	# разведённая соседняя клетка доступна для клика-маркера.
	assert_true(v.is_explored(Vector2i(6, 5)), "adjacent explored")
	assert_false(v.is_explored(Vector2i(10, 10)), "far corner unexplored")


# ==================== WorldSpawner entity gating ====================

func test_spawner_hides_nodes_on_hidden_cells() -> void:
	# Ноды сущностей прячутся на невидимых клетках (иначе «висели» бы
	# над стёртыми тайлами тумана).
	var spawner := preload("res://scripts/world/WorldSpawner.gd").new()
	var visible_node := Node2D.new()
	var hidden_node := Node2D.new()
	spawner._enemy_nodes[Vector2i(6, 5)] = visible_node
	spawner._enemy_nodes[Vector2i(0, 0)] = hidden_node

	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	spawner.apply_fog_visibility(v)
	assert_true(visible_node.visible, "node on visible cell stays visible")
	assert_false(hidden_node.visible, "node on hidden cell is hidden")

	# враг переместился в видимую клетку → визуал снова виден.
	spawner._enemy_nodes.erase(Vector2i(0, 0))
	spawner._enemy_nodes[Vector2i(6, 5)] = hidden_node
	spawner.apply_fog_visibility(v)
	assert_true(hidden_node.visible, "node moved to visible cell shown again")
	spawner.free()
	visible_node.free()
	hidden_node.free()


# ==================== WorldInteractionController gating ====================

func test_interaction_blocked_on_unexplored() -> void:
	var vic := preload("res://scripts/world/WorldInteractionController.gd").new()
	var spawner := _SpawnerStub.new()
	spawner._resources[Vector2i(0, 0)] = true
	var hero := _HeroStub.new()
	vic.setup(hero, spawner, null)

	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
#	(0,0) на расстоянии 8 от (5,5) → неразведённое.
	assert_false(v.is_explored(Vector2i(0, 0)), "resource cell unexplored")
	vic.visibility = v

	# Godot 4.7: lambda копирует value-типы — статус ловим в массив-холдер.
	var status_msgs: Array = []
	vic.status_cb = func(m) -> void:
		status_msgs.append(m)
	var collected := vic.collect_resource_at(Vector2i(0, 0))
	assert_false(collected, "collection blocked on unexplored cell")
	assert_false(spawner._resources.is_empty(), "resource NOT removed")
	assert_eq(status_msgs.size(), 1, "status callback fired once")
	assert_eq(status_msgs[0], "Клетка не разведена", "status text: %s" % status_msgs[0])
	vic.free()
	spawner.free()
	hero.free()


func test_interaction_allowed_on_visible() -> void:
	var vic := preload("res://scripts/world/WorldInteractionController.gd").new()
	var spawner := _SpawnerStub.new()
	spawner._resources[Vector2i(6, 5)] = true
	var hero := _HeroStub.new()
	vic.setup(hero, spawner, null)

	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
#	(6,5) соседняя → видимая и разведённая.
	assert_true(v.is_visible(Vector2i(6, 5)), "resource cell visible")
	vic.visibility = v

	var collected := vic.collect_resource_at(Vector2i(6, 5))
	assert_true(collected, "collection allowed on visible cell")
	assert_true(spawner._resources.is_empty(), "resource removed")
	vic.free()
	spawner.free()
	hero.free()


# ==================== WorldStateDelta fog persistence ====================

func test_delta_fog_persistence() -> void:
	var d := _Delta.new()
	d.set_fog_explored([{"x": 1, "y": 2}, {"x": 3, "y": 4}])
	var data := d.serialize()
	assert_true("fog_explored" in data, "serialize includes fog_explored")
	assert_eq(data["fog_explored"].size(), 2, "fog_explored serialized count")

	var d2 := _Delta.new()
	d2.deserialize(data)
	assert_eq(d2.fog_explored.size(), 2, "deserialize restores fog_explored")
