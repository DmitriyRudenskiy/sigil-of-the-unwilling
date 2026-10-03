extends BaseTest

## T-110. Система сейвов (D-135, Ф4-восстановление).
## Схема секций, запрет производных значений, версия major.minor с
## minor-совместимостью, 3 слота, атомарная запись, байтовая детерминизм (I1).


var _sys: SaveSystem = null


func before_test() -> void:
	_sys = SaveSystem.new()
	_clean_all_slots()


func after_test() -> void:
	super.after_test()
	_clean_all_slots()
	_sys = null


func _clean_all_slots() -> void:
	var dir := DirAccess.open(SaveSystem.SAVE_DIR)
	if dir == null:
		return
	for slot in SaveSystem.SLOTS:
		var path := SaveSystem.SAVE_DIR.path_join("save_%d.json" % slot)
		if FileAccess.file_exists(path):
			dir.remove(path)
		var tmp := path + ".tmp"
		if FileAccess.file_exists(tmp):
			dir.remove(tmp)


func _sample_state() -> Dictionary:
	return {
		"campaign": {"turn": 5, "date": 12},
		"party": {"characters": ["a", "b"]},
		"city": {"districts": 2},
		"economy": {"food": 40},
		"map": {"fog": ["N4", "N6"]},
		"prestige": {"ledger": [{"turn": 3, "deed": "victory", "value": 10}]},
	}


func test_save_and_load_roundtrip() -> void:
	assert_that(_sys.save(1, _sample_state())).is_equal(OK)
	var result: Dictionary = _sys.load(1)
	assert_that(result["error"]).is_equal(OK)
	assert_that(result["version"]).is_equal(SaveSystem.VERSION)
	assert_that(result["state"]).is_equal(_sample_state())


func test_invalid_slot_rejected() -> void:
	assert_that(_sys.save(0, _sample_state())).is_equal(ERR_INVALID_PARAMETER)
	assert_that(_sys.save(4, _sample_state())).is_equal(ERR_INVALID_PARAMETER)
	assert_that((_sys.load(0) as Dictionary)["error"]).is_equal(ERR_INVALID_PARAMETER)


func test_missing_slot() -> void:
	var result: Dictionary = _sys.load(2)
	assert_that(result["error"]).is_equal(ERR_FILE_NOT_FOUND)


func test_forbidden_derived_keys_rejected() -> void:
	var s1 := _sample_state()
	s1["ladder"] = {"step": 3}
	assert_that(_sys.save(1, s1)).is_equal(ERR_INVALID_DATA)

	var s2 := _sample_state()
	(s2["party"] as Dictionary)["morale"] = 80
	assert_that(_sys.save(1, s2)).is_equal(ERR_INVALID_DATA)

	var s3 := _sample_state()
	(s3["party"] as Dictionary)["effective_stats"] = {"str": 10}
	assert_that(_sys.save(1, s3)).is_equal(ERR_INVALID_DATA)

	var s4 := _sample_state()
	(s4["campaign"] as Dictionary)["prestige_balance"] = 120
	assert_that(_sys.save(1, s4)).is_equal(ERR_INVALID_DATA)


func test_prestige_ledger_only() -> void:
	var bad := _sample_state()
	(bad["prestige"] as Dictionary)["balance"] = 500
	assert_that(_sys.save(1, bad)).is_equal(ERR_INVALID_DATA)

	var not_dict := _sample_state()
	not_dict["prestige"] = [1, 2, 3]
	assert_that(_sys.save(1, not_dict)).is_equal(ERR_INVALID_DATA)

	var ok_state := _sample_state()
	assert_that(_sys.save(1, ok_state)).is_equal(OK)
	var result: Dictionary = _sys.load(1)
	assert_that((result["state"]["prestige"] as Dictionary)["ledger"]).is_equal([{"turn": 3, "deed": "victory", "value": 10}])


