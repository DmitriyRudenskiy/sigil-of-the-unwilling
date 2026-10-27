extends BaseTest

## Адаптивный гейт (ui-verification-gates 1.2, спека «Адаптивный UI layout»).
##
## 1.1 (зонд 2026-10-21): все 8 кандидатских экранов headless-инстанцируются
## без игрового состояния → все в обязательном наборе, исключений нет.
## Записи о старте (рецепты отражают хостов, не изобретают свой layout):
## - settings_screen: `setup(Settings)` ДО add_child — Settings это autoload
##   (глобальный, не игровое состояние); standalone-инстанс без setup сам
##   освобождается в _ready (persistent=false по умолчанию).
## - artifact_inventory_screen: корню ставятся полные якоря
##   (anchor_right/bottom = 1.0) — оба хоста (main_menu.tscn:HeroModelWindow,
##   world_ui.tscn:WorldUILayer/ArtifactInventoryScreen) делают ровно это;
##   standalone-корень без якорей 0×0 и layout окна деградирует.
##
## Для каждого экрана × 5 разрешений: вьюпорт нужного размера, 40 кадров
## (успокоение intro-анимаций, см. _SETTLE_FRAMES), обход видимого
## Control-дерева:
## (1) rect элемента внутри вьюпорта (допуск 2 px) — «вьюпорт» здесь
##     layout-размер корневого вьюпорта (`get_visible_rect()`), не окно:
##     stretch mode canvas_items держит layout 1920×1080 на всех 16:9
##     (3440×1440 → 2580×1080, aspect=expand). Элементы под
##     ScrollContainer в этой проверке не участвуют: их выход за вьюпорт
##     достижим скроллом (world_ui: RightColumn/Box — vertical scroll);
## (2) перекрытие sibling-пар > 20% площади меньшего элемента — нарушение,
##     кроме осознанных оверлеев/фонов из явного списка _OVERLAYS.
##     Перекрытия < 100 px² (квадрат 10×10) не считаются — это
##     субпиксельные срезы (party-строки: Icon/Avatar × Name, 17–18 px²);
##     наименьшее реальное перекрытие в кодовой базе — 650 px².
## (3) (T-173, 2026-10-24) экран не должен требовать прокрутки: минимум
##     содержимого ScrollContainer больше его собственного размера
##     (> _TOLERANCE_PX). Осознанные прокручиваемые области — _SCROLL_ALLOWED с
##     основанием; своих «известных дефектов» у этой проверки нет — замер
##     2026-10-24 не нашёл ни одной неосознанной активной полосы.
##     Метрика — НЕ `get_v_scroll_bar().max_value`: он даёт 669 px на
##     character_creation и 23 px на city_screen там, где контент влезает (у
##     скрытой полосы page не обновляется); живой кадр 1280×720 подтверждает: полос
##     на этих экранах нет. Скрытые в дереве контейнеры не меряются вовсе: у них
##     макет не считан, и цифры с них не являются доказательством (на такой цифре
##     0×54 при контенте 1187 px родился несуществующий T-180). Экраны со свёрнутыми
##     по умолчанию панелями проверяются вторично в раскрытом состоянии — см.
##     test_city_screen_legacy_panel_open_responsive.
##
## Известные дефекты (T-154, 2026-10-21): нарушения, совпадающие с
## _KNOWN_VIOLATIONS, печатаются в лог, но НЕ краснят гейт — дефект
## отслеживается в TICKETS.md до визуального фикса владельца. Запись
## удаляется после фикса; устаревшая запись (нарушение не воспроизводится)
## печатается предупреждением.
##
## Нюансы движка (Godot 4.7.2):
## - свойство `Control.global_rect` через свойственную синтаксис даёт
##   «Invalid access to property or key» (проверено на голом Control вне
##   GdUnit) — используется метод `get_global_rect()`;
## - screens с intro-анимацией (main_menu: `_UIAnimator.animate_in`,
##   0.2 c tween с TRANS_BACK) меряются только после успокоения —
##   иначе замеры ловят позицию посреди tween.

