extends BaseTest

# party-training 2.1/2.5 (T-170, вариант (а)): SM рекрута на живом носителе —
# очередь живёт в City.campaign_training, тикает из production-фазы, сериализуется
# CitySerializer'ом. Проверки те же, что у dict-формы (train()), но против
# объекта города: тот самый, который видит экран города и живой сейв.

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")

const FighterCostFood := 20.0
const FighterCostIron := 2.0


func _city(residents: int = 40) -> City:
	var city := TestFactories.make_city()
	city.center = Vector2i(20, 20)
	city.resource_ctx = ResourceContext.new()
	city.resource_ctx.setup(Resources.get_campaign_resource_defs(true), true)
	city.resource_ctx.add(&"food", 100.0)
	city.resource_ctx.add(&"wood", 100.0)
	city.resource_ctx.add(&"iron", 20.0)
	for index in range(residents):
		var resident := PopUnit.new()
		resident.uid = 1000 + index
		city.pop.append(resident)
	return city


func _barracks(city: City, state: String = "active", remaining: int = 0) -> int:
	city.campaign_buildings.append({
		"uid": 7, "id": "campaign_barracks", "state": state,
		"construction_turns_remaining": remaining, "cell": Vector2i(20, 20),
	})
	return 7


func _trainee(id: String = "v1") -> Dictionary:
	return {"id": id, "race": "humans",
		"stats": {"str": 14, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}}


## 2.1: заявка = списание стоимости + запись REQUESTED в очередь города.
func test_request_pays_from_city_and_queues_requested_recruit() -> void:
	var city := _city()
	var uid := _barracks(city)
	var result := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), uid, "fighter", _trainee(), 2)
	assert_bool(result.ok).is_true()
	assert_that(city.campaign_training.size()).is_equal(1)
	var record: Dictionary = city.campaign_training[0]
	assert_that(String(record.state)).is_equal("REQUESTED")
	assert_float(float(record.progress)).is_equal(0.0)
	assert_that(int(record.training_building_uid)).is_equal(uid)
	assert_float(city.resource_ctx.amount(&"food")).is_equal_approx(100.0 - FighterCostFood, 0.0001)
	assert_float(city.resource_ctx.amount(&"iron")).is_equal_approx(20.0 - FighterCostIron, 0.0001)


## 2.4 на живом носителе: ниже порога — отказ, ни записей, ни списаний.
func test_request_below_population_threshold_writes_nothing() -> void:
	var city := _city(10)
	var uid := _barracks(city)
	var result := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), uid, "fighter", _trainee(), 2)
	assert_bool(result.ok).is_false()
	assert_that(String(result.reason)).is_equal("population_below_threshold:10<30")
	assert_that(city.campaign_training).is_empty()
	assert_float(city.resource_ctx.amount(&"iron")).is_equal_approx(20.0, 0.0001)


## Q-M101 в числах: канон-время бойца 0.6 дня < хода (сутки) → боец готов на
## первом же тике. Тест фиксирует следствие, а не желаемое поведение.
func test_canon_training_time_fits_into_single_turn() -> void:
	var city := _city()
	var uid := _barracks(city)
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_bool(CampaignTrainingService.request_training(
		city, catalog, uid, "fighter", _trainee(), 2).ok).is_true()
	var report := CampaignTrainingService.advance_training_turn(city, 5)
	assert_that(int(report.ready)).is_equal(1)
	assert_that((report.members as Array).size()).is_equal(1)
	assert_that(city.campaign_training).is_empty()


## Скоростной множитель из конфига (concurrency_n) и субсуточное время дают
## растяжимый тик — на нём проверяются пауза и сохранение прогресса.
func _advance_slowly(city: City, ticks: int, slots: int = 5) -> Dictionary:
	var last: Dictionary = {}
	for _tick in range(ticks):
		last = CampaignTrainingService.advance_training_turn(city, slots, 10.0)
	return last


## 4.1: разрыв сети (постройка разрушена) → PAUSED с сохранением прогресса и
## без возврата стоимости; восстановление сети → TRAINING с того же прогресса.
func test_network_break_pauses_and_resume_keeps_progress_and_cost() -> void:
	var city := _city()
	var uid := _barracks(city)
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_bool(CampaignTrainingService.request_training(
		city, catalog, uid, "fighter", _trainee(), 2).ok).is_true()
	_advance_slowly(city, 2)
	var progress: float = float((city.campaign_training[0] as Dictionary).progress)
	assert_float(progress).is_greater(0.0)
	assert_float(progress).is_less(1.0)

	city.campaign_buildings[0]["state"] = "ruined"
	var paused := CampaignTrainingService.advance_training_turn(city, 5, 10.0)
	assert_that(int(paused.paused)).is_equal(1)
	assert_that(String((city.campaign_training[0] as Dictionary).state)).is_equal("PAUSED")
	assert_float(float((city.campaign_training[0] as Dictionary).progress)).is_equal(progress)
	assert_float(city.resource_ctx.amount(&"iron")).is_equal_approx(20.0 - FighterCostIron, 0.0001)

	city.campaign_buildings[0]["state"] = "active"
	var resumed := CampaignTrainingService.advance_training_turn(city, 5, 10.0)
	assert_that(int(resumed.resumed)).is_equal(1)
	assert_that(String((city.campaign_training[0] as Dictionary).state)).is_equal("TRAINING")
	assert_float(float((city.campaign_training[0] as Dictionary).progress)) \
		.is_greater(progress)

	# 4.2: продажа здания — инстанса нет вовсе, это тоже разрыв сети.
	city.campaign_buildings.clear()
	var sold := CampaignTrainingService.advance_training_turn(city, 5, 10.0)
	assert_that(int(sold.paused)).is_equal(1)
	assert_that(String((city.campaign_training[0] as Dictionary).state)).is_equal("PAUSED")


