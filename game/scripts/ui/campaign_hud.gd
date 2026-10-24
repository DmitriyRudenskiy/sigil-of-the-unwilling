class_name CampaignHud
extends Control
## Слой кампейн-HUD на `main.tscn` — носитель экранов кампании в игровом пути.
##
## ui-mockup-parity §7.1: носитель выбран владельцем (Q-M87 → (б), D-204) —
## новый слой HUD на `main.tscn`, архивный `scenes/archive/world.tscn` не
## реанимируется. До этого слоя `CityScreen` существовал только как сцена без
## вызывающего: из «Новой игры» в него было попасть нечем. Тем же слоем
## поднят и экран партии (`PartyScreen` был техническим экраном без
## вызывающего — его данные, `composition.party`, существуют).
##
## Полоса счётчиков и дата макета подняты здесь же (7.9–7.11); кнопка хода —
## там же (7.4/7.13, указание владельца 2026-10-23: ход по кнопке, авто-таймера
## дня нет). Миникарта с содержимым (§7.15) остаётся незакрытой — у неё нет
## носителя: поля карты в `main.tscn` нет, дата живёт строкой на месте панели.
##
## Дерево строится кодом, как в `city_screen.gd`: сцена-оболочка без единого
## узла — конвенция экранов игры (T-147/T-148: тема через роли, не через
## `theme_override_*`; новых обходов здесь нет — у кнопки только размер).

signal city_screen_opened
signal city_screen_closed
signal party_screen_opened
signal party_screen_closed
signal settings_screen_opened
signal settings_screen_closed
## D-240: хроника поселения — слой не знает содержимое ленты, он просит его
## показать (те же сигналы, что у города и партии: хост по ним выключает ход).
signal chronicle_screen_opened
signal chronicle_screen_closed
## 7.13 — ход кампании запрашивается нажатием. Слой не знает, как устроен ход
## (`CampaignComposition.advance_turn` + `GameManager.on_day_passed` — это
## драйвер в `main.gd`), поэтому просит, а не делает: носитель сигнала — хост.
signal turn_requested
## Выход в главное меню: тот же разбор, что и с ходом. Слой не знает ни про
## сцену меню, ни про сейв — он просит; хост сохраняет кампанийный слот и меняет
## сцену (mvp-ui-flow 5.4: возврата в меню из живого кампейна не было вовсе).
signal menu_requested

const CityScreenScene := preload("res://scenes/ui/city_screen.tscn")
const SettingsScreenScene := preload("res://scenes/ui/settings_screen.tscn")
const ChronicleScreenScene := preload("res://scenes/ui/chronicle_screen.tscn")
const PartyScreenModelScript := preload("res://scripts/ui/party_screen_model.gd")
const CounterRegistry := preload("res://scripts/ui/campaign_counters.gd")
const CalendarScript := preload("res://scripts/campaign/campaign_calendar.gd")

const CITY_BUTTON_NAME := "CityButton"
const TURN_BUTTON_NAME := "TurnButton"
const COUNTER_BAR_NAME := "CounterBar"
const DATE_LABEL_NAME := "CampaignDate"
const GOALS_PANEL_NAME := "GoalsPanel"
const GOALS_TITLE_NAME := "GoalsTitle"
const GOALS_LIST_NAME := "GoalsList"
const CITY_SCREEN_NAME := "CityScreen"
const PARTY_BUTTON_NAME := "PartyButton"
const PARTY_SCREEN_NAME := "PartyScreen"
const SETTINGS_BUTTON_NAME := "SettingsButton"
const MENU_BUTTON_NAME := "MenuButton"
const SETTINGS_SCREEN_NAME := "SettingsScreen"
const CHRONICLE_BUTTON_NAME := "ChronicleButton"
const CHRONICLE_SCREEN_NAME := "ChronicleScreen"
## Экраны в машине навигации кампании: id перехода и куда возвращаться.
const CITY_SCREEN_ID := &"city"
const PARTY_SCREEN_ID := &"party"
const SETTINGS_SCREEN_ID := &"settings"
const CHRONICLE_SCREEN_ID := &"chronicle"
const MAP_SCREEN_ID := &"map"
## Экраны, которыми владеет этот слой: переключение между ними идёт через
## карту (см. `_show_campaign_screen`), чужие экраны (бой) слой не имеет права
## покидать сам.
## Хроника (D-240) — здесь же, хотя по канону навигации (K-M8,
## `CampaignNavigation`) из неё есть один ход — в карту. Соседняя кнопка слоя
## обязана делать этот ход сама (CHRONICLE → MAP → цель): живая на вид кнопка,
## которая молча упирается в отказ навигации, нарушает инвариант «≤2 клика до
## причины» (mvp-ui-flow 3.3) — отказ без причины игроку не объясняют.
const HUD_SCREEN_IDS: Array[StringName] = [
	CITY_SCREEN_ID, PARTY_SCREEN_ID, SETTINGS_SCREEN_ID, CHRONICLE_SCREEN_ID,
]

