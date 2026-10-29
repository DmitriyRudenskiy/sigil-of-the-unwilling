extends BaseTest

# party-training 2.1/2.5 (T-170, вариант (а)): SM рекрута на живом носителе —
# очередь живёт в City.campaign_training, тикает из production-фазы, сериализуется
# CitySerializer'ом. Проверки те же, что у dict-формы (train()), но против
# объекта города: тот самый, который видит экран города и живой сейв.

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
## Сам скрипт сервиса, а не class_name: инвариант T-171 смотрит список методов.
const ServiceScript := preload("res://scripts/campaign/campaign_training_service.gd")

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


## Список стоимости и её источник — часть договора: без `source` списание
## неотличимо от произвольной правки ресурса города (dict-форма проверяла это
## своим `flow.source`; после T-171 проверка живёт здесь).
func test_request_writes_a_single_ledger_flow_with_training_source() -> void:
	var city := _city()
	_barracks(city)
	assert_bool(CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "fighter", _trainee(), 2).ok).is_true()
	var ledger := city.resource_ctx.get_ledger()
	assert_that(ledger.size()).is_equal(1)
	assert_that(String((ledger[0] as Dictionary).get("source", ""))) \
		.is_equal("training:v1/class:fighter")


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


## party-characters 2.3: замена мёртвого — тот же класс, уровень из конфига.
func test_replacement_reuses_dead_class_and_config_level() -> void:
	var city := _city()
	city.campaign_buildings.append({
		"uid": 8, "id": "aoe4_barracks", "state": "active",
		"construction_turns_remaining": 0, "cell": Vector2i(21, 21),
	})
	var dead := {"id": "h1", "class": "fighter", "race": "humans", "level": 3, "state": "DEAD"}
	var result := CampaignTrainingService.request_replacement(
		city, CampaignBuildingCatalog.load_catalog(), 8, dead,
		{"id": "v9", "race": "humans", "stats": {"str": 14, "dex": 10, "con": 10, "int": 10,
			"wis": 10, "cha": 10}}, 2)
	assert_bool(result.ok).is_true()
	var record: Dictionary = city.campaign_training[0]
	assert_that(String(record.get("class_id", ""))).is_equal("fighter")
	assert_that(int((record.get("trainee", {}) as Dictionary).get("level", 0))) \
		.is_equal(CampaignTrainingService.replacement_level())
	var issued := CampaignTrainingService.advance_training_turn(city, 5)
	var member: Dictionary = (issued.members as Array)[0]
	assert_that(String(member.get("class", ""))).is_equal("fighter")
	assert_that(int(member.get("level", 0))) \
		.is_equal(CampaignTrainingService.replacement_level())


## 2.3: «замена мёртвых» — не «тренировка живого»: живой кандидат отклоняется.
func test_replacement_refuses_living_member() -> void:
	var city := _city()
	var uid := _barracks(city)
	var result := CampaignTrainingService.request_replacement(
		city, CampaignBuildingCatalog.load_catalog(), uid,
		{"id": "h1", "class": "fighter", "state": "READY"}, _trainee("v9"), 2)
	assert_bool(result.ok).is_false()
	assert_that(String(result.reason)).is_equal("member_not_dead")
	assert_that(city.campaign_training).is_empty()
	assert_float(city.resource_ctx.amount(&"iron")).is_equal_approx(20.0, 0.0001)


## 2.3: класс покойного должен тренироваться именно в этом здании.
func test_replacement_requires_class_trained_in_that_building() -> void:
	var city := _city()
	city.campaign_buildings.append({
		"uid": 8, "id": "aoe4_barracks", "state": "active",
		"construction_turns_remaining": 0, "cell": Vector2i(21, 21),
	})
	var result := CampaignTrainingService.request_replacement(
		city, CampaignBuildingCatalog.load_catalog(), 8,
		{"id": "h2", "class": "ranger", "state": "DEAD"},
		{"id": "v10", "race": "humans",
			"stats": {"str": 10, "dex": 14, "con": 10, "int": 10, "wis": 14, "cha": 10}}, 2)
	assert_bool(result.ok).is_false()
	assert_that(String(result.reason)).is_equal("class_not_trained_here:ranger")
	assert_that(city.campaign_training).is_empty()


