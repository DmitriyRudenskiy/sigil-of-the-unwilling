#extends GdUnitTestSuite
# tests/helpers/sprite_asserts.gd
# [AI]: задача 1.7 tasks.md, проверено человеком.
# Проверка готового кадра спрайта со стороны движка: размер, альфа-канал,
# непустой кадр. Функции возвращают список проблем пустым списком = кадр годен,
# чтобы тест мог показать строку с причиной, а не голый false.

class_name SpriteAsserts extends RefCounted

const SIDE := 512
## Ниже этой доли непрозрачных сэмплов кадр считается пустым (фон вместо юнита).
const MIN_OPAQUE_RATIO := 0.02
## Шаг сэмплирования: 512/4 = 128 точек на сторону, кадр проверяется без аллокаций.
const STEP := 4


static func check_frame(path: String, side: int = SIDE) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray(["нет файла"])
	var img := Image.load_from_file(path)
	if img == null:
		return PackedStringArray(["не читается как изображение"])
	var problems := PackedStringArray()
	if img.get_width() != side or img.get_height() != side:
		problems.append("размер %d×%d, ожидалось %d×%d" % [
			img.get_width(), img.get_height(), side, side,
		])
	if not _png_has_alpha(path):
		problems.append("нет альфа-канала")
	elif _opaque_ratio(img) < MIN_OPAQUE_RATIO:
		problems.append("кадр пуст: непрозрачных пикселей меньше %.0f%%" % (MIN_OPAQUE_RATIO * 100.0))
	return problems


## PNG-заголовок: байт 25 — colour type (4 = серый+альфа, 6 = RGBA). У палитры (3)
## альфа бывает в tRNS; в этом пайплайне кадры пишутся только RGBA8.
static func _png_has_alpha(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	f.seek(25)
	var color_type := f.get_8()
	return color_type == 4 or color_type == 6


static func _opaque_ratio(img: Image) -> float:
	var total := 0
	var opaque := 0
	for y in range(0, img.get_height(), STEP):
		for x in range(0, img.get_width(), STEP):
			total += 1
			if img.get_pixelv(Vector2(x, y)).a > 0.05:
				opaque += 1
	return float(opaque) / float(max(total, 1))
