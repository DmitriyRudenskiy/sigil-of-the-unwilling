extends BaseTest

## Носитель экрана города в игровом пути кампании (ui-mockup-parity §7.1).
##
## Носитель выбран владельцем: Q-M87 → (б), D-204 — новый слой кампейн-HUD на
## `scenes/main/main.tscn`; архивный `scenes/archive/world.tscn` с его
## `world_ui_manager` не реанимируется. До этого слоя `CityScreen` был сценой
## без вызывающего: из «Новой игры» в него попасть было нечем (проверено
## grep-ом по игровому пути — вызовов `open()` не было).
##
## Что здесь гейтится (и почему именно так):
## 1. слой поднимается вместе с `main.tscn` и кнопка «Город» активна только
##    после привязки города (несвязанная кнопка обещала бы нажатие, которого
##    нет — приём снят с медальонов нижней панели боя);
## 2. экран привязан к тому же объекту города, что держит композиция (один
##    город, не второй);
## 3. доска города рисует реальный кампейн-город (клетки есть, заглушка
##    «План города» скрыта) — тот дефект закрыт в прошлом заходе и здесь
##    проверяется уже на живом пути;
## 4. кампейн-время стоит, пока экран открыт (тот же приём, что пауза на
##    кризисе), и снова идёт после закрытия;
## 5. очередь достройки города проталкивается production-фазой кампании —
##    иначе построенное навсегда остаётся «в стройке»;
## 6. город — часть сейва (секция city.campaign_city), загрузка старого сейва
##    без секции не остаётся без города.
##
## Числа старта не изобретаются: город строится из campaign.json → start_state
## тем же путём, что поселение (`CampaignCity.start`), поэтому тест сверяет
## запасы города с запасами поселения, а не с константой.

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CampaignBuildingConstructionService := preload("res://scripts/city/campaign_building_construction_service.gd")

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const CITY_BUTTON_PATH := "CampaignHUD/CampaignHud/TopButtons/CityButton"
const CITY_SCREEN_PATH := "CampaignHUD/CampaignHud/CityScreen"
const CLOSE_BUTTON_PATH := "ScreenMargin/ScreenLayout/ScreenHeader/HeaderRow/Close"

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


## Кампейн поднимается так же, как его поднимает игра: сцена `main.tscn`,
## `_ready` → `_init_campaign` → привязка слоя. Окно ставится явным размером:
## headless-окно 64×64 легально включает компактный режим шапки, и замеры
## развёрнутого HUD ловили бы компактную форму (тот же приём, что в
## tests/functional/test_city_screen.gd).
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node("CampaignHUD/CampaignHud") as CampaignHud


func test_carrier_mounts_city_button_on_campaign_scene() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	assert_that(hud).is_not_null()
	var button := main.get_node_or_null(CITY_BUTTON_PATH) as Button
	assert_that(button).is_not_null()
	assert_bool(button.disabled).is_false()
	assert_str(button.text).is_not_empty()


func test_city_screen_binds_to_the_composition_city() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	assert_that(hud.city).is_same(main.composition.city)
	# Один город, не второй: экран открывается тем же объектом, что у композиции.
	hud.open_city_screen()
	var screen := main.get_node_or_null(CITY_SCREEN_PATH) as CityScreen
	assert_that(screen).is_not_null()
	assert_bool(hud.is_city_screen_open()).is_true()
	assert_that(screen.city).is_same(main.composition.city)


func test_open_screen_shows_live_board_not_placeholder() -> void:
	var main := await _boot_campaign()
	_hud().open_city_screen()
	var screen := main.get_node(CITY_SCREEN_PATH) as CityScreen
	assert_bool(screen.visible).is_true()
	var board := screen.get_node(
		"ScreenMargin/ScreenLayout/CityWorkspace/CityBoardPanel/BoardArea/CampaignCityBoard")
	var cells: Array = board.get_rendered_cells()
	assert_int(cells.size()).is_greater(0)
	var placeholder := screen.get_node(
		"ScreenMargin/ScreenLayout/CityWorkspace/CityBoardPanel/BoardArea/BoardPlaceholder") as Label
	assert_bool(placeholder.visible).is_false()


func test_day_cycle_pauses_while_city_screen_open() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	assert_bool(main._city_screen_paused).is_false()
	hud.open_city_screen()
	assert_bool(main._city_screen_paused).is_true()
	hud.close_city_screen()
	assert_bool(main._city_screen_paused).is_false()