func test_minor_compatibility_missing_sections_get_defaults() -> void:
	# Симуляция сейва с меньшим минором: секция "city" отсутствует.
	var raw := {
		"version": SaveSystem.VERSION,
		"sections": {"campaign": {"turn": 7}, "prestige": {"ledger": []}},
	}
	_write_raw(3, _sys._deterministic_json(raw))
	var result: Dictionary = _sys.load(3)
	assert_that(result["error"]).is_equal(OK)
	assert_that((result["state"]["campaign"] as Dictionary)["turn"]).is_equal(7)
	assert_that(result["state"]["city"]).is_equal({})
	assert_that((result["state"]["prestige"] as Dictionary)["ledger"]).is_equal([])


func test_minor_compatibility_extra_sections_preserved() -> void:
	# Симуляция сейва с новым минором: лишняя секция сохраняется.
	var raw := {
		"version": "1.1",
		"sections": {"campaign": {"turn": 9}, "prestige": {"ledger": []}, "anomalies": {"active": 2}},
	}
	_write_raw(3, _sys._deterministic_json(raw))
	var result: Dictionary = _sys.load(3)
	assert_that(result["error"]).is_equal(OK)
	assert_that((result["state"]["anomalies"] as Dictionary)["active"]).is_equal(2)


func test_major_mismatch_rejected() -> void:
	var raw := {
		"version": "2.0",
		"sections": {"campaign": {"turn": 1}, "prestige": {"ledger": []}},
	}
	_write_raw(3, _sys._deterministic_json(raw))
	var result: Dictionary = _sys.load(3)
	assert_that(result["error"]).is_equal(ERR_INVALID_DATA)


func test_corrupted_file_rejected() -> void:
	_write_raw(3, "{не-json")
	var result: Dictionary = _sys.load(3)
	assert_that(result["error"]).is_equal(ERR_PARSE_ERROR)


func test_byte_determinism_key_order_independent() -> void:
	# I1: одинаковый вход (в другом порядке вставки ключей) -> байт-в-байт тот же сейв.
	var a := {
		"campaign": {"turn": 5, "date": 12},
		"party": {},
		"city": {},
		"economy": {"food": 40, "wood": 10},
		"map": {},
		"prestige": {"ledger": []},
	}
	var b := {
		"prestige": {"ledger": []},
		"map": {},
		"economy": {"wood": 10, "food": 40},
		"city": {},
		"party": {},
		"campaign": {"date": 12, "turn": 5},
	}
	assert_that(_sys._deterministic_json(a)).is_equal(_sys._deterministic_json(b))
	assert_that(_sys.save(1, a)).is_equal(OK)
	var bytes_a := _read_bytes(1)
	assert_that(_sys.save(2, b)).is_equal(OK)
	var bytes_b := _read_bytes(2)
	assert_that(bytes_a).is_equal(bytes_b)


func test_atomic_write_leaves_no_tmp() -> void:
	assert_that(_sys.save(1, _sample_state())).is_equal(OK)
	var tmp := SaveSystem.SAVE_DIR.path_join("save_1.json.tmp")
	assert_that(FileAccess.file_exists(tmp)).is_false()


func test_list_and_delete_slots() -> void:
	assert_that(_sys.list_slots()).is_equal([])
	assert_that(_sys.save(2, _sample_state())).is_equal(OK)
	assert_that(_sys.list_slots()).is_equal([2])
	assert_that(_sys.delete(2)).is_equal(OK)
	assert_that(_sys.list_slots()).is_equal([])
	assert_that(_sys.delete(2)).is_equal(ERR_FILE_NOT_FOUND)


func test_default_clone_isolation() -> void:
	# Запись в клон дефолта не должна менять SECTIONS.
	var state := {}
	for sec in SaveSystem.SECTIONS:
		state[sec] = _sys._clone_default(sec)
	(state["prestige"] as Dictionary)["ledger"].append({"turn": 1})
	assert_that((SaveSystem.SECTIONS["prestige"] as Dictionary)["ledger"]).is_equal([])


func _write_raw(slot: int, text: String) -> void:
	var f := FileAccess.open(SaveSystem.SAVE_DIR.path_join("save_%d.json" % slot), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_bytes(slot: int) -> String:
	var f := FileAccess.open(SaveSystem.SAVE_DIR.path_join("save_%d.json" % slot), FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	return text
