extends GdUnitTestSuite

const _MapGen = preload("res://scripts/world/MapGenerator.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")

const SEEDS := [1, 7, 42, 1337, 5555, 20260903, 808080, 1234567, 424242, 999983]

var _mg: Node = null


func after_test() -> void:
	if _mg != null:
		_mg.free()
		_mg = null


func _gen(seed: int) -> void:
	if _mg != null:
		_mg.free()
	_mg = _MapGen.new()
	_mg.seed_value = seed
	_mg.generate()


func _hero_spawn(model) -> Vector2i:
	for y in model.map_height:
		for x in model.map_width:
			if model.is_walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _plain_candidate(model, start: Vector2i) -> Vector2i:
	if model.is_walkable(start):
		return start
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while queue.size() > 0:
		var cell = queue.pop_front()
		for nb in _HexUtils.get_all_neighbors(cell):
			if nb.x < 0 or nb.y < 0 or nb.x >= model.map_width or nb.y >= model.map_height:
				continue
			if visited.has(nb):
				continue
			visited[nb] = true
			if model.is_walkable(nb):
				return nb
			queue.append(nb)
	return start


func _component(model, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start: 1}
	while queue.size() > 0:
		var cell = queue.pop_front()
		for nb in _HexUtils.get_all_neighbors(cell):
			if seen.has(nb) or not model.is_walkable(nb):
				continue
			seen[nb] = 1
			queue.append(nb)
	return seen


func test_capital_placement_stays_in_hero_component() -> void:
	for seed in SEEDS:
		_gen(seed)
		var model = _mg.model
		var spawn := _hero_spawn(model)
		assert_int(spawn.x).is_greater(-1)
		var comp := _component(model, spawn)

		var placed := WorldBootstrap._place_in_hero_component(_mg, Vector2i(10, 10))
		assert_bool(comp.has(placed)).is_true()

		var plain := _plain_candidate(model, Vector2i(10, 10))
		if comp.has(plain):
			assert_that(placed).is_equal(plain)

		var second := WorldBootstrap._place_in_hero_component(_mg, Vector2i(placed.x + 15, placed.y))
		assert_bool(comp.has(second)).is_true()


func test_place_excludes_occupied_cells() -> void:
	_gen(42)
	var preferred := Vector2i(10, 10)
	var plain := WorldBootstrap._place_in_hero_component(_mg, preferred)
	var placed := WorldBootstrap._place_in_hero_component(
		_mg, preferred, {plain: true})
	assert_that(placed).is_not_equal(plain)
	assert_bool(_mg.is_walkable(placed)).is_true()
	var comp := _component(_mg.model, _hero_spawn(_mg.model))
	var all_excluded: Dictionary = {}
	for cell in comp:
		all_excluded[cell] = true
	all_excluded[plain] = true
	var degenerate := WorldBootstrap._place_in_hero_component(_mg, preferred, all_excluded)
	assert_that(degenerate).is_equal(plain)