func test_close_button_of_screen_returns_to_campaign() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	hud.open_city_screen()
	var screen := main.get_node(CITY_SCREEN_PATH) as CityScreen
	(main.get_node(CITY_SCREEN_PATH + "/" + CLOSE_BUTTON_PATH) as Button).emit_signal("pressed")
	await get_tree().process_frame
	assert_bool(screen.visible).is_false()
	assert_bool(hud.is_city_screen_open()).is_false()
	assert_bool(main._city_screen_paused).is_false()


## Экран города зарегистрирован в машине навигации (указание владельца
## 2026-10-23, D-226): узел по-прежнему живёт в носителе, но активным экраном
## становится только через `CampaignUIManager` — иначе `visible_screens()` врёт,
## а кампания остаётся без единого «какой экран сейчас».
func test_city_screen_registered_in_campaign_ui_manager() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	assert_that(manager).is_not_null()
	# Кампания стартует на карте: без begin_campaign машина осталась бы PREGAME.
	assert_str(String(manager.current_screen())).is_equal("map")
	assert_bool(manager.has_screen(&"city")).is_true()
	assert_int(manager.visible_screens().size()).is_equal(0)


func test_open_city_screen_moves_state_machine_to_city() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	_hud().open_city_screen()
	assert_str(String(manager.current_screen())).is_equal("city")
	# Инвариант одного активного экрана: виден ровно город.
	var visible: Array = manager.visible_screens()
	assert_int(visible.size()).is_equal(1)
	assert_str(String(visible[0])).is_equal("city")


func test_close_city_screen_returns_state_machine_to_map() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	var hud := _hud()
	hud.open_city_screen()
	hud.close_city_screen()
	assert_str(String(manager.current_screen())).is_equal("map")
	assert_bool(hud.is_city_screen_open()).is_false()
	assert_bool((main.get_node(CITY_SCREEN_PATH) as CityScreen).visible).is_false()
	assert_int(manager.visible_screens().size()).is_equal(0)


## Переход запрещён — экрана нет: из боя город не открывается, и машина остаётся
## в бою. Причина — та же гарантия «≤2 клика до причины» (mvp-ui-flow 3.3).
func test_city_screen_refused_when_machine_is_in_battle() -> void:
	var main := await _boot_campaign()
	var manager := main.campaign_ui_manager as CampaignUIManager
	assert_bool(bool(manager.show_screen(&"battle").get("ok", false))).is_true()
	var hud := _hud()
	hud.open_city_screen()
	assert_bool(hud.is_city_screen_open()).is_false()
	assert_str(String(manager.current_screen())).is_equal("battle")
	assert_bool((main.get_node(CITY_SCREEN_PATH) as CityScreen).visible).is_false()
	assert_str(String(manager.can_show(&"city").get("reason", ""))) \
		.is_equal("not_allowed_from_battle")


## Носитель без машины (чистые тесты слоя, хосты без `main.tscn`) не обязан её
## иметь: прямое открытие работает, как работало до регистрации экрана.
func test_carrier_opens_screen_without_ui_manager() -> void:
	var hud := CampaignHud.new()
	_main = hud
	_root().add_child(hud)
	await get_tree().process_frame
	hud.bind_city(CampaignComposition.from_campaign_config(12345).city)
	assert_bool(hud.is_city_screen_open()).is_false()
	hud.open_city_screen()
	assert_bool(hud.is_city_screen_open()).is_true()
	assert_bool((hud.get_node("CityScreen") as CityScreen).visible).is_true()
	hud.close_city_screen()
	assert_bool(hud.is_city_screen_open()).is_false()


## Стартовый город = старт кампании: запасы и население из campaign.json
## (K-M15), две хижны (20 мест), жители — первый эшелон mvp_catalog.json.
func test_start_city_mirrors_campaign_start_state() -> void:
	var main := await _boot_campaign()
	var city: City = main.composition.city
	var settlement = main.composition.settlement
	for resource_id in settlement.stocks.keys():
		assert_float(city.resource_ctx.amount(StringName(resource_id))).is_equal(
			float(settlement.stocks[resource_id]))
	assert_int(city.pop.size()).is_equal(settlement.population)
	assert_int(city.campaign_buildings.size()).is_equal(2)
	var ancestries := {}
	for resident in city.pop:
		ancestries[String(resident.ancestry_id)] = true
	assert_int(ancestries.size()).is_greater(1)


