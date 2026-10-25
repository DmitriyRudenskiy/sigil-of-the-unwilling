extends BaseTest

# Тикет T-191, решение D-247 — «писатели без читателя» в theme_override_*.
#
# Гард механический, а не глазомерный: для каждой строки `theme_override_<группа>/<item>`
# в любом `.tscn` под `res://scenes/` проверяются два факта — оба правда движка, а не
# список, который кто-то вёл руками:
#
#   1. группа обязана существовать: `colors`, `constants`, `fonts`, `font_sizes`, `styles`.
#      Опечатка в группе не ошибка загрузки — Godot молча игнорирует неизвестную группу,
#      и узел рисуется дефолтом темы. Так три заголовка `artifact_chest_dialog` писали
#      `theme_override_font_size/font_size = 22` (правильно `font_sizes`) и жили на 16.
#   2. item обязана читать сама нода: имя ищется в fallback-теме движка
#      (`ThemeDB.get_default_theme()`) по всей цепочке базовых классов. Если его нет нигде
#      в цепочке — рисующий код за именем не обращается, объявление мертво. Так три
#      заголовка главного меню держали `constants/letter_spacing` (у `Label` в Godot 4 нет
#      такой константы: трекинг живёт в `FontFile`/`LabelSettings`), а `CenterContainer`
#      держал `constants/separation` (это константа BoxContainer, не CenterContainer).
#
# Разновидность типа (`theme_type_variation`) проверке не мешает: вариация наследует
# базовый нативный тип, а значит и набор читаемых им имён. Обратная сторона — если в
# проектную тему когда-нибудь заведут тип, не выведенный от нативного класса (со своими
# именами items), гард об этом спросит отдельным кейсом, а не промолчит.
#
# Чего гард НЕ утверждает: что значение хорошее, что носитель подобан по гайду и что
# локальный обход вообще уместен — это ось кегля и палитры (UI-AC7, Q-M96), а не ось
# «есть ли у объявления читатель».

const _SCENES_ROOT := "res://scenes"
## Группа в .tscn → метод fallback-темы, перечисляющий items этого вида у типа.
# Именно перечисляющий, а не `has_*`: у fallback-темы `has_color("Label", "font_color")`
# отвечает false (значения по умолчанию лежат не в записях темы), а `get_color_list`
# отдаёт настоящий набор, которым движок и рисует. Проверено на живом движке 4.7.
const _LISTS := {
	"colors": "get_color_list",
	"constants": "get_constant_list",
	"fonts": "get_font_list",
	"font_sizes": "get_font_size_list",
	"styles": "get_stylebox_list",
}
## Сколько объявлений гард обязан увидеть, чтобы «ноль нарушений» не оказались нулём
## просмотренных строк. Замер 2026-10-25: 272 theme_override_* (после снятия семи мёртвых)
## + 104 theme_type_variation = 376.
const _MIN_SCANNED := 350

var _re_ext_scene_a := RegEx.create_from_string(
	"\\[ext_resource type=\"PackedScene\"[^\\]]*path=\"([^\"]+)\"[^\\]]*id=\"([^\"]+)\"")
var _re_ext_scene_b := RegEx.create_from_string(
	"\\[ext_resource type=\"PackedScene\"[^\\]]*id=\"([^\"]+)\"[^\\]]*path=\"([^\"]+)\"")
var _re_node_type := RegEx.create_from_string("\\[node name=\"[^\"]*\" type=\"([^\"]+)\"")
var _re_node_instance := RegEx.create_from_string(
	"\\[node name=\"[^\"]*\"[^\\]]*instance=ExtResource\\(\"([^\"]+)\"\\)")
var _re_override := RegEx.create_from_string("theme_override_(\\w+)/(\\w+) = (\\S+)")
var _theme_types := {}
var _re_role := RegEx.create_from_string("theme_type_variation = &\"([^\"]*)\"")


# ── разбора ────────────────────────────────────────────────────────────────

