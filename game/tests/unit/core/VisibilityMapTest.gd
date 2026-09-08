extends GdUnitTestSuite
# TASK_09: VisibilityMap — FOV/исследованность.


func test_initially_unexplored() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	assert_bool(v.is_explored(Vector2i(5, 5))).is_false()


func test_recompute_marks_hero_visible() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	v.recompute(Vector2i(5, 5), [], 5, 3)
	assert_bool(v.is_visible(Vector2i(5, 5))).is_true()
	assert_bool(v.is_explored(Vector2i(5, 5))).is_true()


func test_out_of_sight_not_visible() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	v.recompute(Vector2i(0, 0), [], 2, 2)
	assert_bool(v.is_visible(Vector2i(9, 9))).is_false()


func test_explored_grows() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	v.recompute(Vector2i(5, 5), [], 5, 3)
	var before := v.explored.size()
	v.recompute(Vector2i(0, 0), [], 5, 3)
	assert_that(v.explored.size() >= before).is_true()


func test_explored_persists_after_fog() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	v.recompute(Vector2i(0, 0), [], 1, 1)
	assert_bool(v.is_explored(Vector2i(0, 1))).is_true()
	v.recompute(Vector2i(9, 9), [], 1, 1)
	assert_bool(v.is_explored(Vector2i(0, 1))).is_true()
	assert_bool(v.is_visible(Vector2i(0, 1))).is_false()


func test_city_sight_source() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	v.recompute(Vector2i(0, 0), [Vector2i(5, 5)], 1, 4)
	assert_bool(v.is_visible(Vector2i(5, 5))).is_true()


func test_is_in_bounds() -> void:
	# 4.7: проверка границ карты
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	assert_bool(v.is_in_bounds(Vector2i(0, 0))).is_true()
	assert_bool(v.is_in_bounds(Vector2i(9, 9))).is_true()
	assert_bool(v.is_in_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(v.is_in_bounds(Vector2i(10, 5))).is_false()


func test_serialize_explored() -> void:
	var v := VisibilityMap.new()
	v.set_map_size(10, 10)
	v.recompute(Vector2i(5, 5), [], 1, 1)
	var arr := v.serialize_explored()
	# диск радиуса 1 = центр + 6 соседей
	assert_that(arr.size()).is_equal(7)
	var v2 := VisibilityMap.new()
	v2.set_map_size(10, 10)
	v2.load_explored(arr)
	assert_bool(v2.is_explored(Vector2i(5, 5))).is_true()
