extends BaseTest

## UI-AC7 (AC1–AC3) на **живых** носителях: экран города кампании и экраны,
## поднимаемые главным меню (настройки, инвентарь артефактов, лента хроники).
##
## Билет UI-AC7 считал только сценевые `theme_override_font_sizes` и по ним же
## перечислял «три худшие сцены». За пределами этого счёта оставался кегль,
## который ставит **код** (`add_theme_font_size_override`), и он же — единственный
## живое чтение игрока: замер 2026-10-24 (GdUnit-обход живого дерева, билет T-189)
## дал 495 узлов ниже 16 px на открытом экране города и 16 — на дереве главного
## меню. Обе цифры после этого среза — ноль.
##
## Что разбиралось per-case (правая колонка — роль по §2 гайда [[17-ui-style-guide]],
## а не автозамена «12 → 16»):
##
## | узел | было | стало | почему |
## |---|---|---|---|
## | 5 вкладок каталога (`CityTab`) | 12 (обход) | 16 из темы | у `CityTab` объявлены только четыре состояния стиля, кегля у него нет; соседние кнопки экрана резолвят 16 — ряд стал однородным |
## | заголовок карточки (`SelectBuilding`) | 17 (обход, вне шкалы) | `CityCardTitle` 20 | карточка целиком перешла на ролевые шрифты, и заголовок 17 перестал быть больше своих же подписей; 20 = «основной текст» §2 |
## | `@Label` ролей постройки | 11 | `LabelSecondary` 16 | вторичная строка (ролей набор, капсом) |
## | `CostCaption` «СТОИМОСТЬ» | 10 | `LabelSecondary` 16 | подпись |
## | `BuildingEffects` | 13 | `LabelSecondary` 16 | плотная строка списка (98 карточек, абзацем не является) |
## | `BuildingPrerequisites` | 12 | `LabelSecondary` 16 | подпись |
## | `BuildingAvailability` | 12 | `LabelSecondary` 16 | подпись |
## | `ApplyButton`/`ResetButton`/`CancelButton` | 14 (обход) | 16 из темы | ряд кнопок формы: остальные кнопки экрана обхода не имели |
## | 5 × `Info` слотов сейва | 14 | `LabelSecondary` 16 | вторичный (метаданные слота) |
## | `ErrorLabel` | 13 | `LabelSecondary` 16 | цвет остаётся своим обходом: палитра — ось Q-M96, этот срез её не решает |
## | 7 × `ArmyCount` | 14 | `LabelNumber` 20 | §2: «числа/статы … счётчики» = 20 PT Mono — тот же носитель, что на боевом HUD; цвет — цвет роли (мутация M6) |
## | `chronicle_entry` (строка ленты) | 14 | `LabelBody` 20 | единственный текст ленты — это проза чтения, §2 = 20 |
##
## Цвета и отступы не трогались ни в одном узле (Q-M96 открыт), поэтому разница в
## кадрах — только кегль и, где роль объявляет шрифт, гарнитура.
##
## Гард сторожит четыре вещи: обходов кегля ниже 16 нет ни в сценах, ни в коде;
## живое дерево экрана города и дерево главного меню не содержат ни одного узла с
## разрешённым кеглем ниже 16 px; роли резолвят кегль **из темы**, а не из дефолта
## движка; и вёрстка не поехала — ряд вкладок и колонка карточек влезают в свои
## контейнеры. Отрицательный контроль (кейс 6) показывает, что обход не пустой.

const _CITY_SCRIPT := "res://scripts/ui/city_screen.gd"
const _MAIN_SCENE := "res://scenes/main/main.tscn"
const _MENU_SCENE := "res://scenes/main_menu.tscn"
const _ENTRY_SCENE := "res://scenes/ui/chronicle_entry.tscn"
const _THEME := "res://assets/theme/game_theme.tres"
const _CITY_SCREEN_PATH := "CampaignHUD/CampaignHud/CityScreen"

