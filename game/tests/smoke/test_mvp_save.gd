extends BaseTest
## T-110: MVP-сейвы — 3 слота, атомарность, версия major.minor,
## I1 (round-trip + байт-детерминизм), запрет производных величин.

const MvpSaveManager = preload("res://scripts/campaign/save/mvp_save_manager.gd")
const MvpSaveSchema = preload("res://scripts/campaign/save/mvp_save_schema.gd")
const CampaignTrainingService = preload("res://scripts/campaign/campaign_training_service.gd")
const CampaignComposition = preload("res://scripts/campaign/campaign_composition.gd")


func before_test() -> void:
	for slot in [1, 2, 3]:
		MvpSaveManager.delete_slot(slot)
		var tmp := MvpSaveManager.get_slot_path(slot) + ".tmp"
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))


func _sample_state() -> Dictionary:
	return {
		"campaign": {"turn": 1, "seed": 12345, "phase": "exploration"},
		"resources": {"food": 30, "wood": 20, "iron": 10},
		# 40, а не 20: порог тренировки 2.4 (10 жителей на юнит) требует
		# 10 × (2 живых + тренируемый) = 30; число здесь ничего не экономит.
		"population": {"count": 40, "housing": 20},
		"party": [
			{"id": "hero_1", "class": "fighter", "race": "gnome", "level": 1, "xp": 0, "stats": {"str": 15, "dex": 10, "con": 14, "int": 12, "wis": 11, "cha": 8}, "luck": 0},
			{"id": "hero_2", "class": "ranger", "race": "halfling", "level": 1, "xp": 0, "stats": {"str": 10, "dex": 15, "con": 12, "int": 11, "wis": 13, "cha": 9}, "luck": 0},
		],
		"city": {"buildings": {}, "districts": []},
		"map": {"region": "R01", "fog": {}, "nodes": {}},
		"prestige": {"ledger": []},
		"sign": {"id": "R1", "progress": 0},
	}


func test_three_slots_and_bounds() -> void:
	var state := _sample_state()
	for slot in [1, 2, 3]:
		var result := MvpSaveManager.save_slot(slot, state)
		assert_bool(bool(result["ok"])).override_failure_message("slot %d: %s" % [slot, result["message"]]).is_true()
	var bad := MvpSaveManager.save_slot(4, state)
	assert_bool(bool(not bad["ok"] and bad["error"] == MvpSaveManager.SaveError.INVALID_SLOT)) \
		.override_failure_message("slot 4 должен отклоняться: %s" % str(bad["message"])).is_true()
	var bad_load := MvpSaveManager.load_slot(0)
	assert_bool(bool(not bad_load["ok"] and bad_load["error"] == MvpSaveManager.SaveError.INVALID_SLOT)) \
		.override_failure_message("slot 0 при загрузке должен отклоняться").is_true()


func test_round_trip_i1() -> void:
	var state := _sample_state()
	var saved := MvpSaveManager.save_slot(1, state)
	assert_bool(bool(saved["ok"])).override_failure_message(str(saved["message"])).is_true()
	var loaded := MvpSaveManager.load_slot(1)
	assert_bool(bool(loaded["ok"])).override_failure_message(str(loaded["message"])).is_true()
	# T-123: JSON round-trip конвертирует int→float — глубокое == с исходным
	# словарём false на всех числовых листьях (вердикт: баг теста, данные
	# численно идентичны); сравнение — числовое глубокое.
	assert_bool(_num_equal(loaded["state"], state)) \
		.override_failure_message("I1: round-trip должен вернуть идентичное состояние").is_true()


