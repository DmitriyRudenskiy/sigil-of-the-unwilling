extends GdUnitTestSuite

func after_test() -> void:
	HexUtils._shift_right = true

func test_neighbors() -> void:
	print("[test] neighbors")
	HexUtils._shift_right = true

	var even := Vector2i(0, 0)
	var even_n := HexUtils.get_all_neighbors(even)
	assert_bool(even_n.size() == 6).is_true()

	var odd := Vector2i(0, 1)
	var odd_n := HexUtils.get_all_neighbors(odd)
	assert_bool(odd_n.size() == 6).is_true()

	assert_bool(even_n != odd_n).is_true()

func test_hex_distance() -> void:
	print("[test] hex_distance")
	HexUtils._shift_right = true

	assert_bool(HexUtils.hex_distance(Vector2i(0, 0), Vector2i(0, 0)) == 0).is_true()
	assert_bool(HexUtils.hex_distance(Vector2i(0, 0), Vector2i(1, 0)) == 1).is_true()
	assert_bool(HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0)) == 2).is_true()
	assert_bool(HexUtils.hex_distance(Vector2i(3, 3), Vector2i(0, 0)) == HexUtils.hex_distance(Vector2i(0, 0), Vector2i(3, 3))).is_true()

func test_even_row_mode() -> void:
	print("[test] even row mode")
	HexUtils._shift_right = false

	var n := HexUtils.get_all_neighbors(Vector2i(0, 0))
	assert_bool(n.size() == 6).is_true()

	var d := HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0))
	assert_bool(d == 2).is_true()

func test_cube_roundtrip() -> void:
	print("[test] cube roundtrip")
	HexUtils._shift_right = true

	for y in 4:
		for x in 4:
			var orig := Vector2i(x, y)
			var cube := HexUtils.offset_to_cube(orig)
			var back := HexUtils.cube_to_offset(cube)
			assert_bool(orig == back).is_true()
