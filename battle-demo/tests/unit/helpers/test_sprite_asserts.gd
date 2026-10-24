#extends GdUnitTestSuite
# tests/unit/helpers/test_sprite_asserts.gd
# [AI]: задача 1.7 tasks.md, проверено человеком.
# Хелпер проверки кадров обязан находить все три дефекта и молчать на годном файле.

extends GdUnitTestSuite

const TMP := "user://sprite_asserts_fixture.png"


func test_frame_ok_has_no_problems() -> void:
	assert_that(_write(Image.FORMAT_RGBA8, 512, Color(1, 0, 0, 1))).is_empty()


func test_wrong_size_is_reported() -> void:
	assert_str(";".join(_write(Image.FORMAT_RGBA8, 256, Color(1, 0, 0, 1)))).contains("размер")


func test_missing_alpha_is_reported() -> void:
	assert_str(";".join(_write(Image.FORMAT_RGB8, 512, Color(1, 0, 0, 1)))).contains("альфа")


func test_empty_frame_is_reported() -> void:
	assert_str(";".join(_write(Image.FORMAT_RGBA8, 512, Color(1, 0, 0, 0)))).contains("пуст")


func test_missing_file_is_reported() -> void:
	assert_str(";".join(SpriteAsserts.check_frame("user://net-takogo-fayla.png"))).contains("нет файла")


func _write(format: int, side: int, color: Color) -> PackedStringArray:
	var img := Image.create(side, side, false, format)
	img.fill(color)
	assert_that(img.save_png(TMP)).is_equal(OK)
	return SpriteAsserts.check_frame(TMP)
