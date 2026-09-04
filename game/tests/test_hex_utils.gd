extends "res://tests/gut_base.gd"
## Headless tests for HexUtils.
## Run: godot --headless -s tests/test_hex_utils.gd

const HexUtilsScript = preload("res://scripts/core/HexUtils.gd")


func test_neighbors() -> void:
	print("[test] neighbors")
	HexUtils.get_config().odd_row_shift_right = true
	
	# Even row
	var even := Vector2i(0, 0)
	var even_n := HexUtils.get_all_neighbors(even)
	check("even row has 6 neighbors", even_n.size() == 6, "got %d" % even_n.size())
	
	# Odd row
	var odd := Vector2i(0, 1)
	var odd_n := HexUtils.get_all_neighbors(odd)
	check("odd row has 6 neighbors", odd_n.size() == 6, "got %d" % odd_n.size())
	
	# Neighbors differ for odd/even
	check("odd/even neighbors differ", even_n != odd_n, "both: %s" % str(even_n))


func test_hex_distance() -> void:
	print("[test] hex_distance")
	HexUtils.get_config().odd_row_shift_right = true
	
	check("same cell", HexUtils.hex_distance(Vector2i(0, 0), Vector2i(0, 0)) == 0)
	check("adjacent x", HexUtils.hex_distance(Vector2i(0, 0), Vector2i(1, 0)) == 1)
	check("distance 2 along x", HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0)) == 2)
	check("distance symmetric", 
		HexUtils.hex_distance(Vector2i(3, 3), Vector2i(0, 0)) == HexUtils.hex_distance(Vector2i(0, 0), Vector2i(3, 3)))


func test_bfs_path() -> void:
	print("[test] bfs_path")
	HexUtils.get_config().odd_row_shift_right = true
	
	# start == goal
	var path := HexUtils.bfs_path(Vector2i(0, 0), Vector2i(0, 0), {}, 10, 10)
	check("start==goal returns [start]", path.size() == 1 and path[0] == Vector2i(0, 0))
	
	# Straight path, no obstacles
	var straight := HexUtils.bfs_path(Vector2i(0, 0), Vector2i(3, 0), {}, 10, 10)
	check("straight path length 4", straight.size() == 4, "got %d" % straight.size())
	check("starts at origin", straight[0] == Vector2i(0, 0))
	check("ends at goal", straight[3] == Vector2i(3, 0))
	
	# Blocked path
	var blocked: Dictionary = {Vector2i(1, 0): true}
	var blocked_path := HexUtils.bfs_path(Vector2i(0, 0), Vector2i(2, 0), blocked, 10, 10)
	check("blocked path is non-empty (goes around)", blocked_path.size() > 0, "got %d" % blocked_path.size())
	
	# Unreachable (completely surrounded)
	var wall: Dictionary = {}
	for n in HexUtils.get_all_neighbors(Vector2i(2, 2)):
		wall[n] = true
	var unreachable := HexUtils.bfs_path(Vector2i(0, 0), Vector2i(2, 2), wall, 10, 10)
	check("unreachable path is empty", unreachable.is_empty())


func test_bfs_reachable() -> void:
	print("[test] bfs_reachable")
	HexUtils.get_config().odd_row_shift_right = true
	
	# 1 step from center in open field
	var reach := HexUtils.bfs_reachable(Vector2i(5, 5), 1, {}, 10, 10)
	check("1 step = 6 neighbors", reach.size() == 6, "got %d" % reach.size())
	
	# 2 steps
	var reach2 := HexUtils.bfs_reachable(Vector2i(5, 5), 2, {}, 20, 20)
	check("2 steps = 18 neighbors", reach2.size() == 18, "got %d" % reach2.size())
	
	# Start cell not included
	check("start cell excluded", not reach.has(Vector2i(5, 5)))
	
	# At boundary
	var edge := HexUtils.bfs_reachable(Vector2i(0, 0), 1, {}, 10, 10)
	check("at boundary < 6 neighbors", edge.size() < 6, "got %d" % edge.size())


func test_even_row_mode() -> void:
	print("[test] even row mode")
	HexUtils.get_config().odd_row_shift_right = false
	
	var n := HexUtils.get_all_neighbors(Vector2i(0, 0))
	check("even mode: 6 neighbors", n.size() == 6)
	
	var d := HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0))
	check("even mode: distance 2", d == 2)


func test_min_heap_pop_empty_guard() -> void:
	print("[test] min_heap empty-pop guard")
	var heap = HexUtilsScript.MinHeap.new()
	var popped = heap.pop()
	check("pop on empty heap returns [] (no crash)",
		popped is Array and popped.is_empty(), "got %s" % str(popped))

func test_min_heap_ordering() -> void:
	print("[test] min_heap ordering")
	var heap = HexUtilsScript.MinHeap.new()
	heap.push([5, "e"])
	heap.push([1, "a"])
	heap.push([3, "c"])
	var p1 = heap.pop()
	check("first pop is smallest (a)", p1[1] == "a", "got %s" % str(p1))
	var p2 = heap.pop()
	check("second pop is next (c)", p2[1] == "c", "got %s" % str(p2))
	var p3 = heap.pop()
	check("third pop is last (e)", p3[1] == "e", "got %s" % str(p3))
	check("heap now empty", heap.pop().is_empty(), "")

func test_cube_roundtrip() -> void:
	print("[test] cube roundtrip")
	HexUtils.get_config().odd_row_shift_right = true
	
	for y in 4:
		for x in 4:
			var orig := Vector2i(x, y)
			var cube := HexUtils.offset_to_cube(orig)
			var back := HexUtils.cube_to_offset(cube)
			check("roundtrip (%d,%d)" % [x, y], orig == back, "got %s" % str(back))


