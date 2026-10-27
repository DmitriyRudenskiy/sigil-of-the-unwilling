extends BaseTest

## Матрица вариантов темы (T-227 С-2).
##
## Семья `test_*_theme_carrier.gd` носила три разных проверки, и две из них были
## рукописными копиями одного и того же утверждения: «вариант заявлен и применяется»
## и «несуществующий тип не резолвит» (11 почти одинаковых тестов, по одному на экран).
## Здесь обе сформулированы от НОСИТЕЛЯ: список вариантов читается из самой темы, и
## проверка покрывает все 70 вариантов, а не те три экрана, которым когда-то завели файл.
## Новый экран или новый вариант темы получает проверку бесплатно — это и есть цель С-2
## («тест на новый экран = ноль новых тестов»).
##
## Что НЕ переезжает: «тема отдаёт ровно те значения, что рисовал снятый override» (AC2) —
## контракт конкретного переноса, числа берутся из истории снятия, а не из темы. Он живёт
## в файле экрана (остаток С-2б в T-227).
##
## Разбор .tres (формат Theme, Godot 4.7): секция вида `Имя/styles/панель = ...` — это и
## нативный тип (`Panel`, `Button`), и вариант. Вариант дополнительно объявляет
## `Имя/base_type = "Тип"`; без него тема секцию держит, но движок вариантом её не считает.

const _THEME := preload("res://assets/theme/game_theme.tres")
const _THEME_PATH := "res://assets/theme/game_theme.tres"

## Секции темы без `base_type` и не являющиеся движковым типом. Тема их держит,
## `get_stylebox(style, секция)` работает, но `theme_type_variation` на узле их не
## подхватывает — то есть присвоить такую секцию варианту = молчаливое ничего.
## `TooltipPanel` используется именно так (kitchen_sink.gd:237) — зафиксировано как дыра,
## а не как норма: чинится регистрацией base_type, см. T-228.
const _ORPHAN_SECTIONS_USED := {
	"TooltipPanel": "T-228 (витрина присваивает не-вариант; носителя подсказки нет)",
}

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _bases() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^([A-Za-z0-9_]+)/base_type = \"([A-Za-z0-9_]+)\"$")
	for m in re.search_all(FileAccess.get_file_as_string(_THEME_PATH)):
		out[m.get_string(1)] = m.get_string(2)
	return out


func _styles() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^([A-Za-z0-9_]+)/styles/([A-Za-z0-9_]+) = ")
	for m in re.search_all(FileAccess.get_file_as_string(_THEME_PATH)):
		var name := m.get_string(1)
		if not out.has(name):
			out[name] = []
		out[name].append(m.get_string(2))
	return out


func _node(base_type: String, variation: String) -> Control:
	assert_bool(ClassDB.class_exists(base_type)).is_true() \
		.override_failure_message("тема объявляет базовый тип %s, которого нет в ClassDB" % base_type)
	assert_bool(ClassDB.is_parent_class(base_type, "Control")).is_true() \
		.override_failure_message("вариант %s объявлен на %s — не Control" % [variation, base_type])
	var node := ClassDB.instantiate(base_type) as Control
	assert_object(node).is_not_null() \
		.override_failure_message("не инстанцируется %s (секция %s)" % [base_type, variation])
	_nodes.append(node)
	node.theme = _THEME
	if variation != "":
		node.theme_type_variation = StringName(variation)
	get_tree().root.add_child(node)
	return node


func _same(a: StyleBox, b: StyleBox) -> bool:
	return a != null and b != null and a.get_instance_id() == b.get_instance_id()


