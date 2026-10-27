extends BaseTest

## Глобальный скан обхода темы (T-227, сведение С-2).
##
## До этого файла механизм 1/2 обхода темы проверялся поделами: каждый гард экрана
## пересчитывал переопределения в «своих» исходниках (`_REMAINING_IN_SCRIPTS`,
## `_REMAINING_IN_SCENES`, `*_has_no_stylebox_overrides`), и новый экран не проверялся
## вообще, пока кто-нибудь не заводил ему свой файл. Здесь проверка одна на весь
## production-код.
##
## Что считается обходом (канон: docs/mvp/TICKETS.md, AC1 тикета T-147):
##   1) вызов `add_theme_stylebox_override` в .gd;
##   2) запись `theme_override_styles/<имя>` в .tscn.
## Оба ложатся в одно псевдосвойство узла, поэтому и допуск один на оба механизма.
##
## Почему текстовый скан, а не обход живого дерева: обход не отличает чужую вложенную
## сцену от своей (правило области, docs/mvp/CAPTURE-HELPER.md), а вызов обязан быть
## виден в исходнике — динамического способа задать stylebox без этого имени нет
## (`set("theme_override_" + x)` — экзотика, которой в репо нет; её ловит рантайм-гард
## экрана, оставленный там, где он был).
##
## Область: `res://scripts/` и `res://scenes/` — то, что едет в игру. `tests/`, `tools/`
## и `addons/` вне: тестовые харнесы и захватчики кадра рисуют служебные рамки, и их
## переопределение не влияет на пиксел игрока.

const _SCAN_DIRS := ["res://scripts", "res://scenes"]

## Единственный документированный остаток: `focus` города ждёт ответа Q-M95
## (подсрез 4.8). Формат: путь → разрешённые имена stylebox-свойств.
const _ALLOWED := {
	"res://scripts/ui/city_screen.gd": ["focus"],
}

const _GD_MARK := "add_theme_stylebox_override"
const _TSCN_MARK := "theme_override_styles/"


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	assert_object(d).is_not_null().override_failure_message("нет каталога %s" % dir_path)
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with(".") and name != "addons":
				_walk(full, out)
		elif name.ends_with(".gd") or name.ends_with(".tscn"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


func _files(ext: String) -> Array[String]:
	var all: Array[String] = []
	for dir_path in _SCAN_DIRS:
		_walk(dir_path, all)
	var out: Array[String] = []
	for f in all:
		if f.ends_with(ext):
			out.append(f)
	out.sort()
	return out


## Строки-комментарии не считаются: четыре из пяти находок в production-коде — это
## комментарии «здесь раньше был override, не возвращайте» (battle_ui, spellbook,
## main_menu, kitchen_sink). Настоящий вызов обязан краснеть, объяснение в комментарии —
## нет. Проверка держит обе правды одновременно.
func _code_lines(text: String, mark: String) -> Array[String]:
	var out: Array[String] = []
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if line.contains(mark):
			out.append("%d: %s" % [i + 1, stripped])
	return out


func test_no_script_level_stylebox_overrides_outside_allowlist() -> void:
	var offenders := PackedStringArray()
	var seen := {}
	for path in _files(".gd"):
		var rel := path
		var code := _code_lines(FileAccess.get_file_as_string(rel), _GD_MARK)
		if code.is_empty():
			continue
		seen[rel] = code.size()
		var allowed: Array = _ALLOWED.get(rel, [])
		if code.size() > allowed.size():
			offenders.append("%s: вызовов %d, допустимо %d\n    %s" % [
				rel, code.size(), allowed.size(), "\n    ".join(code)])
			continue
		for entry in code:
			var body: String = String(entry).split(": ", false, 1)[1]
			var named := false
			for item in allowed:
				if body.contains('"%s"' % String(item)):
					named = true
			if not named:
				offenders.append("%s: переопределение вне допуска %s → %s" % [
					rel, str(allowed), entry])
	assert_int(offenders.size()).is_equal(0) \
		.override_failure_message(
			"переопределение stylebox сильнее варианта темы и делает узел недосягаемым для кита "
			+ "(T-147). Найдено в production-коде:\n%s" % "\n".join(offenders))
	# Допуск обязан быть живым: мёртвая строка в _ALLOWED — это будущая дыра,
	# замаскированная под согласованное исключение.
	for path in _ALLOWED.keys():
		assert_bool(seen.has(path)).is_true() \
			.override_failure_message(
				"в допуске числится %s, а переопределений в нём нет — убери строку из _ALLOWED" % path)


func test_no_scene_level_stylebox_overrides_remain() -> void:
	var found := PackedStringArray()
	for path in _files(".tscn"):
		var code := _code_lines(FileAccess.get_file_as_string(path), _TSCN_MARK)
		for entry in code:
			found.append("%s  %s" % [path, entry])
	assert_int(found.size()).is_equal(0) \
		.override_failure_message(
			"сценевый переопределённый stylebox (механизм 2 обхода темы) — %d шт.:\n%s"
			% [found.size(), "\n".join(found)])


## Скан обязан что-то видеть: пустой список файлов = молчаливый зелёный (тот же класс
## дефекта, что «уровень молчит» в док-гейте).
func test_scan_area_is_not_empty() -> void:
	var gd := _files(".gd")
	var tscn := _files(".tscn")
	assert_bool(gd.size() > 100).is_true() \
		.override_failure_message("скан .gd почти слеп: файлов %d" % gd.size())
	assert_bool(tscn.size() > 20).is_true() \
		.override_failure_message("скан .tscn почти слеп: файлов %d" % tscn.size())