## Сцены, где кегль обязан приезжать из темы: проверяется текст файла, потому что
## запись в сцене — обход независимо от того, в какой узел она кладётся.
const _SCENES := [
	"res://scenes/ui/settings_screen.tscn",
	"res://scenes/ui/save_load_screen.tscn",
	"res://scenes/ui/artifact_inventory_screen.tscn",
	"res://scenes/ui/chronicle_entry.tscn",
]

## AC7: нижняя граница кегля.
const _MIN_KEGL := 16

var _main: Node = null


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame


func _root() -> Node:
	return Engine.get_main_loop().root


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


## Кампейн поднимается так же, как его поднимает игра: сцена `main.tscn`, `_ready`
## → `_init_campaign` → привязка слоя. Окно ставится явным размером: headless-окно
## 64×64 легально включает компактный режим шапки.
func _boot_campaign() -> Node:
	var window := _root() as Window
	window.size = Vector2i(1920, 1080)
	_main = load(_MAIN_SCENE).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Node = _main.get_node("CampaignHUD/CampaignHud")
	# Оверлей первой директивы (T-186) модален и лежит выше слоя HUD: он не мешает
	# коду, но обязан быть снят, иначе измерялся бы кадр с закрытым экраном.
	hud.bind_tutorial({})
	return _main


func _hud() -> Node:
	return _main.get_node("CampaignHUD/CampaignHud")


## Обход живого дерева: собирает узлы, чей **разрешённый** кегль ниже порога.
## Считается резолв, а не наличие записи: только так видно и обход, и роль, и
# дефолт движка (16 px), и ничего нельзя спрятать в «узел без подписи».
func _collect_thin(node: Node, path: String, out: Array[String], seen: Array[int]) -> void:
	var here := path + "/" + str(node.name)
	if node is Control:
		var control := node as Control
		if control is Label or control is Button or control is RichTextLabel \
				or control is LineEdit or control is OptionButton:
			seen[0] += 1
			var kegl := control.get_theme_font_size("font_size")
			if kegl < _MIN_KEGL:
				out.append("%s %s=%d" % [here, control.get_class(), kegl])
	for child in node.get_children():
		_collect_thin(child, here, out, seen)


func _thin_of(node: Node) -> Array[String]:
	var thin: Array[String] = []
	var seen: Array[int] = [0]
	_collect_thin(node, "", thin, seen)
	return thin


func _count_of(node: Node) -> int:
	var thin: Array[String] = []
	var seen: Array[int] = [0]
	_collect_thin(node, "", thin, seen)
	return seen[0]


## 1. Обходов кегля ниже порога не осталось ни в коде экрана города, ни в четырёх
# разобранных сценах. Значения вытаскиваются из текста, поэтому «12 → 15» гард
# тоже поймает: граница — число, а не отсутствие записи.
func test_sources_have_no_sub_floor_font_size() -> void:
	var offenders: Array[String] = []
	# Две формы: сценевая запись (`theme_override_font_sizes/font_size = 12`) и
	# кодовый вызов (`add_theme_font_size_override("font_size", 12)`). Одна общая
	# регулярка их не ловит: у сценевой формы есть `=`, у кодовой — нет.
	var scene_form := RegEx.create_from_string("theme_override_font_sizes/\\w+\\s*=\\s*(\\d+)")
	var code_form := RegEx.create_from_string("add_theme_font_size_override\\([^)]*,\\s*(\\d+)")
	var files: Array[String] = [_CITY_SCRIPT]
	files.append_array(_SCENES)
	for path in files:
		for line in _read(path).split("\n"):
			for pattern in [scene_form, code_form]:
				var match_: RegExMatch = pattern.search(line)
				if match_ != null and int(match_.get_string(1)) < _MIN_KEGL:
					offenders.append("%s: %s" % [path, line.strip_edges()])
	assert_str(", ".join(offenders)).is_empty()