var city: City = null
var city_screen: CityScreen = null
var party_screen: PartyScreen = null
var settings_screen: SettingsScreen = null
var chronicle_screen: ChronicleScreen = null
var _top_row: HBoxContainer = null
var _city_button: Button = null
var _party_button: Button = null
var _settings_button: Button = null
var _chronicle_button: Button = null
var _menu_button: Button = null
var _turn_button: Button = null
## Защита от повторного нажатия во время обработки хода (7.13): пока эмитится
## `turn_requested`, второе нажатие — не второй ход.
var _turn_handling: bool = false
var _turn_enabled: bool = false
var _ui_manager: CampaignUIManager = null
var _party: Array = []
var _party_capacity: int = PartyScreenModelScript.DEFAULT_CAPACITY
## Носитель ленты (D-240) и состояние открытости хроники. Состояние держится
## флагом, а не по `visible` экрана: машина навигации может погасить слой сама
## (уход в бой), и по `visible` слой не отличил бы это от своего закрытия.
var _chronicle: ChronicleLog = null
var _chronicle_open: bool = false
## mvp-ui-flow 2.3 (T-182, M3): панель целей первых трёх дней. Носитель только
## рисует то, что посчитал `CampaignGoalTracker`; сам трекер живёт в композиции.
## Без привязки панели нет: список целей без носителя обещал бы цели, которых
## никто не проверяет (конвенция «нет несуществующих действий»).
var _goals: CampaignGoalTracker = null
var _goals_panel: PanelContainer = null
var _goals_list: VBoxContainer = null
## Полоса счётчиков: id строки реестра → контейнер счётчика. Значений здесь нет:
## числа читаются из носителя при каждом обновлении (D-200).
var _counters: Dictionary = {}


func _ready() -> void:
	_build()


## 7.10 — единственная точка, из которой полоса и дата получают числа. Здесь
## ничего не запоминается: значения читаются из носителя, дата пересчитывается
## из дня кампании (D-200; спека `campaign-hud`: месяц и неделя пересчитываются,
## а не хранятся). Счётчик, который кампейн-состояние не ведёт, прячется: ноль
## вместо «носителя нет» врал бы.
func refresh_campaign(day: int) -> void:
	for row_id in _counters:
		var box := _counters[row_id] as Control
		if box == null or not is_instance_valid(box):
			continue
		var text := CounterRegistry.value_text(CounterRegistry.row_by_id(row_id), city)
		var value := box.get_node_or_null("Value") as Label
		if value != null:
			value.text = text
		box.visible = text != ""
	var date := get_node_or_null(DATE_LABEL_NAME) as Label
	if date != null:
		date.text = CalendarScript.date_label(day)
	_refresh_goals()


## Текст счётчика по id строки реестра ("" — счётчик не показан).
func get_counter_text(row_id: StringName) -> String:
	var box := _counters.get(row_id) as Control
	if box == null or not is_instance_valid(box) or not box.visible:
		return ""
	var value := box.get_node_or_null("Value") as Label
	return "" if value == null else value.text


## Сколько счётчиков полоса рисует (тест: ровно строки реестра с носителем).
func get_counter_count() -> int:
	var count := 0
	for row_id in _counters:
		var box := _counters[row_id] as Control
		if box != null and is_instance_valid(box) and box.visible:
			count += 1
	return count


