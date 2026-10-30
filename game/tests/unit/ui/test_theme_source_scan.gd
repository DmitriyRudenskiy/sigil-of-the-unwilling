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

## Рантаймная закраска цвета вне модуля стиля (T-300): путь → число разрешённых мест.
## Считаются четыре механизма: `node.color =`, `node.modulate =`, `node.self_modulate =`
## и `add_theme_color_override(...)`; местом считается запись, цвет в которой не берётся
## из `ThemeConfig` (см. `_paint_is_off_style`). Допуск **двусторонний и по числу**: лишний
## литерал красит (мест больше), удалённый красит тоже (мест меньше) — список может только
## сокращаться, а «синхронизировать» его вверх нельзя.
## Почему числами, а не именами, как `_ALLOWED`: у stylebox-обхода имя аргумента уникально
## (`"focus"`), у цвета имени нет, а в одном экране один и тот же литерал встречается
## по три раза (`Color("#e0bd67")` в городе), и под каждую копию имя — это шум.
## Подсрез 2 (2026-10-30): шесть мест уехали в модуль стиля — медальон инициативы (2),
## иконки потребностей героя (2), тусклый шрифт неактивной кнопки меню (1), затемнение
## обучающей накладки (1); строки этих файлов из допуска сняты. Остались город (литералы
## подписей, подсрез «город») и панель решения (мёртвый класс, ждёт носитель по Q-M83).
const _COLOR_ALLOWED := {
	# Город перекрашивает подписи через локальную палитру экрана (`PALETTE`) и литералы,
	# а не через роли темы; 12 мест литералами, сведение на ThemeConfig — T-300.
	"res://scripts/ui/city_screen.gd": 12,
	# Панель решения (Q-M83: сцен `decision_panel.tscn` в репо нет, класс никем не
	# instantiated) — четыре канцелярских цвета движка на плашке серьёзности. Мигрировать
	# тон класса без носителя — рисовать пиксел, которого игрок не видит; переедет вместе
	# с носителем панели (T-132).
	"res://scripts/ui/decision_panel.gd": 4,
}

## Идентичные/альфные концы, а не стиль: `Color.WHITE` — «вернуть как есть»,
## `Color.TRANSPARENT` — «растворить», `Color(1, 1, 1, 1)` — то же самое записью.
## Все три — концы твинов и ветки условия «виден/затемнён», состояния они не выражают,
## поэтому из правила сняты (замер 2026-10-29: иначе правило красит
## `modulate = Color.WHITE if видим else <тон тумана>`, то есть верный код).
const _COLOR_IDENTITIES := ["Color.WHITE", "Color.TRANSPARENT"]
const _COLOR_IDENTITY_RE := "Color\\s*\\(\\s*1(?:\\.0+)?\\s*,\\s*1(?:\\.0+)?\\s*,\\s*1(?:\\.0+)?\\s*(,\\s*1(?:\\.0+)?\\s*)?\\)"

const _COLOR_ASSIGN_RE := "\\.(color|modulate|self_modulate)[ \\t]*=[ \\t]*"
const _COLOR_OVERRIDE_MARK := "add_theme_color_override"
const _COLOR_LITERAL_RE := "\\bColor[ \\t]*\\(|\\bColor\\.[A-Z]"
const _STRING_RE := '"[^"]*"'
const _CONST_DECL_RE := "^(const|var)[ \\t]+([A-Za-z_][A-Za-z0-9_]*)"

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


