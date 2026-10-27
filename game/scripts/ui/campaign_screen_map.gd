class_name CampaignScreenMap
extends RefCounted
## Поэлементная карта макета экрана кампании (`reference/10_map_campaign_town.jpeg`,
## строка 10 карты `reference/INDEX.md`, D-203) и единственный способ спросить,
## **что** обязано лежать в кадре и **чем** оно наполнено.
##
## Реестр — данные, не код экрана (D-200, тот же приём, что у `CampaignCounters`):
## `campaign_hud.gd` и гард состава спрашивают у него состав, сами списка узлов не
## хранят. Строка без носителя данных (`data`) и без задачи (`ticket`) — «немой
## писатель», её роняет `tests/unit/ui/test_campaign_screen_map.gd`; то же к
## рисунку (`art`).
##
## `rect` — нормализованные доли кадра макета (2752×1536), снятые с него же;
## `cell` — адрес ячейки сетки 10×10 (`scripts/ui_grid.py`), которым тред говорит
## об элементе. Адрес вычислен из центра `rect`, и тест сверяет объявленный адрес
## с вычисленным, чтобы «кнопка в D5» не разъехалась с координатой.
##
## `node` — имя узла-носителя в экране (`find_child` от `main.tscn`), пустое —
## узла ещё нет, элемент считается скрытым и попадает в реестр скрытых приёмки.
## Гард состава (`tests/functional/ui/test_campaign_hud_composition.gd`) считает
## по нему `COVERAGE n/m`.
##
## Порядок строк внутри блока = порядок элементов макета слева направо (сверху
## вниз для вертикальных полос). Верхняя полоса обязана совпадать с порядком
## `CampaignCounters.ROWS` — расхождение порядка ловит тест.

const FRAME_W := 2752.0
const FRAME_H := 1536.0
const ALPHABET := "ABCDEFGHIJ"

const BLOCKS: Array[StringName] = [
	&"top_counters", &"top_right", &"bottom_band", &"turn_cluster", &"left_column", &"map_field",
]

