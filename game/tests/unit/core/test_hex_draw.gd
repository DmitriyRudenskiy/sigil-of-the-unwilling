extends BaseTest
## TASK_21: HexDraw — геометрия 7-точечного замкнутого hex и кэш полигонов.
## Замечание: PackedVector2Array — value-тип, instance-идентичность при возврате
## не проверяется; здесь проверяем содержимое и стабильность после reset.

func after_test() -> void:
	HexDraw.reset_cache()


func test_points_stable_and_reset_works() -> void:
	HexDraw.reset_cache()
	var a := HexDraw.points(40.0)
	var b := HexDraw.points(40.0)
	assert_that(a).is_equal(b)  # содержимое стабильно (кэш или пересчёт — оба верны)
	HexDraw.reset_cache()
	var c := HexDraw.points(40.0)
	assert_that(c).is_equal(a)


func test_points_geometry_seven_point_closed() -> void:
	var pts := HexDraw.points(10.0)
	assert_that(pts.size()).is_equal(7)
	# is_equal_approx: cos(270°) даёт -0.0, строгий == на Vector2 его отличает от 0.0.
	assert_that(pts[0].is_equal_approx(Vector2(0, -10))).is_true()  # верхушка (i=0, -90°)
	assert_that(pts[6].is_equal_approx(pts[0])).is_true()  # замкнутый polyline


func test_points_at_translates() -> void:
	var pts := HexDraw.points_at(Vector2(100, 50), 10.0)
	assert_that(pts.size()).is_equal(7)
	assert_that(pts[0].is_equal_approx(Vector2(100, 40))).is_true()
	assert_that(pts[3].is_equal_approx(Vector2(100, 60))).is_true()
