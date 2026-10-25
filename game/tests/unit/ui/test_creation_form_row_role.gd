extends BaseTest

# theme-type-hygiene 6.4 (T-148), срез «носитель зазора формы» (D-253).
#
# Что здесь измерялось **до** правки (живой layout `character_creation.tscn`, 40 кадров,
# 1920×1080):
# * у семи строк формы `get_theme_constant("separation")` = 4 — это значение по умолчанию
#   `BoxContainer` в движке, в теме игры не было ни одной записи группы `constants`.
#   Канон — «зазор в строке 8» (§4 [[17-ui-style-guide]], он же `PAD_SM` из §1.3);
# * `Root` формы нёс сценевой `theme_override_constants/separation = 12` — число вне сетки
#   8 px (§1.3 «все размеры кратно 8») и тоже без носителя: обход темы текстом сцены.
#
# После: роли `FormRow` (BoxContainer, 8 = `PAD_SM`) и `FormStack` (VBoxContainer,
# 16 = `PAD`). 16, а не 8 и не 24: поля формы — не «строка» (канон 8) и не «секция»
# (24), а соседние элементы одной секции (`PAD` 16).
#
# Эрратум (важнее самого среза). Унаследованная формулировка T-185 — «фиксированная метка
# + expand поля, визуальный зазор метка↔поле гуляет 15…73 px» — кадром **не** подтвердилась.
# Метки стоят с `horizontal_alignment = 2` (RIGHT); в кадре
# `~/.local/share/sigil-reserve/formrow-t148/labels_zoom.png` двоеточия «Пол:», «Раса:»,
# «Подраса:», «Класс:», «Культура:», «Прошлое:» выстроены в одну вертикаль, зазор до поля
# одинаковый. Числа 15…73 px получены формулой `124 − (0 + ширина_текста)` — это остаток
# колонки **при левом** выравнивании, которого в сцене нет. Настоящий дефект: не гуляющий
# зазор, а отсутствие у зазора носителя и off-grid число.
#
# Гард сторожит: роли объявлены на реальных базовых типах; их числа равны токенам гайда;
# у `separation` есть читатель — это законный элемент контейнеров в фолбэк-теме движка
# (письмо без читателя, класс D-247); живые узлы резолвят ровно объявление роли, и геометрия
# показывает тот же зазор; в сцене не осталось сценевых `theme_override_constants`.
# Отрицательный контроль (кейс 8) отличает роль от темы: та же тема без роли резолвит
# дефолт движка.
#
# Особенность сборки 4.7, из-за которой объявление читается из текста ресурса:
# `Theme.get_constant(theme_type, name)` принимает **два** аргумента и не видит значений,
# записанных на вариант (замер: `has_constant("FormRow","separation") == false`,
# `get_constant("FormRow","separation") == 0` при живом `get_theme_constant() == 8`).
# Поэтому объявление берётся из `.tres`, резолв — с живого узла, а равенство проверяется
# попарно: «объявлено» без «прочитано движком» гард ловит так же хорошо, как наоборот.

const _SCENE_FILE := "res://scenes/ui/character_creation.tscn"
const _THEME := "res://assets/theme/game_theme.tres"

## Роль → [базовый тип, канонический зазор].
const _ROLES := {
	"FormRow": ["BoxContainer", 8],    # §1.3 PAD_SM, «зазор в строке 8» (§4)
	"FormStack": ["VBoxContainer", 16],  # §1.3 PAD — ритм полей одной секции
}

## Дефолт `separation` у контейнеров в движке — он и был зазором до появления ролей.
const _ENGINE_DEFAULT_GAP := 4

const _ROWS := [
	"NameRow", "SexRow", "RaceRow", "SubraceRow", "ClassRow", "CultureRow", "BackgroundRow",
]


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_that(file).is_not_null()
	var text := file.get_as_text()
	file.close()
	return text


func _theme() -> Theme:
	var theme: Theme = load(_THEME)
	assert_that(theme).is_not_null()
	return theme


## Объявление роли в ресурсе темы: `Role/constants/separation = N`.
func _declared_gap(role: String) -> int:
	var re := RegEx.create_from_string("(?m)^" + role + "/constants/separation = (\\d+)\\s*$")
	var found := re.search(_read(_THEME))
	assert_that(found).is_not_null()
	return int(found.get_string(1))


## Узел с ролью и без неё под одной и той же темой — пара «письмо/читатель».
func _carrier(base: String, role: String) -> BoxContainer:
	var node: BoxContainer = BoxContainer.new() if base == "BoxContainer" else (
		HBoxContainer.new() if base == "HBoxContainer" else VBoxContainer.new()
	)
	node.theme = _theme()
	if role != "":
		node.theme_type_variation = StringName(role)
	add_child(node)
	return node


func _scene() -> Node:
	return make_node(load(_SCENE_FILE))


func _root_of(scene: Node) -> Node:
	var root := scene.get_node_or_null("Overlay/Scroll/Root")
	assert_that(root).is_not_null()
	return root


## 1. Роли объявлены и наследуются от указанных базовых типов — иначе узел их не увидит
# и зазор останется движковским (прецедент CityPanel*: base_type обязан быть реальным
# носителем свойства). В 4.7 у Theme нет has_type(), вариации перечисляются по базе.
func test_roles_are_declared_on_real_base_types() -> void:
	var theme := _theme()
	for role: String in _ROLES:
		var base: String = _ROLES[role][0]
		assert_bool(theme.get_type_variation_list(base).has(StringName(role))).is_true().override_failure_message(
			"в теме нет роли %s на базовом типе %s" % [role, base]
		)
		assert_str(theme.get_type_variation_base(role)).is_equal(base)


