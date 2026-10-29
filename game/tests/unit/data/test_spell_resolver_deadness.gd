extends BaseTest

## Инвариант мёртвого фасада (T-283; носитель решения — T-267).
##
## Что измеряется. `SpellResolver` (`scripts/data/spell_resolver.gd`, 70 строк) и
## ведущий им `TemplateEngine` не вызваны ни из чего, что едет в игру: бой колдует
## другим путём — `SpellCaster.cast` (её зовут
## `scripts/systems/battle_action_resolver.gd:102` и
## `scripts/autoload/battle_emulator.gd:42`), у неё свои тесты
## (`tests/unit/systems/test_magic_resistance.gd`,
## `tests/unit/systems/test_battle_spell_targeting.gd`).
##
## Почему тест, а не заметка. До этого файла проверка была односторонней: восемь
## тестов в `tests/unit/data/test_spell_system.gd` дергали `SpellResolver.resolve`
## и зеленели, поэтому «тесты заклинаний зелёные» читалось как «боевая магия
## работает», хотя проверялся фасад, стоящий вне боя. Заметка в
## `docs/18-system-map.md` §3б описывает это состояние, но не краснеет. Здесь
## зафиксированы **оба** направления, чтобы молча нельзя было ни того ни другого:
##   - появился production-вызов → красный: в T-267 надо записать, что резолвер
##     стал носителем магической модели и чем его семантика отличается от
##     `SpellCaster` (тот не берёт стоимость и не знает `influence_req`);
##   - класс удалён (вариант (в) T-267) → красный тоже: вместе с ним снимаются
##     восемь проверок и строка карты системы, а это акт, а не уборка.
##
## Область: `res://scripts/` и `res://scenes/` — то, что едет в игру. `tests/` и
## `tools/` вне: тест фасада обязан его вызывать, иначе измерять нечего. Строки
## комментариев не считаются — объяснение «здесь живого пути нет» не является
## вызовом (тот же приём, что `_code_lines` в `test_theme_source_scan.gd`).

const _SCAN_DIRS := ["res://scripts", "res://scenes"]
const _SELF := "res://scripts/data/spell_resolver.gd"
const _MARKS := ["SpellResolver", "spell_resolver"]


func test_spell_resolver_has_no_production_caller() -> void:
	var offenders := PackedStringArray()
	var files: Array[String] = []
	for dir_path in _SCAN_DIRS:
		_walk(dir_path, files)
	files.sort()
	for path in files:
		if path == _SELF:
			continue
		var text := FileAccess.get_file_as_string(path)
		for mark in _MARKS:
			for line in _code_lines(text, mark):
				offenders.append("%s → %s" % [path, line])
	assert_int(offenders.size()).is_equal(0) \
		.override_failure_message(
			"у SpellResolver появился вызывающий в production-коде, но решение по носителю "
			+ "магической модели ещё не принято (T-267: (а) монтировать этот резолвер и снять "
			+ "SpellCaster / (б) вынести подсистему в prototypes / (в) удалить). Если монтаж "
			+ "согласован — закрой T-267 и обнови docs/18-system-map.md §3б и этот тест:\n%s"
			% "\n".join(offenders))


## Второй край инварианта: файл жив, пока жив инвариант. Удаление молча
## превращает восемь зелёных проверок в отсутствующие — это тот же дефект, что и
## вызов, просто с другим концом.
func test_spell_resolver_file_is_still_here() -> void:
	assert_bool(ResourceLoader.exists(_SELF)).is_true() \
		.override_failure_message(
			"spell_resolver.gd удалён, а инвариант T-283 жив: сними восемь тестов в "
			+ "tests/unit/data/test_spell_system.gd, убери строку SpellResolver из "
			+ "docs/18-system-map.md §3б и закрой T-267 вариантом (в) — вместе с этим файлом.")


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_walk(full, out)
		elif name.ends_with(".gd") or name.ends_with(".tscn"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()


## Только строки кода: комментарий «этого пути в бою нет» — не вызов.
func _code_lines(text: String, mark: String) -> Array[String]:
	var out: Array[String] = []
	var lines := text.split("\n")
	for i in lines.size():
		var stripped: String = String(lines[i]).strip_edges()
		if stripped.begins_with("#") or stripped.begins_with("##"):
			continue
		if stripped.contains(mark):
			out.append("%d: %s" % [i + 1, stripped])
	return out