## 2.3: уровень замены — число из конфига, а не из словаря кандидата.
func test_replacement_level_reads_balance_config() -> void:
	assert_int(CampaignTrainingService.replacement_level()).is_equal(1)


## ─── Порт с dict-формы (T-171) ───────────────────────────────────────────────
## Эти восемь проверок держала T-110-форма `train()`/`available_training_actions()`.
## Сюда они перенесены в том же смысле, но против живого носителя: отказ
## по-прежнему значит «ни записи в очередь, ни списания с города».


## Синтетический каталог нужен там, где реальный `campaign_barracks` проверить не
## может: отсутствующий prerequisite и стоимость незарегистрированным ресурсом.
func _synthetic_catalog(requires_admin: bool = false,
		costs: Dictionary = {"food": 2.0, "iron": 1.0}) -> Dictionary:
	return {"schema_version": 1, "buildings": [{
		"id": "campaign_barracks",
		"training": [{"class_id": "fighter", "costs": costs}],
		"prerequisites": {"buildings": ["admin"] if requires_admin else [],
			"scenario_flags": [], "admin_capacity": 0},
	}]}


## Опции города: ни неодобренного класса, ни класса без канон-времени.
func test_city_options_expose_only_approved_classes() -> void:
	var city := _city()
	_barracks(city)
	var catalog := _synthetic_catalog()
	(catalog.buildings[0] as Dictionary).training = [
		{"class_id": "fighter", "costs": {"food": 2.0, "iron": 1.0}},
		{"class_id": "swordsmen", "costs": {"food": 1.0}},
		{"class_id": "warship", "costs": {"food": 1.0}},
	]
	var options: Array = CampaignTrainingService.available_training_actions_city(
		city, catalog, [], 0, 0)
	assert_that(options.size()).is_equal(1)
	assert_that(String((options[0] as Dictionary).class_id)).is_equal("fighter")


## Наследие `City.level` (повышение города) не гейтит тренировку: опции и заявка
## не зависят от того, первый уровень у города или одиннадцатый.
func test_city_unlocks_ignore_legacy_city_level() -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	var low := _city()
	_barracks(low)
	low.level = 1
	var high := _city()
	_barracks(high)
	high.level = 11
	var low_options: Array = CampaignTrainingService.available_training_actions_city(low, catalog)
	var high_options: Array = CampaignTrainingService.available_training_actions_city(high, catalog)
	assert_that(low_options).is_equal(high_options)
	assert_bool(CampaignTrainingService.request_training(
		low, catalog, 7, "fighter", _trainee(), 0).ok).is_true()


## Гейт класса и отсутствующая постройка-требование: отказ до списания, очередь
## пуста, город не беднее.
func test_request_rejects_class_gate_and_missing_prerequisite() -> void:
	var weak := _city()
	_barracks(weak)
	var before := weak.resource_ctx.serialize()
	var gate := CampaignTrainingService.request_training(
		weak, _synthetic_catalog(), 7, "fighter",
		{"id": "v2", "race": "humans", "stats": {"str": 12, "dex": 10, "con": 10,
			"int": 10, "wis": 10, "cha": 10}}, 0)
	assert_bool(gate.ok).is_false()
	assert_that(String(gate.reason).begins_with("class_gate:")).is_true()
	assert_that(weak.campaign_training).is_empty()
	assert_that(weak.resource_ctx.serialize()).is_equal(before)

	var no_admin := _city()
	_barracks(no_admin)
	var prereq := CampaignTrainingService.request_training(
		no_admin, _synthetic_catalog(true), 7, "fighter", _trainee(), 0)
	assert_bool(prereq.ok).is_false()
	assert_that(String(prereq.reason)).is_equal("prerequisite_missing")
	assert_that(no_admin.campaign_training).is_empty()
	assert_that(no_admin.resource_ctx.serialize()).is_equal(before)