const _RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

const _TOLERANCE_PX := 2.0
const _OVERLAP_LIMIT := 0.2

## Перекрытия меньше этого абсолютного порога не считаются (см. заголовок).
const _MIN_OVERLAP_PX2 := 100.0

## Кадров успокоения после старта экрана: intro-твины до 0.2 c
## (ui_animator.animate_in) + запас; 40 кадров @60 fps ≈ 0.67 c.
const _SETTLE_FRAMES := 40

## Осознанные оверлеи/фоны: перекрытие с sibling-узлами разрешено.
## Скроп по экрану (первый прогон 1.3, 2026-10-21): имена узлов, не пути;
## каждое имя добавляется только с комментарием-основанием.
const _OVERLAYS := {
	"main_menu": [
		"Background",     # фоновая текстура на весь экран
		"TitleLine1", "TitleLine2", "TitleLine3",  # стэк заголовка:
		# осознанное наложение (offset_top в сцене: 204/224 против 0..263)
	],
	"settings_screen": [
		"Background",     # затемнение под окном настроек
	],
	"save_load_screen": [
		"Dim",            # затемнение под окном слотов
	],
	"character_creation": [
		"Background",     # затемнение под карточкой создания героя (T-177); сама
		# карточка `Overlay` с этого среза — не полноэкранный слой, а центр,
		# и она в проверке участвует
	],
	"city_screen": [
		"ScreenShade",    # затемнение под панелью города
		"BoardPlaceholder",  # подложка под доску (под CampaignCityBoard)
		"CityInspector",     # плавающая панель инспектора над доской
		"TerrainLegend",     # плавающая легенда над доской
	],
	"battle_ui": [
		# hero_cards — контейнер на всю ширину для КРАЕВЫХ карточек героев
		# (hero_left x 55–395, hero_right x W-395..W-55); видимые карточки
		# не пересекаются ни с чем в полосе, пересекается только rect контейнера
		# (полная ширина, чтобы держать обе карточки).
		"hero_cards",
		# bar_box — HBox на всю ширину нижней панели: left_box (кнопки слева),
		# spacer, right_box (кнопки справа); видимые кнопки у краёв не пересекаются
		# с центрированным info_box (turn/log), пересекается только rect контейнера.
		"bar_box",
	],
	"artifact_inventory_screen": [
		"Figure",         # кукла; слоты экипировки DollSlot_* рисуются поверх
		"Left", "Side",   # колонки; нижняя панель Bottom осознанно
		"Bottom",         # пересекает их (полоса на всю ширину окна)
		# Items — слой иконок сетки: пустой контейнер размером со всю сетку, на
		# котором иконки стоят по клеткам. Пересекается rect'ом слоя, а не
		# видимым контентом (тот лежит НА клетках, а не рядом с ними) — тот же
		# случай, что hero_cards/bar_box выше.
		"Items",
	],
	"world_ui": [
		"end_overlay",    # оверлей конца похода
		"Frame",          # рамка карты — подложка под MapBox
		"MapBox",         # карта внутри рамки
		"N", "S", "E", "W",  # nav-стрелки на гранях рамки/карты
		"TextureRect",    # minimap: текстура карты (узел с дефолтным именем,
		"Overlay",        # единственный в дереве world_ui) + туман/затемнение
		# поверх текстуры — осознанное наложение
	],
}

## Осознанный bleed за край вьюпорта (явный список, не эвристика),
## скроп по экрану. main_menu TitleLine1 — offset_top = -10 в сцене
## (декоративный заголовок, глифы полностью видны: текст центрирован в
## 274 px box); принято в дизайне (smoke-скрин меню 2026-10-13).
const _BLEED_ALLOWED := {
	"main_menu": ["TitleLine1"],
}