func _num_equal(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a.keys():
			if not b.has(k) or not _num_equal(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _num_equal(a[i], b[i]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b


func test_campaign_city_and_trained_party_state_round_trip() -> void:
	var state := _sample_state()
	state["city"]["campaign_buildings"] = [
		{"uid": 8, "id": "barracks", "state": "active", "cell": {"x": 3, "y": -1}},
	]
	state["city"]["population"] = [
		{"uid": 4, "ancestry_id": "gnome", "archetype_id": "engineers_builders"},
	]
	state["party"].append({
		"id": "trained_1", "class": "fighter", "race": "human", "level": 1,
		"xp": 0, "stats": {"str": 13}, "luck": 0,
	})
	var saved := MvpSaveManager.save_slot(1, state)
	assert_bool(bool(saved["ok"])).override_failure_message(str(saved["message"])).is_true()
	var loaded := MvpSaveManager.load_slot(1)
	assert_bool(bool(loaded["ok"])).override_failure_message(str(loaded["message"])).is_true()
	var saved_city: Dictionary = loaded["state"].city
	assert_that(saved_city.campaign_buildings[0].id).is_equal("barracks")
	assert_that(int(saved_city.campaign_buildings[0].uid)).is_equal(8)
	assert_float(float(saved_city.campaign_buildings[0].cell.x)).is_equal_approx(3.0, 0.0001)
	assert_that(saved_city.population[0].ancestry_id).is_equal("gnome")
	assert_that(saved_city.population[0].archetype_id).is_equal("engineers_builders")
	var trained: Dictionary = loaded["state"].party[-1]
	assert_that(trained.id).is_equal("trained_1")
	assert_that(trained["class"]).is_equal("fighter")
	assert_that(trained.race).is_equal("human")


## party-characters 2.5 (порт с dict-формы, T-171): выученный боец попадает в
## партию и переживает запись/чтение слота — на живом носителе (заявка в очередь
## города, выдача тиком).
## Про стоимость здесь сказано честно: она списывается с city.resource_ctx, а
## build_save_state() пишет секцию "resources" из settlement.stocks — два разных
## регистра, и списание в сейв не попадает (замер T-171: ctx food 700→680,
## stocks 600→600). Dict-форма проверяла 28.0/9.0, потому что сама и писала
## state["resources"]; расхождение регистра зарегистрировано отдельным тикетом.
func test_training_result_is_saved_with_party() -> void:
	var comp: CampaignComposition = CampaignComposition.from_campaign_config(12345)
	var city: City = comp.city
	while city.pop.size() < 40:
		city.add_migrant(PopUnit.State.WORKER, 0)
	city.resource_ctx.add(&"food", 100.0)
	city.resource_ctx.add(&"iron", 20.0)
	city.campaign_buildings.append({"uid": 7, "id": "campaign_barracks", "state": "active",
		"construction_turns_remaining": 0, "cell": city.center})
	var alive := PartySystem.alive_members(comp.party).size()
	var request := CampaignTrainingService.request_training(
		city, CampaignBuildingCatalog.load_catalog(), 7, "fighter",
		{"id": "new_guard", "name": "Guard", "race": "humans",
			"stats": {"str": 13, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}}, alive)
	assert_bool(request.ok).override_failure_message(str(request.get("reason", ""))).is_true()
	var issued: Dictionary = CampaignTrainingService.advance_training_turn(city, 5)
	var members: Array = issued["members"]
	assert_that(members.size()).is_equal(1)
	comp.party.append(members[0])

	var saved := MvpSaveManager.save_slot(1, comp.build_save_state())
	assert_bool(saved.ok).override_failure_message(str(saved.get("message", ""))).is_true()
	var loaded := MvpSaveManager.load_slot(1)
	assert_bool(loaded.ok).is_true()
	var trained: Dictionary = loaded.state.party[-1]
	assert_that(trained.id).is_equal("new_guard")
	assert_that(trained["class"]).is_equal("fighter")
	assert_that(trained.race).is_equal("humans")
	assert_that(city.campaign_training).is_empty()


func test_byte_determinism() -> void:
	var state := _sample_state()
	MvpSaveManager.save_slot(1, state)
	var file := FileAccess.open(MvpSaveManager.get_slot_path(1), FileAccess.READ)
	var bytes_a := file.get_buffer(file.get_length())
	file.close()
	MvpSaveManager.save_slot(2, state)
	file = FileAccess.open(MvpSaveManager.get_slot_path(2), FileAccess.READ)
	var bytes_b := file.get_buffer(file.get_length())
	file.close()
	assert_bool(bool(bytes_a == bytes_b)) \
		.override_failure_message("I1: одинаковые вводные → байт-в-байт одинаковый сейв").is_true()


func test_atomic_no_tmp_left() -> void:
	var state := _sample_state()
	var saved := MvpSaveManager.save_slot(1, state)
	assert_bool(bool(saved["ok"])).override_failure_message(str(saved["message"])).is_true()
	var tmp := MvpSaveManager.get_slot_path(1) + ".tmp"
	assert_bool(bool(not FileAccess.file_exists(tmp))) \
		.override_failure_message("после атомарного сейва tmp-файл не должен оставаться").is_true()


func test_version_minor_compatible() -> void:
	var path := MvpSaveManager.get_slot_path(1)
	var payload := {"version": {"major": 1, "minor": 5}, "state": _sample_state()}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(MvpSaveManager.serialize(payload))
	file.close()
	var loaded := MvpSaveManager.load_slot(1)
	assert_bool(bool(loaded["ok"])).override_failure_message("minor 5 должен быть совместим: %s" % str(loaded["message"])).is_true()


func test_version_major_incompatible() -> void:
	for major in [0, 2]:
		var path := MvpSaveManager.get_slot_path(2)
		var payload := {"version": {"major": major, "minor": 0}, "state": _sample_state()}
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(MvpSaveManager.serialize(payload))
		file.close()
		var loaded := MvpSaveManager.load_slot(2)
		assert_bool(bool(not loaded["ok"] and loaded["error"] == MvpSaveManager.SaveError.INCOMPATIBLE_VERSION)) \
			.override_failure_message("major %d должен отклоняться: %s" % [major, str(loaded["message"])]).is_true()
		MvpSaveManager.delete_slot(2)


func test_derived_keys_rejected() -> void:
	var state := _sample_state()
	state["party"][0]["ladder"] = {"attack": {"margin": 3}}
	var found := MvpSaveSchema.find_derived_keys(state)
	assert_bool(bool(found.size() == 1 and found[0] == "root.party[0].ladder")) \
		.override_failure_message("лестница — производная: %s" % str(found)).is_true()
	var saved := MvpSaveManager.save_slot(1, state)
	assert_bool(bool(not saved["ok"] and saved["error"] == MvpSaveManager.SaveError.INVALID_DATA)) \
		.override_failure_message("сейв с лестницей должен отклоняться").is_true()
	var state2 := _sample_state()
	state2["prestige"]["prestige_balance"] = 1200
	var saved2 := MvpSaveManager.save_slot(1, state2)
	assert_bool(bool(not saved2["ok"] and saved2["error"] == MvpSaveManager.SaveError.INVALID_DATA)) \
		.override_failure_message("баланс Престижа — производная от ledger, сейв должен отклоняться").is_true()


func test_unknown_and_missing_sections() -> void:
	var state := _sample_state()
	state["shards"] = {}
	var saved := MvpSaveManager.save_slot(1, state)
	assert_bool(bool(not saved["ok"] and saved["error"] == MvpSaveManager.SaveError.INVALID_DATA)) \
		.override_failure_message("неизвестная секция должна отклоняться: %s" % str(saved["message"])).is_true()
	state.erase("sign")
	var saved2 := MvpSaveManager.save_slot(1, state)
	assert_bool(bool(not saved2["ok"] and saved2["error"] == MvpSaveManager.SaveError.INVALID_DATA)) \
		.override_failure_message("отсутствующая секция должна отклоняться: %s" % str(saved2["message"])).is_true()


## Catch акта композита (14-я итерация, раунд 4, §3): обязательные секции —
## тест падает при отсутствии ЛЮБОЙ: каждая из SECTIONS по отдельности.
func test_every_missing_section_rejected() -> void:
	for section in MvpSaveSchema.SECTIONS.keys():
		var state := _sample_state()
		state.erase(section)
		var err := MvpSaveSchema.validate(state)
		assert_str(err).is_not_empty() \
			.override_failure_message("отсутствующая секция «%s» должна отклоняться" % section)
		assert_str(err).contains(section) \
			.override_failure_message("ошибка должна называть отсутствующую секцию: %s" % err)
	# Полный состав — валиден (контроль: тест не падает из-за лишнего).
	assert_str(MvpSaveSchema.validate(_sample_state())).is_equal("")


# — T-301: зубы у столбца «покрыто» в doc/SAVE_MATRIX.md ----------------------
#
# Байтовый контракт round-trip (test_cutover_composite, test_campaign_victory)
# сверяет состояние с состоянием: под-ключ, пустой с обеих сторон, потерей не
# считается. Именно поэтому строка матрицы не может быть ссылкой на контракт —
# ей нужен ассерт на непустоту. Без него столбец «покрыто» гниёт молча: сборка
# перестаёт писать секцию, round-trip остаётся зелёным, матрица врёт.
# Батарея, доказывающая зубы: game/tools/mut_save_sections.sh (M1 map.threats,
# M2 city.sm, M4 resources — здесь; M3 birth_carry — в кейсе ниже; все красные).


func _finished_campaign(seed_value: int = 12345) -> CampaignComposition:
	# Тот же composition root, что и main.gd (тот же прогон, что и вершинный
	# контракт test_cutover_composite: 21 ход, K-канон-линия).
	var c := CampaignComposition.from_campaign_config(seed_value)
	var guard := 0
	while not c.campaign.is_done() and guard < 21:
		guard += 1
		c.advance_turn()
	return c


func test_finished_campaign_leaves_no_empty_save_section() -> void:
	var c := _finished_campaign()
	assert_int(c.campaign.current_turn).is_greater(1)
	assert_str(c.campaign.campaign_status).is_not_empty()
	var state := c.build_save_state()

	var res: Dictionary = state["resources"]
	for key in ["food", "wood", "iron"]:
		assert_bool(absf(float(res.get(key, 0.0))) > 0.0).is_true() \
			.override_failure_message("resources.%s нулевой — строка матрицы пуста" % key)

	var pop: Dictionary = state["population"]
	assert_bool((pop.get("residents", []) as Array).size() > 0).is_true()
	assert_int(int(pop.get("next_uid", 0))).is_greater(0)

	var city: Dictionary = state["city"]
	assert_bool((city.get("buildings", []) as Array).size() > 0).is_true()
	assert_bool((city.get("districts", {}) as Dictionary).size() > 0).is_true()
	assert_bool((city.get("sm", {}) as Dictionary).size() > 0).is_true()
	assert_bool(int(city.get("housing", 0)) > 0).is_true()
	assert_bool(int(city.get("party_size", 0)) > 0).is_true()

	var map_sec: Dictionary = state["map"]
	assert_bool((map_sec.get("region", {}) as Dictionary).size() > 0).is_true()
	assert_bool((map_sec.get("threats", {}) as Dictionary).size() > 0).is_true() \
		.override_failure_message("map.threats пуст — «покрыто» в матрице было бы ложью")

	var camp: Dictionary = state["campaign"]
	assert_bool(camp.has("final_battle_seen")).is_true()
	assert_bool(camp.has("final_raid_repelled")).is_true()
	assert_bool((camp.get("chronicle", {}) as Dictionary).size() > 0).is_true()
	assert_bool((camp.get("goals", {}) as Dictionary).size() > 0).is_true()
	assert_bool((camp.get("ethics", {}) as Dictionary).size() > 0).is_true()
	assert_bool((camp.get("supply", {}) as Dictionary).size() > 0).is_true()

	var ledger: Array = (state.get("prestige", {}) as Dictionary).get("ledger", [])
	assert_int(ledger.size()).is_greater(0)
	assert_str(str((state.get("sign", {}) as Dictionary).get("state", ""))).is_not_empty()


func test_population_carries_survive_save_roundtrip() -> void:
	# Переносы дробного счёта населения (population_system.gd:245-246 / :255-256)
	# на канонической линии кампании равны 0.0 (голод, Репутация 0) — whole-state
	# контракт их потерю не видит. Состояние строится напрямую: переносы
	# накапливаются на дробном притоке.
	var PopulationSystem := load("res://scripts/campaign/population_system.gd")
	var pop = PopulationSystem.new()
	pop.process_turn(1, 0.7)
	var live_birth: float = pop._birth_carry
	var live_mig: float = pop._mig_carry
	if live_birth == 0.0 and live_mig == 0.0:
		fail("переносы не накопились на process_turn(1, 0.7) — тест стал пустым")

	# Сторона записи: to_dict обязан нести фактические переносы, а не 0.0. Без
	# этого шага мутант «to_dict пишет 0.0» зелёный: from_dict честно читает то,
	# что записано, и round-trip-равенство (0.0 == 0.0) потери не замечает.
	var d: Dictionary = pop.to_dict()
	assert_float(float(d.get("birth_carry", 0.0))).is_equal(live_birth)
	assert_float(float(d.get("mig_carry", 0.0))).is_equal(live_mig)

	# Сторона чтения: from_dict — статический конструктор, не метод экземпляра.
	var restored = PopulationSystem.from_dict(d)
	assert_float(float(restored.to_dict().get("birth_carry", -1.0))).is_equal(live_birth)
	assert_float(float(restored.to_dict().get("mig_carry", -1.0))).is_equal(live_mig)

	# Сейв, записанный до появления ключей, не должен их выдумывать.
	var legacy = PopulationSystem.from_dict({"residents": [], "next_uid": 1})
	assert_float(float(legacy.to_dict().get("birth_carry", -1.0))).is_equal(0.0)
	assert_float(float(legacy.to_dict().get("mig_carry", -1.0))).is_equal(0.0)
