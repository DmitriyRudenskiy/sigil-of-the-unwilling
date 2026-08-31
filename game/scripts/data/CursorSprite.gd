class_name CursorSprite
## Enum для пронумерованных асетов курсоров + резолвер путей.
##
## Значения enum: семантические (BOOT/HAND/WARRIORS) для определённых курсоров и
## числовые (CURSOR_NN) для остальных. Число значения = номер файла в
## `res://assets/cursors/cursor_%02d.png` (формат `%02d`); числовой fallback,
## если нет семантического названия.
##
## Семантические значения (BOOT/HAND/WARRIORS) и их привязка к конкретным файлам
## определяются в `context-cursor` (идентификация курсоров). В этом цикле — shell:
## BOOT/HAND/WARRIORS заняли номера 1–3 как плейсхолдеры, `path()` резолвит по номеру.

const _PATH_FORMAT := "res://assets/cursors/cursor_%02d.png"

enum Cursor {
	## Семантические (идентификация — context-cursor; номера 1–3 — плейсхолдеры)
	BOOT = 1,
	HAND = 2,
	WARRIORS = 3,
	## Числовые (fallback)
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

## Резолвит номер файла в res://-путь. Числовой fallback по умолчанию.
static func path(id: int) -> String:
	return _PATH_FORMAT % id

## Резолвит по семантическому названию (BOOT/HAND/WARRIORS) или числовому
## (CURSOR_NN). Возвращает "" при неизвестном имени.
static func path_by_name(name: String) -> String:
	if Cursor.has(name):
		return path(Cursor[name])
	return ""
