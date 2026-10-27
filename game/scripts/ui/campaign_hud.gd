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
## ui-mockup-parity 7.12 — панель отряда снизу и её слоты (`PartySlot_0…4`).
const PARTY_PANEL_NAME := "PartyPanel"
const PARTY_SLOTS_NAME := "PartySlots"
## Правый блок силуэта отряда (макет: второй блок за латунной перегородкой).
## Узел заведён отдельным, потому что между блоками макета стоит медальон и
## один контейнер на два блока не оставил бы зазора (D-281, задача 3.2).
const PARTY_SLOTS_RIGHT_NAME := "PartySlotsRight"
const PARTY_SLOT_NAME := "PartySlot"
## Слотов в левом блоке силуэта: макет рисует блок 2×2, остальное до ёмкости
## (`PartyScreenModel.DEFAULT_CAPACITY`) уходит в правый блок (D-281).
const PARTY_BLOCK_LEFT_SLOTS := 4
const GOALS_TITLE_NAME := "GoalsTitle"
const GOALS_LIST_NAME := "GoalsList"
## mvp-ui-flow 2.2 (T-186): туториал-оверлей первых ходов (K-M8: оверлей, не экран).
const TUTORIAL_OVERLAY_NAME := "TutorialOverlay"
const CITY_SCREEN_NAME := "CityScreen"
const PARTY_BUTTON_NAME := "PartyButton"
const PARTY_SCREEN_NAME := "PartyScreen"
const SETTINGS_BUTTON_NAME := "SettingsButton"
const MENU_BUTTON_NAME := "MenuButton"
const SETTINGS_SCREEN_NAME := "SettingsScreen"
const CHRONICLE_BUTTON_NAME := "ChronicleButton"
const CHRONICLE_SCREEN_NAME := "ChronicleScreen"
const SIGN_PLAQUE_NAME := "SignPlaque"
const SIGN_NAME_LABEL_NAME := "SignName"
const SIGN_RANK_LABEL_NAME := "SignRank"
const SIGN_PRESTIGE_LABEL_NAME := "SignPrestige"
## D-281 (задачи 3.3–3.7) — блоки макета 10, заведённые этим срезом. Имена узлов
## читают тесты места и съёмка, поэтому они константы, а не литералы.
const MEDALLION_NAME := "Medallion"
const MEDALLION_BADGE_NAME := "MedallionBadge"
const ABILITY_FRAME_NAME := "AbilityFrame"
const CART_BUTTON_NAME := "CartButton"
const MINIMAP_NAME := "CampaignMinimap"
const RESET_TILE_NAME := "ResetTile"
## Ячеек каркаса способностей — сколько рисует макет (8), а не сколько есть
## носителю: способностей в данных нет, блок зарезервирован под них (T-244).
const ABILITY_CELLS := 8
const TURN_SIDE_BUTTON_NAMES: Array[String] = ["TurnSwordsButton", "TurnGlobeButton"]
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
var _top_row: Control = null
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
## 7.12 — панель отряда: ряд слотов и сами кнопки. Данных здесь нет: слоты
## читают `PartyScreenModel` поверх `_party` при каждом обновлении (D-200).
var _party_panel: Control = null
var _party_slots_row: Container = null
var _party_slots_right: Container = null
var _party_slots: Array[Button] = []
## signs-prestige 2.3 — плита Знака (имя, титул ранга, Престиж). Как и у панели
## отряда, значений здесь нет: композиция — единственный носитель Престижа
## (K-M16), слой только печатает её числа (D-200).
var _composition: CampaignComposition = null
var _sign_plaque: PanelContainer = null
var _sign_name: Label = null
var _sign_rank: Label = null
var _sign_prestige: Label = null
## mvp-ui-flow 2.2 (T-186): модалка первой директивы. Как и панель целей, слоя
## без данных не имеет: без привязанных директив оверлей не показывается
## (конвенция «нет несуществующих действий»). Директивы — `campaign.json →
## tutorial`, их приносит хост.
var _tutorial: TutorialOverlay = null
var _tutorial_directives: Dictionary = {}
## Последний день, который хост показал слою. Своего счёта дней у HUD нет
## (D-200) — это значение того же пуша, что рисует дату.
var _campaign_day: int = 0
## D-281 — медальон, каркас способностей, миникарта и сброс выбора. Значений
## здесь ни у чего нет: доля месяца считается из календаря, бейдж — из трекера
## целей, точки миникарты и выбор региона — из поля карты (D-200).
var _medallion: Button = null
var _medallion_ring: RingProgress = null
var _medallion_badge: Label = null
## Журнал целей открыт? Панель целей (D-241) живёт как жила, медальон — только
## вход в неё: клик прячет и показывает, ничего не пересчитывая.
var _goals_journal_open: bool = true
var _cart_button: Button = null
var _turn_side_buttons: Array[Button] = []
var _minimap: CampaignMinimap = null
var _reset_tile: Button = null
var _map_field: CampaignMapField = null
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
	_campaign_day = day
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
	# Состав партии меняется не только в момент привязки (тренировка, бой, смерть),
	# а `refresh_campaign` — единная точка обновления слоя; `bind_party` хост
	# вызывает один раз при поднятии кампейна.
	_refresh_party_panel()
	_refresh_sign_plaque()
	# Медальон: прожитая доля месяца (D-281, задача 3.3). Число берётся из
	# календаря, а не из счётчика дней слоя: длину месяца задаёт календарь.
	if _medallion_ring != null:
		var month_day := int(CalendarScript.date_of(day).day)
		_medallion_ring.set_fraction(
			month_day / float(CalendarScript.days_per_month()))
	if _minimap != null:
		_minimap.refresh()
	_refresh_reset_tile()


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

	_top_row = Control.new()
	_top_row.name = "TopButtons"
	_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_row)
	# Хост кнопок — прозрачный `Control` на весь кадр, а не `HBoxContainer`: ряд
	# расставлял кнопки по порядку, тогда как макет 10 кладёт их в разные углы
	# (книга и шестерня — справа сверху, полоса тайлов — слева снизу, узел хода —
	# в правом нижнем). Имя узла оставлено: пути `TopButtons/…` несут семь
	# функциональных тестов и MCP-съёмка; менять их ради переименования незачем.
	# `set_anchors_and_offsets_preset`, а не `set_anchors_preset`: второй сохраняет
	# текущий прямоугольник, а он у только что созданного узла нулевой — ряд
	# собрался размером 0×0 и кнопки схлопнулись в левый верхний угол.
	_top_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
	_build_party_panel()
	_build_sign_plaque()
	# 7.17: полоса кнопок — на роль темы (`ButtonAction`), а не на дефолтный вид
	# `Button`, который в кампании давал ахроматический серый (макет — золото по
	# тёмному). Роль одна на ряд: кнопки ряда однотипны, а локальные оверрайды
	# цвета/кегля запрещены конвенцией T-147/T-148.
	for entry in [
		[&"tile_city", _city_button], [&"tile_party", _party_button],
		[&"tile_menu", _menu_button], [&"button_book", _chronicle_button],
		[&"button_gear", _settings_button], [&"turn_button", _turn_button],
	]:
		var button: Button = entry[1]
		button.theme_type_variation = &"ButtonAction"
		# Размер — по ячейке макета, а не по подписи: минимальный размер кнопки
		# (140×40) шире ячейки 0.04 кадра, и соседние кнопки легли бы друг на
		# друга. Подпись до носителя рисунка (T-247) остаётся текстовой и
		# сокращается многоточием, а не обрезается по пикселю.
		button.custom_minimum_size = Vector2.ZERO
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_place(button, entry[0])
	_build_medallion()
	_build_ability_frame()
	_build_cart_button()
	_build_turn_side_buttons()
	_build_minimap()
	_build_reset_tile()
	_build_tutorial_overlay()


