extends BaseTest

# UI-AC7 (кегль ≥ 16 px) + theme-type-hygiene Т-4: экран создания героя.
#
# До среза `scenes/ui/character_creation.tscn` нёс **десять** сценевых
# `theme_override_font_sizes`: заголовок 20, подзаголовок 12, семь подписей полей
# формы по 14 и сводка выбора 12. Девять из них — ниже 16 px, то есть прямое
# нарушение AC7 («тексты ≥ 16 px», [[14-ux-battle-hud]] §7) и одновременно нарушение §2
# гайда («кегль вне шкалы 16/20/24/32/48 не вводить»). Билет UI-AC7 требует
# per-case разбора, а не автозамены «12 → 16»: здесь разбор такой —
#
# | узел | было | стало | роль по §2 |
# |---|---|---|---|
# | `TitleLabel` | 20 | `LabelStrong` 24 | заголовок блока (тот же носитель, что у заголовка панели целей, T-182) |
# | `SubtitleLabel` | 12 | `LabelSecondary` 16 | вторичный (подпись под заголовком) |
# | 7 × `*LabelNode` | 14 | `LabelBody` 20 | основной текст (метки полей формы) |
# | `SummaryLabel` | 12 | `LabelSecondary` 16 | вторичный (сводка выбора) |
#
# Метки полей подняты до 20, а не до 16: это основной текст формы, а соседние
# `LineEdit`/`OptionButton`/`Button` резолвят 16 из `default_font_sizes/default`,
# который сам гайд (§2, сноска про ловушку) называет **вне шкалы** — ровнять
# метки на него означало бы закрепить чужое значение вместо роли. При 20 px
# самая длинная метка («Прошлое:») занимает 92 px в колонке 120 px — колонка
# T-177 не поехала, карточка выросла на 10 px (685 → 695 при 1080).
#
# Гард сторожит три вещи: оверрайдов кегля нет ни в сцене, ни в скрипте; каждая
# роль резолвит кегль **из темы**, а не из дефолта движка; и ни один `Label`
# сцены не опустился ниже 16 px. Отрицательный контроль (кейс 5) показывает, что
# предикат не пустой: узел без носителя резолвит 16 и гард это видит.

const _SCENE_FILE := "res://scenes/ui/character_creation.tscn"
const _SCRIPT_FILE := "res://scripts/ui/character_creation_ui.gd"
const _THEME := "res://assets/theme/game_theme.tres"

## Роль → ожидаемый носитель и кегль (значение берётся из темы, не с потолка).
const _ROLES := {
	"Overlay/Scroll/Root/TitleLabel": "LabelStrong",
	"Overlay/Scroll/Root/SubtitleLabel": "LabelSecondary",
	"Overlay/Scroll/Root/NameRow/NameLabelNode": "LabelBody",
	"Overlay/Scroll/Root/SexRow/SexLabelNode": "LabelBody",
	"Overlay/Scroll/Root/RaceRow/RaceLabelNode": "LabelBody",
	"Overlay/Scroll/Root/SubraceRow/SubraceLabelNode": "LabelBody",
	"Overlay/Scroll/Root/ClassRow/ClassLabelNode": "LabelBody",
	"Overlay/Scroll/Root/CultureRow/CultureLabelNode": "LabelBody",
	"Overlay/Scroll/Root/BackgroundRow/BackgroundLabelNode": "LabelBody",
	"Overlay/Scroll/Root/SummaryLabel": "LabelSecondary",
}

## AC7: нижняя граница кегля (он же AC7 спеки [[14-ux-battle-hud]] §7).
const _MIN_KEGL := 16


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


func _creation() -> Node:
	return make_node(load(_SCENE_FILE))


func _label(root: Node, path: String) -> Label:
	var label := root.get_node_or_null(path) as Label
	assert_that(label).is_not_null()
	return label


