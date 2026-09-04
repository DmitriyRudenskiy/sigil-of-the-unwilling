extends "res://tests/gut_base.gd"
## Связность карты: столица (и второй город) ДОЛЖНЫ лежать в той же
## компоненте связности, что и спавн героя (без учёта тумана). Иначе —
## soft-lock: игрок никогда не дойдёт до собственного города, сценарии
## 1/4 гибнут.
##
## Точка входа: случайный seed на каждую партию (shard_seed=0), поэтому
## инвариант проверяем по набору фиксированных сидов (1234567 и 424242 —
## реальные «островные» карты, найденные при отладке).

const _MapGen = preload("res://scripts/world/MapGenerator.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")

const SEEDS := [1, 7, 42, 1337, 5555, 20260903, 808080, 1234567, 424242, 999983]

var _mg: Node = null


func after_each() -> void:
	if _mg != null:
		_mg.free()
		_mg = null


func _gen(seed: int) -> void:
	_mg = _MapGen.new()
	_mg.seed_value = seed
	_mg.generate()


## То же правило, что HeroMovementController._place_hero_on_map:
## первая проходимая клетка в row-major порядке (и старт BFS в
## MapGenerator._compute_reachable_cells).
func _hero_spawn(model) -> Vector2i:
	for y in model.map_height:
		for x in model.map_width:
			if model.is_walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Старое правило (до фикса): (10,10) или ближайшая проходимая клетка.
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


## BFS по проходимым клеткам из start (туман не учитывается).
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
		assert_gt(spawn.x, -1, "seed %d: есть хотя бы одна проходимая клетка" % seed)
		var comp := _component(model, spawn)

		var placed := WorldBootstrap._place_in_hero_component(_mg, Vector2i(10, 10))
		assert_true(comp.has(placed),
			"seed %d: столица %s в компоненте героя %s (размер: %d)"
			% [seed, str(placed), str(spawn), comp.size()])

		# (10,10) уже в компоненте → переносить столицу не нужно.
		var plain := _plain_candidate(model, Vector2i(10, 10))
		if comp.has(plain):
			assert_eq(placed, plain, "seed %d: столичная клетка не сдвинута зря" % seed)

		# Второй город — тоже в компоненте (иначе мёртвый город-призрак).
		var second := WorldBootstrap._place_in_hero_component(_mg, Vector2i(placed.x + 15, placed.y))
		assert_true(comp.has(second), "seed %d: второй город %s в компоненте" % [seed, str(second)])


func test_place_excludes_occupied_cells() -> void:
	# Аудит #23: столица/второй город не должны попасть на занятую клетку
	# (вражеский стак / ресурс / сундук).
	_gen(42)
	var preferred := Vector2i(10, 10)
	var plain := WorldBootstrap._place_in_hero_component(_mg, preferred)
	var placed := WorldBootstrap._place_in_hero_component(
		_mg, preferred, {plain: true})
	assert_ne(placed, plain, "не на занятой клетке")
	assert_true(_mg.is_walkable(placed), "клетка проходима")
	# Вырожденный случай: вся компонента занята — не падает, отдаёт кандидата.
	var comp := _component(_mg.model, _hero_spawn(_mg.model))
	var all_excluded: Dictionary = {}
	for cell in comp:
		all_excluded[cell] = true
	all_excluded[plain] = true
	var degenerate := WorldBootstrap._place_in_hero_component(_mg, preferred, all_excluded)
	assert_eq(degenerate, plain, "вырожденный случай: без краша")
