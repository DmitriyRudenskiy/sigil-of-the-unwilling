extends GdUnitTestSuite


func test_bfs_path() -> void:
	print("[test] bfs_path")
	HexUtils.get_config().odd_row_shift_right = true
	
	var path := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(0, 0), {}, 10, 10)
	assert_bool(path.size() == 1 and path[0] == Vector2i(0, 0)).is_true()
	
	var straight := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(3, 0), {}, 10, 10)
	assert_bool(straight.size() == 4).is_true()
	assert_bool(straight[0] == Vector2i(0, 0)).is_true()
	assert_bool(straight[3] == Vector2i(3, 0)).is_true()
	
	var blocked: Dictionary = {Vector2i(1, 0): true}
	var blocked_path := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(2, 0), blocked, 10, 10)
	assert_bool(blocked_path.size() > 0).is_true()
	
	var wall: Dictionary = {}
	for n in HexUtils.get_all_neighbors(Vector2i(2, 2)):
		wall[n] = true
	var unreachable := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(2, 2), wall, 10, 10)
	assert_bool(unreachable.is_empty()).is_true()


func test_bfs_reachable() -> void:
	print("[test] bfs_reachable")
	HexUtils.get_config().odd_row_shift_right = true
	
	var reach := HexPathfinding.bfs_reachable(Vector2i(5, 5), 1, {}, 10, 10)
	assert_bool(reach.size() == 6).is_true()
	
	var reach2 := HexPathfinding.bfs_reachable(Vector2i(5, 5), 2, {}, 20, 20)
	assert_bool(reach2.size() == 18).is_true()
	
	assert_bool(not reach.has(Vector2i(5, 5))).is_true()
	
	var edge := HexPathfinding.bfs_reachable(Vector2i(0, 0), 1, {}, 10, 10)
	assert_bool(edge.size() < 6).is_true()