## Рантаймная закраска цвета (T-300). Три гарда темы смотрят на **стили**: stylebox
## переопределения, вариант темы, резолв носителя. Цвет, который код пишет прямо в узел
## (`cell.modulate = CELL_HOVER`, `label.add_theme_color_override("font_color", …)`,
## `rect.color = Color.GREEN`), ни в один из них не попадает: он не стиль, а свойство
## узла. Практический смысл — цвет состояния не меняется вместе с темой и не краснеет,
## когда экран переводят на роли темы; именно так и жил золотой подсвет клетки инвентаря
## (константа экрана `CELL_HOVER`, общий тон-канон не объявлен).
##
## Почему скан исходников, а не живого дерева: обход видит **значение** цвета, но не его
## источник, а дефект и есть источник — «взят не из модуля стиля». Значение из ThemeConfig
## и литерал неразличимы, пока не сравнили запись. Тот же выбор уже обоснован выше для
## stylebox-обхода (обход не отличает чужую вложенную сцену от своей).
##
## Что НЕ считается (зафиксировано, чтобы молчание было объяснимо, а не случайным):
##   1) цвета из данных: `_Enums.parse_color(...)`, `art.get_rarity_color()`, параметры
##      функций — источник не экран, а каталог/вызывающий код;
##   2) записи через строковое имя свойства (`tween_property(n, "modulate", …)`,
##      `set("color", …)`) — тот же класс, что `set("theme_override_" + x)` выше: текстовый
##      скан их не видит, их ловит рантайм-гард конкретного экрана;
##   3) сценевые `theme_override_colors/*` и `color = Color(...)` в .tscn — это механизм 2
##      темы, он объят правилом T-147 по stylebox, а по цветам — вне объёма T-300;
##   4) многострочное объявление константы (`const PALETTE := {` и `Color(...)` на
##      следующих строках): разбор разворачивает идентификатор по **своей** строке, видит
##      `{` и считает место стилевым. Практический смысл — локальный словарь тонов
##      (`PALETTE.text_muted` в городе) laundering'ом проходит гард. Сводится на нет не
##      регуляркой, а переносом палитры в модуль стиля (T-300, подсрез «город»).
func test_runtime_color_paint_comes_from_style_module() -> void:
	var offenders := PackedStringArray()
	var seen := {}
	var sites := 0
	for path in _files(".gd"):
		var paints: Dictionary = _paint_sites(path)
		var off: Array[String] = paints["off"]
		sites += (paints["all"] as Array).size()
		if off.is_empty():
			continue
		seen[path] = off.size()
		var allowed: int = int(_COLOR_ALLOWED.get(path, 0))
		if off.size() != allowed:
			offenders.append("%s: закрашиваний вне модуля стиля %d, допущено %d\n    %s" % [
				path, off.size(), allowed, "\n    ".join(off)])
	assert_int(offenders.size()).is_equal(0) \
		.override_failure_message(
			"цвет состояния закрашен в узел мимо модуля стиля (ThemeConfig): он не меняется "
			+ "с темой и не покрывается ни одним гардом темы (T-300). Перенеси тон в ThemeConfig "
			+ "или уменьши допуск, если тон удалён:\n%s" % "\n".join(offenders))
	# Две опоры живости: слепой скан и мёртвый допуск. Порог считается по **всем** местам
	# закраски (замер 2026-10-30 — 69), а не по нарушениям: сведение допуска — цель тикета,
	# и гард, краснеющий от собственных успехов, рано или поздно «починили» бы понижением
	# порога. Слепому скану всё равно, сколько дыр, — ему бы перестать видеть места.
	assert_bool(sites >= 40).is_true() \
		.override_failure_message(
			"скан закраски цвета почти слеп: мест закраски %d (замер 2026-10-30 — 69)" % sites)
	for path in _COLOR_ALLOWED.keys():
		assert_bool(seen.has(path)).is_true() \
			.override_failure_message(
				"в допуске числится %s, а закрашиваний вне модуля стиля в нём нет — строка устарела" % path)


