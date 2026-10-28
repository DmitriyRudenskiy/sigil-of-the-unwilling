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
		"data": &"CampaignCounters", "art": &"plate_panel", "ticket": "T-259",
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
		"data": &"CampaignCounters", "art": &"icon_drop_red", "ticket": "T-159",
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
		"data": &"CampaignCounters", "art": &"icon_gem_green", "ticket": "T-159",
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
		"data": &"CampaignCounters", "art": &"icon_gold", "ticket": "T-159",
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
		"rect": Rect2(0.9050, 0.0050, 0.0400, 0.0600),
		"data": &"ChronicleScreen", "art": &"button_book", "ticket": "T-259",
		"mockup": "круглая кнопка с книгой",
	},
	{
		"id": &"button_gear", "block": &"top_right", "cell": "J1",
		"node": "SettingsButton",
		"rect": Rect2(0.9500, 0.0050, 0.0400, 0.0600),
		"data": &"SettingsScreen", "art": &"button_gear", "ticket": "T-259",
		"mockup": "круглая кнопка с шестернёй",
	},
	{
		"id": &"party_frame", "block": &"bottom_band", "cell": "F10",
		"node": "PartyPanel",
		"rect": Rect2(0.2550, 0.8500, 0.5000, 0.1500),
		"data": &"PartyPanel", "art": &"plate_party", "ticket": "T-259",
		"mockup": "силуэт панели отряда из двух блоков",
	},
	{
		"id": &"party_block_left", "block": &"bottom_band", "cell": "D10",
		"node": "PartySlots",
		"rect": Rect2(0.2650, 0.8600, 0.0880, 0.1300),
		"data": &"PartyPanel", "art": &"plate_slot", "ticket": "",
		"mockup": "блок 2×2 слотов, занято два портрета",
	},
	{
		"id": &"party_block_right", "block": &"bottom_band", "cell": "E10",
		"node": "PartySlotsRight",
		"rect": Rect2(0.3570, 0.8600, 0.1930, 0.1300),
		"data": &"PartyPanel", "art": &"plate_slot", "ticket": "map-screen-full-copy",
		"mockup": "блок 2×2 слотов; ёмкость 5, три ячейки не рисуются (D-281)",
	},
	{
		"id": &"medallion_ring", "block": &"bottom_band", "cell": "F9",
		"node": "MedallionRing",
		"rect": Rect2(0.4395, 0.7575, 0.1350, 0.2400),
		"data": &"CampaignCalendar", "art": &"medallion_ring", "ticket": "T-259",
		"mockup": "кольцо прогресса вокруг медальона = дни месяца",
	},
	{
		"id": &"medallion", "block": &"bottom_band", "cell": "F9",
		"node": "Medallion",
		"rect": Rect2(0.4470, 0.7820, 0.1200, 0.1910),
		"data": &"CampaignGoalTracker", "art": &"medallion", "ticket": "T-259",
		"mockup": "медальон со свитком, клик — журнал целей (D-241)",
	},
	{
		"id": &"medallion_badge", "block": &"bottom_band", "cell": "F8",
		"node": "MedallionBadge",
		"rect": Rect2(0.4870, 0.7550, 0.0400, 0.0450),
		"data": &"CampaignGoalTracker", "art": &"medallion_badge", "ticket": "T-259",
		"mockup": "тёмный круглый чип с золотым числом над кольцом = активные цели",
	},
	{
		"id": &"sign_plaque", "block": &"bottom_band", "cell": "F10",
		"node": "SignPlaque",
		"rect": Rect2(0.4380, 0.9580, 0.1310, 0.0420),
		"data": &"SettlementName", "art": &"plate_sign", "ticket": "T-259",
		"mockup": "тёмная плита с именем поселения золотым письмом, по краям чипы",
	},
	{
		"id": &"sign_coins", "block": &"bottom_band", "cell": "E10",
		"node": "",
		"rect": Rect2(0.4440, 0.9650, 0.0140, 0.0300),
		"data": &"TreasurySystem", "art": &"chip_coins", "ticket": "T-259",
		"mockup": "медная монета со спиралью у левого края таблички",
	},
	{
		"id": &"sign_house", "block": &"bottom_band", "cell": "E10",
		"node": "",
		"rect": Rect2(0.4620, 0.9650, 0.0140, 0.0300),
		"data": &"", "art": &"chip_house", "ticket": "T-248",
		"mockup": "зелёный чип с домиком у левого края таблички; щита обороны в макете нет",
	},
	{
		"id": &"sign_food", "block": &"bottom_band", "cell": "F10",
		"node": "",
		"rect": Rect2(0.5390, 0.9650, 0.0140, 0.0300),
		"data": &"", "art": &"chip_food", "ticket": "T-246",
		"mockup": "комок хлеба у правого края таблички — провизии как данных нет",
	},
	{
		"id": &"sign_apple", "block": &"bottom_band", "cell": "F10",
		"node": "",
		"rect": Rect2(0.5550, 0.9650, 0.0140, 0.0300),
		"data": &"", "art": &"chip_apple", "ticket": "T-246",
		"mockup": "красное яблоко с листом у правого края; склянки в макете не нарисовано",
	},
	{
		"id": &"ability_frame", "block": &"bottom_band", "cell": "G10",
		"node": "AbilityFrame",
		"rect": Rect2(0.5750, 0.8550, 0.1560, 0.1400),
		"data": &"", "art": &"plate_ability", "ticket": "T-244",
		"mockup": "сетка 2×4 из тёмного камня в латунной рамке, занято два слота (птица, лотос)",
	},
	{
		"id": &"cart_button", "block": &"bottom_band", "cell": "H10",
		"node": "CartButton",
		"rect": Rect2(0.7100, 0.8800, 0.0450, 0.0700),
		"data": &"CityScreen", "art": &"cart_button", "ticket": "T-259",
		"mockup": "круглая латунная кнопка повозки",
	},
	{
		"id": &"turn_button", "block": &"turn_cluster", "cell": "J9",
		"node": "TurnButton",
		"rect": Rect2(0.9150, 0.8100, 0.0800, 0.1600),
		"data": &"CampaignHud.advance_day", "art": &"turn_button", "ticket": "T-259",
		"mockup": "латунное кольцо с четырьмя остриями, бирюзовый центр с золотым «TURN»",
	},
	{
		"id": &"turn_swords", "block": &"turn_cluster", "cell": "I9",
		"node": "TurnSwordsButton",
		"rect": Rect2(0.8750, 0.8330, 0.0400, 0.0580),
		"data": &"", "art": &"button_swords", "ticket": "T-245",
		"mockup": "малая круглая кнопка со скрещёнными мечами",
	},
	{
		"id": &"turn_globe", "block": &"turn_cluster", "cell": "I10",
		"node": "TurnGlobeButton",
		"rect": Rect2(0.8750, 0.9140, 0.0450, 0.0620),
		"data": &"", "art": &"button_globe", "ticket": "T-245",
		"mockup": "малая круглая кнопка с глобусом",
	},
	{
		"id": &"date_plaque", "block": &"left_column", "cell": "A8",
		"node": "CampaignDate",
		"rect": Rect2(0.0150, 0.6750, 0.1300, 0.0500),
		"data": &"GameText.campaign_date", "art": &"plate_date", "ticket": "T-259",
		"mockup": "тёмная плита с золотой строкой даты и латунной шестерней на конце",
	},
	{
		"id": &"date_gear", "block": &"left_column", "cell": "B8",
		"node": "",
		"rect": Rect2(0.1250, 0.6850, 0.0150, 0.0300),
		"data": &"", "art": &"gear_date", "ticket": "T-245",
		"mockup": "малая шестерня на правом конце плашки даты",
	},
	{
		"id": &"minimap", "block": &"left_column", "cell": "A9",
		"node": "CampaignMinimap",
		"rect": Rect2(0.0100, 0.7300, 0.1250, 0.2650),
		"data": &"MapScreenModel", "art": &"plate_minimap", "ticket": "T-259",
		"mockup": "тёмная плита с нарисованным островом посреди кадра",
	},
	{
		"id": &"tile_city", "block": &"left_column", "cell": "B9",
		"node": "CityButton",
		"rect": Rect2(0.1570, 0.7950, 0.0400, 0.0600),
		"data": &"CityScreen", "art": &"tile_city", "ticket": "T-259",
		"mockup": "первый тайл вертикальной плиты: золотая башня",
	},
	{
		"id": &"tile_party", "block": &"left_column", "cell": "B9",
		"node": "PartyButton",
		"rect": Rect2(0.1570, 0.8550, 0.0400, 0.0500),
		"data": &"PartyScreen", "art": &"tile_party", "ticket": "T-259",
		"mockup": "второй тайл вертикальной плиты: золотая руна",
	},
	{
		"id": &"tile_menu", "block": &"left_column", "cell": "B10",
		"node": "MenuButton",
		"rect": Rect2(0.1570, 0.9050, 0.0400, 0.0450),
		"data": &"MenuButton", "art": &"tile_menu", "ticket": "T-259",
		"mockup": "третий тайл вертикальной плиты: золотой шеврон",
	},
	{
		"id": &"tile_reset", "block": &"left_column", "cell": "B10",
		"node": "ResetTile",
		"rect": Rect2(0.1570, 0.9500, 0.0400, 0.0450),
		"data": &"MapFieldSelection", "art": &"tile_reset", "ticket": "T-259",
		"mockup": "четвёртый тайл вертикальной плиты: контурный круг — сброс выбора региона",
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
		"data": &"RegionMap.hero_region", "art": &"hero_marker", "ticket": "T-259",
		"mockup": "конный рыцарь = показанная партия",
	},
]