func get_date_text() -> String:
	var date := get_node_or_null(DATE_LABEL_NAME) as Label
	return "" if date == null else date.text


## 7.13 — доступность кнопки хода. Её выключает хост (`main.gd`), когда ход
## сделать нельзя: открыт экран кампании (время стоит), идёт кризис (ход не
## игрового экрана), или кампания закончена. Слой не решает это сам — он не
## знает ни про кризис, ни про экран боя.
func set_turn_enabled(value: bool) -> void:
	_turn_enabled = value
	if _turn_button != null:
		_turn_button.disabled = not value


func is_turn_enabled() -> bool:
	return _turn_enabled and _turn_button != null and not _turn_button.disabled


func _build() -> void:
	name = "CampaignHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Слой не имеет права перехватывать ввод кампании: клики проходят сквозь
	# HUD, а кнопки (дети) берут своё как обычно.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_top_row = HBoxContainer.new()
	_top_row.name = "TopButtons"
	_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_row)
	_top_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Ширина ряда под шесть кнопок: 6 × 140 + 5 × 16 separation + 16 отступ.
	_top_row.add_theme_constant_override("separation", 16)
	_top_row.offset_left = -936.0
	_top_row.offset_right = -16.0
	_top_row.offset_top = 16.0
	_top_row.offset_bottom = 56.0

	_city_button = Button.new()
	_city_button.name = CITY_BUTTON_NAME
	_city_button.text = GameText.campaign_city()
	_city_button.custom_minimum_size = Vector2(140, 40)
	# До привязки города кнопки нет: несвязанная кнопка обещала бы нажатие,
	# которого нет (тот же приём, что у пустых медальонов нижней панели боя).
	_city_button.disabled = true
	_city_button.pressed.connect(_on_city_pressed)
	_top_row.add_child(_city_button)

	_party_button = Button.new()
	_party_button.name = PARTY_BUTTON_NAME
	# «Партия», а не «отряд»: по глоссарию партия — персонажи игрока, отряд —
	# военная единица города (02e 12), их путать нельзя.
	_party_button.text = GameText.campaign_party()
	_party_button.custom_minimum_size = Vector2(140, 40)
	_party_button.disabled = true
	_party_button.pressed.connect(_on_party_pressed)
	_top_row.add_child(_party_button)

	_chronicle_button = Button.new()
	_chronicle_button.name = CHRONICLE_BUTTON_NAME
	_chronicle_button.text = GameText.campaign_chronicle()
	_chronicle_button.tooltip_text = GameText.campaign_chronicle_hint()
	_chronicle_button.custom_minimum_size = Vector2(140, 40)
	# Как и с городом/партией: до привязки ленты кнопки нет — без носителя
	# кнопка обещала бы экран, в котором нечего показать.
	_chronicle_button.disabled = true
	_chronicle_button.pressed.connect(_on_chronicle_pressed)
	_top_row.add_child(_chronicle_button)

	_settings_button = Button.new()
	_settings_button.name = SETTINGS_BUTTON_NAME
	_settings_button.text = GameText.campaign_settings()
	_settings_button.custom_minimum_size = Vector2(140, 40)
	# До привязки сервиса настроек кнопки нет: без `Settings` экран настроек сам
	# себя закрывает в `_ready` (конвенция «нет несуществующих действий»). До
	# 2026-10-24 настроек в кампании не было вовсе: из живого кампейна они были
	# недостижимы (экран жил только в меню и в бою).
	_settings_button.disabled = true
	_settings_button.pressed.connect(_on_settings_pressed)
	_top_row.add_child(_settings_button)

	_menu_button = Button.new()
	_menu_button.name = MENU_BUTTON_NAME
	_menu_button.text = GameText.campaign_menu()
	_menu_button.tooltip_text = GameText.campaign_menu_hint()
	_menu_button.custom_minimum_size = Vector2(140, 40)
	# Кнопка включена сразу, в отличие от города и партии: действие существует
	# независимо от привязок — выйти в меню можно всегда, а сохранение перед
	# выходом делает хост. Что именно делает кнопка — в подсказке (7.13).
	_menu_button.pressed.connect(_on_menu_pressed)
	_top_row.add_child(_menu_button)

	_turn_button = Button.new()
	_turn_button.name = TURN_BUTTON_NAME
	# Короткая подпись в ряд с «Город»/«Партия»; что именно делает кнопка —
	# в подсказке (7.13: нажатие завершает ход, а не «следующий день»).
	_turn_button.text = GameText.campaign_turn()
	_turn_button.tooltip_text = GameText.campaign_turn_hint()
	_turn_button.custom_minimum_size = Vector2(140, 40)
	# Кнопка появляется только вместе с драйвером: `main.gd` включает её после
	# того, как подключит `turn_requested`. Нажатие без обработчика обещало бы
	# ход, которого нет (конвенция «нет несуществующих действий»). 7.13: авто-
	# таймера дня нет, и до привязки на экране не остаётся ни одного способа
	# закончить ход — это честно: кампания без драйвера хода не поднята.
	_turn_button.disabled = true
	_turn_button.pressed.connect(_on_turn_pressed)
	_top_row.add_child(_turn_button)
	_build_counter_bar()
	_build_date_label()
	_build_goals_panel()


