class_name CampaignCity
extends RefCounted
## Кампейн-город — носитель городского экрана в игровом пути кампании.
##
## Почему это отдельный корень (ui-mockup-parity §7.1, носитель выбран владельцем
## в Q-M87 → (б), D-204: «экран кампании — новый слой HUD на main.tscn»):
## экран города (`CityScreen`) умеет показывать только модель `City` с
## кампейн-постройками (`city.campaign_buildings`), а кампейн-слой до сих пор
## такую модель не создавал — экран было нечем открыть.
##
## Честная граница каноничности (важно, не выдумана здесь):
##   · `SettlementProcessor` остаётся источником истины кампейн-экономики
##     (запасы, постройки-строки, районы, производство хода);
##   · `City` здесь — носитель городского экрана: состав жителей, застройки
##     клеток и баланса ресурсов он отражает состояние на момент старта
##     кампании, дальше живёт своей жизнью (стройка, очередь достройки).
##     Сведение двух моделей в одну — отдельный вопрос владельцу (Q-M98),
##     здесь он не решается.
##
## Числа старта — из одного источника с кампейн-слоем: `campaign.json →
## start_state` (K-M15; еда 600 — якорь T-003/Q-M91), состав жителей —
## `mvp_catalog.json` (первый эшелон 7 рас, K-M5-правка/T-001 — ссылка, не
## копия). Ни одного числа не переписываем. I1: ни ГСЧ сверх seed кампании.

const ArenaRingSystem := preload("res://scripts/city/arena_ring_system.gd")
const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")

const MVP_CATALOG_JSON := "res://assets/data/mvp_catalog.json"
## Название столицы кампейна — имя первого осколка (`shard_manager.SHARD_1_ID`),
## тот же корень, что у столицы мирового пути (`world_bootstrap`).
const CAPITAL_NAME := "Перворечье"
## Две стартовые хижины = 20 мест (канон старта R2: housing 20).
const STARTING_HOUSE_ID := "campaign_housing"
const STARTING_HOUSES := 2
## Клетки стартовых хижин — те же индексы канонического списка клеток, что и
## стартовый фикстура-рецепт (`CampaignCityBalanceFixture`), чтобы экран
## показывал тот же старт, что считает баланс.
const STARTING_HOUSE_CELLS: Array[int] = [4, 5]


## Стартовый кампейн-город. `stocks` — запасы кампейна (campaign.json →
## start_state.resources), `population` — число жителей (start_state.population).
static func start(stocks: Dictionary, population: int) -> City:
	var city := City.new()
	city.display_name = CAPITAL_NAME
	city.center = ArenaRingSystem.ARENA_CENTER
	# Ядро — ромб 2×2 (`HexUtils.core_cells`), НЕ доска застройки: `City.cell_is_built`
	# считает каждую клетку ядра занятой, поэтому 52 клетки доски здесь сделали бы
	# всю доску непроходимой для размещения (проверено: «footprint cell is
	# occupied» на любой клетке). Тот же корень, что у `world_bootstrap` и
	# `CampaignCityBalanceFixture`. Доска (52 клетки) — `CampaignBuildingPlacement.city_cells`.
	city.core_cells = CityFactory.core_cells_for(city.center)
	city.owner = &"player"
	city.is_capital = true
	city.level = 1
	_seed_resources(city, stocks)
	_seed_residents(city, population)
	_seed_starting_houses(city)
	return city


## Кампейн-регистр ресурсов (food/wood/iron) — тот же путь, что у баланса
## (`CampaignCityBalanceFixture`): реестр, а не автозагрузка `Resources`, —
## иначе модуль нельзя загрузить в `-s`-режиме инструментов.
static func _seed_resources(city: City, stocks: Dictionary) -> void:
	var registry := ResourceRegistry.new()
	var defs: Array = registry.get_campaign_resource_defs(true)
	registry.free()
	city.ensure_resource_ctx(defs).setup(defs, true)
	for resource_id in stocks.keys():
		city.resource_ctx.add(StringName(resource_id), float(stocks[resource_id]))
	city.resource_ctx.clear_ledger()


## Жители: по одному представителю первого эшелона на круг (K-M5-правка:
## «первый эшелон 7 рас, по одной на группу»), ids — из `mvp_catalog.json`.
static func _seed_residents(city: City, population: int) -> void:
	var races: Array = _first_tier_races()
	if races.is_empty():
		return
	for index in range(maxi(population, 0)):
		var race: Dictionary = races[index % races.size()]
		var resident: PopUnit = city.add_migrant(PopUnit.State.WORKER, 0)
		resident.ancestry_id = String(race.get("id", ""))
		resident.archetype_id = String(race.get("group", ""))


static func _seed_starting_houses(city: City) -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	var cells: Array[Vector2i] = CampaignBuildingPlacement.city_cells(city.center)
	for house_index in range(STARTING_HOUSES):
		if house_index >= STARTING_HOUSE_CELLS.size():
			return
		var cell_index := STARTING_HOUSE_CELLS[house_index]
		if cell_index >= cells.size():
			return
		var definition: Dictionary = _find_building(catalog, STARTING_HOUSE_ID)
		if definition.is_empty():
			return
		var house := definition.duplicate(true)
		house.merge({
			"uid": city._uid_seq,
			"cell": cells[cell_index],
			"state": "active",
			"construction_turns_remaining": 0,
			"assigned_workers": 0,
			"paid_costs": {},
		}, true)
		city.campaign_buildings.append(house)
		city._uid_seq += 1


static func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for definition in catalog.get("buildings", []):
		if String(definition.get("id", "")) == building_id:
			return definition as Dictionary
	return {}


static func _first_tier_races() -> Array:
	var file := FileAccess.open(MVP_CATALOG_JSON, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return []
	var races: Array = []
	for race in (parsed as Dictionary).get("races", []):
		if race is Dictionary and bool((race as Dictionary).get("first_tier", false)):
			races.append(race)
	return races
