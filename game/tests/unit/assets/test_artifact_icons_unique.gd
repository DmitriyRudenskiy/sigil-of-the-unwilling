extends BaseTest

## Т-235: набор иконок артефактов обязан оставаться набором.
##
## Задача сместилась с «нарисовать» на «не дать набору снова стать не-набором»:
## 60 файлов уже существуют (носитель рисунка — контур `scripts/concept_art/`,
## 128×128 с альфой), а исторический дефект был именно про дубли: процедурный
## `scripts/build/gen_artifact_icons.gd` рисовал форму по **слоту**, поэтому 12
## групп дублей оставили 23 id без собственного рисунка — 60 файлов, 31 уникальный
## рисунок. Инвентарь резолвит `artifacts/%s.png`, так что game-лог был зелёным, а
## игрок видел один и тот же меч в двадцати ячейках.
##
## Что уже закрыто другими носителями и что добавляет этот файл:
##
## | Инвариант | Носитель |
## | --- | --- |
## | у каждого id есть файл и наоборот | `test_rows_and_icons_are_one_to_one` |
## | у 6 кузнечных id файл непустой | `test_forgeable_ids_have_non_empty_icons` |
## | двум id не достался один и тот же растр | этот файл |
## | у каждого id есть видимые пиксели | этот файл (до него — только у 6 id) |
##
## Проверка 1:1 зелёна и при дубле: файлы на месте, имена сходятся с реестром, а
## картинки одинаковые. Отличает её хеш содержимого, а не наличие файла.
##
## Батарея — `game/tools/mut_icon_unique.sh` (дубль, полностью прозрачная иконка,
## уехавший каталог).
const ICON_DIR := "res://assets/artifacts"

# Столько файлов было в наборе до сета 29. Порог нужен, чтобы «область скана
# пуста» не читалась как «дублей нет»: каталог переезжает или переименовывается —
# и всё, что по нему проходит, молча зеленеет.
const _MIN_SET := 54


func _icon_names() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(ICON_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension().to_lower() == "png":
			out.append(f.get_basename())
	out.sort()
	return out


## Область скана обязана быть живёй: иначе две проверки ниже проходят, ничего не
## найдя, и в отчёте это выглядит как «набор чист».
func test_scan_area_holds_the_whole_set() -> void:
	var dir := DirAccess.open(ICON_DIR)
	assert_bool(dir != null).is_true().override_failure_message(
		"каталог иконок %s не открылся — проверки дублей были бы зелёными без единого файла" % ICON_DIR
	)
	var files := _icon_names()
	assert_int(files.size()).is_greater_equal(_MIN_SET).override_failure_message(
		"в %s найдено %d PNG, ожидалось не меньше %d: область скана не должна молча усохнуть"
		% [ICON_DIR, files.size(), _MIN_SET]
	)


## Собственный рисунок у каждого id. Хеш файла, а не пикселей: два одинаковых
## растра, сохранённых разными байтами — отдельная беда (её ловит контакт-лист),
## а переиздание одного растра под двумя id — та, что уже случалась.
func test_no_two_icons_share_the_same_raster() -> void:
	var first_owner := {}
	var dups := ""
	var dups_n := 0
	for id in _icon_names():
		var digest := FileAccess.get_sha256("%s/%s.png" % [ICON_DIR, id])
		if first_owner.has(digest):
			dups_n += 1
			dups += "  `%s` == `%s` (sha256 %s…)\n" % [first_owner[digest], id, digest.substr(0, 12)]
		else:
			first_owner[digest] = id
	assert_bool(dups_n == 0).is_true().override_failure_message(
		"в наборе %d id, уникальных рисунков %d — дубли:\n%s" % [_icon_names().size(), first_owner.size(), dups]
	)


## Невидимая иконка для игры хуже кривой: клетка инвентаря остаётся пустой, а
## файл, размер и md5 у неё образцовые. До этого файла непустоту мерили только 6
## кузнечных id — остальные 54 могли быть прозрачными хоть целиком.
##
## Растр читается с диска (`Image.load_from_file`), а не через `load(path)`: второе
## отдаёт кэш импорта, собранный с прежних байтов: мутант «иконка обнулила альфу»
## на первом варианте был зелёным именно здесь. Проверка, которая меряет кэш,
## не меряет то, что лежит в git.
func test_every_icon_has_visible_pixels() -> void:
	for id in _icon_names():
		var path := "%s/%s.png" % [ICON_DIR, id]
		var img := Image.load_from_file(path)
		assert_bool(img != null).is_true().override_failure_message(
			"иконка `%s` не декодируется из байтов файла — в игре это пустая клетка" % id
		)
		if img == null:
			continue
		assert_bool(img.get_used_rect().has_area()).is_true().override_failure_message(
			"иконка `%s` декодируется, но прозрачна целиком — в игре это пустая клетка" % id
		)