## 7.10 — полоса счётчиков макета: один контейнер на строку реестра, порядок —
## как в макете слева направо. В макете счётчики выглядят кнопками, но делать
## мёртвые кнопки нельзя (конвенция «нет несуществующих действий»): это метки с
## иконкой, а каноническое имя ресурса уходит в подсказку.
func _build_counter_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = COUNTER_BAR_NAME
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.offset_left = 16.0
	bar.offset_top = 16.0
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for row in CounterRegistry.rendered_rows():
		var box := HBoxContainer.new()
		box.name = "Counter_%s" % String(row.get("id", &""))
		box.tooltip_text = CounterRegistry.label_text(row)
		box.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CounterRegistry.icon(row)
		box.add_child(icon)
		var value := Label.new()
		value.name = "Value"
		box.add_child(value)
		bar.add_child(box)
		_counters[row.get("id", &"")] = box


## 7.11 — дата макета. В макете она живёт в панели миникарты (левый нижний
## угол); панели с содержимым нет — показывать на миникарте нечего, пока в
## игровом пути нет поля карты, поэтому здесь только строка даты на её месте.
##
## Прямоугольник задан всеми четырьмя offset'ами, а не двумя: у пресета
## BOTTOM_LEFT якоря верх/низ стоят на нижней границе, и при `offset_top = 0`
## высота_label'а получается нулевой — текст есть в модели, его нет на экране
## (функциональный тест по `get_date_text()` этого не видит, кадр — да).
func _build_date_label() -> void:
	var date := Label.new()
	date.name = DATE_LABEL_NAME
	date.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	date.offset_left = 24.0
	date.offset_top = -48.0
	date.offset_right = 424.0
	date.offset_bottom = -24.0
	date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(date)


## mvp-ui-flow 2.3 (T-182, M3): панель целей первых трёх дней — левый верхний
## угол, под полосой счётчиков: макетных 8 экранов у HUD нет (D-185: путь
## макета в репо отсутствует), поэтому место выбирается по принципу «не трогать
## занятые зоны»: счётчики слева сверху, кнопки справа сверху, дата слева снизу.
## Карточка — `PanelCard` (поле панели с золотой рамкой), как и остальные панели
## поверх поля; панель скрыта до привязки трекера.
func _build_goals_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = GOALS_PANEL_NAME
	panel.theme_type_variation = &"PanelCard"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 64.0
	panel.offset_right = 356.0
	panel.offset_bottom = 64.0
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var column := VBoxContainer.new()
	column.name = "GoalsColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var title := Label.new()
	title.name = GOALS_TITLE_NAME
	title.text = GameText.campaign_goals_title()
	# Кегль — токенами темы, не оверрайдами (гайд §2). Оговорка: гайд называет роли
	# «подзаголовок 24» (`LabelSubheading`) и «вторичный 16» (`LabelCaption`), а в
	# теме объявлены `LabelStrong` 24 и `LabelSecondary` 16 — те же роли и кегли под
	# другими именами. Расхождение имён темы и гайда — предмет theme-type-hygiene,
	# здесь берётся тот носитель, который реально существует.
	title.theme_type_variation = &"LabelStrong"
	column.add_child(title)
	var list := VBoxContainer.new()
	list.name = GOALS_LIST_NAME
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_theme_constant_override("separation", 2)
	column.add_child(list)
	_goals_panel = panel
	_goals_list = list
	add_child(panel)


