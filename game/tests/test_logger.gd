extends "res://tests/gut_base.gd"
## Проверки GameLogger (scripts/core/GameLogger.gd).
##
## GameLogger не имеет захватываемого sink (print_rich / push_warning /
## push_error), поэтому сам вывод assert'ами не проверить. Проверяем:
## - контракт формата тегов: `_tag()` дописывает пробелы до `TAG_WIDTH`
##   и оборачивает в `[color=gray]...[/color]`;
## - smoke: все 9 публичных методов вызываются без ошибок.

const _LOGGER := preload("res://scripts/core/GameLogger.gd")
const _Platform := preload("res://scripts/core/Platform.gd")

## Снимает ANSI-обёртку цвета и квадратные скобки: "[color=gray][X     ][/color]" -> "X     ".
func _visible_tag(t: String) -> String:
	var s: String = t.replace("[color=gray]", "").replace("[/color]", "")
	return s.substr(1, s.length() - 2)

func test_tag_pads_to_width() -> void:
	assert_eq(_visible_tag(_LOGGER._tag("Battle")).length(), _LOGGER.TAG_WIDTH, "короткий тег дополнен до TAG_WIDTH")
	assert_eq(_visible_tag(_LOGGER._tag("")).length(), _LOGGER.TAG_WIDTH, "пустой тег даёт TAG_WIDTH пробелов")

func test_tag_wraps_in_gray() -> void:
	var t := _LOGGER._tag("Hero")
	if _Platform.is_headless():
		# ponytail: headless drops color markup (finding #11) — tag is plain.
		assert_true(not t.begins_with("[color=gray]"), "в headless тег без color-обвязки")
		assert_eq(_visible_tag(t), "Hero".rpad(_LOGGER.TAG_WIDTH), "видимая часть — имя + пробелы до TAG_WIDTH")
		return
	assert_true(t.begins_with("[color=gray]"), "тег начинается с [color=gray]")
	assert_true(t.ends_with("[/color]"), "тег заканчивается [/color]")
	assert_eq(_visible_tag(t), "Hero".rpad(_LOGGER.TAG_WIDTH), "видимая часть тега — имя + пробелы до TAG_WIDTH")

func test_long_tag_not_truncated() -> void:
	var t := _LOGGER._tag("VeryLongTagName123")
	assert_eq(_visible_tag(t), "VeryLongTagName123", "rpad не укорачивает длинный тег")
	assert_gt(_visible_tag(t).length(), _LOGGER.TAG_WIDTH, "длинный тег шире TAG_WIDTH")

func test_public_methods_smoke() -> void:
	# print_rich-методы
	_LOGGER.info("info smoke", "Test")
	_LOGGER.trace("trace smoke", "Test")
	_LOGGER.battle("battle smoke")
	_LOGGER.world("world smoke")
	_LOGGER.inventory("inventory smoke")
	_LOGGER.ui("ui smoke")
	_LOGGER.hero("hero smoke")
	# push_warning / push_error: в headless дают строки WARNING:/ERROR: в логе —
	# ожидаемо для этого теста (CI-маркеры на это не срабатывают).
	_LOGGER.warn("warn smoke", "Test")
	_LOGGER.error("error smoke", "Test")
	assert_push_error("error smoke")  # GUT считает незахваченный push_error падением теста
	assert_true(true, "публичные методы GameLogger вызваны без исключений")
