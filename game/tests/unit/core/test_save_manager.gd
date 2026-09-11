# TASK_18 B2.5: SaveManager — слоты, валидация, повреждённые сейвы.
extends BaseTest


const SLOT := 3

func before_test() -> void:
	# Чистое состояние слота
	if SaveManager.has_save_in_slot(SLOT):
		SaveManager.delete_slot(SLOT)

func after_test() -> void:
	if SaveManager.has_save_in_slot(SLOT):
		SaveManager.delete_slot(SLOT)

func _valid_save_data() -> SaveData:
	var sd := SaveData.new()
	sd.run_seed = 12345
	sd.hero = {"cell": {"x": 1, "y": 2}}
	sd.world = {"cities": []}
	return sd

func test_get_slot_path_clamped() -> void:
	assert_that(SaveManager.get_slot_path(1)).is_equal("user://save_slot_1.json")
	assert_that(SaveManager.get_slot_path(5)).is_equal("user://save_slot_5.json")
	assert_that(SaveManager.get_slot_path(99)).is_equal("user://save_slot_5.json")
	assert_that(SaveManager.get_slot_path(0)).is_equal("user://save_slot_1.json")

func test_has_save_in_slot_initially_false() -> void:
	assert_bool(SaveManager.has_save_in_slot(SLOT)).is_false()

func test_save_load_roundtrip() -> void:
	var sm = auto_free(SaveManager.new())
	var err: int = sm.save_to_slot(_valid_save_data(), SLOT)
	assert_int(err).is_equal(SaveManager.SaveError.OK)
	assert_bool(SaveManager.has_save_in_slot(SLOT)).is_true()
	var res := SaveManager.load_slot(SLOT)
	assert_int(res["error"]).is_equal(SaveManager.SaveError.OK)
	assert_int(res["data"].run_seed).is_equal(12345)

func test_save_null_data_invalid() -> void:
	var sm = auto_free(SaveManager.new())
	assert_int(sm.save_to_slot(null, SLOT)).is_equal(SaveManager.SaveError.INVALID_DATA)

func test_save_object_without_to_dict_invalid() -> void:
	var sm = auto_free(SaveManager.new())
	var dummy := Node.new()
	assert_int(sm.save_to_slot(dummy, SLOT)).is_equal(SaveManager.SaveError.INVALID_DATA)
	dummy.free()

func test_load_missing_slot_file_not_found() -> void:
	var res := SaveManager.load_slot(SLOT)
	assert_int(res["error"]).is_equal(SaveManager.SaveError.FILE_NOT_FOUND)
	assert_that(res["data"]).is_null()
	assert_that(str(res["message"])).contains("not found")

func test_load_corrupt_json_parse_fail() -> void:
	_write_raw(SaveManager.get_slot_path(SLOT), "{not json!!")
	var res := SaveManager.load_slot(SLOT)
	assert_int(res["error"]).is_equal(SaveManager.SaveError.PARSE_FAIL)
	assert_that(str(res["message"])).contains("line")

func test_load_non_dict_root_invalid() -> void:
	_write_raw(SaveManager.get_slot_path(SLOT), "[1, 2, 3]")
	var res := SaveManager.load_slot(SLOT)
	assert_int(res["error"]).is_equal(SaveManager.SaveError.INVALID_DATA)

func test_load_invalid_save_data() -> void:
	var bad := SaveData.new()
	bad.run_seed = 0  # невалидный seed
	sm_save(bad)
	var res := SaveManager.load_slot(SLOT)
	assert_int(res["error"]).is_equal(SaveManager.SaveError.INVALID_DATA)

func test_delete_slot() -> void:
	sm_save(_valid_save_data())
	assert_bool(SaveManager.delete_slot(SLOT)).is_true()
	assert_bool(SaveManager.has_save_in_slot(SLOT)).is_false()
	assert_bool(SaveManager.delete_slot(SLOT)).is_false()

func test_error_to_string_known_and_unknown() -> void:
	assert_that(SaveManager.error_to_string(SaveManager.SaveError.OK)).is_equal("OK")
	assert_that(SaveManager.error_to_string(SaveManager.SaveError.PARSE_FAIL)).contains("JSON")
	assert_that(SaveManager.error_to_string(999)).is_equal("Unknown error")

func test_save_game_uses_slot_1() -> void:
	if SaveManager.has_save_in_slot(1):
		SaveManager.delete_slot(1)
	var sm = auto_free(SaveManager.new())
	assert_int(sm.save_game(_valid_save_data())).is_equal(SaveManager.SaveError.OK)
	assert_bool(sm.has_save()).is_true()
	assert_that(sm.delete_save()).is_true()
	assert_bool(sm.has_save()).is_false()

func _write_raw(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()

func sm_save(data: SaveData) -> void:
	var sm := SaveManager.new()
	sm.save_to_slot(data, SLOT)
	sm.free()