## Место блока по карте элементов макета (D-281): координаты берутся из реестра,
## а не из числа в коде экрана, — блок не может разойтись со своим адресом, а
## сдвиг в реестре автоматически двигает экран.
##
## Каждый блок растянут ровно в свой прямоугольник: у экрана нет ни одного
## собственного числа, с которого можно было бы разойтись с макетом.
func _place(node: Control, element_id: StringName) -> void:
	var rect: Rect2 = CampaignScreenMap.row_by_id(element_id).get("rect", Rect2())
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.anchor_left = rect.position.x
	node.anchor_top = rect.position.y
	node.anchor_right = rect.end.x
	node.anchor_bottom = rect.end.y
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


## 7.10 — полоса счётчиков макета: один контейнер на строку реестра, порядок —
## как в макете слева направо. В макете счётчики выглядят кнопками, но делать
## мёртвые кнопки нельзя (конвенция «нет несуществующих действий»): это метки с
## иконкой, а каноническое имя ресурса уходит в подсказку.
func _build_counter_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = COUNTER_BAR_NAME
	bar.add_theme_constant_override("separation", 0)
	add_child(bar)
	_place(bar, &"counter_frame")
	for row in CounterRegistry.rendered_rows():
		var box := HBoxContainer.new()
		box.name = "Counter_%s" % String(row.get("id", &""))
		box.tooltip_text = CounterRegistry.label_text(row)
		box.add_theme_constant_override("separation", 4)
		# Ячейки полосы делят её ширину поровну: в макете счётчики — равные
		# латунные ячейки, и равная доля ширины есть у каждой строки реестра.
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CounterRegistry.icon(row)
		box.add_child(icon)
		var value := Label.new()
		value.name = "Value"
		# Гайд §2: «Числа/статы — счётчики ресурсов» идут ролью `LabelNumber`
		# (20 PT Mono). Без роли число резолвило 16 px движковским белым без
		# гарнитуры — то есть полоса счётчиков была единственной строкой макета,
		# нарисованной вне темы (7.17).
		value.theme_type_variation = &"LabelNumber"
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
	add_child(date)
	_place(date, &"date_plaque")
	date.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Дата — вторичная строка (гайд §2, `LabelSecondary` 16): она не счётчик, но
	# и не заголовок; роль несёт ещё и гарнитуру с цветом, поэтому «просто кегль»
	# здесь не выбор.
	date.theme_type_variation = &"LabelSecondary"


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