## 2.1: READY ждёт освобождения слота партии и не теряет запись.
func test_ready_recruit_waits_for_free_party_slot() -> void:
	var city := _city()
	var uid := _barracks(city)
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_bool(CampaignTrainingService.request_training(
		city, catalog, uid, "fighter", _trainee(), 2).ok).is_true()
	var waiting := CampaignTrainingService.advance_training_turn(city, 0)
	assert_that(int(waiting.waiting_slot)).is_equal(1)
	assert_that(city.campaign_training.size()).is_equal(1)
	assert_that(String((city.campaign_training[0] as Dictionary).state)).is_equal("READY")

	var issued := CampaignTrainingService.advance_training_turn(city, 1)
	assert_that((issued.members as Array).size()).is_equal(1)
	assert_that(city.campaign_training).is_empty()
	var member: Dictionary = (issued.members as Array)[0]
	assert_that(String(member.id)).is_equal("v1")
	assert_that(String(member.get("class", ""))).is_equal("fighter")
	assert_that(String(member.race)).is_equal("humans")
	assert_int(int(member.get("max_hp", 0))).is_greater(0)


## 2.5: очередь переживает сериализацию города (носитель — blob city.campaign_city).
func test_training_queue_survives_city_roundtrip() -> void:
	var city := _city()
	var uid := _barracks(city)
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_bool(CampaignTrainingService.request_training(
		city, catalog, uid, "fighter", _trainee(), 2).ok).is_true()
	CampaignTrainingService.advance_training_turn(city, 0, 10.0)

	var restored := TestFactories.make_city()
	CitySerializer.deserialize(restored, CitySerializer.serialize(city))
	assert_that(restored.campaign_training.size()).is_equal(1)
	var record: Dictionary = restored.campaign_training[0]
	assert_that(int(record.uid)).is_equal(int((city.campaign_training[0] as Dictionary).uid))
	assert_that(String(record.state)).is_equal("TRAINING")
	assert_float(float(record.progress)).is_equal_approx(\
		float((city.campaign_training[0] as Dictionary).progress), 0.0001)
	# Продолжить можно: восстановленная очередь тикает дальше.
	var before := float(record.progress)
	CampaignTrainingService.advance_training_turn(restored, 0, 10.0)
	assert_float(float((restored.campaign_training[0] as Dictionary).progress)) \
		.is_greater(before)


## 2.5: сейв до появления очереди (version 5) мигрирует в пустую очередь.
func test_save_without_queue_migrates_to_empty() -> void:
	var city := _city()
	var data := CitySerializer.serialize(city)
	data.erase("campaign_training")
	data["version"] = 5
	var restored := TestFactories.make_city()
	CitySerializer.deserialize(restored, data)
	assert_that(restored.campaign_training).is_empty()


## 2.5: битая запись (без class_id) не «чинится» молча — в очередь она не попадает.
func test_malformed_queue_record_is_not_restored() -> void:
	var city := _city()
	var data := CitySerializer.serialize(city)
	data["campaign_training"] = [{"state": "TRAINING"}, {"state": "TRAINING", "class_id": "fighter"}]
	var restored := TestFactories.make_city()
	CitySerializer.deserialize(restored, data)
	assert_that(restored.campaign_training.size()).is_equal(1)
	assert_that(String((restored.campaign_training[0] as Dictionary).get("class_id", ""))).is_equal("fighter")


## Опции города: казарма даёт бойца и следопыта, волшебника нет (ни канон-времени).
func test_city_options_follow_population_gate_and_canon_time() -> void:
	var city := _city()
	var uid := _barracks(city)
	var catalog := CampaignBuildingCatalog.load_catalog()
	var options: Array = CampaignTrainingService.available_training_actions_city(city, catalog, [], 0, 2)
	var classes: Array[String] = []
	for option in options:
		classes.append(String((option as Dictionary).class_id))
	assert_bool(classes.has("fighter")).is_true()
	assert_bool(classes.has("ranger")).is_true()
	assert_bool(classes.has("wizard")).is_false()
	# Ниже порога — ни одной опции (причина — в population_gate_city).
	var poor := _city(5)
	_barracks(poor)
	assert_that(CampaignTrainingService.available_training_actions_city(
		poor, catalog, [], 0, 2)).is_empty()


## Проводка (T-170 вариант (а)): production-фаза тикает очередь города и выдаёт
## члена партии — проверка не сервиса, а именно шва кампании.
func test_production_phase_ticks_queue_and_fills_party() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	var city: City = comp.city
	while city.pop.size() < 40:
		city.add_migrant(PopUnit.State.WORKER, 0)
	city.resource_ctx.add(&"food", 100.0)
	city.resource_ctx.add(&"iron", 20.0)
	city.campaign_buildings.append({
		"uid": 7, "id": "campaign_barracks", "state": "active",
		"construction_turns_remaining": 0, "cell": city.center,
	})
	var alive := PartySystem.alive_members(comp.party).size()
	var result := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "fighter", _trainee(), alive)
	assert_bool(result.ok).is_true()
	comp.advance_turn()
	assert_that(PartySystem.alive_members(comp.party).size()).is_equal(alive + 1)
	assert_that(city.campaign_training).is_empty()
