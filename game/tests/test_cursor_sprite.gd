extends GdUnitTestSuite

const CursorSprite = preload("res://scripts/data/CursorSprite.gd")

func test_enum_has_semantic_and_numeric_values() -> void:
	assert_bool(CursorSprite.Cursor.BOOT == 1).is_true()
	assert_bool(CursorSprite.Cursor.HAND == 2).is_true()
	assert_bool(CursorSprite.Cursor.WARRIORS == 3).is_true()
	assert_bool(CursorSprite.Cursor.CURSOR_04 == 4).is_true()
	assert_bool(CursorSprite.Cursor.CURSOR_32 == 32).is_true()

func test_enum_has_32_values() -> void:
	assert_that(CursorSprite.Cursor.values().size()).is_equal(32)

func test_path_resolver_format() -> void:
	for i in range(1, 33):
		assert_that(CursorSprite.path(i)).is_equal("res://assets/cursors/cursor_%02d.png" % i)

func test_path_resolver_specific() -> void:
	assert_that(CursorSprite.path(1)).is_equal("res://assets/cursors/cursor_01.png")
	assert_that(CursorSprite.path(10)).is_equal("res://assets/cursors/cursor_10.png")
	assert_that(CursorSprite.path(32)).is_equal("res://assets/cursors/cursor_32.png")

func test_path_by_name_semantic() -> void:
	assert_that(CursorSprite.path_by_name("BOOT")).is_equal("res://assets/cursors/cursor_01.png")
	assert_that(CursorSprite.path_by_name("HAND")).is_equal("res://assets/cursors/cursor_02.png")
	assert_that(CursorSprite.path_by_name("WARRIORS")).is_equal("res://assets/cursors/cursor_03.png")

func test_path_by_name_unknown() -> void:
	assert_that(CursorSprite.path_by_name("DOES_NOT_EXIST")).is_equal("")