## ui-mockup-parity 7.12 — панель отряда снизу: пять слотов из `PartyScreenModel`.
#
## Слот — не второй список партии, а ярлык к её экрану: занятый слот открывает
## `PartyScreen` тем же путём, что верхняя кнопка, пустой — выключен и на выбор
## не реагирует (спека campaign-hud «Пустой слот», конвенция «нет несуществующих
## действий»). Своего состояния «выбран кто-то» в слое нет намеренно: второй
## носитель выбора разошёлся бы с экраном партии (урок двух носителей населения,
## T-183), а «активный отряд» макета в MVP нечем — партия одна, и это
## зарегистрировано (T-193), а не имитировано подсветкой.
##
## Панель стоит по строке реестра `party_frame` — нижняя полоса, средняя колонка
## (D-281 3.2: сюда она переехала из левого угла). Прямоугольник задан якорями
## строки, размер добирается минимальным размером детей.
func _build_party_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = PARTY_PANEL_NAME
	panel.theme_type_variation = &"PanelCard"
	add_child(panel)
	_place(panel, &"party_frame")
	# Как и панель целей: плита не имеет права перехватывать клики кампании.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# До привязки партии панели нет: пять пустых рамок выглядели бы обещанием
	# отряда, которого нет.
	panel.visible = false
	var blocks := HBoxContainer.new()
	blocks.name = "PartyBlocks"
	blocks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocks.add_theme_constant_override("separation", 12)
	panel.add_child(blocks)
	# Силуэт отряда из макета — два блока по две колонки; между ними в кадре
	# стоит медальон. Ёмкость не меняется: 4 слота в левом блоке, остальное — в
	# правом (D-281; три неиспользуемые ячейки макета не рисуются).
	var row := GridContainer.new()
	row.name = PARTY_SLOTS_NAME
	row.columns = 2
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	blocks.add_child(row)
	var right := GridContainer.new()
	right.name = PARTY_SLOTS_RIGHT_NAME
	right.columns = 2
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 4)
	blocks.add_child(right)
	_party_panel = panel
	_party_slots_row = row
	_party_slots_right = right
	_rebuild_party_slots(_party_capacity)


