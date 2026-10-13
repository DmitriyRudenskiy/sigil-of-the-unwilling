"""T-030: районный слой — 7 групп, рабочие/вакансии, настроение, нужды, «три в одном».

Числа — districts.json (K-M15): старт 70, пороги <40/≥80, множители 0.85/1.10,
дефицит −10/день, дезертирство 1 поп/2 дня (02g §5, 07-balance §5).
"""
extends BaseTest

const SettlementProcessorScript := preload("res://scripts/campaign/settlement_processor.gd")


func _config() -> Dictionary:
	return MvpInvariants.load_config("districts")


func _system() -> DistrictSystem:
	return DistrictSystem.new(_config(), {"farm": 2, "sawmill": 2, "mine": 2})


func _start_buildings() -> Array:
	return [
		{"id": "farm", "group": "Земледельцы и Пивовары", "output_day": {"food": 1.0}, "efficiency": 1.0},
		{"id": "sawmill", "group": "Инженеры и Строители", "output_day": {"wood": 0.5}, "efficiency": 1.0},
		{"id": "mine", "group": "Металлурги и Техники", "output_day": {"iron": 0.25}, "efficiency": 1.0},
	]


func test_seven_districts_start_at_70() -> void:
	var sys := _system()
	for g in SettlementProcessorScript.GROUPS:
		assert_float(float(sys.mood[str(g)])).override_failure_message(
			"старт настроения не 70: " + str(g)).is_equal(70.0)
	var report := sys.process_turn(_start_buildings(), 20, 5, "OK")
	var districts: Dictionary = report.get("districts", {})
	assert_int(SettlementProcessorScript.GROUPS.size()).is_equal(7)
	assert_int(districts.size()).is_equal(8)  # 7 групп + «Без группы»
	# Покрытая нужда (ферма: кап 6 ≥ спрос 2) — без дрейфа; непокрытая −1/сезон.
	assert_float(float(districts["Земледельцы и Пивовары"]["mood"])) \
		.override_failure_message("покрытая нужда сдвинула настроение").is_equal(70.0)
	assert_float(float(districts["Инженеры и Строители"]["mood"])) \
		.override_failure_message("непокрытая нужда не дала −1/сезон").is_equal(69.0)


func test_workers_assigned_and_vacancy_halts_building() -> void:
	var sys := _system()
	var buildings := _start_buildings()
	# Рабочих хватает только на первое здание порядка GROUPS (Инженеры — лесопилка).
	sys.process_turn(buildings, 2, 0, "OK")
	assert_int(int(buildings[1]["workers"])).override_failure_message("лесопилка не укомплектована").is_equal(2)
	assert_int(int(buildings[0]["workers"])).override_failure_message("на ферме не хватило рабочих").is_equal(0)
	# Вакансия останавливает здание (02g §3): производство нулевое.
	var proc: SettlementProcessor = SettlementProcessor.new()
	proc.buildings = buildings
	proc.population = 0
	proc.stocks = {"food": 0.0, "wood": 0.0, "iron": 0.0}
	var report: Dictionary = proc.process_production(1.0)
	var prod: Dictionary = report.get("production", {})
	assert_float(float(prod.get("wood", 0.0))).override_failure_message(
		"укомплектованная лесопилка не производит").is_greater(0.0)
	assert_float(float(prod.get("food", 0.0))).override_failure_message(
		"здание с вакансией производит (должно стоять)").is_equal(0.0)


func test_mood_thresholds_drive_production_mult() -> void:
	var sys := _system()
	sys.mood["Инженеры и Строители"] = 30.0  # <40 → ×0.85
	sys.mood["Металлурги и Техники"] = 85.0  # ≥80 → ×1.10
	var buildings := _start_buildings()
	sys.process_turn(buildings, 20, 0, "OK")
	assert_float(float(buildings[1].get("mood_mult", 0.0))).override_failure_message(
		"низкое настроение не дало ×0.85").is_equal(0.85)
	assert_float(float(buildings[2].get("mood_mult", 0.0))).override_failure_message(
		"высокое настроение не дало ×1.10").is_equal(1.1)
	assert_float(float(buildings[0].get("mood_mult", 0.0))).override_failure_message(
		"норма (40–79) не должна множить").is_equal(1.0)


