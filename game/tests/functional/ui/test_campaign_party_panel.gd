extends BaseTest

## ui-mockup-parity 7.12 + 7.16 + 7.17 — панель отряда, состав кадра и роли темы
## на живом кампейн-HUD.
##
## Почему эти проверки живут здесь, а не в unit-тесте модели: до этого раунда
## партия в кампейне была видна только через верхнюю кнопку, а макет просит
## нижнюю панель со слотами. Проверять «слоты есть» по `PartyScreenModel` —
## значит проверить модель, которая и так зелёная; здесь гейтится связка:
## живой ростер → слоты → экран партии, и то, что элементы реально лежат в кадре
## (нулевой прямоугольник = «текст есть в модели, его нет на экране» — урок
## строки даты, 7.11).
##
## 7.16 — чекер состава вместо пиксельного расстояния. Пиксельная метрика
## паритета мерой не является (задача 7.16: пустой серый кадр против макета даёт
## «80% сходства»), поэтому покрывается реестром: для каждой строки макетного
## реестра — есть ли живой носитель, виден ли он и занимает ли ненулевую область.
## Покрытие печатается в протокол (`COVERAGE:`), чтобы отчёт гейта его видел.
##
## 7.17 — тема вместо ахроматического серого: кегль и гарнитура счётчиков, даты
## и слотов спрашиваются у резолвера движка. Сюжет в том, что роль обязана быть
## объявлена в теме: `theme_type_variation = &"LabelSecundary"` движок молча
## игнорирует, и узел остаётся на базовом типе (16 px движковским белым) — ровно
## тот дефект, который 7.17 и запрещает.
##
## Пикселей макета в репо нет (D-185: путь макета в репо отсутствует), поэтому
## канон состава — реестр `design.md` §7.9–7.17, а не изображение.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const PartyScreenModelScript := preload("res://scripts/ui/party_screen_model.gd")
const CounterRegistryScript := preload("res://scripts/ui/campaign_counters.gd")
const TUTORIAL_OVERLAY_PATH := HUD_PATH + "/TutorialOverlay"
const HUD_PATH := "CampaignHUD/CampaignHud"
const PARTY_PANEL_PATH := HUD_PATH + "/PartyPanel"
const COUNTER_BAR_PATH := HUD_PATH + "/CounterBar"
const DATE_LABEL_PATH := HUD_PATH + "/CampaignDate"
const TOP_BUTTONS_PATH := HUD_PATH + "/TopButtons"
const PARTY_SCREEN_PATH := HUD_PATH + "/PartyScreen"

## Строки макетного реестра, у которых обязан быть живой носитель: id → путь к
## носителю. Счётчики перечисляются отдельно (их строки знает `CounterRegistry`).
const SIMPLE_CARRIERS := {
	"дата (7.11)": DATE_LABEL_PATH,
	"кнопка хода (7.13)": TOP_BUTTONS_PATH + "/TurnButton",
	"кнопка города (7.14)": TOP_BUTTONS_PATH + "/CityButton",
	"кнопка партии (7.14)": TOP_BUTTONS_PATH + "/PartyButton",
	"кнопка журнала (7.14)": TOP_BUTTONS_PATH + "/ChronicleButton",
	"кнопка настроек (7.14)": TOP_BUTTONS_PATH + "/SettingsButton",
	"кнопка меню (7.14)": TOP_BUTTONS_PATH + "/MenuButton",
	"панель отряда (7.12)": PARTY_PANEL_PATH,
	"панель целей (mvp-ui-flow 2.3)": HUD_PATH + "/GoalsPanel",
	"плита Знака (signs-prestige 2.3)": HUD_PATH + "/SignPlaque",
	# D-281 (3.3–3.7) — блоки макета 10, заведённые срезом перестановки.
	"медальон (D-281 3.3)": HUD_PATH + "/Medallion",
	"каркас способностей (D-281 3.4)": HUD_PATH + "/AbilityFrame",
	"повозка (D-281 3.4)": HUD_PATH + "/CartButton",
	"мечи узла хода (D-281 3.5)": HUD_PATH + "/TurnSwordsButton",
	"глобус узла хода (D-281 3.5)": HUD_PATH + "/TurnGlobeButton",
	"миникарта (D-281 3.7)": HUD_PATH + "/CampaignMinimap",
	"сброс выбора (D-281 3.7)": HUD_PATH + "/ResetTile",
}

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false
	super.after_test()