## 2. Живой экран города: ни одного узла ниже 16 px. До среза здесь было 495
# узлов (5 вкладок + 5 строк × 98 карточек) — счётчик карточек берётся из
# каталога, а не с потолка, поэтому кейс 3 сторожит и то, что обход дошёл до
# карточек, а не прошёл по пустому экрану.
func test_live_city_screen_is_readable() -> void:
	var main := await _boot_campaign()
	_hud().open_city_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := main.get_node(_CITY_SCREEN_PATH) as Node
	assert_that(screen).is_not_null()
	var seen := _count_of(screen)
	assert_int(seen).is_greater(400)
	assert_str(", ".join(_thin_of(screen))).is_empty()


## 3. Роли карточки резолвят кегль своего носителя из темы, а не из дефолта
# движка: заголовок — `CityCardTitle`, четыре служебные строки — `LabelSecondary`,
# вкладка — `CityTab` без кегля (тогда резолв = 16 темы, а не 12 обхода).
func test_card_roles_resolve_kegl_from_theme() -> void:
	var theme := _theme()
	var main := await _boot_campaign()
	_hud().open_city_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := main.get_node(_CITY_SCREEN_PATH) as Node
	var cards := screen.find_child("CatalogCards", true, false)
	assert_that(cards).is_not_null()
	assert_int(cards.get_child_count()).is_greater(0)
	# Первый ребёнок колонки — плейсхолдер «Нет зданий в этой категории» (он живёт
	# в том же VBox и никогда не удаляется), поэтому карточка = первая панель.
	var card: Node = null
	for child in cards.get_children():
		if child is PanelContainer:
			card = child
			break
	assert_that(card).is_not_null()
	var title := card.find_child("SelectBuilding", true, false) as Button
	assert_that(title).is_not_null()
	assert_str(str(title.theme_type_variation)).is_equal("CityCardTitle")
	assert_int(title.get_theme_font_size("font_size")).is_equal(
		theme.get_font_size("font_size", "CityCardTitle"))
	for role_name in ["BuildingRoles", "BuildingEffects", "BuildingPrerequisites",
			"BuildingAvailability", "CostCaption"]:
		var label := card.find_child(role_name, true, false) as Label
		assert_that(label).is_not_null()
		assert_str(str(label.theme_type_variation)).is_equal("LabelSecondary")
		assert_int(label.get_theme_font_size("font_size")).is_equal(
			theme.get_font_size("font_size", "LabelSecondary"))
	var tabs := screen.find_child("CategoryTabs", true, false) as Node
	assert_int(tabs.get_child_count()).is_greater(0)
	var tab := tabs.get_child(0) as Button
	assert_str(str(tab.theme_type_variation)).is_equal("CityTab")
	assert_int(tab.get_theme_font_size("font_size")).is_equal(_MIN_KEGL)


## 4. Вёрстка не поехала: кегль вырос — значит ширина строки тоже. Ряд вкладок и
# колонка карточек обязаны влезать в свои контейнеры, иначе каталог начал бы
# резать текст (у `CatalogScroll` горизонтальный скролл выключен намеренно).
func test_catalog_layout_still_fits() -> void:
	var main := await _boot_campaign()
	_hud().open_city_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := main.get_node(_CITY_SCREEN_PATH) as Node
	var tabs := screen.find_child("CategoryTabs", true, false) as Control
	var sidebar := tabs.get_parent() as Control
	assert_bool(tabs.get_combined_minimum_size().x <= sidebar.size.x) \
		.override_failure_message("ряд вкладок шире боковой панели").is_true()
	var cards := screen.find_child("CatalogCards", true, false) as Control
	var scroll := cards.get_parent() as Control
	assert_bool(cards.get_combined_minimum_size().x <= scroll.size.x) \
		.override_failure_message("колонка карточек шире скролла").is_true()


