extends SceneTree
## Headless tests for HexUtils.
## Run: godot --headless -s tests/test_hex_utils.gd

const HexUtilsScript = preload("res://scripts/HexUtils.gd")

var failed := 0
var passed := 0

func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		printerr("  FAIL  ", name, " — ", detail)


func test_neighbors() -> void:
	print("[test] neighbors")
	HexUtils.odd_row_shift_right = true
	
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
	HexUtils.odd_row_shift_right = true
	
	check("same cell", HexUtils.hex_distance(Vector2i(0, 0), Vector2i(0, 0)) == 0)
	check("adjacent x", HexUtils.hex_distance(Vector2i(0, 0), Vector2i(1, 0)) == 1)
	check("distance 2 along x", HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0)) == 2)
	check("distance symmetric", 
		HexUtils.hex_distance(Vector2i(3, 3), Vector2i(0, 0)) == HexUtils.hex_distance(Vector2i(0, 0), Vector2i(3, 3)))


func test_bfs_path() -> void:
	print("[test] bfs_path")
	HexUtils.odd_row_shift_right = true
	
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
	HexUtils.odd_row_shift_right = true
	
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
	HexUtils.odd_row_shift_right = false
	
	var n := HexUtils.get_all_neighbors(Vector2i(0, 0))
	check("even mode: 6 neighbors", n.size() == 6)
	
	var d := HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0))
	check("even mode: distance 2", d == 2)


func test_cube_roundtrip() -> void:
	print("[test] cube roundtrip")
	HexUtils.odd_row_shift_right = true
	
	for y in 4:
		for x in 4:
			var orig := Vector2i(x, y)
			var cube := HexUtils.offset_to_cube(orig)
			var back := HexUtils.cube_to_offset(cube)
			check("roundtrip (%d,%d)" % [x, y], orig == back, "got %s" % str(back))


func _init() -> void:
	print("=== HexUtils headless tests ===")
	test_neighbors()
	test_hex_distance()
	test_bfs_path()
	test_bfs_reachable()
	test_even_row_mode()
	test_cube_roundtrip()
	print("\n=== %d passed, %d failed ===" % [passed, failed])
	await process_frame
	quit(1 if failed > 0 else 0)
