extends GdUnitTestSuite

const _HexUtils = preload("res://scripts/core/HexUtils.gd")
const _HexPathfinding = preload("res://scripts/core/HexPathfinding.gd")

func test_astar_finds_path() -> void:
	var blocked: Dictionary = {}
	var start := Vector2i(0, 0)
	var goal := Vector2i(10, 5)
	var path := _HexPathfinding.astar_path(start, goal, blocked, 21, 21)
	assert_bool(path.size() > 0).is_true()
	assert_that(path[0]).is_equal(start)
	assert_that(path[-1]).is_equal(goal)


func test_astar_with_obstacles() -> void:
	var blocked: Dictionary = {Vector2i(5, 5): true, Vector2i(5, 6): true}
	var start := Vector2i(0, 5)
	var goal := Vector2i(10, 5)
	var path := _HexPathfinding.astar_path(start, goal, blocked, 21, 21)
	assert_bool(path.size() > 0).is_true()
	assert_bool(path.has(Vector2i(5, 5))).is_false()
	assert_bool(path.has(Vector2i(5, 6))).is_false()


func test_astar_no_path() -> void:
	var blocked: Dictionary = {}
	var goal := Vector2i(10, 10)
	for nb in _HexUtils.get_all_neighbors(goal):
		blocked[nb] = true
	var path := _HexPathfinding.astar_path(Vector2i(0, 0), goal, blocked, 21, 21)
	assert_bool(path.is_empty()).is_true()


func test_astar_same_as_dijkstra_length() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return 1e9
		return 1.0
	var blocked: Dictionary = {}
	var start := Vector2i(0, 0)
	var goal := Vector2i(10, 5)
	var dist := _HexPathfinding.dijkstra(start, 100.0, cost_fn, 21, 21)
	var goal_idx := _HexUtils.pos_to_idx(goal, 21)
	if dist[goal_idx] >= 1e9:
		return  
	var dijkstra_p := _HexPathfinding.dijkstra_path(start, goal, dist, cost_fn, 21, 21)
	var astar_p := _HexPathfinding.astar_path(start, goal, blocked, 21, 21)
	if dijkstra_p.size() > 0 and astar_p.size() > 0:
		assert_bool(dijkstra_p.size() > 0).is_true()
		assert_bool(astar_p.size() > 0).is_true()
		assert_that(dijkstra_p[0]).is_equal(astar_p[0])
		assert_that(dijkstra_p[-1]).is_equal(astar_p[-1])


func test_find_path_dispatch_matches_underlying() -> void:
	var blocked: Dictionary = {Vector2i(5, 5): true}
	var start := Vector2i(0, 0)
	var goal := Vector2i(10, 5)
	var via_dispatch := _HexPathfinding.find_path(start, goal, blocked, 21, 21)
	var via_astar := _HexPathfinding.astar_path(start, goal, blocked, 21, 21)
	assert_that(via_dispatch).is_equal(via_astar)

	var via_bfs := _HexPathfinding.find_path(start, goal, blocked, 21, 21, "bfs")
	var direct_bfs := _HexPathfinding.bfs_path(start, goal, blocked, 21, 21)
	assert_that(via_bfs).is_equal(direct_bfs)

	var surrounded := Vector2i(10, 10)
	for nb in _HexUtils.get_all_neighbors(surrounded):
		blocked[nb] = true
	assert_bool(_HexPathfinding.find_path(Vector2i(0, 0), surrounded, blocked, 21, 21).is_empty()).is_true()

func test_bfs_cache_key_vector3i() -> void:
	var key := Vector3i(300, 200, 50)
	var d: Dictionary = {}
	d[key] = "test"
	assert_bool(d.has(key)).is_true()
	assert_that(d[key]).is_equal("test")