## Кампейн поднимается так же, как его поднимает игра: сцена `main.tscn`,
## `_ready` → `_init_campaign` → привязка слоя. Туториалная модалка перекрывает
## кадр и ловит клики, поэтому она закрывается — её собственная проверка живёт в
## `test_campaign_tutorial_overlay.gd`.
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud := _main.get_node(HUD_PATH) as CampaignHud
	var overlay := _main.get_node_or_null(TUTORIAL_OVERLAY_PATH) as TutorialOverlay
	if overlay != null and overlay.is_open():
		overlay.dismiss()
		await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node(HUD_PATH) as CampaignHud


## ── 7.12 — панель и её слоты ────────────────────────────────────────────────

func test_party_panel_has_capacity_slots() -> void:
	var main := await _boot_campaign()
	var panel := main.get_node_or_null(PARTY_PANEL_PATH) as PanelContainer
	assert_that(panel).is_not_null()
	assert_bool(panel.visible).is_true()
	# Силуэт отряда — два блока по две колонки (D-281); ёмкость распределена
	# между ними, поэтому слоты собираются обходом обоих.
	for block_name in ["PartySlots", "PartySlotsRight"]:
		assert_that(panel.find_child(block_name, true, false)).is_not_null()
	var slots := _slots(main)
	assert_int(slots.size()).is_equal(PartyScreenModelScript.DEFAULT_CAPACITY)
	for i in slots.size():
		assert_str(slots[i].name).is_equal("PartySlot_%d" % i)


## Занятых слотов ровно столько, сколько живых бойцов: мёртвый в бою слота не
## занимает (alive-модель D-221), лишний слот был бы обещанием бойца.
func test_occupied_slots_match_alive_roster() -> void:
	var main := await _boot_campaign()
	var slots := _slots(main)
	var alive := _alive_count(main.composition.party as Array)
	assert_int(alive).is_greater(0)
	assert_int(_occupied(slots)).is_equal(alive)
	# Подписан занятый слот тем же словарём, что экран партии: id и уровень.
	var first := slots[0]
	assert_str(first.text).contains(str(main.composition.party[0].get("id", "")))
	assert_str(first.tooltip_text).contains(str(main.composition.party[0].get("class", "")))


## Пустой слот на выбор не реагирует (спека campaign-hud «Пустой слот»):
## выключенная кнопка не эмитит `pressed` — это гарантия движка, поэтому
## проверяется флаг и пустая подпись.
##
## Ростер специально урезается: стартовая партия может быть полной, и тогда
## цикл «проверить пустые слоты» не проверил бы ничего (тест был бы зелёным при
## любой мутации — тот же класс vacuous-ассертов, который гейтит
## `ci2_vacuous_asserts.py`).
func test_empty_slots_are_inert() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var party: Array = main.composition.party
	while party.size() > 2:
		party.pop_back()
	hud.refresh_campaign(main.game_manager.get_current_day())
	await get_tree().process_frame
	var slots := _slots(main)
	assert_int(_occupied(slots)).is_equal(2)
	for i in range(2, slots.size()):
		assert_bool(slots[i].disabled).is_true()
		assert_str(slots[i].text).is_empty()


## Смерть в бою снимает слот: панель перечитывается тем же `refresh_campaign`,
## что счётчики и дата (хост не обязан вызывать `bind_party` заново). Без этой
## проверки панель осталась бы со «слотом мертвеца» — D-221 (alive-модель)
## действует и здесь.
func test_death_releases_its_slot() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var party: Array = main.composition.party
	var alive := _alive_count(party)
	assert_int(alive).is_greater_equal(2)
	assert_int(_occupied(_slots(main))).is_equal(alive)
	# Смерть — через состояние ростера, как её оставляет бой, и через штатное
	# обновление слоя.
	(party[alive - 1] as Dictionary)["state"] = PartySystem.STATE_DEAD
	hud.refresh_campaign(main.game_manager.get_current_day())
	await get_tree().process_frame
	var slots := _slots(main)
	assert_int(_occupied(slots)).is_equal(alive - 1)
	assert_bool(slots[alive - 1].disabled).is_true()
	assert_str(slots[alive - 1].text).is_empty()


