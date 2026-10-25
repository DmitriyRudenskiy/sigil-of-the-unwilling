extends BaseTest

## mvp-ui-flow 2.3 (T-182, M3): цели первых трёх дней на живом носителе.
##
## Трекер целей был написан ещё в 5.2 и оставался моделью без читателя: ни одного
## вызова `CampaignGoalTracker` вне его собственного теста (проверено grep-ом по
## игровому пути). Здесь гейтится не арифметика трекера (это делает
## `test_campaign_goal_tracker.gd`), а **провода**: кто пишет цель, из каких чисел
## берётся регион руин и что происходит с целями в сейве.
##
## Почему это проверяется ходом кампании, а не вызовом `note_*`:
## цель обязана закрываться событием, а не вежливой просьбой теста. Прямой вызов
## `note_building_built()` проверял бы трекер и молчал бы о том, что production-
## фаза его не вызывает, — ровно так и жили до T-182.

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingConstructionService := preload("res://scripts/city/campaign_building_construction_service.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CampaignCityProgression := preload("res://scripts/city/campaign_city_progression.gd")

const GOAL_IDS := ["farm", "barracks", "train_warrior", "ruins"]


## Город стартовой кампании + постройка в стройке (рецепт снят с
## `test_campaign_city_carrier.gd`: на 1-м уровне лимит клеток выбран ядром,
## поэтому первая постройка возможна только после повышения уровня).
func _request_farm(composition: CampaignComposition) -> void:
	var city: City = composition.city
	var catalog := CampaignBuildingCatalog.load_catalog()
	var cell := _free_cell(city)
	assert_str(String(CampaignCityProgression.try_level_up(city).get("reason", ""))) \
		.is_equal("")
	var result: Dictionary = CampaignBuildingConstructionService.request(
		city, catalog, "campaign_farm", cell, _terrain_by_cell())
	assert_str(String(result.get("reason", "")) + "|ok=" + str(result.get("ok"))) \
		.is_equal("|ok=true")


## Свободная клетка доски (рецепт `test_campaign_city_carrier.gd`): не ядро
## (ромб 2×2 помечен занятым по построению) и не под кампейн-постройкой.
func _free_cell(city: City) -> Vector2i:
	var taken := {}
	for instance in city.campaign_buildings:
		taken[instance.get("cell", Vector2i.ZERO)] = true
	for cell in CampaignBuildingPlacement.city_cells(city.center):
		if city.cell_is_built(cell) or taken.has(cell):
			continue
		return cell
	return Vector2i.ZERO


## Рельеф — пустой словарь, как у живой доски кампейна (пояснение и проверка по
## каталогу — в `test_campaign_city_carrier.gd`).
func _terrain_by_cell() -> Dictionary:
	return {}


func _goal(composition: CampaignComposition, goal_id: String) -> Dictionary:
	for goal in composition.goals.goals:
		if String(goal.get("id", "")) == goal_id:
			return goal
	return {}


## Регион руин считается из данных маски, поэтому и в тесте он ищется, а не
## пишется строкой: хардкод «R03» прошёл бы сегодня и соврал бы после
## перерисовки movement.json (та же цена, что у немой строки в данных событий).
func _ruins_region(map: RegionMap) -> String:
	for region in map.regions:
		if map.node_type(String(region)) == "ruin":
			return String(region)
	return ""


## Свежая кампания несёт набор M3: ферма + казармы (день 1), воин (день 2),
## руины (день 3). Порядок и дни — канон 07-ui-ux, а не решение носителя.
func test_fresh_campaign_carries_the_three_day_goal_set() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	assert_int(composition.goals.goals.size()).is_equal(GOAL_IDS.size())
	assert_bool(composition.goals.visible()).is_true()
	assert_str(String(_goal(composition, "farm").get("target", ""))).is_equal("campaign_farm")
	assert_str(String(_goal(composition, "barracks").get("target", ""))).is_equal("campaign_barracks")
	assert_str(String(_goal(composition, "train_warrior").get("target", ""))).is_equal("fighter")
	assert_int(int(_goal(composition, "farm").get("day", 0))).is_equal(1)
	assert_int(int(_goal(composition, "train_warrior").get("day", 0))).is_equal(2)
	assert_int(int(_goal(composition, "ruins").get("day", 0))).is_equal(3)


## Регион руин в цели берётся из маски движения, а не из строки: цель должна
## закрываться тем регионом, где руина реально лежит (Q-M91-семья: у регион-графа
## и у маски движения разные id, и строка из одного файла в другом молчит).
func test_ruins_goal_targets_the_region_that_holds_the_ruin() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var ruins := _ruins_region(composition.region_map)
	assert_str(ruins).is_not_equal("")
	assert_str(String(_goal(composition, "ruins").get("target", ""))).is_equal(ruins)


## Цель дня 1 закрывает достройка здания production-фазой хода, а не заявка:
## заявка — это «заказано», цель — «построено».
func test_building_completed_on_turn_closes_the_day_one_goal() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	_request_farm(composition)
	assert_bool(composition.goals.is_complete("farm")).is_false()
	composition.advance_turn()
	assert_bool(composition.goals.is_complete("farm")).is_true()
	assert_bool(composition.goals.is_complete("barracks")).is_false()


## Цель дня 2 закрывает выпуск рекрута, а не заявка в очередь.
func test_graduated_recruit_closes_the_day_two_goal() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var city: City = composition.city
	# Порог населения (10 жителей на юнита, 02-mechanics §3.3 EC3) на старте
	# кампании = 30 против 20 жителей: заявку не приняли бы не из-за целей, а из-за
	# правила. Жители «рождаются» — как их добавляет носитель в тестах тренировки.
	while city.pop.size() < 30:
		var resident := PopUnit.new()
		resident.uid = 2000 + city.pop.size()
		city.pop.append(resident)
	city.campaign_buildings.append({
		"uid": 7, "id": "campaign_barracks", "state": "active",
		"construction_turns_remaining": 0, "cell": Vector2i(city.center.x + 3, city.center.y),
	})
	var result := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "fighter", _trainee(), 2)
	assert_bool(bool(result.get("ok", false))).is_true()
	assert_bool(composition.goals.is_complete("train_warrior")).is_false()
	for turn in range(12):
		composition.advance_turn()
		if composition.goals.is_complete("train_warrior"):
			break
	assert_bool(composition.goals.is_complete("train_warrior")).is_true()