## Поставить узел в прямоугольник строки реестра: доли кадра становятся якорями,
## поэтому экран не содержит ни одного собственного числа, с которым можно
## разойтись с макетом. `host_id` — строка-хозяин, если узел вложен в другой
## блок (ячейка счётчика внутри полосы, кольцо вокруг медальона); пустая — весь
## кадр. Прямоугольник задан всеми четырьмя якорями при нулевых offset'ах: у
## пресета с краем якоря верх/низ стоят на одной границе и высота получается
## нулевой — текст есть в модели, его нет на экране.
static func apply_rect(node: Control, element_id: StringName, host_id: StringName = &"") -> void:
	_apply_rect(node, row_by_id(element_id).get("rect", Rect2()), host_id)


## Носитель, размеченный сразу несколькими строками: его клетка — объединение
## (плита столбца тайлов стоит по четырём тайлам, своей строки у неё нет).
static func apply_rect_union(node: Control, ids: Array, host_id: StringName = &"") -> void:
	var union := Rect2()
	for id in ids:
		var rect: Rect2 = row_by_id(StringName(id)).get("rect", Rect2())
		union = rect if union.size == Vector2.ZERO else union.merge(rect)
	_apply_rect(node, union, host_id)


static func _apply_rect(node: Control, rect: Rect2, host_id: StringName) -> void:
	var host: Rect2 = row_by_id(host_id).get("rect", Rect2(0.0, 0.0, 1.0, 1.0))
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.anchor_left = (rect.position.x - host.position.x) / host.size.x
	node.anchor_top = (rect.position.y - host.position.y) / host.size.y
	node.anchor_right = (rect.end.x - host.position.x) / host.size.x
	node.anchor_bottom = (rect.end.y - host.position.y) / host.size.y
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


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
## (одна задача T-259 на всю партию носителей экрана).
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
