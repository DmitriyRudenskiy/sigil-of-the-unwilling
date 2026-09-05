extends "res://tests/gut_base.gd"
## Headless tests for HexUtils (геометрия: соседи, расстояния, cube).
## Путь — в tests/test_hex_pathfinding.gd, куча — в tests/test_min_heap.gd (аудит #9).


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


func test_even_row_mode() -> void:
	print("[test] even row mode")
	HexUtils.get_config().odd_row_shift_right = false
	
	var n := HexUtils.get_all_neighbors(Vector2i(0, 0))
	check("even mode: 6 neighbors", n.size() == 6)
	
	var d := HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0))
	check("even mode: distance 2", d == 2)


func test_cube_roundtrip() -> void:
	print("[test] cube roundtrip")
	HexUtils.get_config().odd_row_shift_right = true
	
	for y in 4:
		for x in 4:
			var orig := Vector2i(x, y)
			var cube := HexUtils.offset_to_cube(orig)
			var back := HexUtils.cube_to_offset(cube)
			check("roundtrip (%d,%d)" % [x, y], orig == back, "got %s" % str(back))


