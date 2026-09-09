extends GdUnitTestSuite

const _Vis = preload("res://scripts/core/VisibilityMap.gd")
const _MapGen = preload("res://scripts/world/MapGenerator.gd")
const _MapModel = preload("res://scripts/world/MapModel.gd")
const _Delta = preload("res://scripts/world/WorldStateDelta.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")

func test_visible_disk_around_hero() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	var changed := v.recompute(Vector2i(5, 5), [], 3, 4)
	assert_bool(changed).is_true()
	assert_bool(v.is_visible(Vector2i(5, 5))).is_true()
	assert_bool(v.is_visible(Vector2i(6, 5))).is_true()
	assert_bool(v.is_visible(Vector2i(9, 5))).is_false()
	assert_bool(v.is_explored(Vector2i(9, 5))).is_false()
	assert_bool(v.is_explored(Vector2i(6, 5))).is_true()

func test_sight_sources_are_cities() -> void:
	var v := _Vis.new()
	v.set_map_size(21, 21)
	var changed := v.recompute(Vector2i(5, 5), [Vector2i(15, 15)], 3, 4)
	assert_bool(changed).is_true()
	assert_bool(v.is_visible(Vector2i(15, 15))).is_true()
	assert_bool(v.is_visible(Vector2i(5, 5))).is_true()
	assert_bool(v.is_visible(Vector2i(10, 10))).is_false()
	assert_bool(v.is_explored(Vector2i(15, 15))).is_true()

func test_explored_is_monotonic() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	var explored_before := v.serialize_explored().size()
	var changed := v.recompute(Vector2i(0, 0), [], 3, 4)
	assert_bool(changed).is_true()
	var explored_after := v.serialize_explored().size()
	assert_int(explored_after).is_greater(explored_before)
	assert_bool(v.is_explored(Vector2i(5, 5))).is_true()

func test_serialize_and_load_roundtrip() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	var arr := v.serialize_explored()
	assert_array(arr).is_not_empty()
	assert_bool(arr[0] is Dictionary and arr[0].has("x") and arr[0].has("y")).is_true()

	var v2 := _Vis.new()
	v2.set_map_size(11, 11)
	v2.load_explored(arr)
	assert_that(v2.serialize_explored().size()).is_equal(arr.size())
	for item in arr:
		assert_bool(v2.is_explored(Vector2i(int(item["x"]), int(item["y"])))).is_true()

func test_is_visible_requires_explored() -> void:
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	assert_bool(v.is_visible(Vector2i(0, 0))).is_false()
	assert_bool(v.is_explored(Vector2i(0, 0))).is_false()

class _MapGenStub:
	extends MapGenerator
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
	var g := _make_map_gen_stub(11)
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	g.visibility = v
	var m := _make_movement(g)
	assert_bool(m._terrain_cost(Vector2i(6, 5)) < INF).is_true()
	assert_bool(m._terrain_cost(Vector2i(0, 0)) == INF).is_true()
	g.free()
	m.free()

func test_base_blocked_contains_unexplored() -> void:
	var g := _make_map_gen_stub(11)
	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	g.visibility = v
	var m := _make_movement(g)
	var blocked := m._base_blocked()
	assert_bool(blocked.has(Vector2i(0, 0))).is_true()
	assert_bool(blocked.has(Vector2i(6, 5))).is_false()
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
	assert_bool(v.is_explored(Vector2i(6, 5))).is_true()
	assert_bool(v.is_explored(Vector2i(10, 10))).is_false()

func test_spawner_hides_nodes_on_hidden_cells() -> void:
	var spawner := preload("res://scripts/world/WorldSpawner.gd").new()
	var visible_node := Node2D.new()
	var hidden_node := Node2D.new()
	spawner._enemy_nodes[Vector2i(6, 5)] = visible_node
	spawner._enemy_nodes[Vector2i(0, 0)] = hidden_node

	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	spawner.apply_fog_visibility(v)
	assert_bool(visible_node.visible).is_true()
	assert_bool(hidden_node.visible).is_false()

	spawner._enemy_nodes.erase(Vector2i(0, 0))
	spawner._enemy_nodes[Vector2i(6, 5)] = hidden_node
	spawner.apply_fog_visibility(v)
	assert_bool(hidden_node.visible).is_true()
	spawner.free()
	visible_node.free()
	hidden_node.free()

func test_interaction_blocked_on_unexplored() -> void:
	var vic := preload("res://scripts/world/WorldInteractionController.gd").new()
	var spawner := _SpawnerStub.new()
	spawner._resources[Vector2i(0, 0)] = true
	var hero := _HeroStub.new()
	vic.setup(hero, spawner, null)

	var v := _Vis.new()
	v.set_map_size(11, 11)
	v.recompute(Vector2i(5, 5), [], 3, 4)
	assert_bool(v.is_explored(Vector2i(0, 0))).is_false()
	vic.visibility = v

	var status_msgs: Array = []
	vic.status_cb = func(m) -> void:
		status_msgs.append(m)
	var collected := vic.collect_resource_at(Vector2i(0, 0))
	assert_bool(collected).is_false()
	assert_bool(spawner._resources.is_empty()).is_false()
	assert_that(status_msgs.size()).is_equal(1)
	assert_that(status_msgs[0]).is_equal("Клетка не разведена")
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
	assert_bool(v.is_visible(Vector2i(6, 5))).is_true()
	vic.visibility = v

	var collected := vic.collect_resource_at(Vector2i(6, 5))
	assert_bool(collected).is_true()
	assert_bool(spawner._resources.is_empty()).is_true()
	vic.free()
	spawner.free()
	hero.free()

func test_delta_fog_persistence() -> void:
	var d := _Delta.new()
	d.set_fog_explored([{"x": 1, "y": 2}, {"x": 3, "y": 4}])
	var data := d.serialize()
	assert_bool("fog_explored" in data).is_true()
	assert_that(data["fog_explored"].size()).is_equal(2)

	var d2 := _Delta.new()
	d2.deserialize(data)
	assert_that(d2.fog_explored.size()).is_equal(2)
