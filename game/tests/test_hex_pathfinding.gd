extends "res://tests/gut_base.gd"
## Headless tests for HexPathfinding (аудит #9: вынесен из test_hex_utils.gd).


func test_bfs_path() -> void:
	print("[test] bfs_path")
	HexUtils.get_config().odd_row_shift_right = true
	
	# start == goal
	var path := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(0, 0), {}, 10, 10)
	check("start==goal returns [start]", path.size() == 1 and path[0] == Vector2i(0, 0))
	
	# Straight path, no obstacles
	var straight := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(3, 0), {}, 10, 10)
	check("straight path length 4", straight.size() == 4, "got %d" % straight.size())
	check("starts at origin", straight[0] == Vector2i(0, 0))
	check("ends at goal", straight[3] == Vector2i(3, 0))
	
	# Blocked path
	var blocked: Dictionary = {Vector2i(1, 0): true}
	var blocked_path := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(2, 0), blocked, 10, 10)
	check("blocked path is non-empty (goes around)", blocked_path.size() > 0, "got %d" % blocked_path.size())
	
	# Unreachable (completely surrounded)
	var wall: Dictionary = {}
	for n in HexUtils.get_all_neighbors(Vector2i(2, 2)):
		wall[n] = true
	var unreachable := HexPathfinding.bfs_path(Vector2i(0, 0), Vector2i(2, 2), wall, 10, 10)
	check("unreachable path is empty", unreachable.is_empty())


func test_bfs_reachable() -> void:
	print("[test] bfs_reachable")
	HexUtils.get_config().odd_row_shift_right = true
	
	# 1 step from center in open field
	var reach := HexPathfinding.bfs_reachable(Vector2i(5, 5), 1, {}, 10, 10)
	check("1 step = 6 neighbors", reach.size() == 6, "got %d" % reach.size())
	
	# 2 steps
	var reach2 := HexPathfinding.bfs_reachable(Vector2i(5, 5), 2, {}, 20, 20)
	check("2 steps = 18 neighbors", reach2.size() == 18, "got %d" % reach2.size())
	
	# Start cell not included
	check("start cell excluded", not reach.has(Vector2i(5, 5)))
	
	# At boundary
	var edge := HexPathfinding.bfs_reachable(Vector2i(0, 0), 1, {}, 10, 10)
	check("at boundary < 6 neighbors", edge.size() < 6, "got %d" % edge.size())