## Известные layout-дефекты (T-154, 2026-10-21): префиксы путей
## нарушений, которые печатаются, но не краснят гейт до фикса сцены.
## (а) из старого основания снята 2026-10-27 (grid-inventory-and-merchant 4.4):
## окно экрана стало 1400 px (макет), Center больше не сворачивается в 0×0 и
## строка Right/Inventory не уходит за правый край — запись про неё удалена
## (гейт её больше не печатает). Осталось (б): Bottom — PanelContainer с 8
## детьми: все ArmySlot_* и Formations накладываются в один и тот же
## content-rect, Form_0×Form_2 / Form_1×Form_3 пересекаются на 12 px
## (min-высота кнопки 48 > шаг строк 36). Живой носитель: main_menu
## HeroModelWindow + world_ui WorldUILayer/ArtifactInventoryScreen.
const _KNOWN_VIOLATIONS := {
	"artifact_inventory_screen": [
		"Center/Window/Bottom/ArmySlot_",
		"Center/Window/Bottom/Formations",
	],
	# world_ui: вложенный WorldUILayer/ArtifactInventoryScreen в сцене
	# visible=false — гейт меряет начальное состояние, нарушений нет;
	# дефект того же окна покрывается standalone-записями выше.
}

## Осознанные прокручиваемые области (T-173): нормализованные пути (см.
## _norm_path: автоимена `@VBoxContainer@89` → `@VBoxContainer@*`). Каждая
## запись — с основанием; отсутствие экрана в списке значит «прокрутки тут нет».
const _SCROLL_ALLOWED := {
	"world_ui": [
		# Единственная живая полоса в наборе: контент 1695 px в колонке 1060 px
		# (кадр ~/.local/share/sigil-reserve/responsive-t173/world-720.png).
		# Носителя у экрана нет: точка входа — scenes/archive/world.tscn, её
		# вызывает WorldStateSerializer.start_game(), у которого нет ни вызова,
		# ни autoload (замер T-173). Архив остаётся в гейте ради проверок (1) и (2).
		"WorldUILayer/AdventureUI/RightColumn/Box",
	],
	"chronicle_screen": [
		# Лента кампании произвольной длины (D-240): прокрутка — проектное
		# решение. Пустой экран полосу не показывает (замер overflow_y = 0),
		# запись страхует длину ленты, а не фиксирует дефект.
		"Root/Panel/VBox/Scroll",
	],
}

const _SCREENS := {
	"main_menu": "res://scenes/main_menu.tscn",
	"settings_screen": "res://scenes/ui/settings_screen.tscn",
	"save_load_screen": "res://scenes/ui/save_load_screen.tscn",
	"character_creation": "res://scenes/ui/character_creation.tscn",
	"city_screen": "res://scenes/ui/city_screen.tscn",
	"battle_ui": "res://scenes/ui/battle_ui.tscn",
	"artifact_inventory_screen": "res://scenes/ui/artifact_inventory_screen.tscn",
	"world_ui": "res://scenes/ui/world_ui.tscn",
	# 2026-10-24 (T-173): живой экран кампании из D-240; раньше в наборе его не было.
	"chronicle_screen": "res://scenes/ui/chronicle_screen.tscn",
}

## Явные исключения (спека «Экран с игровым состоянием исключён явно»).
## 2026-10-21: пустой — все 8 экранов инстанцируются headless (зонд 1.1).
## Незарегистрированное исключение не допускается: экран, который перестанет
## отрендериться без игрового состояния, обязан появиться здесь с причиной.
const _EXCLUDED := {}

var _screen: Node = null
var _original_size := Vector2i(1920, 1080)


func before_test() -> void:
	_original_size = get_tree().root.size


func after_test() -> void:
	super.after_test()
	get_tree().root.size = _original_size
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
		_screen = null
	await get_tree().process_frame


