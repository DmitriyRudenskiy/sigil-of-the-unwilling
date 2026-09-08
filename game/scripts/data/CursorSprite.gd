class_name CursorSprite

const _PATH_FORMAT := "res://assets/cursors/cursor_%02d.png"

enum Cursor {
	BOOT = 1,
	HAND = 2,
	WARRIORS = 3,
	CURSOR_04 = 4,
	CURSOR_05 = 5,
	CURSOR_06 = 6,
	CURSOR_07 = 7,
	CURSOR_08 = 8,
	CURSOR_09 = 9,
	CURSOR_10 = 10,
	CURSOR_11 = 11,
	CURSOR_12 = 12,
	CURSOR_13 = 13,
	CURSOR_14 = 14,
	CURSOR_15 = 15,
	CURSOR_16 = 16,
	CURSOR_17 = 17,
	CURSOR_18 = 18,
	CURSOR_19 = 19,
	CURSOR_20 = 20,
	CURSOR_21 = 21,
	CURSOR_22 = 22,
	CURSOR_23 = 23,
	CURSOR_24 = 24,
	CURSOR_25 = 25,
	CURSOR_26 = 26,
	CURSOR_27 = 27,
	CURSOR_28 = 28,
	CURSOR_29 = 29,
	CURSOR_30 = 30,
	CURSOR_31 = 31,
	CURSOR_32 = 32,
}

static func path(id: int) -> String:
	return _PATH_FORMAT % id

static func path_by_name(name: String) -> String:
	if Cursor.has(name):
		return path(Cursor[name])
	return ""
