extends BaseTest

# theme-type-hygiene 6.5 (T-148.5), срез «титул главного меню в носителе» (D-258).
#
# Что было. Три строки названия игры держали всё оформление сценевыми оверрайдами:
# `theme_override_fonts/font = ExtResource("6")` (PT_Serif-Bold), кегли 206/41/123 и
# смещения тени 6/3/4. Это единственные три `theme_override_fonts` во всех сценах репо
# (инвентарь 6.5: «3, все — main_menu») и три из четырёх оставшихся групп носителя.
#
# Почему ролей три, а не одна. Вариация темы не наследуется от другой вариации
# (`base_type` указывает только на встроенный тип), а кегль — часть вариации. Значит,
# «одна роль на титул» физически покрывает один кегль; остальные два остались бы
# оверрайдами и роль стала бы декорацией. Роли: `TitleMain` (206), `TitleLink` (41),
# `TitleWord` (123); шрифт и смещение тени — в объявлении.
#
# Что осталось в сцене сознательно. `font_color` (0.902, 0.812, 0.604) и
# `font_shadow_color` (0,0,0,0.85): палитра — вопрос владельца (**Q-M96**), и перенос
# цвета в носитель — это уже решение о цвете, а не о месте хранения. Гард проверяет,
# что цвета по-прежнему на узлах: если кто-то «заодно» перенесёт их в тему, кейс 6
# краснеет и вопрос вернётся владельцу.
#
# Про нулевую визуальную дельту. Срез — рефакторинг в носитель, он не имеет права
# менять картинку: ux-review = кадры 1920×1080 до и после, побайтовое совпадение
# (`docs/mvp/TICKETS.md` T-148, D-258).
#
# Особенность 4.7 (та же, что в test_creation_form_row_role.gd): `Theme.get_constant`
# принимает два аргумента и не видит значений, записанных на вариант, поэтому объявление
# читается из текста `.tres`, а резолв — с живого узла; равенство проверяется попарно.

const _SCENE_FILE := "res://scenes/main_menu.tscn"
const _THEME := "res://assets/theme/game_theme.tres"
const _TITLE_FONT := "res://assets/fonts/PT_Serif-Bold.ttf"

## Роль → [узел сцены, кегль, смещение тени X, смещение тени Y].
const _ROLES := {
	"TitleMain": ["TitleLine1", 206, 6, 6],
	"TitleLink": ["TitleLine2", 41, 3, 3],
	"TitleWord": ["TitleLine3", 123, 4, 4],
}

## Дефолт кегля `Label` в движке — с ним сравнивается отрицательный контроль.
const _ENGINE_FONT_SIZE := 16


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


func _declared(role: String, group: String, item: String, default := "") -> String:
	var re := RegEx.create_from_string("(?m)^%s/%s/%s = (.+)$" % [role, group, item])
	var found := re.search(_read(_THEME))
	if found == null:
		return default
	return found.get_string(1).strip_edges()


func _declared_int(role: String, group: String, item: String) -> int:
	var raw := _declared(role, group, item)
	assert_str(raw).is_not_equal("")
	return int(raw)


## 1. Роли объявлены на реальном базовом типе `Label` — без `base_type` движок вариацию
# не резолвит (прецедент CityPanel*), а сцена получит дефолты.
func test_title_roles_are_declared_on_label() -> void:
	var theme := _theme()
	var list := theme.get_type_variation_list("Label")
	for role: String in _ROLES:
		assert_bool(list.has(StringName(role))).is_true().override_failure_message(
			"в теме нет роли %s на базовом типе Label" % role
		)
		assert_str(theme.get_type_variation_base(role)).is_equal("Label")


## 2. Объявленные значения = измеренные: шрифт титула, кегли 206/41/123, тень 6/3/4.
func test_declared_values_match_the_measured_title() -> void:
	for role: String in _ROLES:
		var spec: Array = _ROLES[role]
		assert_int(_declared_int(role, "font_sizes", "font_size")).is_equal(int(spec[1]))
		assert_int(_declared_int(role, "constants", "shadow_offset_x")).is_equal(int(spec[2]))
		assert_int(_declared_int(role, "constants", "shadow_offset_y")).is_equal(int(spec[3]))
		# Шрифт в .tres — ссылка на ext_resource **темы** (не сцены): резолвится она на
		# этапе загрузки ресурса, поэтому сверяется заголовок темы, а живую проверку делает
		# кейс 4.
		var font_ref := _declared(role, "fonts", "font")
		assert_str(font_ref).is_not_empty()  # у роли обязан быть шрифт, иначе титул пишется дефолтом
		if font_ref == "":
			continue  # иначе разбор ссылки падает и маскирует единственный нужный вердикт
		var id := RegEx.create_from_string('ExtResource\\("([^"]+)"\\)').search(font_ref)
		assert_that(id).is_not_null()
		var line := RegEx.create_from_string('(?m)^\\[ext_resource type="FontFile"[^\n]*id="%s"\\]$' % id.get_string(1))
		var found := line.search(_read(_THEME))
		assert_that(found).is_not_null()
		var path := RegEx.create_from_string('path="([^"]+)"').search(found.get_string(0))
		assert_that(path).is_not_null()
		assert_str(path.get_string(1)).is_equal(_TITLE_FONT)