## Недострой сеть не держит: опций нет, заявка отклонена, списаний нет.
func test_in_progress_building_cannot_train() -> void:
	var city := _city()
	_barracks(city, "active", 1)
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_that(CampaignTrainingService.available_training_actions_city(
		city, catalog, [], 0, 0)).is_empty()
	var before := city.resource_ctx.serialize()
	var result := CampaignTrainingService.request_training(city, catalog, 7, "fighter", _trainee(), 0)
	assert_bool(result.ok).is_false()
	assert_that(String(result.reason)).is_equal("training_building_unavailable")
	assert_that(city.campaign_training).is_empty()
	assert_that(city.resource_ctx.serialize()).is_equal(before)


## generic_unit из MVP-каталога — не класс: заявка отклонена до очереди.
func test_request_rejects_unapproved_generic_unit() -> void:
	var city := _city()
	_barracks(city)
	var before := city.resource_ctx.serialize()
	var result := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "swordsmen", _trainee(), 0)
	assert_bool(result.ok).is_false()
	assert_that(String(result.reason)).is_equal("unsupported_class:swordsmen")
	assert_that(city.campaign_training).is_empty()
	assert_that(city.resource_ctx.serialize()).is_equal(before)


## Списание атомарно: не хватило железа — ни частичного списания, ни записи.
func test_request_payment_failure_is_atomic() -> void:
	var city := _city()
	city.resource_ctx.deserialize({"food": 100.0, "wood": 100.0})
	_barracks(city)
	var before := city.resource_ctx.serialize()
	var result := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "fighter", _trainee(), 0)
	assert_bool(result.ok).is_false()
	assert_that(String(result.reason)).is_equal("insufficient_stock")
	assert_that(city.campaign_training).is_empty()
	assert_that(city.resource_ctx.serialize()).is_equal(before)


## Разрушенная постройка и стоимость вне реестра ресурсов — тот же отказ.
func test_request_rejects_ruined_building_and_unregistered_resource() -> void:
	var ruined := _city()
	_barracks(ruined, "ruined")
	var before := ruined.resource_ctx.serialize()
	var ruined_result := CampaignTrainingService.request_training(
		ruined, CampaignBuildingCatalog.load_catalog(), 7, "fighter", _trainee(), 0)
	assert_that(String(ruined_result.reason)).is_equal("training_building_unavailable")
	assert_that(ruined.resource_ctx.serialize()).is_equal(before)

	var gold := _city()
	_barracks(gold)
	var gold_result := CampaignTrainingService.request_training(
		gold, _synthetic_catalog(false, {"gold": 1.0}), 7, "fighter", _trainee(), 0)
	assert_that(String(gold_result.reason)).is_equal("unregistered_training_resource:gold")
	assert_that(gold.campaign_training).is_empty()


## Тултип «нужно +N жителей» (spec: «the UI shows the population constraint»):
## порог считается на юнит, и очередь города входит в меру — в отличие от
## dict-формы, где очередь не учитывалась (расхождение зафиксировано T-171).
func test_population_gate_city_reports_missing_residents() -> void:
	var city := _city(4)
	var gate: Dictionary = CampaignTrainingService.population_gate_city(city, 4)
	assert_bool(bool(gate.get("ok", true))).is_false()
	assert_that(int(gate.get("required", 0))).is_equal(50)
	assert_that(int(gate.get("missing", 0))).is_equal(46)
	var rich := _city(100)
	assert_that(int(CampaignTrainingService.population_gate_city(rich, 0).get("required", 0))) \
		.is_equal(10)
	_barracks(rich)
	assert_bool(CampaignTrainingService.request_training(
		rich, CampaignBuildingCatalog.load_catalog(), 7, "fighter", _trainee("w1"), 0).ok).is_true()
	assert_that(int(CampaignTrainingService.population_gate_city(rich, 0).get("required", 0))) \
		.is_equal(20)


