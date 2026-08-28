extends "res://tests/test_base.gd"
## Tests for typed error handling: SaveManager, ResourceNodeManager, GameSettings.

const _SaveManager = preload("res://scripts/core/SaveManager.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")


# ==================== SaveManager ====================

func test_load_no_file() -> void:
	var sm := _SaveManager.new()
	sm.delete_save()
	var result: Dictionary = sm.load_game()
	assert_eq(result["error"], _SaveManager.SaveError.FILE_NOT_FOUND, "no file error")
	assert_null(result["data"], "data is null")
	sm.free()


func test_load_invalid_json() -> void:
	var sm := _SaveManager.new()
	var f := FileAccess.open(_SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("not valid json {{{")
	f.close()
	var result: Dictionary = sm.load_game()
	assert_eq(result["error"], _SaveManager.SaveError.PARSE_FAIL, "parse error")
	assert_null(result["data"], "data is null")
	sm.delete_save()
	sm.free()


func test_load_invalid_data() -> void:
	var sm := _SaveManager.new()
	var f := FileAccess.open(_SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"version": 1, "run_seed": 0, "hero": {}, "world": {}}')
	f.close()
	var result: Dictionary = sm.load_game()
	assert_eq(result["error"], _SaveManager.SaveError.INVALID_DATA, "invalid data")
	sm.delete_save()
	sm.free()


func test_save_null_data() -> void:
	var sm := _SaveManager.new()
	var err: int = sm.save_game(null)
	assert_eq(err, _SaveManager.SaveError.INVALID_DATA, "null data rejected")
	sm.free()


func test_error_to_string() -> void:
	assert_eq(_SaveManager.error_to_string(_SaveManager.SaveError.OK), "OK", "OK msg")
	assert_eq(_SaveManager.error_to_string(_SaveManager.SaveError.PARSE_FAIL), "JSON parse error", "parse msg")
	assert_false(_SaveManager.error_to_string(_SaveManager.SaveError.WRITE_FAIL).is_empty(), "write msg")


func test_save_and_load_round_trip() -> void:
	var sm := _SaveManager.new()
	sm.delete_save()
	var data := _SaveData.new()
	data.run_seed = 42
	data.version = _SaveData.CURRENT_VERSION
	data.hero = {"cell": {"x": 5, "y": 5}, "level": 5}
	data.world = {}
	var err := sm.save_game(data)
	assert_eq(err, _SaveManager.SaveError.OK, "save succeeded")
	var result: Dictionary = sm.load_game()
	assert_eq(result["error"], _SaveManager.SaveError.OK, "load succeeded")
	assert_not_null(result["data"], "data loaded")
	assert_eq(result["data"].run_seed, 42, "seed preserved")
	sm.delete_save()
	sm.free()


# ==================== GameSettings константы ====================

func test_battle_constants_exist() -> void:
	assert_true(GameSettings.BATTLE_HEX_OUTLINE_RADIUS > 0, "hex radius > 0")
	assert_true(GameSettings.BATTLE_ATTACK_LUNGE_PX > 0, "lunge > 0")
	assert_true(GameSettings.BATTLE_MOVE_TWEEN_SEC > 0, "tween > 0")
	assert_true(GameSettings.BATTLE_FIELD_RING > 0, "ring > 0")


func test_spawn_constants_exist() -> void:
	assert_true(GameSettings.SPAWN_RESOURCE_NODE_CHANCE > 0, "resource chance > 0")
	assert_true(GameSettings.SPAWN_DECOR_SAND_CHANCE > 0, "decor chance > 0")
	assert_true(GameSettings.SPAWN_SCROLL_MAX_ATTEMPTS > 0, "scroll attempts > 0")
	assert_true(GameSettings.SPAWN_CHEST_MIN_BORDER > 0, "chest border > 0")


func test_camera_constants_exist() -> void:
	assert_true(GameSettings.CAMERA_SPEED > 0, "camera speed > 0")
	assert_true(GameSettings.CAMERA_EDGE_ZONE > 0, "edge zone > 0")
	assert_true(GameSettings.CAMERA_ZOOM_TWEEN_SEC > 0, "zoom tween > 0")


func test_menu_constants_exist() -> void:
	assert_true(GameSettings.MENU_BTN_MIN_SIZE.x > 0, "menu btn width > 0")
	assert_true(GameSettings.MENU_BTN_MIN_SIZE.y > 0, "menu btn height > 0")
	assert_true(GameSettings.MENU_LOCK_MIN_SIZE.x > 0, "lock width > 0")


func test_city_constants_exist() -> void:
	assert_true(GameSettings.CITY_PANEL_W > 0, "city panel width > 0")
	assert_true(GameSettings.CITY_PANEL_TOP > 0, "city panel top > 0")