## id — ключ _SCREENS; opener — необязательный хук состояния-варианта (вызывается
## после успокоения макета, проверяется то же состояние тремя проверками).
func _check_screen(id: String, opener: Callable = Callable()) -> void:
	var unknown: Array[String] = []
	var known: Array[String] = []
	var matched_prefixes := {}  # path_prefix -> true (детект устаревших записей)
	for res in _RESOLUTIONS:
		get_tree().root.size = res
		_screen = await _boot(id)
		if _screen == null:
			unknown.append("%s: экран не стартовал на %s" % [id, res])
			continue
		if opener.is_valid():
			opener.call(_screen)
			for _i in _SETTLE_FRAMES:
				await get_tree().process_frame
		var vp: Rect2 = get_viewport().get_visible_rect()
		var batch: Array[String] = []
		_check_bounds(id, _screen, vp, res, batch)
		_check_overlaps(id, _screen, batch)
		_check_scroll(id, _screen, batch)
		for v in batch:
			if _match_known(id, v, matched_prefixes):
				known.append(v)
			else:
				unknown.append(v)
		_screen.queue_free()
		_screen = null
		await get_tree().process_frame
		await get_tree().process_frame
	if known.size() > 0:
		print("responsive %s: %d известных нарушений (T-154), не краснят гейт:\n%s" % [id, known.size(), "\n".join(known)])
	for prefix in _KNOWN_VIOLATIONS.get(id, []):
		if not matched_prefixes.has(prefix):
			print("responsive %s: T-154 — известное нарушение '%s' не воспроизводится; запись устарела, удалить" % [id, prefix])
	assert_bool(unknown.is_empty()) \
		.override_failure_message(
			"адаптив %s: %d нарушений:\n%s" % [id, unknown.size(), "\n".join(unknown)]
		).is_true()


## true, если нарушение совпадает с записью _KNOWN_VIOLATIONS (префикс пути
## в сообщении; путь — после первого «: »).
func _match_known(id: String, violation: String, matched: Dictionary) -> bool:
	var colon := violation.find(": ")
	if colon < 0:
		return false
	var path_part := violation.substr(colon + 2)
	for prefix in _KNOWN_VIOLATIONS.get(id, []):
		if path_part.begins_with(prefix):
			matched[prefix] = true
			return true
	return false


## Старт экрана (зонд 1.1): instantiate + (settings: setup(Settings)) +
## _SETTLE_FRAMES кадров (успокоение intro-анимаций).
func _boot(id: String) -> Node:
	var packed: PackedScene = ResourceLoader.load(_SCREENS[id]) as PackedScene
	if packed == null:
		push_error("responsive: не загрузилась сцена %s" % _SCREENS[id])
		return null
	var node: Node = packed.instantiate()
	if id == "settings_screen":
		(node as SettingsScreen).setup(Settings)
	if id == "artifact_inventory_screen" and node is Control:
		var root_c := node as Control
		root_c.anchor_right = 1.0
		root_c.anchor_bottom = 1.0
	get_tree().root.add_child(node)
	for _i in _SETTLE_FRAMES:
		await get_tree().process_frame
	return node


func _check_bounds(id: String, node: Node, vp: Rect2, win: Vector2i, out: Array[String]) -> void:
	var controls: Array = []
	_collect_controls(node, controls)
	var limit := vp.grow(_TOLERANCE_PX)
	for c in controls:
		var control := c as Control
		if not control.is_visible_in_tree():
			continue
		if _has_scroll_ancestor(node, control):
			continue  # контент под ScrollContainer: выход за вьюпорт достижим скроллом
		var r: Rect2 = control.get_global_rect()
		if not limit.encloses(r) and not _bleed_allowed(id, node, control):
			out.append(
				"вне вьюпорта win=%s layout=%s: %s rect=%s" % [win, vp.size, _path(node, control), r]
			)