func _trainee() -> Dictionary:
	return {"id": "v1", "race": "humans",
		"stats": {"str": 14, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}}


## Цель дня 3 закрывает первый визит узла. Проверка идёт через `visit_node`, а не
## через `note_region_visited`: связь «сигнал регион-графа → трекер» и есть тот
## провод, которого у модели не было.
func test_first_visit_of_ruins_closes_the_day_three_goal() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var ruins := _ruins_region(composition.region_map)
	var loot: Dictionary = composition.region_map.visit_node(ruins)
	assert_bool(bool(loot.get("looted", false))).is_true()
	assert_bool(composition.goals.is_complete("ruins")).is_true()


## Визит региона без узла цель не закрывает: иначе «выйти в поле» и «найти руины»
## были бы одним и тем же действием.
func test_visit_of_a_region_without_node_keeps_the_goal_open() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var start := composition.region_map.start_region
	assert_str(composition.region_map.node_type(start)).is_equal("")
	composition.region_map.visit_node(start)
	assert_bool(composition.goals.is_complete("ruins")).is_false()


## Цели — состояние: закрытое не возвращается при сохранении/загрузке (постройку
## снесут, а цель остаётся закрытой — так и задумано, M3 меряет пройденное).
func test_goals_survive_save_roundtrip() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	composition.goals.note_building_built("campaign_farm")
	var restored := CampaignComposition.new()
	restored.load_save_state(JSON.parse_string(JSON.stringify(composition.build_save_state())))
	assert_bool(restored.goals.is_complete("farm")).is_true()
	assert_bool(restored.goals.is_complete("barracks")).is_false()
	assert_int(restored.goals.pending().size()).is_equal(GOAL_IDS.size() - 1)


## Сейв до T-182 секции целей не имеет: загрузка обязана дать свежий набор M3,
## а не пустой список и не панель без целей.
func test_save_without_goals_section_restores_the_default_set() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var state: Dictionary = composition.build_save_state()
	(state.get("campaign", {}) as Dictionary).erase("goals")
	var restored := CampaignComposition.new()
	restored.load_save_state(state)
	assert_int(restored.goals.goals.size()).is_equal(GOAL_IDS.size())
	assert_bool(restored.goals.visible()).is_true()
	assert_str(String(_goal(restored, "ruins").get("target", ""))) \
		.is_equal(_ruins_region(restored.region_map))


## Регресс на переподключение: при загрузке `region_map` создаётся заново
## (`RegionMap.from_dict`), и связь со старым объектом ушла бы вместе с ним —
## цель «руины» стала бы недостижимой в загруженной кампании.
func test_ruins_goal_still_reachable_after_load() -> void:
	var composition := CampaignComposition.from_campaign_config(12345)
	var restored := CampaignComposition.new()
	restored.load_save_state(JSON.parse_string(JSON.stringify(composition.build_save_state())))
	var ruins := _ruins_region(restored.region_map)
	restored.region_map.visit_node(ruins)
	assert_bool(restored.goals.is_complete("ruins")).is_true()
