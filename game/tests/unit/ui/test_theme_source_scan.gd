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

## Мёртвые присваивания варианта темы. Две формы: литерала нет среди секций темы
## (узел остаётся на базовом типе) и литерал равен типу самого узла (резолвится ровно
## тот же набор стилей). Пусто с T-228; допуск двусторонний, как и выше: свежий литерал
## краснеет, протухшая строка допуска краснеет тоже.
const _DEAD_VARIATION_ASSIGNMENTS := {}

const _VARIATION_MARK := "theme_type_variation"
const _THEME_PATH := "res://assets/theme/game_theme.tres"


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


## Назначения варианта темы литералом (T-228). Причина, почему это ищется именно здесь:
## `theme_type_variation = "Что-то"` — единственный способ надеть вариант, и он молчит,
## если секции с таким именем в теме нет. Дыра T-228 была в критерии гарда (он спрашивал
## ClassDB, а не тему), а не в источниках; скан держит обе мёртвые формы.
## Замер T-228 (кадр до/после + `Theme.get_type_list()`): Godot резолвит вариант по
## ИМЕНИ секции темы, регистрация через `base_type` для резолва не нужна — она даёт
## цепочку отката и видимость в редакторе. Значит «не зарегистрирован как вариант» ≠
## «не работает»: `TooltipPanel`/`TooltipLabel` на витрине живые (снятие убрало золотую
## пластину подсказки, 7330 px), а мёртвы — имя вне темы и самоприсваивание.
## Строки-комментарии не считаются; генераторы сцен (esc-кавычки внутри .gd) чинятся
## съёмом обратных слэшей, иначе `gen_inventory_scene.gd` писал бы вариант в обход скана.

const _VARIATION_RE := "theme_type_variation\\s*=\\s*&?\"([A-Za-z0-9_]+)\""
const _NODE_TYPE_RE := "^\\[node [^[]* type=\"([A-Za-z0-9_]+)\""


## Пары {name, type}: литерал + тип узла, которому он назначен (для .tscn; в .gd типа
## нет — там самоприсваивание ловит рантайм-гард дерева, а не текст).
func _variation_literals(path: String) -> Array[Dictionary]:
	var text := FileAccess.get_file_as_string(path).replace("\\", "")
	var re := RegEx.create_from_string(_VARIATION_RE)
	var re_node := RegEx.create_from_string(_NODE_TYPE_RE)
	var out: Array[Dictionary] = []
	var node_type := ""
	for raw in text.split("\n"):
		var stripped: String = String(raw).strip_edges()
		if stripped.begins_with("[node "):
			var nm := re_node.search(stripped)
			node_type = String(nm.get_string(1)) if nm != null else ""
		if stripped.begins_with("#"):
			continue
		for m in re.search_all(stripped):
			out.append({"name": String(m.get_string(1)), "type": node_type})
	return out


## Живые секции темы: собственные типы, унаследованные от движка типы (включая
## не-классовые TooltipPanel/TooltipLabel) и зарегистрированные варианты.
func _theme_sections() -> Dictionary:
	var theme: Theme = load(_THEME_PATH)
	var sections := {}
	for s in theme.get_type_list():
		sections[String(s)] = true
	# Разбор текста темы — вторая опора: если get_type_list() когда-нибудь перестанет
	# включать варианты, скан не ослепнет молча.
	var re := RegEx.create_from_string("(?m)^([A-Za-z0-9_]+)/base_type = \"([A-Za-z0-9_]+)\"$")
	for m in re.search_all(FileAccess.get_file_as_string(_THEME_PATH)):
		sections[String(m.get_string(1))] = true
	assert_bool(sections.size() > 60).is_true() \
		.override_failure_message("разбор секций темы сломался: секций %d" % sections.size())
	return sections


func test_no_dead_theme_type_variation_assignment() -> void:
	var sections := _theme_sections()
	var offenders := PackedStringArray()
	var seen := {}
	var total := 0
	for path in _files(".gd") + _files(".tscn"):
		for lit in _variation_literals(path):
			total += 1
			var name := String(lit["name"])
			var reason := ""
			if not sections.has(name):
				reason = "секции темы с таким именем нет — молчаливое ничего"
			elif String(lit["type"]) != "" and name == String(lit["type"]):
				reason = "вариант равен типу узла %s — самоприсваивание, вид не меняется" % lit["type"]
			if reason == "":
				continue
			var allowed: Array = _DEAD_VARIATION_ASSIGNMENTS.get(path, [])
			if allowed.has(name):
				seen[path] = true
				continue
			offenders.append("%s: %s — %s" % [path, name, reason])
	assert_int(offenders.size()).is_equal(0) \
		.override_failure_message(
			"мёртвое присваивание варианта темы (узел не меняет вид, автор думает, что стилизовал):\n%s"
			% "\n".join(offenders))
	# Скан обязан быть живым в обе стороны: пустая область и протухший допуск.
	assert_bool(total >= 150).is_true() \
		.override_failure_message("скан присваиваний почти слеп: литералов %d" % total)
	for path in _DEAD_VARIATION_ASSIGNMENTS.keys():
		assert_bool(seen.has(path)).is_true() \
			.override_failure_message("допуск %s устарел: мёртвых присваиваний в нём нет" % path)