## 3. У письма есть читатель: `font`, `font_size`, `shadow_offset_x/y` — законные элементы
# `Label` в фолбэк-теме движка, иначе роли пишут в никуда (класс D-247).
func test_title_items_exist_in_engine_theme() -> void:
	var fallback: Theme = ThemeDB.get_default_theme()
	assert_that(fallback).is_not_null()
	assert_bool(fallback.get_font_list("Label").has("font")).is_true()
	assert_bool(fallback.get_font_size_list("Label").has("font_size")).is_true()
	for item in ["shadow_offset_x", "shadow_offset_y"]:
		assert_bool(fallback.get_constant_list("Label").has(item)).is_true().override_failure_message(
			"у Label в движке нет константы %s: роль титула пишет в никуда" % item
		)


## 4. Живой кадр: три узла несут свои роли и резолвят объявленные значения. Оверрайдов
# шрифта/кегля/тени на узлах нет — иначе носитель молча перекрывается сценой.
func test_title_nodes_resolve_their_roles() -> void:
	var menu := make_node(load(_SCENE_FILE))
	for _i in 20:
		await get_tree().process_frame
	for role: String in _ROLES:
		var spec: Array = _ROLES[role]
		var label := menu.get_node_or_null(NodePath(spec[0])) as Label
		assert_that(label).is_not_null()
		assert_str(String(label.theme_type_variation)).is_equal(role)
		assert_int(label.get_theme_font_size("font_size")).is_equal(int(spec[1]))
		assert_int(label.get_theme_constant("shadow_offset_x")).is_equal(int(spec[2]))
		assert_int(label.get_theme_constant("shadow_offset_y")).is_equal(int(spec[3]))
		var font: Font = label.get_theme_font("font")
		assert_that(font).is_not_null()
		assert_str(font.resource_path).is_equal(_TITLE_FONT)
		# «Оверрайда нет» доказывается обращением к самому оверрайду, а не `has_theme_*`:
		# в 4.7 has_theme_font/has_theme_constant резолвят значение по цепочке (базовый тип
		# + вариация + тема) и возвращают true и без сценевого переопределения — проверка
		# на них была бы пустой (замер: has_theme_font == true при снятом оверрайде).
		assert_that(label.get("theme_override_fonts/font")).is_null().override_failure_message(
			"на %s вернулся сценевой theme_override_fonts: роль %s перекрыта" % [spec[0], role]
		)
		assert_that(label.get("theme_override_font_sizes/font_size")).is_null()
		assert_that(label.get("theme_override_constants/shadow_offset_x")).is_null()
		assert_that(label.get("theme_override_constants/shadow_offset_y")).is_null()


## 5. Отрицательный контроль: та же тема, но `Label` без роли резолвит дефолт движка —
# иначе «кегель 206» ничего не доказывает (роль могла бы не отличать себя от темы).
func test_label_without_role_keeps_engine_defaults() -> void:
	var bare := Label.new()
	bare.theme = _theme()
	add_child(bare)
	assert_int(bare.get_theme_font_size("font_size")).is_equal(_ENGINE_FONT_SIZE)
	var font: Font = bare.get_theme_font("font")
	assert_that(font).is_not_null()
	assert_bool(font.resource_path == _TITLE_FONT).is_false()


## 6. Цвета титула остались сценевыми оверрайдами: палитра — Q-M96, и перенос цвета
# в носитель — решение о цвете, которого у агента нет. Гард ловит «заодно перенесли».
func test_title_colors_stay_scene_overrides_until_qm96() -> void:
	var menu := make_node(load(_SCENE_FILE))
	for role: String in _ROLES:
		var spec: Array = _ROLES[role]
		var label := menu.get_node_or_null(NodePath(spec[0])) as Label
		assert_that(label).is_not_null()
		# Тот же критерий, что и в кейсе 4: именно наличие сценевого оверрайда,
		# а не разрешимость цвета темой.
		assert_that(label.get("theme_override_colors/font_color")).is_not_null().override_failure_message(
			"цвет титула %s ушёл в носитель до ответа владельца по Q-M96" % spec[0]
		)
		assert_that(label.get("theme_override_colors/font_shadow_color")).is_not_null()


## 7. Шрифт титула больше не нужен сцене: ext_resource снят, а `load_steps` пересчитан
# (устаревшее число — молча терпимая движком ложь в заголовке сцены).
func test_scene_no_longer_loads_the_title_font() -> void:
	var text := _read(_SCENE_FILE)
	assert_bool(text.contains('type="FontFile"')).is_false().override_failure_message(
		"шрифт титула всё ещё грузится сценой: носитель — роль темы"
	)
	var header := RegEx.create_from_string("(?m)^\\[gd_scene load_steps=(\\d+)").search(text)
	assert_that(header).is_not_null()
	var declared_steps := int(header.get_string(1))
	var resources := 0
	for line in text.split("\n"):
		if line.begins_with("[ext_resource ") or line.begins_with("[sub_resource "):
			resources += 1
	assert_int(declared_steps).is_equal(resources + 1)