const ROWS: Array[Dictionary] = [
	{
		"id": &"counter_frame", "block": &"top_counters", "cell": "C1",
		"node": "CounterBar",
		"rect": Rect2(0.0, 0.004, 0.585, 0.055),
		"data": &"CampaignCounters", "art": &"", "ticket": "T-247",
		"mockup": "латунная рамка полосы с разделителем и орнаментом конца",
	},
	{
		"id": &"counter_crystals", "block": &"top_counters", "cell": "A1",
		"node": "Counter_crystals",
		"rect": Rect2(0.0, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"IconRegistry", "ticket": "T-159",
		"mockup": "синий кристалл «14»",
	},
	{
		"id": &"counter_drop_red", "block": &"top_counters", "cell": "B1",
		"node": "Counter_drop_red",
		"rect": Rect2(0.0731, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"", "ticket": "T-159",
		"mockup": "красная капля «0»",
	},
	{
		"id": &"counter_food", "block": &"top_counters", "cell": "B1",
		"node": "Counter_food",
		"rect": Rect2(0.1462, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"IconRegistry", "ticket": "",
		"mockup": "сноп «13»",
	},
	{
		"id": &"counter_gem_green", "block": &"top_counters", "cell": "C1",
		"node": "Counter_gem_green",
		"rect": Rect2(0.2193, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"", "ticket": "T-159",
		"mockup": "зелёный кристалл «1»",
	},
	{
		"id": &"counter_sack", "block": &"top_counters", "cell": "D1",
		"node": "Counter_sack",
		"rect": Rect2(0.2924, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"IconRegistry", "ticket": "T-159",
		"mockup": "мешок «31»",
	},
	{
		"id": &"counter_wood", "block": &"top_counters", "cell": "E1",
		"node": "Counter_wood",
		"rect": Rect2(0.3655, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"IconRegistry", "ticket": "",
		"mockup": "брёвна «51»",
	},
	{
		"id": &"counter_ore", "block": &"top_counters", "cell": "E1",
		"node": "Counter_ore",
		"rect": Rect2(0.4386, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"IconRegistry", "ticket": "",
		"mockup": "руда «34»",
	},
	{
		"id": &"counter_gold", "block": &"top_counters", "cell": "F1",
		"node": "Counter_gold",
		"rect": Rect2(0.5117, 0.004, 0.0731, 0.05),
		"data": &"CampaignCounters", "art": &"", "ticket": "T-159",
		"mockup": "монеты «246»",
	},
	{
		"id": &"counter_ninth", "block": &"top_counters", "cell": "G1",
		"node": "",
		"rect": Rect2(0.5848, 0.004, 0.05, 0.05),
		"data": &"", "art": &"", "ticket": "T-243",
		"mockup": "«0» без иконки, частично закрыт орнаментом",
	},
	{
		"id": &"button_book", "block": &"top_right", "cell": "J1",
		"node": "ChronicleButton",
		"rect": Rect2(0.9, 0.02, 0.04, 0.06),
		"data": &"ChronicleScreen", "art": &"", "ticket": "T-247",
		"mockup": "круглая кнопка с книгой",
	},
	{
		"id": &"button_gear", "block": &"top_right", "cell": "J1",
		"node": "SettingsButton",
		"rect": Rect2(0.95, 0.02, 0.04, 0.06),
		"data": &"SettingsScreen", "art": &"", "ticket": "T-247",
		"mockup": "круглая кнопка с шестернёй",
	},
	{
		"id": &"party_frame", "block": &"bottom_band", "cell": "B9",
		"node": "PartyPanel",
		"rect": Rect2(0.02, 0.8, 0.34, 0.185),
		"data": &"PartyPanel", "art": &"", "ticket": "T-247",
		"mockup": "силуэт панели отряда из двух блоков",
	},
	{
		"id": &"party_block_left", "block": &"bottom_band", "cell": "B9",
		"node": "PartySlots",
		"rect": Rect2(0.03, 0.815, 0.16, 0.16),
		"data": &"PartyPanel", "art": &"party_frame", "ticket": "",
		"mockup": "блок 2×2 слотов, занято два портрета",
	},
	{
		"id": &"party_block_right", "block": &"bottom_band", "cell": "C9",
		"node": "",
		"rect": Rect2(0.2, 0.815, 0.15, 0.16),
		"data": &"PartyPanel", "art": &"party_frame", "ticket": "map-screen-full-copy",
		"mockup": "блок 2×2 слотов; ёмкость 5, три ячейки не рисуются (D-281)",
	},
	{
		"id": &"medallion_ring", "block": &"bottom_band", "cell": "E9",
		"node": "",
		"rect": Rect2(0.355, 0.775, 0.11, 0.2),
		"data": &"CampaignCalendar", "art": &"medallion", "ticket": "T-247",
		"mockup": "кольцо прогресса вокруг медальона = дни месяца",
	},
	{
		"id": &"medallion", "block": &"bottom_band", "cell": "E9",
		"node": "",
		"rect": Rect2(0.36, 0.78, 0.1, 0.19),
		"data": &"CampaignGoalTracker", "art": &"", "ticket": "T-247",
		"mockup": "медальон со свитком, клик — журнал целей (D-241)",
	},
	{
		"id": &"medallion_badge", "block": &"bottom_band", "cell": "E9",
		"node": "",
		"rect": Rect2(0.43, 0.78, 0.035, 0.05),
		"data": &"CampaignGoalTracker", "art": &"medallion", "ticket": "T-247",
		"mockup": "бейдж со свитком у края медальона = активные цели",
	},
	{
		"id": &"sign_plaque", "block": &"bottom_band", "cell": "F10",
		"node": "SignPlaque",
		"rect": Rect2(0.47, 0.86, 0.19, 0.125),
		"data": &"SettlementName", "art": &"", "ticket": "T-247",
		"mockup": "табличка «Tuxero Egrot City»",
	},
	{
		"id": &"sign_coins", "block": &"bottom_band", "cell": "E10",
		"node": "",
		"rect": Rect2(0.475, 0.9, 0.035, 0.05),
		"data": &"TreasurySystem", "art": &"sign_plaque", "ticket": "T-247",
		"mockup": "монета «1200»",
	},
	{
		"id": &"sign_shield", "block": &"bottom_band", "cell": "F10",
		"node": "",
		"rect": Rect2(0.512, 0.9, 0.035, 0.05),
		"data": &"DefenseSystem", "art": &"sign_plaque", "ticket": "T-247",
		"mockup": "щит «100»",
	},
	{
		"id": &"sign_food", "block": &"bottom_band", "cell": "G10",
		"node": "",
		"rect": Rect2(0.6, 0.9, 0.035, 0.05),
		"data": &"", "art": &"sign_plaque", "ticket": "T-246",
		"mockup": "печенье «100» — провизии как данных нет",
	},
	{
		"id": &"sign_potion", "block": &"bottom_band", "cell": "G10",
		"node": "",
		"rect": Rect2(0.637, 0.9, 0.035, 0.05),
		"data": &"", "art": &"sign_plaque", "ticket": "T-246",
		"mockup": "склянка «10» — зелий как данных нет",
	},
	{
		"id": &"ability_frame", "block": &"bottom_band", "cell": "H9",
		"node": "",
		"rect": Rect2(0.68, 0.8, 0.18, 0.185),
		"data": &"", "art": &"", "ticket": "T-244",
		"mockup": "панель 2×4 способностей, занято два слота (птица, лотос)",
	},
	{
		"id": &"cart_button", "block": &"bottom_band", "cell": "J10",
		"node": "",
		"rect": Rect2(0.87, 0.86, 0.07, 0.11),
		"data": &"CityScreen", "art": &"", "ticket": "T-247",
		"mockup": "круглая латунная кнопка повозки",
	},
	{
		"id": &"turn_button", "block": &"turn_cluster", "cell": "J9",
		"node": "TurnButton",
		"rect": Rect2(0.8695, 0.7487, 0.1232, 0.2318),
		"data": &"CampaignHud.advance_day", "art": &"", "ticket": "T-247",
		"mockup": "золотое кольцо «TURN»",
	},
	{
		"id": &"turn_swords", "block": &"turn_cluster", "cell": "I9",
		"node": "",
		"rect": Rect2(0.8, 0.79, 0.05, 0.09),
		"data": &"", "art": &"", "ticket": "T-245",
		"mockup": "малая круглая кнопка со скрещёнными мечами",
	},
	{
		"id": &"turn_globe", "block": &"turn_cluster", "cell": "I10",
		"node": "",
		"rect": Rect2(0.8, 0.89, 0.05, 0.09),
		"data": &"", "art": &"", "ticket": "T-245",
		"mockup": "малая круглая кнопка с глобусом",
	},
	{
		"id": &"date_plaque", "block": &"left_column", "cell": "A7",
		"node": "CampaignDate",
		"rect": Rect2(0.015, 0.657, 0.145, 0.066),
		"data": &"GameText.campaign_date", "art": &"", "ticket": "T-247",
		"mockup": "плашка «Month 2 Week 1 Day 1»",
	},
	{
		"id": &"date_gear", "block": &"left_column", "cell": "B7",
		"node": "",
		"rect": Rect2(0.13, 0.66, 0.03, 0.055),
		"data": &"", "art": &"", "ticket": "T-245",
		"mockup": "малая шестерня на правом конце плашки даты",
	},
	{
		"id": &"minimap", "block": &"left_column", "cell": "A9",
		"node": "",
		"rect": Rect2(0.0145, 0.723, 0.145, 0.262),
		"data": &"MapScreenModel", "art": &"", "ticket": "T-247",
		"mockup": "квадратная панель миникарты с островом",
	},
	{
		"id": &"tile_city", "block": &"left_column", "cell": "B8",
		"node": "CityButton",
		"rect": Rect2(0.165, 0.723, 0.04, 0.065),
		"data": &"CityScreen", "art": &"", "ticket": "T-247",
		"mockup": "первый тайл вертикальной полосы",
	},
	{
		"id": &"tile_party", "block": &"left_column", "cell": "B9",
		"node": "PartyButton",
		"rect": Rect2(0.165, 0.789, 0.04, 0.065),
		"data": &"PartyScreen", "art": &"", "ticket": "T-247",
		"mockup": "второй тайл полосы",
	},
	{
		"id": &"tile_menu", "block": &"left_column", "cell": "B9",
		"node": "MenuButton",
		"rect": Rect2(0.165, 0.854, 0.04, 0.065),
		"data": &"MenuButton", "art": &"", "ticket": "T-247",
		"mockup": "третий тайл полосы",
	},
	{
		"id": &"tile_reset", "block": &"left_column", "cell": "B10",
		"node": "",
		"rect": Rect2(0.165, 0.92, 0.04, 0.065),
		"data": &"MapFieldSelection", "art": &"", "ticket": "T-247",
		"mockup": "четвёртый тайл (круг) — сброс выбора региона",
	},
	{
		"id": &"map_field", "block": &"map_field", "cell": "F5",
		"node": "CampaignMapField",
		"rect": Rect2(0.008, 0.045, 0.984, 0.755),
		"data": &"MapScreenModel", "art": &"world-map-tile-atlas", "ticket": "T-194",
		"mockup": "изометрический город с дорогами = гексы графа в рамке (D-281)",
	},
	{
		"id": &"hero_marker", "block": &"map_field", "cell": "E5",
		"node": "",
		"rect": Rect2(0.45, 0.45, 0.04, 0.06),
		"data": &"RegionMap.hero_region", "art": &"", "ticket": "T-247",
		"mockup": "конный рыцарь = показанная партия",
	},
]



static func row_by_id(id: StringName) -> Dictionary:
	for row in ROWS:
		if row.get("id", &"") == id:
			return row
	return {}


static func rows_in_block(block: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in ROWS:
		if row.get("block", &"") == block:
			rows.append(row)
	return rows


## Строки, у которых нет носителя значения: экран обязан показать их заглушкой с
## меткой задачи, а не выдуманным числом (D-200).
static func data_missing_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in ROWS:
		if row.get("data", &"") == &"":
			rows.append(row)
	return rows


## `ticket` — либо зарегистрированная задача `T-###` (носителя нет и он не
## появится сам), либо имя смены OpenSpec, которая элемент строит (узел ещё не
## написан, но работа идёт). Пустая строка допустима только у элемента с узлом.

## Строки без готового рисунка: они едут в партию контура `world-map-art-pipeline`
## (одна задача T-247 на всю партию носителей экрана).
static func art_missing_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in ROWS:
		if row.get("art", &"") == &"":
			rows.append(row)
	return rows


## Адрес ячейки сетки 10×10 по центру `rect` — тот же словарь, что даёт
## `scripts/ui_grid.py` при разметке кадра (`A1`..`J10`).
static func cell_of(rect: Rect2) -> String:
	var col := int(clamp((rect.position.x + rect.size.x / 2.0) * 10.0, 0.0, 9.999))
	var row := int(clamp((rect.position.y + rect.size.y / 2.0) * 10.0, 0.0, 9.999))
	return "%s%d" % [String(ALPHABET[col]), row + 1]


## Пиксельный прямоугольник элемента в разрешении макета — для вырезания ячейки.
static func pixel_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x * FRAME_W, rect.position.y * FRAME_H,
		rect.size.x * FRAME_W, rect.size.y * FRAME_H)
