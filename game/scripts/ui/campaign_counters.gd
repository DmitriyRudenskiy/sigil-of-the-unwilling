class_name CampaignCounters
extends RefCounted
## 7.9–7.10 (ui-mockup-parity) — реестр счётчиков верхней полосы макета карты
## (`reference/10_map_campaign_town.jpeg`) и единственный способ достать из
## носителя текст и иконку счётчика.
##
## Реестр — данные, не код полосы: `campaign_hud.gd` спрашивает у него строки,
## сам ничего не хранит (D-200). Строка либо указывает канонический носитель
## (`resource` — id из `ResourceRegistry`, значение читается из
## `City.resource_ctx`), либо зарегистрированную задачу (`ticket`) о том, что
## носителя нет. Тест `test_campaign_hud_counters.gd` роняет сборку на строке без
## того и другого — «мёртвый писатель» не переживает ревью
## (`tests/unit/ui/test_campaign_counters.gd`).
##
## Счётчики без носителя полосой **не рисуются** (первая ветвь спеки
## `campaign-hud`: «либо не показан, либо показан с явным „носителя нет“»):
## пять прочерков в ряд выглядят как сломанный интерфейс, а задача видна в
## реестре и в `docs/mvp/TICKETS.md` (T-159).
##
## Порядок строк = порядок иконок макета слева направо.

const ROWS: Array[Dictionary] = [
	{
		"id": &"crystals",
		"mockup": "синий кристалл",
		"resource": &"crystals",
		# Слой 1: id существует, но кампейн-состояние его не ведёт (MVP — триада
		# `CAMPAIGN_MVP_IDS`), поэтому значение показать нечем.
		"ticket": "T-159",
	},
	{
		"id": &"drop_red",
		"mockup": "красная капля",
		"resource": &"",
		"ticket": "T-159",
	},
	{
		"id": &"food",
		"mockup": "сноп",
		"resource": &"food",
		"ticket": "",
	},
	{
		"id": &"gem_green",
		"mockup": "зелёный кристалл",
		"resource": &"",
		"ticket": "T-159",
	},
	{
		"id": &"wood",
		"mockup": "брёвна",
		"resource": &"wood",
		"ticket": "",
	},
	{
		"id": &"ore",
		"mockup": "руда",
		"resource": &"iron",
		"ticket": "",
	},
	{
		"id": &"sack",
		"mockup": "мешок",
		"resource": &"provisions",
		# Слой 2: `SettlementProcessor` ведёт MVP-триаду, провиант в кампейн-ходе
		# не считается.
		"ticket": "T-159",
	},
	{
		"id": &"gold",
		"mockup": "монеты",
		"resource": &"",
		# Золото живёт в мировом пути (`CITY_RESOURCE_CAPACITIES.gold`), в
		# кампейн-составе поля нет.
		"ticket": "T-159",
	},
]


## Строки, которые полоса имеет право рисовать: только с носителем.
static func rendered_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in ROWS:
		if has_carrier(row):
			rows.append(row)
	return rows


static func has_carrier(row: Dictionary) -> bool:
	return row.get("resource", &"") != &""


static func row_by_id(id: StringName) -> Dictionary:
	for row in ROWS:
		if row.get("id", &"") == id:
			return row
	return {}


## Подпись счётчика — каноническое имя ресурса (`ResourceRegistry`), а не строка
## полосы: переименование ресурса меняет подпись само. Полоса её не рисует
## (в макете иконка и число), она уходит в подсказку.
static func label_text(row: Dictionary) -> String:
	var id: StringName = row.get("resource", &"")
	if id == &"":
		return String(row.get("mockup", ""))
	# Инстанс реестра, а не синглтон: статический контекст не имеет права трогать
	# автозагрузку, иначе модуль не загрузится в `-s`-режиме инструментов (тот же
	# приём, что у `CampaignCity._seed_resources`).
	var registry := ResourceRegistry.new()
	var names: Dictionary = {}
	for def in registry.get_campaign_resource_defs():
		names[def.id] = def.display_name
	registry.free()
	return String(names.get(id, row.get("mockup", "")))


static func icon(row: Dictionary) -> Texture2D:
	var id: StringName = row.get("resource", &"")
	if id == &"":
		return null
	# Иконка — из атласа ресурсов (`IconRegistry`), fallback там же: полоса не
	# рисует пустую клетку, если иконки нет.
	return IconRegistry.resource_texture(String(id))


## Значение счётчика из носителя. Носитель есть, но кампейн-состояние ресурс не
## ведёт — строка пустая: полоса такие строки не рисует (`rendered_rows`), а
## ноль вместо «ресурса нет» врать отказывается.
static func value_text(row: Dictionary, city: City) -> String:
	var id: StringName = row.get("resource", &"")
	if id == &"" or city == null or city.resource_ctx == null:
		return ""
	if not city.resource_ctx.get_all().has(id):
		return ""
	return str(int(city.resource_ctx.amount(id)))