## 5. Главное меню со своими экранами (настройки, инвентарь артефактов, хроника,
# выбор сохранения) и строка ленты хроники. Экраны подняты как в игре — инстансами
# внутри `main_menu.tscn`, а не вторыми копиями.
func test_menu_tree_is_readable() -> void:
	var menu := make_node(load(_MENU_SCENE))
	var seen := _count_of(menu)
	assert_int(seen).is_greater(60)
	assert_str(", ".join(_thin_of(menu))).is_empty()


## 5b. Строка ленты хроники приезжает ролью `LabelBody`: у единственного носителя
# ленты нет своего кегля, и он обязан быть объявлен в теме, а не в сцене.
func test_chronicle_entry_reads_as_body() -> void:
	var theme := _theme()
	var entry := make_node(load(_ENTRY_SCENE)) as Label
	assert_that(entry).is_not_null()
	assert_str(str(entry.theme_type_variation)).is_equal("LabelBody")
	var declared: int = theme.get_font_size("font_size", "LabelBody")
	assert_int(declared).is_greater_equal(_MIN_KEGL)
	assert_int(entry.get_theme_font_size("font_size")).is_equal(declared)


## 6. Отрицательный контроль: обход из кейсов 2 и 5 не пустой предикат. Узел с
# обходом 12 px, добавленный в то же дерево, обязан быть найден — иначе «пустой
# список нарушений» ничего не значит.
func test_walker_catches_planted_override() -> void:
	var host := Control.new()
	add_child(auto_free(host))
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	host.add_child(auto_free(label))
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 15)
	host.add_child(auto_free(button))
	var thin := _thin_of(host)
	assert_int(thin.size()).is_equal(2)
	var joined := ", ".join(thin)
	assert_bool(joined.contains("=12")).override_failure_message(
		"обход не нашёл посаженный обход 12 px").is_true()
	assert_bool(joined.contains("=15")).override_failure_message(
		"обход не нашёл посаженный обход 15 px").is_true()


## 7. Счётчик войск: роль дала 20 px mono, и бокс, размеченный под 14 px, стал тесен.
# Проверка — арифметика, а не «на глаз»: бокс обязан вмещать четырёхзначное число
# (стартовый стек героя — `103`, `_init_default_army`), выравнивание обязано держать
# цифру на прежнем месте (правый край) и давать ей расти влево, а не за край слота,
# и сам бокс обязан оставаться в слоте 76 px.
func test_army_counter_fits_its_slot() -> void:
	var menu := make_node(load(_MENU_SCENE))
	var win: Node = menu.get_node("HeroModelWindow") as Node
	var game_theme: Theme = load(_THEME) as Theme
	var declared: int = int(game_theme.get_font_size("font_size", "LabelNumber"))
	# Макет 12: армейская полоса — четыре карточки в колонке справа (D-280).
	for i in 4:
		var slot: Control = win.get_node(
				"Center/Window/Sheet/Units/Bottom/Cards/Card_%d" % i) as Control
		var lbl: Label = slot.get_node("ArmyCount_%d" % i) as Label
		assert_str(lbl.theme_type_variation).is_equal("LabelNumber")
		var kegl: int = lbl.get_theme_font_size("font_size")
		assert_int(kegl).override_failure_message(
			"счётчик Slot_%d резолвит не кегль роли LabelNumber" % i).is_equal(declared)
		var font: Font = lbl.get_theme_font("font_size") as Font
		var need: float = font.get_string_size("1234", HORIZONTAL_ALIGNMENT_LEFT, -1, kegl).x
		var box: float = lbl.offset_right - lbl.offset_left
		assert_float(box).override_failure_message(
			"бокс счётчика Slot_%d уже четырёхзначного числа (%.1f < %.1f)" % [i, box, need]
			).is_greater_equal(need)
		assert_int(lbl.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_RIGHT)
		assert_bool(lbl.offset_right <= slot.size.x and lbl.offset_bottom <= slot.size.y) \
			.override_failure_message("счётчик Slot_%d выходит за границы слота" % i).is_true()