## Слотов ровно столько, сколько ёмкость партии: `PartyScreenModel` знает про
# `DEFAULT_CAPACITY` (= `CampaignTrainingService.PARTY_CAPACITY`), свою моду
# слой не изобретает.
func _rebuild_party_slots(capacity: int) -> void:
	if _party_slots_row == null:
		return
	for block in [_party_slots_row, _party_slots_right]:
		if block == null:
			continue
		for child in block.get_children():
			block.remove_child(child)
			child.queue_free()
	_party_slots.clear()
	for i in maxi(capacity, 0):
		var slot := Button.new()
		slot.name = "%s_%d" % [PARTY_SLOT_NAME, i]
		slot.theme_type_variation = &"ButtonAction"
		slot.custom_minimum_size = Vector2(96, 52)
		# Пустой слот выключен до первого наполнения: нажатие несуществующего
		# бойца не должно быть действием (7.12, спека «Пустой слот»). Включает и
		# подписывает их `_refresh_party_panel`.
		slot.disabled = true
		slot.pressed.connect(_on_party_slot_pressed)
		# Первые четыре слота — левый блок 2×2, остальные — правый (D-281).
		(_party_slots_row if i < PARTY_BLOCK_LEFT_SLOTS else _party_slots_right).add_child(slot)
		_party_slots.append(slot)


## Слоты читают модель партии, а не своё состояние: `bind_party` получает живой
## массив `composition.party`, поэтому перечисление при каждом обновлении кампейна
## даёт тот же источник, что у экрана партии.
func _refresh_party_panel() -> void:
	if _party_panel == null or _party_slots.is_empty():
		return
	var model: Dictionary = PartyScreenModelScript.roster_model(_party, _party_capacity)
	var shown: Array = []
	for member in (model.get("members", []) as Array):
		# Мёртвый в бою слота не занимает — та же alive-модель (D-221), что у
		# экрана партии и у гейтинга тренировки.
		if str(member.get("state", PartySystem.STATE_READY)) != PartySystem.STATE_DEAD:
			shown.append(member)
	for i in _party_slots.size():
		var slot := _party_slots[i]
		if i >= shown.size():
			slot.disabled = true
			slot.text = ""
			slot.tooltip_text = ""
			continue
		var member: Dictionary = shown[i]
		slot.disabled = false
		slot.text = "%s · ур. %d" % [str(member.get("id", "")), int(member.get("level", 1))]
		slot.tooltip_text = "%s — %s, %s, ур. %d" % [
			str(member.get("id", "")), str(member.get("class", "")),
			str(member.get("race", "")), int(member.get("level", 1)),
		]


## Занятый слот открывает экран партии — тем же путём, что верхняя кнопка (машина
## навигации + перечитывание данных). Пустой слот до обработчика не доходит: он
## `disabled`.
func _on_party_slot_pressed() -> void:
	open_party_screen()


## signs-prestige 2.3 — плита Знака: имя знака, титул ранга и Престиж.
##
## У Престижа до этой правки не было носителя на экране: ранги, титулы и SM Знака
## считались в композиции и попадали на экран только строкой хроники (T-187), а
## `prestige_rank_name()` не читал никто. Плита — не второй счётчик, а печать
## готовых чисел композиции (`prestige_balance`, `prestige_rank_name`,
## `sign_display_name`), поэтому разойтись с носителем она не может (D-200).
##
## Угол — нижний правый: панель целей заняла верх слева, кнопки — верх справа,
## панель отряда и дата — низ слева; правый нижний угол в кадре единственный
## свободный. Пиксельного макета-эталона под рукой нет (D-185), поэтому выбор
## угла — решение слоя, а не сверка с макетом.
##
## Плиты нет до выбора Знака: «Безымянный · Престиж 0» было бы статусом, которого
## игрок ещё не получал (конвенция «нет несуществующих сущностей»), а DORMANT в
## препрейме — штатное состояние раннера и тестов, а не кампания.
func _build_sign_plaque() -> void:
	var panel := PanelContainer.new()
	panel.name = SIGN_PLAQUE_NAME
	panel.theme_type_variation = &"PanelCard"
	# Плита — статус, а не действие: клики кампании она перехватывать не должна.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Строка реестра — однострочная плашка макета (4.5% кадра), а содержимое у
	# плиты четырёхстрочное (имя, титул, престиж, метки задачи): по высоте оно
	# больше своего прямоугольника. Расти обязано вверх, иначе нижний край уходит
	# за нижнюю кромку окна и метки задачи становятся невидимыми.
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.visible = false
	add_child(panel)
	_place(panel, &"sign_plaque")
	var column := VBoxContainer.new()
	column.name = "SignColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	# 7.17: роль темы, а не локальные оверрайды цвета/кегля (T-147/T-148).
	_sign_name = Label.new()
	_sign_name.name = SIGN_NAME_LABEL_NAME
	_sign_name.theme_type_variation = &"LabelStrong"
	column.add_child(_sign_name)
	_sign_rank = Label.new()
	_sign_rank.name = SIGN_RANK_LABEL_NAME
	_sign_rank.theme_type_variation = &"LabelSecondary"
	column.add_child(_sign_rank)
	var prestige_row := HBoxContainer.new()
	prestige_row.name = "SignPrestigeRow"
	prestige_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prestige_row.add_theme_constant_override("separation", 6)
	column.add_child(prestige_row)
	# Подпись у числа обязательна: «240» без подписи — число без рассказа, а
	# вшить число в подпись — потерять роль `LabelNumber` (гайд §2).
	var caption := Label.new()
	caption.name = "SignPrestigeCaption"
	caption.text = GameText.campaign_prestige_label()
	caption.theme_type_variation = &"LabelSecondary"
	prestige_row.add_child(caption)
	_sign_prestige = Label.new()
	_sign_prestige.name = SIGN_PRESTIGE_LABEL_NAME
	_sign_prestige.theme_type_variation = &"LabelNumber"
	prestige_row.add_child(_sign_prestige)
	# Печенье и склянка макета (T-246): предметов провизии и зелий в носителях
	# нет — `HeroInventory` хранит артефакты, а в `data/` таких предметов нет
	# вовсе. Рисуется метка задачи, а не иконка с нулём (D-200).
	var todo_row := HBoxContainer.new()
	todo_row.name = "SignTodoRow"
	todo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	todo_row.add_theme_constant_override("separation", 6)
	column.add_child(todo_row)
	for entry in [
		["SignSuppliesTodo", GameText.campaign_todo_supplies()],
		["SignPotionsTodo", GameText.campaign_todo_potions()],
	]:
		var todo := Label.new()
		todo.name = String(entry[0])
		todo.text = String(entry[1])
		todo.theme_type_variation = &"LabelSecondary"
		todo.tooltip_text = GameText.campaign_todo_hint()
		todo_row.add_child(todo)
	_sign_plaque = panel