## Проводка до машины навигации кампании (`CampaignUIManager`). Порядок важен:
## менеджер привязывается до `bind_city`, иначе экран не будет в нём зарегистрирован.
## Без менеджера носитель работает по-старому — открывает экран напрямую.
func bind_ui_manager(manager: CampaignUIManager) -> void:
	if manager == null or manager == _ui_manager:
		return
	_ui_manager = manager
	_ui_manager.screen_changed.connect(_on_screen_changed)


## Привязка кампейн-города: экран создаётся здесь, а не в `_ready` — слой HUD
## переживает отсутствие города (сейв без города, тест без данных), а экран
## без города показывать нечего.
func bind_city(value: City, rng: RandomNumberGenerator = null) -> void:
	city = value
	if city == null:
		if _city_button != null:
			_city_button.disabled = true
		return
	if city_screen == null:
		city_screen = CityScreenScene.instantiate() as CityScreen
		city_screen.name = CITY_SCREEN_NAME
		# Экран закрыт до `open()`: корневой Control сцены видим по умолчанию,
		# и без этого шага он лег бы поверх кампании сразу после загрузки.
		city_screen.visible = false
		city_screen.close_requested.connect(_on_city_screen_close_requested)
		add_child(city_screen)
		# Экран живёт в носителе, но активным экраном он становится только через
		# машину навигации: иначе `visible_screens()` врёт, а чужой переход
		# (бой, партия) не гасит город.
		if _ui_manager != null:
			_ui_manager.register_screen(CITY_SCREEN_ID, city_screen)
	# Герой кампейн-слоя — не `HeroController` (партия — словари ростера),
	# а карта кампейна — не `MapGenerator`: экран принимает город и без них
	# (подпись переносимого груза и рельеф клеток тогда просто не рисуются).
	city_screen.setup(city, null, city.center, rng, Vector2i.ZERO, Callable())
	_city_button.disabled = false


## Привязка партии: экран создаётся здесь, как и город — слой переживает
## тест без данных и ростер, которого ещё нет. Ёмкость — из модели экрана
## (там же, откуда её берёт ростер), хост может передать свою.
## Граница: опций в этом экране нет, но уже не из-за сервиса — живая форма
## `CampaignTrainingService.available_training_actions_city` читает `City` (T-170,
## вариант (а)); кнопки заявки в HUD слоя кампании нет, она относится к UI-слою города
## (`mvp-ui-flow`), и за ней ux-review. Dict-форма `available_training_actions`
## остаётся наследием T-110 — вычищается в T-171.
func bind_party(party: Array, capacity: int = PartyScreenModelScript.DEFAULT_CAPACITY) -> void:
	_party = party
	_party_capacity = capacity
	if _party_button == null:
		return
	if party_screen == null:
		party_screen = PartyScreen.new()
		party_screen.name = PARTY_SCREEN_NAME
		# Экран закрыт до открытия: корневой Control видим по умолчанию, и без
		# этого шага он лёг бы поверх кампании сразу после загрузки.
		party_screen.visible = false
		add_child(party_screen)
		if _ui_manager != null:
			_ui_manager.register_screen(PARTY_SCREEN_ID, party_screen)
	refresh_party_screen()
	_party_button.disabled = false


## Привязка трекера целей M3 (хост вызывает её вслед за поднятием кампании).
## Смена трекера переподключается: загрузка сейва приносит другой объект
## (`CampaignGoalTracker.from_dict`), и панель обязана слушать новый, а не вчерашний.
func bind_goals(tracker: CampaignGoalTracker) -> void:
	if tracker == _goals:
		return
	if _goals != null and _goals.goal_completed.is_connected(_on_goal_completed):
		_goals.goal_completed.disconnect(_on_goal_completed)
	_goals = tracker
	if _goals != null and not _goals.goal_completed.is_connected(_on_goal_completed):
		_goals.goal_completed.connect(_on_goal_completed)
	_refresh_goals()