## Стройка в носителе — игровым путём, а не в обход ёмкости: на старте лимит
## 1-го уровня (4 клетки, `CampaignCityProgression.CELL_LIMITS`) уже выбран
## ядром-ромбом 2×2, поэтому первая постройка возможна после повышения уровня
## города — тот же вызов, что делает кнопка «Уровень города» в шапке экрана
## (`CityScreen.level_up_pressed`). Дальше очередь достройки проталкивается
## production-фазой хода кампании: построенное не должно навсегда остаться
## «в стройке».
func test_building_needs_city_level_then_completes_on_turn() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var city: City = composition.city
	var catalog := CampaignBuildingCatalog.load_catalog()
	var cell := _free_cell(city)
	var blocked := CampaignBuildingConstructionService.explain_request(
		city, catalog, "campaign_farm", cell, _terrain_by_cell())
	assert_bool(bool(blocked.get("ok", false))).is_false()
	assert_str(String(blocked.get("reason", ""))).is_equal("city_capacity")
	var level_up := CampaignCityProgression.try_level_up(city)
	assert_str(String(level_up.get("reason", "")) + "|ok=" + str(level_up.get("ok"))).is_equal("|ok=true")
	assert_int(city.level).is_equal(2)
	var result: Dictionary = CampaignBuildingConstructionService.request(
		city, catalog, "campaign_farm", cell, _terrain_by_cell())
	assert_str(_rejection_note(result)).is_equal("")
	assert_str(String((result.get("instance", {}) as Dictionary).get("state", ""))) \
		.is_equal("inactive")
	composition.advance_turn()
	assert_str(String(_find_building(city, "campaign_farm").get("state", ""))) \
		.is_equal("active")


## Город — часть сейва: застройка, построенная в экране, переживает
## JSON round-trip (контракт T-110 на новой секции).
func test_city_survives_save_roundtrip() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	CampaignCityProgression.try_level_up(composition.city)
	var catalog := CampaignBuildingCatalog.load_catalog()
	var request: Dictionary = CampaignBuildingConstructionService.request(
		composition.city, catalog, "campaign_farm", _free_cell(composition.city),
		_terrain_by_cell())
	assert_str(_rejection_note(request)).is_equal("")
	var restored := CampaignComposition.new()
	restored.load_save_state(JSON.parse_string(JSON.stringify(composition.build_save_state())))
	assert_that(restored.city).is_not_null()
	assert_that(_find_building(restored.city, "campaign_farm")).is_not_null()
	assert_int(restored.city.level).is_equal(composition.city.level)


## Сейвы до §7.1 без секции города: загрузка не оставляет кампанию без города.
func test_save_without_city_section_restores_start_city() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var state: Dictionary = composition.build_save_state()
	(state.get("city", {}) as Dictionary).erase("campaign_city")
	var restored := CampaignComposition.new()
	restored.load_save_state(JSON.parse_string(JSON.stringify(state)))
	assert_that(restored.city).is_not_null()
	assert_int(restored.city.campaign_buildings.size()).is_equal(2)


## Пустая строка = запрос принят; иначе — причина и список претензий прямо в
## тексте падения (GdUnit-assert «is_true»/«is_bool» не принимают пояснений).
func _rejection_note(result: Dictionary) -> String:
	if bool(result.get("ok", false)):
		return ""
	return "%s %s" % [result.get("reason"), result.get("issues")]



func _find_building(city: City, building_id: String) -> Dictionary:
	for instance in city.campaign_buildings:
		if String(instance.get("id", "")) == building_id:
			return instance as Dictionary
	return {}


## Свободная клетка доски: не ядро (ромб 2×2 — `City.cell_is_built` помечает
## его занятым по построению) и не под кампейн-постройкой.
func _free_cell(city: City) -> Vector2i:
	var taken := {}
	for instance in city.campaign_buildings:
		taken[instance.get("cell", Vector2i.ZERO)] = true
	for cell in CampaignBuildingPlacement.city_cells(city.center):
		if city.cell_is_built(cell) or taken.has(cell):
			continue
		return cell
	return Vector2i.ZERO


## Рельеф клеток — пустой словарь: это то же, что даёт живому пути доска
## экрана (`CampaignCityBoard.get_terrain_by_cell` без terrain_provider — в
## кампейне нет гексагональной карты-источника, она была у архивного мира).
## Пустой рельеф безвреден: ни одна постройка каталога не требует terrain_tags
## (проверено по всем 98), поэтому размещение не отклоняется за «unknown».
func _terrain_by_cell() -> Dictionary:
	return {}