## (3) T-173: экран не должен требовать прокрутки. Минимум содержимого
## ScrollContainer сравнивается с его собственным размером: если содержимое
## больше — полоса активна, игрок не видит часть интерфейса без скролла.
## Дети ScrollContainer выкладываются столбцом, поэтому по высоте берётся СУММА
## минимумов детей, по ширине — МАКСИМУМ (то, что считает сам движок).
## Учитываются только видимые в дереве контейнеры с включённым режимом прокрутки
## по соответствующей оси (DISABLE = контент обрезается, а не прокручивается;
## это ловит проверка (1), если элемент выходит за вьюпорт).
func _check_scroll(id: String, root: Node, out: Array[String]) -> void:
	var scrolls: Array[ScrollContainer] = []
	_collect_scrolls(root, scrolls)
	for sc in scrolls:
		var cy := 0.0
		var cx := 0.0
		for ch in sc.get_children():
			if ch is Control:
				var min_size: Vector2 = (ch as Control).get_combined_minimum_size()
				cy += min_size.y
				cx = maxf(cx, min_size.x)
		var oy: float = cy - sc.size.y
		var ox: float = cx - sc.size.x
		var why := ""
		if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and oy > _TOLERANCE_PX:
			why = "по высоте: контент %d px в окне %d px (+%d px)" % [int(cy), int(sc.size.y), int(oy)]
		elif sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and ox > _TOLERANCE_PX:
			why = "по ширине: контент %d px в окне %d px (+%d px)" % [int(cx), int(sc.size.x), int(ox)]
		if why == "":
			continue
		var path := _norm_path(_path(root, sc))
		if path in _SCROLL_ALLOWED.get(id, []):
			continue
		out.append("прокрутка %s: %s (%s)" % [id, path, why])


## Сбор видимых в дереве ScrollContainer (собирается всё дерево, включая сам узел).
func _collect_scrolls(node: Node, out: Array[ScrollContainer]) -> void:
	if node is ScrollContainer and (node as Control).is_visible_in_tree():
		out.append(node as ScrollContainer)
	for ch in node.get_children():
		_collect_scrolls(ch, out)


## Godot даёт контейнерам без имени автоимена вида `@VBoxContainer@89`, счётчик
## меняется между запусками — нормализуем суффикс, чтобы записи allowlist были
## воспроизводимы между прогонами.
func _norm_path(path: String) -> String:
	var parts: Array[String] = []
	for part in path.split("/"):
		if part.begins_with("@") and part.length() > 1 and part[part.length() - 1].is_valid_int():
			var at := part.rfind("@")
			parts.append(part.substr(0, at) + "@*")
		else:
			parts.append(part)
	return "/".join(parts)


## Есть ли у элемента предок-ScrollContainer (не считая его самого).
func _has_scroll_ancestor(root: Node, c: Node) -> bool:
	var cur: Node = c.get_parent()
	while cur != null and cur != root:
		if cur is ScrollContainer:
			return true
		cur = cur.get_parent()
	return false


func _check_overlaps(id: String, root: Node, out: Array[String]) -> void:
	_check_overlaps_node(id, root, root, out)


## Рекурсия: node — текущий родитель, root — корень экрана (полные пути
## в отчёте; без root пути были бы parent-относительными).
func _check_overlaps_node(id: String, root: Node, node: Node, out: Array[String]) -> void:
	var controls: Array[Control] = []
	for ch in node.get_children():
		if ch is Control:
			controls.append(ch)
	for i in controls.size():
		for j in range(i + 1, controls.size()):
			var a: Control = controls[i]
			var b: Control = controls[j]
			if not a.is_visible_in_tree() or not b.is_visible_in_tree():
				continue
			if _is_overlay(id, a) or _is_overlay(id, b):
				continue
			var ra: Rect2 = a.get_global_rect()
			var rb: Rect2 = b.get_global_rect()
			var inter: Rect2 = ra.intersection(rb)
			if inter.size.x <= 0.0 or inter.size.y <= 0.0:
				continue
			if inter.get_area() < _MIN_OVERLAP_PX2:
				continue  # субпиксельный срез (см. _MIN_OVERLAP_PX2)
			var smaller := minf(ra.get_area(), rb.get_area())
			if smaller <= 0.0:
				continue
			if inter.get_area() / smaller > _OVERLAP_LIMIT:
				out.append(
					"перекрытие %s%%: %s × %s (общее %d px²)" % [
						str(int(inter.get_area() / smaller * 100.0)),
						_path(root, a), _path(root, b), int(inter.get_area()),
					]
				)
	for ch in node.get_children():
		_check_overlaps_node(id, root, ch, out)