## Текст строки цели (тест и хост читают то, что видит игрок; "" — панель не привязана).
func get_goal_text(goal_id: String) -> String:
	if _goals_list == null:
		return ""
	var row := _goals_list.get_node_or_null("Goal_%s" % goal_id) as Label
	return "" if row == null else row.text


## Список незакрытых целей, сгруппированных по дням. Панель видна, пока цели не
## закрыты все (`CampaignGoalTracker.visible()`), и прячется целиком: «всё
## сделано» — это отсутствие панели, а не пустой список под заголовком.
func _refresh_goals() -> void:
	if _goals_panel == null or _goals_list == null:
		return
	for child in _goals_list.get_children():
		_goals_list.remove_child(child)
		child.queue_free()
	var pending: Array = [] if _goals == null else _goals.pending()
	# pending() сохраняет порядок трекера, а он приходит из сейва любым. Заголовки
	# дней печатаются сменой дня, поэтому список приводится к порядку по дню: иначе
	# две цели дня 1, разнесённые целью дня 2, дали бы два заголовка «День 1».
	pending.sort_custom(func(a, b): return int(a.get("day", 0)) < int(b.get("day", 0)))
	var day := -1
	for goal in pending:
		var goal_day := int(goal.get("day", 0))
		if goal_day != day:
			_daily_header(goal_day)
			day = goal_day
		var row := Label.new()
		var goal_id := String(goal.get("id", ""))
		row.name = "Goal_%s" % goal_id
		row.text = "· %s" % GameText.campaign_goal(goal_id)
		row.theme_type_variation = &"LabelBody"
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_goals_list.add_child(row)
	_goals_panel.visible = _goals != null and _goals.visible()


## Заголовок дня внутри списка целей.
func _daily_header(goal_day: int) -> void:
	var head := Label.new()
	head.name = "GoalDay%d" % goal_day
	head.text = GameText.campaign_goal_day(goal_day)
	head.theme_type_variation = &"LabelSecondary"
	_goals_list.add_child(head)


func _on_goal_completed(_goal_id: String) -> void:
	_refresh_goals()


func open_city_screen() -> void:
	if city_screen == null:
		return
	# Открытие идёт через SM: отказ машины (переход запрещён из боя, партии,
	# хроники) оставляет кампанию в её экране, а не кладёт город поверх.
	if not _show_campaign_screen(CITY_SCREEN_ID):
		return
	_open_city_screen()


func open_party_screen() -> void:
	if party_screen == null:
		return
	if not _show_campaign_screen(PARTY_SCREEN_ID):
		return
	# Данные партии меняются между открытиями (бой, тренировка, ход) — экран
	# перечитывается при каждом открытии, а не один раз при привязке.
	refresh_party_screen()
	_open_party_screen()


func close_city_screen() -> void:
	if city_screen == null or not city_screen.is_open():
		return
	if _ui_manager != null:
		_ui_manager.show_screen(MAP_SCREEN_ID)
	_close_city_screen()


func close_party_screen() -> void:
	if party_screen == null or not party_screen.visible:
		return
	if _ui_manager != null:
		_ui_manager.show_screen(MAP_SCREEN_ID)
	_close_party_screen()


func is_city_screen_open() -> bool:
	return city_screen != null and city_screen.is_open()


func is_party_screen_open() -> bool:
	return party_screen != null and party_screen.visible


func refresh_city_screen() -> void:
	if city_screen != null and city_screen.is_open():
		city_screen.refresh()


func refresh_party_screen() -> void:
	if party_screen != null:
		party_screen.refresh(_party, _party_capacity, [])