## Места, где в узел пишется цвет, и пометка «вне модуля стиля» для каждого:
## `{"all": [«NN: строка»], "off": [«NN: строка»]}`. «all» нужен проверке живости — она
## меряет не дыры, а площадь скана.
func _paint_sites(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var consts := _color_consts(text)
	var re := RegEx.create_from_string(_COLOR_ASSIGN_RE)
	var lit := RegEx.create_from_string(_COLOR_LITERAL_RE)
	var lines := text.split("\n")
	var all: Array[String] = []
	var off: Array[String] = []
	for i in lines.size():
		var stripped: String = String(lines[i]).strip_edges()
		if stripped.begins_with("#"):
			continue
		var rhs := ""
		var m := re.search(stripped)
		if m != null:
			rhs = stripped.substr(m.get_end(0))
			# `==` (сравнение) — не закраска; `.color =` внутри объявления тоже не встречается.
			if rhs.strip_edges().begins_with("="):
				continue
		elif stripped.contains(_COLOR_OVERRIDE_MARK):
			rhs = stripped.substr(
				stripped.find(_COLOR_OVERRIDE_MARK) + _COLOR_OVERRIDE_MARK.length())
		else:
			continue
		# многострочный вызов: тянем следующие строки, пока скобки не сошлись
		var j := i
		# многострочность бывает двумя способами: незакрытая скобка и перенос обратным
		# слэшем (`cell.modulate = CELL_EMPTY if свободна else …` — две строки, скобок нет)
		while (rhs.count("(") > rhs.count(")") or rhs.strip_edges().ends_with("\\")) \
				and j + 1 < lines.size():
			j += 1
			rhs += " " + String(lines[j]).strip_edges()
		all.append("%d: %s" % [i + 1, stripped])
		if _paint_is_off_style(rhs, consts, lit):
			off.append("%d: %s" % [i + 1, stripped])
	return {"all": all, "off": off}


## Цветовые константы файла: имя → правая часть объявления. Нужны потому, что состояние
## чаще всего красят именно ими (`cell.modulate = CELL_HOVER`), и источник цвета живёт
## на строку объявления, а не на строку записи.
func _color_consts(text: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string(_CONST_DECL_RE)
	for raw in text.split("\n"):
		var stripped: String = String(raw).strip_edges()
		if stripped.begins_with("#"):
			continue
		var m := re.search(stripped)
		if m == null:
			continue
		var eq := stripped.find("=")
		if eq < 0:
			continue
		out[String(m.get_string(2))] = stripped.substr(eq + 1)
	return out


## «Вне модуля стиля» = в выражении есть цвет движка/литерал, и ни одного источника стиля
## (`ThemeConfig`, `get_theme_color`, `GameNumbers` — тон тумана войны). Одиночный
## идентификатор разворачивается в объявление файла и классифицируется по нему; если
## объявления нет (параметр функции, поле, вызов из данных) — место вне правила.
func _paint_is_off_style(rhs: String, consts: Dictionary, lit: RegEx) -> bool:
	var expr := _strip_identity_colors(rhs)
	if _expr_is_styled(expr):
		return false
	if lit.search(_without_strings(expr)) != null:
		return true
	# Состояния красят константами экрана: в строке записи цвета нет
	# (`cell.modulate = CELL_EMPTY if свободна else (CELL_HOVER …)`), источник живёт на
	# строке объявления. Разворачиваем каждый идентификатор выражения в объявление файла
	# (вложенность — один уровень, глубже в репо не встречается).
	for m in RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*").search_all(_without_strings(expr)):
		var tok := String(m.get_string(0))
		if not consts.has(tok):
			continue
		var src := _strip_identity_colors(String(consts[tok]))
		if _expr_is_styled(src):
			continue
		if lit.search(src) != null:
			return true
	return false


## Снятие идентичных тонов («вернуть как есть», «растворить») из выражения — и запись
## `Color(1, 1, 1, 1)`, и `Color(1.0, 1.0, 1.0, 1.0)`, и именованные концы твинов.
func _strip_identity_colors(expr: String) -> String:
	var out := expr
	for identity in _COLOR_IDENTITIES:
		out = out.replace(identity, "")
	return RegEx.create_from_string(_COLOR_IDENTITY_RE).sub(out, "", true)

## Строковые литералы из выражения вынимаются: `add_theme_color_override("font_color", X)`
## и `d.get("color", …)` не источники цвета, а без съёма их слова попадают в разбор
## идентификаторов и рождают ложные находки (замер: `s.color = _CE.parse_color(d.get(
## "color", …))` резолвил токен `color` в `var color = _CE.SpellColor.COLORLESS`).
func _without_strings(expr: String) -> String:
	return RegEx.create_from_string(_STRING_RE).sub(expr, " ", true)


## Источник стиля в выражении: модуль стиля `ThemeConfig` или чтение темы. Третий гость
## — `GameNumbers`: тон тумана войны исторически объявлен в числовом модуле
## (`MAP_FOG_MODULATE`), и два спавнера читают именно его; перенос тона в модуль стиля —
## шаг T-300, до него выражение считается стилевым, иначе гард красит не дыру, а перенос.
func _expr_is_styled(expr: String) -> bool:
	return expr.contains("ThemeConfig") or expr.contains("get_theme_color") \
			or expr.contains("GameNumbers")