## Тип корня инстансированной сцены: PackedScene читается без instantiate.
func _instance_root_type(path: String, depth := 0) -> String:
	if depth > 6 or path == "" or not ResourceLoader.exists(path):
		return ""
	var ps: PackedScene = load(path) as PackedScene
	if ps == null or ps.get_state() == null:
		return ""
	var t := String(ps.get_state().get_node_type(0))
	if t != "":
		return t
	var nested: PackedScene = ps.get_state().get_node_instance(0) as PackedScene
	if nested == null:
		return ""
	return _instance_root_type(String(nested.resource_path), depth + 1)


## Читает ли класс (или любой его базовый класс) theme-item `item` вида `group`.
func _class_reads(cls: String, group: String, item: String) -> bool:
	var fallback: Theme = ThemeDB.get_default_theme()
	var lister: String = String(_LISTS[group])
	var c := cls
	while c != "" and c != "Object":
		if PackedStringArray(fallback.call(lister, c)).has(item):
			return true
		c = String(ClassDB.get_parent_class(StringName(c)))
	return false


## Разбирает текст сцены. Возвращает [seen, violations]:
## seen — сколько строк theme_override_* просмотрено,
## violations — человекочитаемые описания строк без читателя.
func _scan(text: String, resolve_instance: Callable) -> Array:
	var seen := 0
	var bad: Array = []
	var node_type := ""
	var ext_scenes := {}
	for ln in text.split("\n"):
		var m := _re_ext_scene_a.search(ln)
		if m != null:
			ext_scenes[m.get_string(2)] = m.get_string(1)
			continue
		m = _re_ext_scene_b.search(ln)
		if m != null:
			ext_scenes[m.get_string(1)] = m.get_string(2)
			continue
		m = _re_node_type.search(ln)
		if m != null:
			node_type = m.get_string(1)
			continue
		m = _re_node_instance.search(ln)
		if m != null:
			var target := String(ext_scenes.get(m.get_string(1), ""))
			node_type = resolve_instance.call(target) if target != "" else ""
			continue
		if ln.begins_with("[node "):
			node_type = ""  # у узла без type= и без instance= тип гарду неизвестен
			continue
		var role := _re_role.search(ln)
		if role != null:
			seen += 1
			var role_name := role.get_string(1)
			if role_name != "" and not _role_exists(role_name):
				bad.append("узел %s: роль \"%s\" не объявлена ни в теме проекта, ни среди типов движка"
					% [node_type, role_name])
			continue
		m = _re_override.search(ln)
		if m == null:
			continue
		seen += 1
		var group := m.get_string(1)
		var item := m.get_string(2)
		if not _LISTS.has(group):
			bad.append("группа \"%s\" не существует (узел типа %s) — движок игнорирует строку"
				% [group, node_type])
			continue
		if node_type == "":
			continue  # тип неизвестен (инстанс вне резолвера) — вердикт не выдумываем
		if not _class_reads(node_type, group, item):
			bad.append("%s не читает \"%s/%s\"" % [node_type, group, item])
	return [seen, bad]


## Читателем роли (theme_type_variation) является список типов темы: несуществующее имя
# движок не считает ошибкой — узел просто остаётся на базовом типе, то есть опечатка в
# роли молча откатывает текст на 16 px и на шрифт без гарнитуры (тот же класс дефекта,
# что и `LabelCode` из T-190: роль «назначена», кегль «не поменялся», виноватой выглядит тема).
func _role_exists(role_name: String) -> bool:
	if _theme_types.is_empty():
		var theme: Theme = load("res://assets/theme/game_theme.tres") as Theme
		for t in theme.get_type_list():
			_theme_types[String(t)] = true
	if _theme_types.has(role_name):
		return true
	return ClassDB.class_exists(StringName(role_name))


func _all_scenes(dir_path: String, acc: Array) -> Array:
	var d := DirAccess.open(dir_path)
	if d == null:
		return acc
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_all_scenes(dir_path.path_join(f), acc)
		elif f.ends_with(".tscn"):
			acc.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	return acc


# ── кейсы ──────────────────────────────────────────────────────────────────