## 2.4: число порога — из баланса-конфига (campaign.json training), не из кода.
func test_population_threshold_reads_balance_config() -> void:
	assert_int(CampaignTrainingService.population_per_unit()).is_equal(10)


## Канон времени тренировки (07-balance «Базовые бойцы MVP», K-M15): воин 0.6,
## следопыт 0.5; волшебника нет — T-041 (0.0 = число не установлено).
func test_training_days_come_from_balance_config() -> void:
	assert_float(CampaignTrainingService.training_days("fighter")).is_equal_approx(0.6, 0.0001)
	assert_float(CampaignTrainingService.training_days("ranger")).is_equal_approx(0.5, 0.0001)
	assert_float(CampaignTrainingService.training_days("wizard")).is_equal_approx(0.0, 0.0001)


## T-171: у сервиса один вход. Dict-форма (`train`, `available_training_actions`,
## `population_gate`, `_building_instances`) читателя не имела и держала вытесненную
## семантику «боец сразу в партии» — возврат её вернёт и расхождение гейтов,
## поэтому отсутствие проверяется по списку методов скрипта, а не по grep.
func test_dict_entry_points_are_gone() -> void:
	var script: Script = ServiceScript
	var names: Array[String] = []
	for method in script.get_script_method_list():
		names.append(String((method as Dictionary).get("name", "")))
	assert_that(names.size()).is_greater(0)  # сломанный разбор не должен зелёнить
	for gone in ["train", "available_training_actions", "population_gate",
			"_building_instances"]:
		assert_bool(gone in names).is_false()
	for alive in ["request_training", "available_training_actions_city",
			"population_gate_city", "advance_training_turn"]:
		assert_bool(alive in names).is_true()


## D-221 (alive-модель) на живом носителе: DEAD не занимают активный слот.
## Слоты считает вызывающий — `campaign_composition.gd` (`_process_city_training`:
## PARTY_CAPACITY − alive_members(party)); проверка фиксирует то же правило на шве
## тренировки. Dict-форма держала его внутри себя (`party_capacity_reached` на
## заявке) и потому отказывала там, где по spec рекрут становится в очередь.
func test_dead_members_do_not_consume_a_training_slot() -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	var roster := [
		{"id": "h1", "class": "fighter", "state": "READY"},
		{"id": "h2", "class": "ranger", "state": "READY"},
		{"id": "h3", "class": "fighter", "state": "READY"},
		{"id": "h4", "class": "ranger", "state": "READY"},
		{"id": "h5", "class": "fighter", "state": "DEAD"},
	]
	var alive := PartySystem.alive_members(roster).size()
	assert_that(alive).is_equal(4)
	var city := _city(70)
	_barracks(city)
	assert_bool(CampaignTrainingService.request_training(
		city, catalog, 7, "fighter", _trainee(), alive).ok).is_true()
	var issued := CampaignTrainingService.advance_training_turn(
		city, CampaignTrainingService.PARTY_CAPACITY - alive)
	assert_that((issued.members as Array).size()).is_equal(1)

	# Пять живых — свободных слотов нет: заявка ждёт слота, а не отклоняется.
	var full := _city(70)
	_barracks(full)
	assert_bool(CampaignTrainingService.request_training(
		full, catalog, 7, "fighter", _trainee("v2"), 5).ok).is_true()
	var blocked := CampaignTrainingService.advance_training_turn(
		full, CampaignTrainingService.PARTY_CAPACITY - 5)
	assert_that((blocked.members as Array).size()).is_equal(0)
	assert_that(int(blocked.waiting_slot)).is_equal(1)