## Клик по занятому слоту открывает экран партии — проверка идёт от сигнала UI
## (урок T-131: вызов системного метода напрямую прятал три падения резолвера).
func test_occupied_slot_opens_party_screen() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var party_screen := main.get_node_or_null(PARTY_SCREEN_PATH) as Control
	assert_that(party_screen).is_not_null()
	assert_bool(party_screen.visible).is_false()
	var slots := _slots(main)
	assert_bool(slots[0].disabled).is_false()
	slots[0].pressed.emit()
	await get_tree().process_frame
	assert_bool(party_screen.visible).is_true()
	assert_bool(hud.is_party_screen_open()).is_true()
	# Инвариант одного видимого экрана: партия открыта поверх кампании, но не
	# вместе с чужим экраном.
	assert_bool(hud.is_city_screen_open()).is_false()


## ── 7.17 — тема вместо ахроматического серого ───────────────────────────────

func test_hud_elements_resolve_from_theme_roles() -> void:
	var main := await _boot_campaign()
	# Эталон — тема проекта, а не `ThemeDB.get_default_theme()`: последний отдаёт
	# движковский fallback, где проектных ролей нет вовсе (у него LabelNumber
	# резолвится в 16 — ровно те 16, от которых 7.17 и уходит).
	var base := load("res://assets/theme/game_theme.tres") as Theme
	# Счётчики — «числа/статы» гайда §2: `LabelNumber` (20, PT Mono, пергамент).
	# Ячейка ищется по имени: первым ребёнком полосы стоит плита-носитель (T-280).
	var bar := main.get_node(COUNTER_BAR_PATH) as Control
	var first := ""
	for child in bar.get_children():
		if String(child.name).begins_with("Counter_"):
			first = String(child.name)
			break
	assert_str(first).is_not_empty()
	var value := bar.get_node(NodePath(first)).get_node("Value") as Label
	assert_str(str(value.theme_type_variation)).is_equal("LabelNumber")
	assert_int(value.get_theme_font_size("font_size")).is_equal(
		int(base.get_font_size(&"font_size", &"LabelNumber")))
	assert_str(str(value.get_theme_font("font").resource_path)).contains("PT_Mono")
	# Дата — вторичная строка (`LabelSecondary`, 16).
	var date := main.get_node(DATE_LABEL_PATH) as Label
	assert_str(str(date.theme_type_variation)).is_equal("LabelSecondary")
	assert_int(date.get_theme_font_size("font_size")).is_equal(
		int(base.get_font_size(&"font_size", &"LabelSecondary")))
	# Полоса кнопок и слоты — роль `ButtonAction` с плитой кита (носитель дописан
	# к роли именем варианта темы, T-280), а не дефолт `Button`.
	var turn := main.get_node(TOP_BUTTONS_PATH + "/TurnButton") as Button
	assert_str(str(turn.theme_type_variation)).is_equal("ButtonAction_turn_button")
	for slot in _slots(main):
		assert_str(str(slot.theme_type_variation)).is_equal("ButtonAction_plate_slot")
	# Панель отряда — та же карточка поля, что панель целей, только с плитой кита.
	var panel := main.get_node(PARTY_PANEL_PATH) as PanelContainer
	assert_str(str(panel.theme_type_variation)).is_equal("PanelCard_plate_party")


## ── 7.16 — чекер состава кадра ──────────────────────────────────────────────