func _is_overlay(id: String, c: Control) -> bool:
	return c.name in _OVERLAYS.get(id, [])


func _bleed_allowed(id: String, root: Node, c: Control) -> bool:
	var allowed: Array = _BLEED_ALLOWED.get(id, [])
	if c.name in allowed:
		return true
	# bleed разрешён, если элемент внутри поддерева узла из списка
	var cur: Node = c
	while cur != null and cur != root:
		if cur.name in allowed:
			return true
		cur = cur.get_parent()
	return false


func _collect_controls(node: Node, out: Array) -> void:
	if node is Control:
		out.append(node)
	for ch in node.get_children():
		_collect_controls(ch, out)


func _path(root: Node, n: Node) -> String:
	if n == root:
		return "<root>"
	var parts: Array[String] = []
	var cur: Node = n
	while cur != null and cur != root:
		parts.push_front(cur.name)
		cur = cur.get_parent()
	return "/".join(parts)


func test_main_menu_responsive() -> void:
	await _check_screen("main_menu")


func test_settings_screen_responsive() -> void:
	await _check_screen("settings_screen")


func test_save_load_screen_responsive() -> void:
	await _check_screen("save_load_screen")


func test_character_creation_responsive() -> void:
	await _check_screen("character_creation")


func test_city_screen_responsive() -> void:
	await _check_screen("city_screen")


func test_battle_ui_responsive() -> void:
	await _check_screen("battle_ui")


func test_artifact_inventory_screen_responsive() -> void:
	await _check_screen("artifact_inventory_screen")


func test_world_ui_responsive() -> void:
	await _check_screen("world_ui")


func test_chronicle_screen_responsive() -> void:
	await _check_screen("chronicle_screen")


## Состояние-вариант живого города (T-173): переключатель «Классические действия
## города» разворачивает панель, скрытую по умолчанию. В исходном состоянии гейт её
## не видит, а цифры со скрытого узла бессмысленны (0×54 при контенте 1187 px —
## на этом замере родился и померил ошибку несуществующий T-180), поэтому раскрытое
## состояние проверяется теми же тремя проверками отдельно.
func test_city_screen_legacy_panel_open_responsive() -> void:
	await _check_screen("city_screen", func(s: Node) -> void:
		var toggle := s.get_node_or_null("ScreenMargin/ScreenLayout/ScreenFooter/LegacyToggle") as Button
		assert_object(toggle).is_not_null().override_failure_message(
			"город обязан нести переключатель легаси-действ — иначе состояние-вариант не проверить"
		)
		toggle.pressed.emit()
	)


## Проверка (3) не должна стать молчаливой (требование T-173): синтетический
## ScrollContainer с контентом выше окна обязан быть назван нарушением — иначе
## зелёный гейт ничего не значит. Два высоких ребёнка заодно страхуют от
## повторного срабатывания на каждого ребёнка (одно нарушение на контейнер).
## Позитивный кейс (полосы нет) — все экраны набора, кроме двух осознанных
## записей _SCROLL_ALLOWED.
func test_scroll_check_lovit_perepolnenie() -> void:
	var host := Node.new()
	host.name = "ProbeHost"
	get_tree().root.add_child(host)
	auto_free(host)
	var sc := ScrollContainer.new()
	sc.name = "ProbeScroll"
	var inner := VBoxContainer.new()
	inner.custom_minimum_size = Vector2(180, 400)
	sc.add_child(inner)
	var inner2 := VBoxContainer.new()
	inner2.custom_minimum_size = Vector2(120, 400)
	sc.add_child(inner2)
	host.add_child(sc)
	sc.size = Vector2(200, 100)
	await get_tree().process_frame
	var out: Array[String] = []
	_check_scroll("probe", host, out)
	assert_int(out.size()).is_equal(1)
	assert_str(out[0]).contains("ProbeScroll")
	assert_str(out[0]).contains("+700 px")
