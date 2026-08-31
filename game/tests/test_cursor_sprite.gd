extends "res://tests/test_base.gd"
## Тесты enum CursorSprite: семантические + числовые значения, резолвер пути.

const CursorSprite = preload("res://scripts/data/CursorSprite.gd")

func test_enum_has_semantic_and_numeric_values() -> void:
	# Семантические
	assert_true(CursorSprite.Cursor.BOOT == 1)
	assert_true(CursorSprite.Cursor.HAND == 2)
	assert_true(CursorSprite.Cursor.WARRIORS == 3)
	# Числовой fallback
	assert_true(CursorSprite.Cursor.CURSOR_04 == 4)
	assert_true(CursorSprite.Cursor.CURSOR_32 == 32)

func test_enum_has_32_values() -> void:
	assert_eq(CursorSprite.Cursor.values().size(), 32)

func test_path_resolver_format() -> void:
	# %02d, курсоры 01..32
	for i in range(1, 33):
		assert_eq(CursorSprite.path(i), "res://assets/cursors/cursor_%02d.png" % i)

func test_path_resolver_specific() -> void:
	assert_eq(CursorSprite.path(1), "res://assets/cursors/cursor_01.png")
	assert_eq(CursorSprite.path(10), "res://assets/cursors/cursor_10.png")
	assert_eq(CursorSprite.path(32), "res://assets/cursors/cursor_32.png")

func test_path_by_name_semantic() -> void:
	assert_eq(CursorSprite.path_by_name("BOOT"), "res://assets/cursors/cursor_01.png")
	assert_eq(CursorSprite.path_by_name("HAND"), "res://assets/cursors/cursor_02.png")
	assert_eq(CursorSprite.path_by_name("WARRIORS"), "res://assets/cursors/cursor_03.png")

func test_path_by_name_unknown() -> void:
	assert_eq(CursorSprite.path_by_name("DOES_NOT_EXIST"), "")
