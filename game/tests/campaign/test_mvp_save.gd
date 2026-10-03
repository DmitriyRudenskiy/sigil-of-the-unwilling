extends BaseTest
## T-110: MVP-сейвы — 3 слота, атомарность, версия major.minor,
## I1 (round-trip + байт-детерминизм), запрет производных величин.

const MvpSaveManager = preload("res://scripts/campaign/save/mvp_save_manager.gd")
const MvpSaveSchema = preload("res://scripts/campaign/save/mvp_save_schema.gd")


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
		"population": {"count": 20, "housing": 20},
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
		assert_that(result["ok"]).override_failure_message("slot %d: %s" % [slot, result["message"]])
	var bad := MvpSaveManager.save_slot(4, state)
	assert_that(not bad["ok"] and bad["error"] == MvpSaveManager.SaveError.INVALID_SLOT) \
		.override_failure_message("slot 4 должен отклоняться: %s" % str(bad["message"]))
	var bad_load := MvpSaveManager.load_slot(0)
	assert_that(not bad_load["ok"] and bad_load["error"] == MvpSaveManager.SaveError.INVALID_SLOT) \
		.override_failure_message("slot 0 при загрузке должен отклоняться")


func test_round_trip_i1() -> void:
	var state := _sample_state()
	var saved := MvpSaveManager.save_slot(1, state)
	assert_that(saved["ok"]).override_failure_message(str(saved["message"]))
	var loaded := MvpSaveManager.load_slot(1)
	assert_that(loaded["ok"]).override_failure_message(str(loaded["message"]))
	assert_that(loaded["state"] == state) \
		.override_failure_message("I1: round-trip должен вернуть идентичное состояние")


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
	assert_that(bytes_a == bytes_b) \
		.override_failure_message("I1: одинаковые вводные → байт-в-байт одинаковый сейв")


func test_atomic_no_tmp_left() -> void:
	var state := _sample_state()
	var saved := MvpSaveManager.save_slot(1, state)
	assert_that(saved["ok"]).override_failure_message(str(saved["message"]))
	var tmp := MvpSaveManager.get_slot_path(1) + ".tmp"
	assert_that(not FileAccess.file_exists(tmp)) \
		.override_failure_message("после атомарного сейва tmp-файл не должен оставаться")


func test_version_minor_compatible() -> void:
	var path := MvpSaveManager.get_slot_path(1)
	var payload := {"version": {"major": 1, "minor": 5}, "state": _sample_state()}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(MvpSaveManager.serialize(payload))
	file.close()
	var loaded := MvpSaveManager.load_slot(1)
	assert_that(loaded["ok"]).override_failure_message("minor 5 должен быть совместим: %s" % str(loaded["message"]))


func test_version_major_incompatible() -> void:
	for major in [0, 2]:
		var path := MvpSaveManager.get_slot_path(2)
		var payload := {"version": {"major": major, "minor": 0}, "state": _sample_state()}
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(MvpSaveManager.serialize(payload))
		file.close()
		var loaded := MvpSaveManager.load_slot(2)
		assert_that(not loaded["ok"] and loaded["error"] == MvpSaveManager.SaveError.INCOMPATIBLE_VERSION) \
			.override_failure_message("major %d должен отклоняться: %s" % [major, str(loaded["message"])])
		MvpSaveManager.delete_slot(2)


func test_derived_keys_rejected() -> void:
	var state := _sample_state()
	state["party"][0]["ladder"] = {"attack": {"margin": 3}}
	var found := MvpSaveSchema.find_derived_keys(state)
	assert_that(found.size() == 1 and found[0] == "root.party[0].ladder") \
		.override_failure_message("лестница — производная: %s" % str(found))
	var saved := MvpSaveManager.save_slot(1, state)
	assert_that(not saved["ok"] and saved["error"] == MvpSaveManager.SaveError.INVALID_DATA) \
		.override_failure_message("сейв с лестницей должен отклоняться")
	var state2 := _sample_state()
	state2["prestige"]["prestige_balance"] = 1200
	var saved2 := MvpSaveManager.save_slot(1, state2)
	assert_that(not saved2["ok"] and saved2["error"] == MvpSaveManager.SaveError.INVALID_DATA) \
		.override_failure_message("баланс Престижа — производная от ledger, сейв должен отклоняться")


func test_unknown_and_missing_sections() -> void:
	var state := _sample_state()
	state["shards"] = {}
	var saved := MvpSaveManager.save_slot(1, state)
	assert_that(not saved["ok"] and saved["error"] == MvpSaveManager.SaveError.INVALID_DATA) \
		.override_failure_message("неизвестная секция должна отклоняться: %s" % str(saved["message"]))
	state.erase("sign")
	var saved2 := MvpSaveManager.save_slot(1, state)
	assert_that(not saved2["ok"] and saved2["error"] == MvpSaveManager.SaveError.INVALID_DATA) \
		.override_failure_message("отсутствующая секция должна отклоняться: %s" % str(saved2["message"]))
