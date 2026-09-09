extends GdUnitTestSuite

const W := 10
const H := 10


func _assert_valid_steps(path: Array) -> void:
	for i in range(1, path.size()):
		assert_int(HexUtils.hex_distance(path[i - 1], path[i])).is_equal(1)


func test_bfs_path_found() -> void:
	var path := HexPathfinding.bfs_path(Vector2i.ZERO, Vector2i(3, 2), {}, W, H)
	assert_array(path).is_not_empty()
	assert_vector(path[0]).is_equal(Vector2i.ZERO)
	assert_vector(path.back()).is_equal(Vector2i(3, 2))
	_assert_valid_steps(path)


## Из test_hex_pathfinding (root): старт == финиш → путь из одной клетки.
func test_bfs_path_same_cell_returns_singleton() -> void:
	var path := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(0, 0), {}, W, H)
	assert_array(path).has_size(1)
	assert_vector(path[0]).is_equal(Vector2i(0, 0))


func test_bfs_path_empty_when_goal_blocked() -> void:
	var path := HexPathfinding.bfs_path(Vector2i.ZERO, Vector2i(1, 0), {Vector2i(1, 0): true}, W, H)
	assert_array(path).is_empty()


## Из test_hex_pathfinding (root): стена из соседей делает клетку недостижимой.
func test_bfs_path_wall_makes_goal_unreachable() -> void:
	var wall: Dictionary = {}
	for n in HexUtils.get_all_neighbors(Vector2i(2, 2)):
		wall[n] = true
	var unreachable := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(2, 2), wall, W, H)
	assert_array(unreachable).is_empty()


func test_bfs_path_avoids_blocked_cell() -> void:
	var blocked_cell := Vector2i(1, 1)
	var path := HexPathfinding.bfs_path(Vector2i(0, 1), Vector2i(2, 1), {blocked_cell: true}, W, H)
	assert_array(path).is_not_empty()
	for c in path:
		assert_bool(c != blocked_cell).is_true()


func test_astar_path_valid() -> void:
	var path := HexPathfinding.astar_path(Vector2i.ZERO, Vector2i(4, 3), {}, W, H)
	assert_array(path).is_not_empty()
	assert_vector(path[0]).is_equal(Vector2i.ZERO)
	assert_vector(path.back()).is_equal(Vector2i(4, 3))
	_assert_valid_steps(path)


func test_astar_matches_bfs_length_on_open_map() -> void:
	var bfs := HexPathfinding.bfs_path(Vector2i.ZERO, Vector2i(5, 2), {}, W, H)
	var astar := HexPathfinding.astar_path(Vector2i.ZERO, Vector2i(5, 2), {}, W, H)
	assert_array(astar).is_not_empty()
	assert_int(astar.size()).is_equal(bfs.size())


func test_bfs_reachable_steps() -> void:
	var start := Vector2i(5, 5)
	var reach := HexPathfinding.bfs_reachable(start, 1, {}, W, H)
	assert_dict(reach).not_contains_keys([start])
	assert_dict(reach).has_size(6)
	for d in reach.values():
		assert_int(d).is_equal(1)


## Из test_hex_pathfinding (root): 2 шага = 18 клеток, на краю карты меньше 6.
func test_bfs_reachable_two_steps_and_edge() -> void:
	var reach2 := HexPathfinding.bfs_reachable(Vector2i(5, 5), 2, {}, 20, 20)
	assert_dict(reach2).has_size(18)
	var edge := HexPathfinding.bfs_reachable(Vector2i(0, 0), 1, {}, W, H)
	assert_dict(edge).not_contains_keys([Vector2i(0, 0)])
	assert_int(edge.size()).is_less(6)


func test_dijkstra_accumulates_costs() -> void:
	var cost_fn := func(cell: Vector2i) -> float: return 3.0 if cell.x == 5 else 1.0
	var dist := HexPathfinding.dijkstra(Vector2i.ZERO, 100.0, cost_fn, W, H)
	
	assert_float(dist[HexUtils.pos_to_idx(Vector2i(6, 0), W)]).is_equal_approx(8.0, 0.01)


func test_dijkstra_inf_blocks_cell() -> void:
	var cost_fn := func(cell: Vector2i) -> float: return INF if cell.x == 5 else 1.0
	var dist := HexPathfinding.dijkstra(Vector2i.ZERO, 100.0, cost_fn, W, H)
	assert_float(dist[HexUtils.pos_to_idx(Vector2i(6, 0), W)]).is_equal(INF)


func test_dijkstra_path() -> void:
	var cost_fn := func(_cell: Vector2i) -> float: return 1.0
	var dist := HexPathfinding.dijkstra(Vector2i.ZERO, 100.0, cost_fn, W, H)
	var path := HexPathfinding.dijkstra_path(Vector2i.ZERO, Vector2i(3, 1), dist, cost_fn, W, H)
	assert_array(path).is_not_empty()
	assert_vector(path[0]).is_equal(Vector2i.ZERO)
	assert_vector(path.back()).is_equal(Vector2i(3, 1))
	_assert_valid_steps(path)


func test_find_path_dispatch() -> void:
	var p_bfs := HexPathfinding.find_path(Vector2i.ZERO, Vector2i(2, 2), {}, W, H, "bfs")
	var p_astar := HexPathfinding.find_path(Vector2i.ZERO, Vector2i(2, 2), {}, W, H, "astar")
	assert_array(p_bfs).is_not_empty()
	assert_array(p_astar).is_not_empty()
	_assert_valid_steps(p_bfs)
	_assert_valid_steps(p_astar)