func test_famine_drops_mood_and_deserts() -> void:
	var sys := _system()
	var buildings := _start_buildings()
	# DEFICIT (голод): −10/день × 20 дней → пол 0; <40 → дезертирство 1/2 дня.
	var report := sys.process_turn(buildings, 20, 5, "DEFICIT")
	assert_float(float(sys.mood["Земледельцы и Пивовары"])).override_failure_message(
		"голод не уронил настроение в пол").is_equal(0.0)
	assert_int(int(report.get("desertion", 0))).override_failure_message(
		"дезертирство <40: 1 поп/2 дня (поселенческое, D-134)").is_equal(10)


func test_need_mvp_cut_food_per_group() -> void:
	var sys := _system()
	var buildings := _start_buildings()
	var report := sys.process_turn(buildings, 20, 5, "OK")
	var districts: Dictionary = report.get("districts", {})
	# Ферма: кап 6 (02g §5.4) ≥ спрос 2×1 → покрыта; лесопилка: кап 0 < 2 → нет.
	assert_bool(bool(districts["Земледельцы и Пивовары"]["need_ok"])) \
		.override_failure_message("нужда еды фермерского района не покрыта").is_true()
	assert_bool(bool(districts["Инженеры и Строители"]["need_ok"])) \
		.override_failure_message("нужда без провайдера не может быть покрыта").is_false()


func test_merge_three_in_one() -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	var buildings := [
		{"id": "terrascape_fruit_farm", "group": "Земледельцы и Пивовары", "output_day": {"food": 1.0}},
		{"id": "campaign_farm", "group": "Земледельцы и Пивовары", "output_day": {"food": 2.0}},
		{"id": "campaign_farm", "group": "Земледельцы и Пивовары", "output_day": {"food": 2.0}},
	]
	var result := DistrictSystem.merge_three(buildings, catalog, "terrascape_fruit_farm")
	assert_bool(bool(result.get("ok", false))).override_failure_message(
		"«три в одном» не слилось: " + str(result.get("reason", ""))).is_true()
	var merged: Array = result.get("buildings", [])
	assert_int(merged.size()).is_equal(1)
	assert_str(str(merged[0].get("id", ""))).is_equal("terrascape_fruit_farm")
	# Компонентов нет — отказ.
	var poor := [{"id": "terrascape_fruit_farm", "group": "Земледельцы и Пивовары"}]
	assert_bool(bool(DistrictSystem.merge_three(poor, catalog, "terrascape_fruit_farm").get("ok", true))) \
		.override_failure_message("слияние без компонентов прошло").is_false()


func test_composition_wires_districts_into_save() -> void:
	var c: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	c.advance_turn()
	# Стартовые здания укомплектованы (население 20 ≥ 6 слотов) — производство не встало.
	for b in c.settlement.buildings:
		assert_int(int(b.get("workers", -1))).override_failure_message(
			"стартовое здание не назначено: " + str(b.get("id", ""))).is_equal(int(b.get("jobs", 0)))
	var state := c.build_save_state()
	var saved_mood: Dictionary = (state.get("city", {}).get("districts", {}) as Dictionary).get("mood", {})
	assert_int(saved_mood.size()).override_failure_message("настроение не собрано в сейв").is_equal(8)
	var c2: CampaignComposition = CampaignComposition.from_campaign_config(999)
	c2.load_save_state(state)
	assert_float(c2.districts.mood["Земледельцы и Пивовары"]).override_failure_message(
		"настроение не восстановилось из сейва").is_equal(
			float(saved_mood["Земледельцы и Пивовары"]))