## 2. Числа ролей — токены гайда, а не первые попавшиеся.
func test_role_gaps_match_canon_tokens() -> void:
	for role: String in _ROLES:
		var canon: int = _ROLES[role][1]
		assert_int(_declared_gap(role)).is_equal(canon)


## 3. У письма есть читатель: `separation` — законный элемент базового типа в фолбэк-теме
# движка. Если движок уберёт или переименует item, роли станут мёртвыми записями —
# гард краснеет здесь, а не в кадре (класс D-247).
func test_separation_item_exists_in_engine_theme() -> void:
	var fallback: Theme = ThemeDB.get_default_theme()
	assert_that(fallback).is_not_null()
	for role: String in _ROLES:
		var base: String = _ROLES[role][0]
		assert_bool(fallback.get_constant_list(base).has("separation")).is_true().override_failure_message(
			"в фолбэк-теме движка нет constants/separation у %s: роль %s пишет в никуда" % [base, role]
		)


## 4. Семь строк формы несут `FormRow`; `ButtonsRow` — нет: у ряда кнопок своя раскладка
# (центрирование), общий зазор формы им не назначен. `Root` несёт `FormStack`.
func test_nodes_carry_their_roles() -> void:
	var scene := _scene()
	var root := _root_of(scene)
	for name in _ROWS:
		var row := root.get_node_or_null(name) as HBoxContainer
		assert_that(row).is_not_null()
		assert_str(String(row.theme_type_variation)).is_equal("FormRow")
	var buttons := root.get_node_or_null("ButtonsRow") as HBoxContainer
	assert_that(buttons).is_not_null()
	assert_str(String(buttons.theme_type_variation)).is_not_equal("FormRow")
	assert_str(String((root as Control).theme_type_variation)).is_equal("FormStack")


## 5. Резолв живых узлов равен объявлению роли, и геометрия показывает тот же зазор:
# правый край коробки метки до левого края поля = 8 px для каждой из семи строк, вертикаль
# Root = 16 px. Проверка парная: число из темы без живого резолва — письмо в никуда,
# резолв без геометрии не доказывает, что раскладка его использовала.
func test_nodes_resolve_and_render_the_declared_gaps() -> void:
	var scene := _scene()
	for _i in 40:
		await get_tree().process_frame
	var root := _root_of(scene)
	var row_gap := _declared_gap("FormRow")
	var gaps: Dictionary = {}
	for name in _ROWS:
		var row := root.get_node_or_null(name) as HBoxContainer
		assert_int(row.get_theme_constant("separation")).is_equal(row_gap)
		var label := row.get_child(0) as Label
		var field := row.get_child(1) as Control
		assert_that(label).is_not_null()
		assert_that(field).is_not_null()
		var gap := int(field.position.x - (label.position.x + label.size.x))
		assert_int(gap).is_equal(row_gap)
		gaps[name] = gap
	# Ровность — то, ради чего роль введена: зазор не зависит от длины слова.
	var values := gaps.values()
	assert_int(values.max()).is_equal(values.min())
	assert_int(root.get_theme_constant("separation")).is_equal(_declared_gap("FormStack"))


## 6. Зазор между полями по вертикали соответствует объявлению `FormStack` и на живом
# кадре: соседние строки формы разделены ровно на 16 px.
func test_form_stack_gap_is_visible_in_layout() -> void:
	var scene := _scene()
	for _i in 40:
		await get_tree().process_frame
	var root := _root_of(scene)
	var stack_gap := _declared_gap("FormStack")
	var first := root.get_node_or_null("NameRow") as Control
	var second := root.get_node_or_null("SexRow") as Control
	assert_that(first).is_not_null()
	assert_that(second).is_not_null()
	var step := int(second.position.y - (first.position.y + first.size.y))
	assert_int(step).is_equal(stack_gap)


## 7. Отрицательный контроль: та же тема, но узел без роли резолвит дефолт движка.
# Кейс отличает роль от темы (и от `BoxContainer/constants/separation` в теме игры) —
# иначе «резолв = 8» ничего не доказывает.
func test_theme_without_role_keeps_engine_default() -> void:
	assert_int(_carrier("HBoxContainer", "").get_theme_constant("separation")).is_equal(_ENGINE_DEFAULT_GAP)
	assert_int(_carrier("VBoxContainer", "").get_theme_constant("separation")).is_equal(_ENGINE_DEFAULT_GAP)
	assert_int(_carrier("HBoxContainer", "FormRow").get_theme_constant("separation")).is_equal(_declared_gap("FormRow"))
	assert_int(_carrier("VBoxContainer", "FormStack").get_theme_constant("separation")).is_equal(_declared_gap("FormStack"))


## 8. Сценевых оверрайдов констант в файле нет: зазор обязан приходить из ролей,
# иначе оверрайд молча переопределит их при приёмке (у `Root` до правки лежал 12).
func test_scene_carries_no_constant_override() -> void:
	assert_int(_read(_SCENE_FILE).count("theme_override_constants/")).is_equal(0)