## Для каждой строки макетного реестра: носитель есть, он виден и занимает
## ненулевую область. Печатается покрытие — отчёт гейта обязан его видеть.
func test_frame_composition_coverage_is_complete() -> void:
	var main := await _boot_campaign()
	# Плита Знака — носитель, привязанный к состоянию: без выбранного Знака её
	# нет (раннер и препрейм-тесты). Игровой путь Знак выбирает всегда, поэтому
	# покрытие считается по кампании со Знаком, а не по голому запуску.
	main.composition.set_sign("spark")
	_hud().refresh_campaign(main.game_manager.get_current_day())
	await get_tree().process_frame
	var total := 0
	var covered := 0
	var frame := (main.get_node(HUD_PATH) as Control).get_global_rect()
	var missing: PackedStringArray = PackedStringArray()
	for label in SIMPLE_CARRIERS:
		total += 1
		if _carrier_in_frame(main.get_node_or_null(NodePath(String(SIMPLE_CARRIERS[label]))), frame):
			covered += 1
		else:
			missing.append("%s → %s" % [label, SIMPLE_CARRIERS[label]])
	var hidden: PackedStringArray = PackedStringArray()
	for row in CounterRegistryScript.rendered_rows():
		total += 1
		var row_id := StringName(row.get("id", &""))
		var box := main.get_node(COUNTER_BAR_PATH).get_node_or_null(
			"Counter_%s" % String(row_id)) as Control
		if _carrier_in_frame(box, frame):
			covered += 1
		elif _hud().get_counter_text(row_id) == "":
			# Счётчик скрыт по значению, а не по небрежности: реестр сам решает,
			# какую строку показывать (город без кристаллов не обязан врать
			# нулём). Это не отсутствие носителя — но и не покрытие кадра.
			hidden.append(String(row_id))
		else:
			missing.append("счётчик %s" % String(row_id))
	var slots := _slots(main)
	for i in slots.size():
		total += 1
		if _carrier_in_frame(slots[i], frame):
			covered += 1
		else:
			missing.append("слот отряда %d" % i)
	var shown := int(100.0 * covered / maxi(total, 1))
	print("COVERAGE: состав кадра кампейн-HUD — %d/%d (%d%%); скрыто по значению: %s;" % [
		covered, total, shown,
		"нет" if hidden.is_empty() else ", ".join(hidden),
	])
	print("COVERAGE: отсутствующее: %s" % (
		"нет" if missing.is_empty() else ", ".join(missing)))
	# «Скрыто по значению» — не дырка в составе, но и не покрытый элемент: сумма
	# видимого и скрытого обязана давать реестр целиком, иначе где-то носитель
	# потерялся молча.
	assert_int(hidden.size() + covered).is_equal(total)
	assert_int(missing.size()).is_equal(0)


## Носитель «в кадре» = узел виден и его глобальный прямоугольник ненулевой.
## Нулевой прямоугольник при непустом тексте — ровно тот дефект, из-за которого
## строка даты существовала в модели и исчезала на экране.
## Носитель считается покрытым кадром, только он видим, ненулевой и **целиком
## лежит в кадре**: узел, свесившийся за нижнюю кромку (плита Знака дорастала за
## окно на 72 px — урок этого среза), на глаз не виден, а по прежней мере «просто
## ненулевой прямоугольник» засчитывался покрытым.
func _carrier_in_frame(node: Node, frame: Rect2) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var control := node as Control
	if control == null:
		return false
	var item := control
	while item != null:
		if not item.visible:
			return false
		item = item.get_parent() as Control
	var rect := control.get_global_rect()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and frame.encloses(rect.grow(-0.5))


func _alive_count(party: Array) -> int:
	var count := 0
	for member in party:
		if str(member.get("state", PartySystem.STATE_READY)) != PartySystem.STATE_DEAD:
			count += 1
	return count


func _occupied(slots: Array[Button]) -> int:
	var count := 0
	for slot in slots:
		if not slot.disabled:
			count += 1
	return count


func _slots(main: Node) -> Array[Button]:
	var out: Array[Button] = []
	for block_name in ["PartySlots", "PartySlotsRight"]:
		# Блоки лежат внутри `PartyBlocks`, поэтому поиск рекурсивный по имени —
		# иначе тест был бы привязан к промежуточному узлу.
		var block := main.find_child(block_name, true, false)
		if block == null:
			continue
		for child in block.get_children():
			var button := child as Button
			if button != null:
				out.append(button)
	return out