## 1. Живой каталог сцен: ни одного theme_override_* без читателя.
func test_no_scene_declares_an_unread_theme_item() -> void:
	var seen_total := 0
	var report: Array = []
	for path in _all_scenes(_SCENES_ROOT, []):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var res: Array = _scan(f.get_as_text(), _instance_root_type)
		seen_total += int(res[0])
		for v in res[1]:
			report.append("%s: %s" % [path, v])
	assert_int(seen_total).override_failure_message(
		"гард просмотрел слишком мало объявлений — сломан разбор, а не сцены"
		).is_greater_equal(_MIN_SCANNED)
	assert_str("\n".join(PackedStringArray(report))).override_failure_message(
		"theme_override_* без читателя (%d)" % report.size()).is_empty()


## 2. Отрицательный контроль: гард находит все четыре способа испортить объявление —
# несуществующая группа, несуществующий item в живой группе, константа не того контейнера
# и роль, которой нет ни в теме, ни среди типов движка. Без этого кейса «зелёный гард» не
# значит ничего: он мог зеленеть потому, что вообще ничего не разбирает (так и было на
# этапе, когда проверка роли стояла ниже continue и была недостижима).
func test_guard_catches_planted_dead_overrides() -> void:
	var text := "\n".join(PackedStringArray([
		"[node name=\"Ok\" type=\"Label\"]",
		"theme_override_font_sizes/font_size = 20",
		"[node name=\"Dead\" type=\"Label\"]",
		"theme_override_constants/letter_spacing = 4",
		"[node name=\"Typo\" type=\"Label\"]",
		"theme_override_font_size/font_size = 22",
		"[node name=\"Box\" type=\"CenterContainer\"]",
		"theme_override_constants/separation = 8",
		"[node name=\"Role\" type=\"Label\"]",
		"theme_type_variation = &\"LabelSecundary\"",
	]))
	var res: Array = _scan(text, _instance_root_type)
	assert_int(int(res[0])).is_equal(5)
	var bad: Array = res[1]
	assert_int(bad.size()).override_failure_message(
		"посаженные мёртвые объявления не найдены: %s" % str(bad)).is_equal(4)
	var joined := " | ".join(PackedStringArray(bad))
	assert_str(joined).contains("letter_spacing")
	assert_str(joined).contains("группа \"font_size\"")
	assert_str(joined).contains("CenterContainer не читает")
	assert_str(joined).contains("LabelSecundary")


## 3. Резолвер инстансов тоже обязан быть проверен: иначе «тип неизвестен» превращается
# в тихое «типа не знаем — пропускаем». Узел, собранный из чужой сцены, гарду
# должен быть виден со своим типом.
func test_instance_root_type_resolves_nested_scenes() -> void:
	# main_menu инстансит artifact_inventory_screen: у того корень — Control-скрипт на
	# нативном типе, то есть тип обязан быть непустым.
	var t := _instance_root_type("res://scenes/ui/artifact_inventory_screen.tscn")
	assert_str(t).override_failure_message(
		"не резолвится тип корня инстансированной сцены").is_not_empty()
	assert_str(_instance_root_type("res://scenes/main_menu.tscn")).is_not_empty()


## 4. Собственные (не нативные и не вариационные) типы тема всё-таки держит — `TooltipPanel`
# и `TooltipLabel`. Это не поломка, а условие, которое надо знать: items из такого типа
# читает нативный код узла, поэтому проверка цепочки классов остаётся верной, а вот
# «тип темы == нативный класс» — ложь. Кейс фиксирует факт, чтобы следующий, кто решит
# «упростить» гард до `ClassDB.class_exists(тип_темы)`, получил красный.
func test_theme_has_custom_types_beyond_native_classes() -> void:
	var theme: Theme = load("res://assets/theme/game_theme.tres") as Theme
	var custom: Array = []
	for t in theme.get_type_list():
		var name := String(t)
		var base := String(theme.get_type_variation_base(name))
		if ClassDB.class_exists(StringName(name)):
			continue
		if base != "" and base != name and ClassDB.class_exists(StringName(base)):
			continue
		custom.append(name)
	assert_int(custom.size()).override_failure_message(
		"собственные типы темы исчезли — гард можно упрощать, но тогда и этот кейс"
		).is_greater_equal(1)
	assert_str(", ".join(PackedStringArray(custom))).contains("TooltipLabel")