## Привязка настроек: экран создаётся здесь же, что город и партия. Порядок
## вызовов важен: `setup()` до `add_child` (иначе `_ready` не найдёт сервис и
## экран закроет себя сам), `persistent = true` до первого закрытия (без него
## `_do_close()` освободил бы узел, а ссылка слоя осталась бы висячей),
## `show_additional = false` — потому что дополнительный блок настроек это
## контекст меню («Арена», «Хроника», предпросмотр модели): в кампании арена и
## предпросмотр не играют, а его `chronicle_requested` в кампейне некем слушается
## — кнопка была бы мёртвой. Кампейнская лента (D-240) — своя кнопка слоя.
func bind_settings(settings: Node) -> void:
	if settings == null:
		return
	if settings_screen == null or not is_instance_valid(settings_screen):
		settings_screen = SettingsScreenScene.instantiate() as SettingsScreen
		settings_screen.name = SETTINGS_SCREEN_NAME
		settings_screen.persistent = true
		settings_screen.show_additional = false
		settings_screen.setup(settings)
		add_child(settings_screen)
		settings_screen.visible = false
		settings_screen.closed.connect(_on_settings_screen_closed)
		if _ui_manager != null:
			_ui_manager.register_screen(SETTINGS_SCREEN_ID, settings_screen)
	if _settings_button != null:
		_settings_button.disabled = false


func open_settings_screen() -> void:
	if settings_screen == null:
		return
	if not _show_campaign_screen(SETTINGS_SCREEN_ID):
		return
	settings_screen.visible = true
	settings_screen_opened.emit()


func close_settings_screen() -> void:
	if settings_screen == null or not settings_screen.visible:
		return
	if _ui_manager != null:
		_ui_manager.show_screen(MAP_SCREEN_ID)
	_close_settings_screen()


func is_settings_screen_open() -> bool:
	return settings_screen != null and is_instance_valid(settings_screen) \
		and settings_screen.visible


func _on_settings_pressed() -> void:
	if is_settings_screen_open():
		close_settings_screen()
	else:
		open_settings_screen()


func _on_settings_screen_closed() -> void:
	close_settings_screen()


func _on_menu_pressed() -> void:
	menu_requested.emit()


## Привязка хроники (D-240): экран создаётся здесь же, что город и партия.
## Кнопка включается только с носителем ленты: без `ChronicleLog` экран показывал
## бы пустоту там, где у кампании просто не было событий.
func bind_chronicle(log: ChronicleLog) -> void:
	if log == null:
		return
	_chronicle = log
	if chronicle_screen == null or not is_instance_valid(chronicle_screen):
		chronicle_screen = ChronicleScreenScene.instantiate() as ChronicleScreen
		chronicle_screen.name = CHRONICLE_SCREEN_NAME
		add_child(chronicle_screen)
		chronicle_screen.closed.connect(_on_chronicle_screen_closed)
		if _ui_manager != null:
			_ui_manager.register_screen(CHRONICLE_SCREEN_ID, chronicle_screen)
	if _chronicle_button != null:
		_chronicle_button.disabled = false


## Лента перечитывается при каждом открытии: записи добавляются ходами, а экран
## не имеет права показывать состояние на момент привязки (тот же приём, что у
## партии).
func refresh_chronicle_screen() -> void:
	if chronicle_screen == null or not is_instance_valid(chronicle_screen) \
			or _chronicle == null:
		return
	chronicle_screen.show_records(_chronicle.records())


func open_chronicle_screen() -> void:
	if chronicle_screen == null or _chronicle == null or _chronicle_open:
		return
	if not _show_campaign_screen(CHRONICLE_SCREEN_ID):
		return
	_chronicle_open = true
	refresh_chronicle_screen()
	chronicle_screen_opened.emit()


func close_chronicle_screen() -> void:
	if not _chronicle_open:
		return
	# Закрытие идёт через машину: она гасит слой и возвращает кампанию на карту.
	if _ui_manager != null and _ui_manager.current_screen() == CHRONICLE_SCREEN_ID:
		_ui_manager.show_screen(MAP_SCREEN_ID)
	_finish_chronicle_close()


func is_chronicle_screen_open() -> bool:
	return _chronicle_open and chronicle_screen != null \
			and is_instance_valid(chronicle_screen) and chronicle_screen.visible


func _on_chronicle_pressed() -> void:
	if is_chronicle_screen_open():
		close_chronicle_screen()
	else:
		open_chronicle_screen()


