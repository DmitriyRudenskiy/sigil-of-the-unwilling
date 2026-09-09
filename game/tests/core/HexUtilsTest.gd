extends GdUnitTestSuite


func test_offset_cube_roundtrip() -> void:
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(3, -2), Vector2i(-5, 7), Vector2i(10, 10), Vector2i(-1, 0)]
	for c in cells:
		var back := HexUtils.cube_to_offset(HexUtils.offset_to_cube(c))
		assert_vector(back).is_equal(c)


## Из test_hex_utils (root): режим even-row (смещение влево).
## Оригинал грязнил статический конфиг — здесь возвращаем дефолт.
func test_even_row_mode() -> void:
	HexUtils._shift_right = false
	var n := HexUtils.get_all_neighbors(Vector2i(0, 0))
	assert_array(n).has_size(6)
	assert_int(HexUtils.hex_distance(Vector2i(0, 0), Vector2i(2, 0))).is_equal(2)
	HexUtils._shift_right = true


func test_hex_distance_zero_and_symmetry() -> void:
	var a := Vector2i(2, 5)
	var b := Vector2i(-3, 1)
	assert_int(HexUtils.hex_distance(a, a)).is_zero()
	assert_int(HexUtils.hex_distance(a, b)).is_equal(HexUtils.hex_distance(b, a))


func test_hex_distance_neighbors_are_one() -> void:
	var ring1 := HexUtils.ring(Vector2i.ZERO, 1)
	assert_array(ring1).has_size(6)
	for n in ring1:
		assert_int(HexUtils.hex_distance(Vector2i.ZERO, n)).is_equal(1)


func test_ring_zero_returns_center() -> void:
	var r := HexUtils.ring(Vector2i(4, 4), 0)
	assert_array(r).has_size(1)
	assert_vector(r[0]).is_equal(Vector2i(4, 4))


func test_triangle_inequality() -> void:
	var a := Vector2i(-4, 3)
	var b := Vector2i(7, -2)
	var c := Vector2i(1, 6)
	assert_int(HexUtils.hex_distance(a, c)).is_less_equal(
		HexUtils.hex_distance(a, b) + HexUtils.hex_distance(b, c))


func test_ring_sizes_and_distances() -> void:
	var center := Vector2i(1, 1)
	for r in [2, 3, 5]:
		var ring := HexUtils.ring(center, r)
		assert_array(ring).has_size(r * 6)
		for c in ring:
			assert_int(HexUtils.hex_distance(center, c)).is_equal(r)


func test_get_all_neighbors_six_distinct() -> void:
	var nbs := HexUtils.get_all_neighbors(Vector2i(5, 3))
	assert_array(nbs).has_size(6)
	var seen: Dictionary = {}
	for n in nbs:
		assert_bool(not seen.has(n)).is_true()
		seen[n] = true
		assert_int(HexUtils.hex_distance(Vector2i(5, 3), n)).is_equal(1)


func test_idx_roundtrip() -> void:
	var w := 25
	var h := 18
	for c in [Vector2i.ZERO, Vector2i(w - 1, h - 1), Vector2i(7, 3)]:
		var idx := HexUtils.pos_to_idx(c, w)
		assert_vector(HexUtils.idx_to_pos(idx, w)).is_equal(c)