## Пересчёт плиты. Вызывается из `refresh_campaign`: Престиж меняется ходами
## (фракционные действия, события), а не только в момент привязки.
func _refresh_sign_plaque() -> void:
	if _sign_plaque == null:
		return
	var sign_id := "" if _composition == null else str(_composition.sign_id)
	_sign_plaque.visible = _composition != null and sign_id != ""
	if not _sign_plaque.visible:
		return
	_sign_name.text = _composition.sign_display_name(sign_id)
	_sign_rank.text = _composition.prestige_rank_name()
	_sign_prestige.text = str(_composition.prestige_balance())


## signs-prestige 2.3 — привязка носителя Престижа. Композиция передаётся как
## есть: у слоя нет права пересчитывать ранг или Престиж (K-M16, D-200).
func bind_sign(value: CampaignComposition) -> void:
	if _composition == value:
		return
	_composition = value
	_refresh_sign_plaque()


## Что плита показывает игроку ("" — плиты нет; тесты и хост читают кадр,
## а не пересчитывают модель).
func get_sign_text() -> String:
	return "" if _sign_plaque == null or not _sign_plaque.visible else _sign_name.text


func get_sign_rank_text() -> String:
	return "" if _sign_plaque == null or not _sign_plaque.visible else _sign_rank.text


func get_prestige_text() -> String:
	return "" if _sign_plaque == null or not _sign_plaque.visible else _sign_prestige.text


## mvp-ui-flow 2.2 (T-186): директивы первых ходов (`campaign.json → tutorial`).
## Пустой словарь = оверлею нечего показывать: слой молчит, а не сочиняет текст.
func bind_tutorial(directives: Dictionary) -> void:
	_tutorial_directives = directives.duplicate(true)


func is_tutorial_open() -> bool:
	return _tutorial != null and _tutorial.is_open()


## Текст показанной директивы ("" — оверлей закрыт). Тест и хост читают то, что
## видит игрок.
func get_tutorial_text() -> String:
	return "" if _tutorial == null else _tutorial.directive_text()


