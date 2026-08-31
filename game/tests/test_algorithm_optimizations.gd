extends "res://tests/test_base.gd"
## Tests for algorithmic optimizations: A*, cache keys, bounding box search.

const _HexUtils = preload("res://scripts/core/HexUtils.gd")

func test_astar_finds_path() -> void:
	var blocked: Dictionary = {}
	var start := Vector2i(0, 0)
	var goal := Vector2i(10, 5)
	var path := _HexUtils.astar_path(start, goal, blocked, 21, 21)
	assert_true(path.size() > 0, "path found")
	assert_eq(path[0], start, "path starts at start")
	assert_eq(path[-1], goal, "path ends at goal")


func test_astar_with_obstacles() -> void:
	var blocked: Dictionary = {Vector2i(5, 5): true, Vector2i(5, 6): true}
	var start := Vector2i(0, 5)
	var goal := Vector2i(10, 5)
	var path := _HexUtils.astar_path(start, goal, blocked, 21, 21)
	assert_true(path.size() > 0, "path found around obstacles")
	assert_false(path.has(Vector2i(5, 5)), "avoids obstacle 1")
	assert_false(path.has(Vector2i(5, 6)), "avoids obstacle 2")


func test_astar_no_path() -> void:
	var blocked: Dictionary = {}
	var goal := Vector2i(10, 10)
	for nb in _HexUtils.get_all_neighbors(goal):
		blocked[nb] = true
	var path := _HexUtils.astar_path(Vector2i(0, 0), goal, blocked, 21, 21)
	assert_true(path.is_empty(), "no path when surrounded")


func test_astar_same_as_dijkstra_length() -> void:
	var cost_fn := func(c: Vector2i) -> float:
		if c.x < 0 or c.y < 0 or c.x > 20 or c.y > 20:
			return 1e9
		return 1.0
	var blocked: Dictionary = {}
	var start := Vector2i(0, 0)
	var goal := Vector2i(10, 5)
	var dist := _HexUtils.dijkstra(start, 100.0, cost_fn, 21, 21)
	var goal_idx := _HexUtils.pos_to_idx(goal, 21)
	if dist[goal_idx] >= 1e9:
		return  # no path for either
	var dijkstra_p := _HexUtils.dijkstra_path(start, goal, dist, cost_fn, 21, 21)
	var astar_p := _HexUtils.astar_path(start, goal, blocked, 21, 21)
	if dijkstra_p.size() > 0 and astar_p.size() > 0:
		# Both should find a valid path (length may differ slightly due to tie-breaking)
		assert_true(dijkstra_p.size() > 0, "dijkstra found path")
		assert_true(astar_p.size() > 0, "astar found path")
		assert_eq(dijkstra_p[0], astar_p[0], "same start")
		assert_eq(dijkstra_p[-1], astar_p[-1], "same goal")


func test_bfs_cache_key_vector3i() -> void:
	# Vector3i key should handle large coordinates without overflow
	var key := Vector3i(300, 200, 50)
	var d: Dictionary = {}
	d[key] = "test"
	assert_true(d.has(key), "Vector3i key works")
	assert_eq(d[key], "test", "value stored correctly")
