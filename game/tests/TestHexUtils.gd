extends GdUnitTestSuite

const HexUtils = preload("res://scripts/core/HexUtils.gd")

func test_hex_distance_same_cell() -> void:
    assert_int(HexUtils.hex_distance(Vector2i(5, 5), Vector2i(5, 5))).is_equal(0)

func test_hex_distance_adjacent() -> void:
    var center := Vector2i(10, 10)
    for nb in HexUtils.get_all_neighbors(center):
        assert_int(HexUtils.hex_distance(center, nb)).is_equal(1)

func test_offset_to_cube_and_back() -> void:
    var original := Vector2i(13, 7)
    var cube := HexUtils.offset_to_cube(original)
    var restored := HexUtils.cube_to_offset(cube)
    assert_object(restored).is_equal(original)