## Ребёнок растянут на весь родителя — так рисуются носитель внутри кнопки
## (кольцо медальона) и плашка без собственной раскладки.
func _fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Медальон нижней полосы (D-281, задача 3.3): кольцо = прожитая доля месяца из
## CampaignCalendar.days_per_month(), бейдж = цели с done == false, клик = журнал
## целей (носитель D-241). Резной ободок макета — T-247; до носителя рисунка
## кольцо рисуется линией.
func _build_medallion() -> void:
	_medallion = Button.new()
	_medallion.name = MEDALLION_NAME
	_medallion.theme_type_variation = &"ButtonAction"
	_medallion.custom_minimum_size = Vector2.ZERO
	_medallion.tooltip_text = GameText.campaign_goals_title()
	_medallion.pressed.connect(_on_medallion_pressed)
	add_child(_medallion)
	_place(_medallion, &"medallion")
	_medallion_ring = RingProgress.new()
	_medallion_ring.name = "MedallionRing"
	_medallion_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion.add_child(_medallion_ring)
	_fill(_medallion_ring)
	_medallion_badge = Label.new()
	_medallion_badge.name = MEDALLION_BADGE_NAME
	_medallion_badge.theme_type_variation = &"LabelNumber"
	_medallion_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion.add_child(_medallion_badge)
	_medallion_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER)


## Клик по медальону — вход/выход журнала целей. Пересчёта целей здесь нет:
## `_refresh_goals` — единственная точка, решающая, что видно.
func _on_medallion_pressed() -> void:
	_goals_journal_open = not _goals_journal_open
	_refresh_goals()


## Каркас способностей (D-281, задача 3.4): восемь пустых ячеек и метка задачи.
## Иконки птицы и лотоса с макета не рисуются: способностей в носителях нет
## (T-244), немой писатель дороже пустой рамки (D-200). Кнопкой ячейка не
## заведена — нажатие без действия было бы тем же враньём.
func _build_ability_frame() -> void:
	var panel := PanelContainer.new()
	panel.name = ABILITY_FRAME_NAME
	panel.theme_type_variation = &"PanelCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_place(panel, &"ability_frame")
	var column := VBoxContainer.new()
	column.name = "AbilityColumn"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var grid := GridContainer.new()
	grid.name = "AbilityCells"
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("separation", 3)
	column.add_child(grid)
	for i in ABILITY_CELLS:
		var cell := Panel.new()
		cell.name = "AbilityCell_%d" % i
		cell.theme_type_variation = &"PanelSlotThin"
		cell.custom_minimum_size = Vector2(26, 26)
		grid.add_child(cell)
	var note := Label.new()
	note.name = "AbilityTodoNote"
	note.text = GameText.campaign_todo_abilities()
	note.theme_type_variation = &"LabelSecondary"
	note.tooltip_text = GameText.campaign_todo_hint()
	column.add_child(note)


## Круглая кнопка повозки (D-281, задача 3.4): вход в городской экран тем же
## путём, что и тайл «Город», — второго носителя города слой не заводит.
## Доступность = доступность городского экрана (`bind_city`).
func _build_cart_button() -> void:
	_cart_button = Button.new()
	_cart_button.name = CART_BUTTON_NAME
	_cart_button.theme_type_variation = &"ButtonAction"
	_cart_button.text = GameText.city_cart()
	_cart_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_cart_button.custom_minimum_size = Vector2.ZERO
	_cart_button.disabled = true
	_cart_button.pressed.connect(_on_city_pressed)
	add_child(_cart_button)
	_place(_cart_button, &"cart_button")


## Две малые кнопки узла хода (D-281, задача 3.5): мечи и глобус макета.
## Экрана-носителя у них нет (T-245), поэтому они нарисованы и выключены:
## кликабельная кнопка без действия обещает то, чего нет.
func _build_turn_side_buttons() -> void:
	for index in TURN_SIDE_BUTTON_NAMES.size():
		var button := Button.new()
		button.name = TURN_SIDE_BUTTON_NAMES[index]
		button.theme_type_variation = &"ButtonAction"
		button.custom_minimum_size = Vector2.ZERO
		button.disabled = true
		button.tooltip_text = GameText.campaign_todo_hint()
		add_child(button)
		_place(button, &"turn_swords" if index == 0 else &"turn_globe")
		_turn_side_buttons.append(button)


## Миникарта левой колонки (D-281, задача 3.7): второй вид того же носителя, что
## у поля карты. Своих координат и своего тумана нет — читает CampaignMapField.
func _build_minimap() -> void:
	_minimap = CampaignMinimap.new()
	_minimap.name = MINIMAP_NAME
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)
	_place(_minimap, &"minimap")


