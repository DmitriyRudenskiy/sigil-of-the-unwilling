class_name DhashMeasure
extends RefCounted

# Единственная реализация меры различимости иконок (dHash 9×8 по яркости со
# смешиванием альфы с носителем). Ей же режет гейт
# (tests/unit/assets/test_resource_icons_asset1.gd), ею же снимаются константы
# A-9 (ячейки удалённого атласа HoMM III) и печатается матрица
# (tools/dhash_report.gd).
#
# Почему одна: PIL-ресайс 16×16→9×8 расходится с Godot на 2–12 бит на пару
# (ore↔silver: Godot 11, PIL 13/16/23 в зависимости от фильтра). Порог 12 при
# таком шуме ненадёжен в обе стороны, а ложный PASS анти-рекола (A-9) — худшая
# из ошибок: он говорит «это не перекрас», когда проверить нельзя.

const FIELD := 8                       # §7.1 шаг 2: поле = канвас − 8 px с каждой стороны
const CARRIER := Color8(0x28, 0x1C, 0x0F)  # §4.1 тёмное дерево поля карты
const _HEX_DIGITS := "0123456789abcdef"


# Яркость как её видит глаз на носителе: альфа — смешивание с деревом поля.
static func lum(c: Color) -> float:
	var a := c.a
	return 0.2126 * (c.r * a + CARRIER.r * (1.0 - a)) \
		+ 0.7152 * (c.g * a + CARRIER.g * (1.0 - a)) \
		+ 0.0722 * (c.b * a + CARRIER.b * (1.0 - a))


static func hash9x8(src: Image) -> int:
	var small := src.duplicate()
	small.resize(9, 8)
	var h := 0
	for y in range(8):
		for x in range(8):
			if lum(small.get_pixel(x, y)) > lum(small.get_pixel(x + 1, y)):
				h |= 1 << (y * 8 + x)
	return h


# Анти-рекол (A-9): весь канвас — ячейки референса заполняют его целиком.
static func hash_canvas(img: Image) -> int:
	return hash9x8(img)


# Различие форм (парная матрица): только поле содержимого. На всём канвасе мера
# вырождена — 8 px прозрачных полей дают длинные прогоны равных яркостей, биты
# гаснут, расстояние между любыми двумя иконками жмётся к нулю.
static func hash_field(img: Image) -> int:
	return hash9x8(img.get_region(Rect2i(FIELD, FIELD, 32 - 2 * FIELD, 32 - 2 * FIELD)))


static func hamming(a: int, b: int) -> int:
	var d := a ^ b
	var n := 0
	for i in range(64):
		n += (d >> i) & 1
	return n


static func hex64(hex: String) -> int:
	var v := 0
	for i in range(hex.length()):
		v = (v << 4) | _HEX_DIGITS.find(hex[i])
	return v