## Экран погасил себя сам (своя кнопка «Закрыть»): слой догоняет машину, иначе
## навигация осталась бы на хронике, а кнопка хода — выключенной.
func _on_chronicle_screen_closed() -> void:
	close_chronicle_screen()


func _finish_chronicle_close() -> void:
	if not _chronicle_open:
		return
	_chronicle_open = false
	if chronicle_screen != null and is_instance_valid(chronicle_screen):
		chronicle_screen.visible = false
	chronicle_screen_closed.emit()


func _on_city_pressed() -> void:
	if is_city_screen_open():
		close_city_screen()
	else:
		open_city_screen()


func _on_city_screen_close_requested() -> void:
	close_city_screen()


## 7.13 — нажатие просит ход ровно один раз. Замок держится на время обработки:
## повторный `pressed` внутри того же кадра (двойной клик, скриптовый эмит из
## теста, наведение клавиши ввода) не должен давать второй `advance_turn` —
## задвоенный ход менял бы дату и счётчики дважды.
func _on_turn_pressed() -> void:
	if _turn_handling or not _turn_enabled:
		return
	_turn_handling = true
	turn_requested.emit()
	_turn_handling = false


func _on_party_pressed() -> void:
	if is_party_screen_open():
		close_party_screen()
	else:
		open_party_screen()


## Esc закрывает экран, у которого своего выхода нет: у `CityScreen` есть и
## кнопка, и свой обработчик Esc; технический экран партии выхода не имеет,
## а ложится поверх кнопок — без этого шага из него не было бы выхода.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if is_party_screen_open():
			close_party_screen()
			get_viewport().set_input_as_handled()
		elif is_settings_screen_open():
			# Экран настроек закрывается своей «Отменой», но Esc — ожидание игрока,
			# а не выход из-за экрана: закрытие идёт тем же путём, что и кнопка.
			close_settings_screen()
			get_viewport().set_input_as_handled()
		elif is_chronicle_screen_open():
			# У ленты своего Esc-выхода нет (экран знает только «Закрыть»), а по
			# канону из неё один переход — в карту: без этой ветки она закрывалась
			# бы только мышью.
			close_chronicle_screen()
			get_viewport().set_input_as_handled()


## Смена активного экрана машиной, а не игроком: уход в бой/партию/хронику
## закрывает город, иначе под следующим экраном остался бы живой открытый город.
## То же для партии — экраны переключаются, а не складываются стопкой.
func _on_screen_changed(screen: StringName) -> void:
	if screen != CITY_SCREEN_ID:
		_close_city_screen()
	if screen != PARTY_SCREEN_ID:
		_close_party_screen()
	if screen != SETTINGS_SCREEN_ID:
		_close_settings_screen()
	if screen != CHRONICLE_SCREEN_ID:
		_finish_chronicle_close()


func _open_city_screen() -> void:
	city_screen.open()
	city_screen_opened.emit()


func _close_city_screen() -> void:
	if city_screen == null or not city_screen.is_open():
		return
	city_screen.close()
	city_screen_closed.emit()


func _open_party_screen() -> void:
	party_screen.visible = true
	party_screen_opened.emit()


func _close_party_screen() -> void:
	if party_screen == null or not party_screen.visible:
		return
	party_screen.visible = false
	party_screen_closed.emit()


func _close_settings_screen() -> void:
	if settings_screen == null or not is_instance_valid(settings_screen) \
			or not settings_screen.visible:
		return
	settings_screen.visible = false
	settings_screen_closed.emit()


## Открыть экран кампании через машину. Между двумя экранами слоя машина
## перехода не даёт (`CITY→PARTY` запрещён), поэтому смена идёт через карту:
## тот же легальный путь, что и закрытие. С чужого экрана (бой, хроника) слой
## сам не сходит — отказ машины остаётся отказом.
func _show_campaign_screen(id: StringName) -> bool:
	if _ui_manager == null:
		return true
	var current := _ui_manager.current_screen()
	if current != MAP_SCREEN_ID and current != id and HUD_SCREEN_IDS.has(current):
		_ui_manager.show_screen(MAP_SCREEN_ID)
	return bool(_ui_manager.show_screen(id).get("ok", false))