## Четвёртый тайл левой колонки (D-281, задача 3.7): сброс выбора региона.
## Неактивен без выбора — кнопка, которой нечего снимать, обещала бы действие.
func _build_reset_tile() -> void:
	_reset_tile = Button.new()
	_reset_tile.name = RESET_TILE_NAME
	_reset_tile.theme_type_variation = &"ButtonAction"
	_reset_tile.text = GameText.campaign_reset_region()
	_reset_tile.tooltip_text = GameText.campaign_reset_region_hint()
	_reset_tile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reset_tile.custom_minimum_size = Vector2.ZERO
	_reset_tile.disabled = true
	_reset_tile.pressed.connect(_on_reset_tile_pressed)
	add_child(_reset_tile)
	_place(_reset_tile, &"tile_reset")


func _on_reset_tile_pressed() -> void:
	if _map_field != null:
		_map_field.clear_selection()
	_refresh_reset_tile()


func _on_region_selected(_card: Dictionary) -> void:
	_refresh_reset_tile()


func _refresh_reset_tile() -> void:
	if _reset_tile != null:
		_reset_tile.disabled = _map_field == null or _map_field.selected_region() == ""


## Привязка поля карты (D-281, задача 3.7): миникарта и сброс выбора читают тот
## же узел, что рисует карту. `MapScreenModel` — view model без состояния, выбор
## живёт в поле, поэтому второго носителя выбора здесь не появляется.
func bind_map_field(field: CampaignMapField) -> void:
	_map_field = field
	if _minimap != null:
		_minimap.bind_field(field)
	if field != null and not field.region_selected.is_connected(_on_region_selected):
		field.region_selected.connect(_on_region_selected)
	_refresh_reset_tile()


func _build_tutorial_overlay() -> void:
	var overlay := TutorialOverlay.new()
	overlay.name = TUTORIAL_OVERLAY_NAME
	add_child(overlay)
	_tutorial = overlay


## Первый вход в экран (mvp-ui-flow: «* → TUTORIAL … on first entry to a screen»).
## Экран в сигнатуре не нужен: содержимое оверлея — директива дня, а не справка
## про экран; текста про экраны в репо нет ни в одном носителе, и сочинять его
## здесь означало бы изобретать канон.
func _on_tutorial_requested(_screen: StringName) -> void:
	if _tutorial == null or _tutorial_directives.is_empty():
		return
	_tutorial.try_show(
		_campaign_day, String(_tutorial_directives.get("day_%d" % _campaign_day, ""))
	)


## Проводка до машины навигации кампании (`CampaignUIManager`). Порядок важен:
## менеджер привязывается до `bind_city`, иначе экран не будет в нём зарегистрирован.
## Без менеджера носитель работает по-старому — открывает экран напрямую.
func bind_ui_manager(manager: CampaignUIManager) -> void:
	if manager == null or manager == _ui_manager:
		return
	_ui_manager = manager
	_ui_manager.screen_changed.connect(_on_screen_changed)
	# mvp-ui-flow 2.2 (T-186): потребитель `tutorial_requested`. До этого среза
	# сигнал уходил в никуда — «оверлей первых ходов» существовал только в спеке.
	_ui_manager.tutorial_requested.connect(_on_tutorial_requested)


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
	# Повозка макета ведёт в тот же городской экран (D-281, задача 3.4), поэтому и
	# живёт она ровно тогда, когда жив экран: доступность у них общая.
	if _cart_button != null:
		_cart_button.disabled = false


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
	if capacity != _party_capacity:
		# Ёмкость могла прийти из сейва или из другого носителя — слоты
		# перестраиваются, а не прячутся: лишние слоты были бы обещанием бойца.
		_party_capacity = capacity
		_rebuild_party_slots(capacity)
	else:
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
	_refresh_party_panel()
	if _party_panel != null:
		_party_panel.visible = true
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
	_goals_panel.visible = (
		_goals != null and _goals.visible() and _goals_journal_open
	)
	# Бейдж медальона — сколько целей ещё открыто (D-281, задача 3.3). Ноль не
	# печатается: «0» на медальоне читается как «цель есть, но пустая».
	if _medallion_badge != null:
		_medallion_badge.text = "" if pending.is_empty() else str(pending.size())
		_medallion_badge.visible = not pending.is_empty()


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
