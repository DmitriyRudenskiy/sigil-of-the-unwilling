extends BaseTest



func test_load_no_file() -> void:
	var sm = auto_free( SaveManager.new())
	sm.delete_save()
	var result: Dictionary = sm.load_game()
	assert_that(result["error"]).is_equal(SaveManager.SaveError.FILE_NOT_FOUND)
	assert_that(result["data"]).is_null()
	sm.free()

func test_load_invalid_json() -> void:
	var sm = auto_free( SaveManager.new())
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("not valid json {{{")
	f.close()
	var result: Dictionary = sm.load_game()
	assert_that(result["error"]).is_equal(SaveManager.SaveError.PARSE_FAIL)
	assert_that(result["data"]).is_null()
	sm.delete_save()
	sm.free()

func test_load_invalid_data() -> void:
	var sm = auto_free( SaveManager.new())
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"version": 1, "run_seed": 0, "hero": {}, "world": {}}')
	f.close()
	var result: Dictionary = sm.load_game()
	assert_that(result["error"]).is_equal(SaveManager.SaveError.INVALID_DATA)
	sm.delete_save()
	sm.free()

func test_save_null_data() -> void:
	var sm = auto_free( SaveManager.new())
	var err: int = sm.save_game(null)
	assert_that(err).is_equal(SaveManager.SaveError.INVALID_DATA)
	sm.free()

func test_error_to_string() -> void:
	assert_that(SaveManager.error_to_string(SaveManager.SaveError.OK)).is_equal("OK")
	assert_that(SaveManager.error_to_string(SaveManager.SaveError.PARSE_FAIL)).is_equal("JSON parse error")
	assert_bool(SaveManager.error_to_string(SaveManager.SaveError.WRITE_FAIL).is_empty()).is_false()

func test_save_and_load_round_trip() -> void:
	var sm = auto_free( SaveManager.new())
	sm.delete_save()
	var data := SaveData.new()
	data.run_seed = 42
	data.version = SaveData.CURRENT_VERSION
	data.hero = {"cell": {"x": 5, "y": 5}, "level": 5}
	data.world = {}
	var err = sm.save_game(data)
	assert_that(err).is_equal(SaveManager.SaveError.OK)
	var result: Dictionary = sm.load_game()
	assert_that(result["error"]).is_equal(SaveManager.SaveError.OK)
	assert_that(result["data"]).is_not_null()
	assert_that(result["data"].run_seed).is_equal(42)
	sm.delete_save()
	sm.free()

func test_battle_constants_exist() -> void:
	assert_bool(GameNumbers.BATTLE_HEX_OUTLINE_RADIUS > 0).is_true()
	assert_bool(GameNumbers.BATTLE_ATTACK_LUNGE_PX > 0).is_true()
	assert_bool(GameNumbers.BATTLE_MOVE_TWEEN_SEC > 0).is_true()
	assert_bool(GameNumbers.BATTLE_FIELD_RING > 0).is_true()

func test_spawn_constants_exist() -> void:
	assert_bool(GameNumbers.SPAWN_RESOURCE_NODE_CHANCE > 0).is_true()
	assert_bool(GameNumbers.SPAWN_DECOR_SAND_CHANCE > 0).is_true()
	assert_bool(GameNumbers.SPAWN_SCROLL_MAX_ATTEMPTS > 0).is_true()
	assert_bool(GameNumbers.SPAWN_CHEST_MIN_BORDER > 0).is_true()

func test_camera_constants_exist() -> void:
	assert_bool(GameNumbers.CAMERA_SPEED > 0).is_true()
	assert_bool(GameNumbers.CAMERA_EDGE_ZONE > 0).is_true()
	assert_bool(GameNumbers.CAMERA_ZOOM_TWEEN_SEC > 0).is_true()

func test_menu_constants_exist() -> void:
	assert_bool(Vector2(GameNumbers.MENU_BTN_MIN_W, GameNumbers.MENU_BTN_MIN_H).x > 0).is_true()
	assert_bool(Vector2(GameNumbers.MENU_BTN_MIN_W, GameNumbers.MENU_BTN_MIN_H).y > 0).is_true()
	assert_bool(GameNumbers.MENU_LOCK_MIN_SIZE.x > 0).is_true()

func test_city_constants_exist() -> void:
	assert_bool(GameNumbers.CITY_PANEL_W > 0).is_true()
	assert_bool(GameNumbers.CITY_PANEL_TOP > 0).is_true()