## Секции темы обязаны быть чем-то: нативным типом, вариантом с base_type или
## задокументированной сиротой. Плюс base_type из .tres обязан совпадать с тем, что
## держит движок (расхождение = вариант зарегистрирован на другой тип, и экраны,
## надеющие его, получают дефолт).
func test_theme_sections_are_types_or_variations() -> void:
	var bases := _bases()
	var styles := _styles()
	assert_bool(bases.size() > 40).is_true() \
		.override_failure_message("вариантов найдено %d — разбор .tres сломался" % bases.size())
	var bad := PackedStringArray()
	var orphans := PackedStringArray()
	for name in bases.keys():
		var base_type: String = bases[name]
		if not ClassDB.class_exists(base_type):
			bad.append("%s: базовый тип %s не существует" % [name, base_type])
			continue
		if not ClassDB.is_parent_class(base_type, "Control"):
			bad.append("%s: базовый тип %s не Control" % [name, base_type])
			continue
		var declared := String(_THEME.get_type_variation_base(StringName(name)))
		if declared != base_type:
			bad.append("%s: движок говорит base_type=%s, .tres — %s" % [name, declared, base_type])
		var registered := false
		for t in _THEME.get_type_variation_list(StringName(base_type)):
			if String(t) == name:
				registered = true
		if not registered:
			bad.append("%s: не зарегистрирован в get_type_variation_list(%s)" % [name, base_type])
	for name in styles.keys():
		if not bases.has(name) and not ClassDB.class_exists(name):
			orphans.append(name)
	var offenders := PackedStringArray()
	for name in orphans:
		if not _ORPHAN_SECTIONS_USED.has(name):
			offenders.append("секция %s: ни нативный тип, ни вариант (base_type не объявлен)" % name)
	for entry in _ORPHAN_SECTIONS_USED.keys():
		if not orphans.has(entry):
			offenders.append("допуск %s устарел: секция больше не сирота" % entry)
	assert_int(bad.size() + offenders.size()).is_equal(0) \
		.override_failure_message("секции темы расходятся с движком:\n%s"
			% "\n".join(bad) + "\n" + "\n".join(offenders))


## Позитивный контракт по всем вариантам: каждый объявленный stylebox резолвится на
## свежем узле своего базового типа (та же проверка, что была рукописной в гардах
## армии/миникарты/столицы, но от носителя).
func test_every_variation_style_resolves_on_its_base_type() -> void:
	var styles := _styles()
	var bases := _bases()
	var dead := PackedStringArray()
	var checked := 0
	for name in styles.keys():
		if not bases.has(name):
			continue
		for style in styles[name]:
			var node := _node(bases[name], name)
			if not ThemeCarrierGuard.resolves_carrier(node, _THEME, style, name):
				dead.append("%s/%s: узел %s не резолвит носителя" % [name, style, bases[name]])
			checked += 1
	assert_int(dead.size()).is_equal(0) \
		.override_failure_message("не резолвится %d пар вариант/стиль:\n%s"
			% [dead.size(), "\n".join(dead)])
	# Меньше — значит разбор .tres потерял секции и контракт молчит.
	assert_bool(checked >= 60).is_true() \
		.override_failure_message("позитивный контракт почти пуст: пар %d (в теме 71)" % checked)


## Негативный контроль вместо одиннадцати рукописных копий — с поправкой, которую
## рукописные копии не видели: если вариант держит ТОТ ЖЕ ресурс, что и базовый тип
## (`MenuPlate/focus`, `ProgressBarMana/background`), незарегистрированное имя резолвит
## его законно, и проверка на такой паре пуста. Строка с null-базой не считается.
func test_unregistered_variation_does_not_resolve_when_it_can() -> void:
	var styles := _styles()
	var bases := _bases()
	var lying := PackedStringArray()
	var meaningful := 0
	var vacuous := 0
	for name in styles.keys():
		if not bases.has(name):
			continue
		var style: String = styles[name][0]
		var node := _node(bases[name], "")
		var declared: StyleBox = _THEME.get_stylebox(style, name)
		# Пустая строка: у базового типа тот же ресурс, что и у варианта, — любое
		# неизвестное имя резолвит его законно, и проверка на такой паре ничего не ловит.
		if _same(node.get_theme_stylebox(style), declared):
			vacuous += 1
			continue
		node.theme_type_variation = StringName(name + "Missing")
		var as_missing: StyleBox = node.get_theme_stylebox(style)
		meaningful += 1
		if _same(as_missing, declared):
			lying.append("%sMissing резолвит %s" % [name, style])
	assert_int(lying.size()).is_equal(0) \
		.override_failure_message("несуществующие типы резолвят носителей:\n%s" % "\n".join(lying))
	assert_bool(meaningful >= 30).is_true() \
		.override_failure_message("негативный контроль почти пуст: значимых строк %d" % meaningful)
	print("Тема: значимых негативных строк %d, пустых (ресурс общий с базовым типом) %d"
		% [meaningful, vacuous])
