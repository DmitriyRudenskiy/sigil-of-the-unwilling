extends BaseTest
## T-110: MVP-сейвы — 3 слота, атомарность, версия major.minor,
## I1 (round-trip + байт-детерминизм), запрет производных величин.

const MvpSaveManager = preload("res://scripts/campaign/save/mvp_save_manager.gd")
const MvpSaveSchema = preload("res://scripts/campaign/save/mvp_save_schema.gd")
const CampaignTrainingService = preload("res://scripts/campaign/campaign_training_service.gd")


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

func test_training_result_is_saved_with_party_and_resource_costs() -> void:
	var state := _sample_state()
	state.city.campaign_buildings = [{"uid": 8, "id": "barracks", "state": "active"}]
	var catalog := {"schema_version": 1, "buildings": [{
		"id": "barracks", "training": [{"class_id": "fighter",
			"costs": {"food": 2.0, "iron": 1.0}}],
		"prerequisites": {"buildings": [], "scenario_flags": [], "admin_capacity": 0},
	}]}
	var trained := CampaignTrainingService.train(state, catalog, 8, "fighter", {
		"id": "new_guard", "name": "Guard", "race": "humans",
		"stats": {"str": 13, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10},
	})
	assert_bool(trained.ok).is_true()
	var saved := MvpSaveManager.save_slot(1, state)
	assert_bool(saved.ok).is_true()
	var loaded := MvpSaveManager.load_slot(1)
	assert_bool(loaded.ok).is_true()
	assert_that(loaded.state.party[-1].id).is_equal("new_guard")
	assert_that(loaded.state.party[-1]["class"]).is_equal("fighter")
	assert_float(float(loaded.state.resources.food)).is_equal_approx(28.0, 0.0001)
	assert_float(float(loaded.state.resources.iron)).is_equal_approx(9.0, 0.0001)

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