## 1. Сценевых оверрайдов кегля в файле не осталось ни одной записи. Считаем по
# тексту файла: запись в сцене — это и есть обход темы, независимо от того, в
# какой узел она кладётся.
func test_scene_carries_no_font_size_override() -> void:
	var offenders: Array[String] = []
	for line in _read(_SCENE_FILE).split("\n"):
		if line.strip_edges().begins_with("theme_override_font_sizes"):
			offenders.append(line.strip_edges())
	assert_int(offenders.size()).is_equal(0)


## 2. Скрипт экрана не догоняет кегль кодом (`add_theme_font_size_override`) —
# иначе снятая сценевая запись вернётся в другом механизме того же обхода.
func test_script_has_no_font_size_override_call() -> void:
	var text := _read(_SCRIPT_FILE)
	assert_bool(text.contains("add_theme_font_size_override")).is_false()


## 3. Каждая роль резолвит кегль своего носителя из темы. Проверка «значение ==
# значение из темы», а не «значение == число»: поднимут кегль роли в теме —
# экран поедет вместе с ней, и это правильный резолв, гард не должен его ловить.
func test_roles_resolve_kegl_from_theme() -> void:
	var theme := _theme()
	var root := _creation()
	for path in _ROLES:
		var variation: String = _ROLES[path]
		var label := _label(root, path)
		assert_str(str(label.theme_type_variation)).is_equal(variation)
		var declared: int = theme.get_font_size("font_size", variation)
		assert_int(declared).is_greater_equal(_MIN_KEGL)
		assert_int(label.get_theme_font_size("font_size")).is_equal(declared)


## 4. AC7 по всему экрану: ни один `Label` не ниже 16 px. Считаются и те, что
# идут без носителя (подзаголовки кнопок, всплывающие подписи), — путь к AC7
# лежит через резолв, а не через «проверить только изменённые узлы».
func test_every_label_is_readable() -> void:
	var root := _creation()
	var thin: Array[String] = []
	_walk(root, thin)
	assert_str(", ".join(thin)).is_empty()


## 5. Отрицательный контроль: предикат из кейса 3 не пустой. Узел без носителя
# резолвит дефолт темы (16), а не кегль роли — значит проверка «резолв ==
# объявление роли» отличает роль от дефолта, а не проходит всегда.
func test_guard_catches_missing_variation() -> void:
	var theme := _theme()
	var root := _creation()
	var title := _label(root, "Overlay/Scroll/Root/TitleLabel")
	var declared: int = theme.get_font_size("font_size", "LabelStrong")
	title.theme_type_variation = &""
	var resolved: int = title.get_theme_font_size("font_size")
	# Тема игры своего `default_font_size` не объявляет (-1), поэтому узел без
	# носителя падает на встроенные 16 px движка — ровно те, что резолвят поля
	# формы. Дефолт ниже роли (24) — значит сверка «резолв == объявление роли»
	# отличает носитель от дефолта.
	assert_int(theme.get_default_font_size()).is_equal(-1)
	assert_int(resolved).is_not_equal(declared)
	assert_int(resolved).is_less(declared)
	assert_int(resolved).is_equal(16)


## 6. Колонка меток (T-177) выдерживает новый кегль: ни одна метка формы не
# шире колонки, иначе вёрстка «метка справа — поле слева» поедет молча.
func test_label_column_still_holds_the_cyrillic_labels() -> void:
	var theme := _theme()
	var font: Font = theme.get_font("font", "LabelBody")
	assert_that(font).is_not_null()
	var kegl: int = theme.get_font_size("font_size", "LabelBody")
	var widest := 0.0
	var root := _creation()
	for path in _ROLES:
		if not str(path).ends_with("LabelNode"):
			continue
		var label := _label(root, path)
		widest = maxf(widest, font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, kegl).x)
	assert_bool(widest <= 120.0).is_true()


func _walk(node: Node, thin: Array[String]) -> void:
	if node is Label:
		var label := node as Label
		var kegl := label.get_theme_font_size("font_size")
		if kegl < _MIN_KEGL:
			thin.append("%s=%d" % [label.name, kegl])
	for child in node.get_children():
		_walk(child, thin)
