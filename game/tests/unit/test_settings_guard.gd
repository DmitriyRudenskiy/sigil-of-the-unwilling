extends BaseTest


var _screen: Node = null

func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.free()
	_screen = null

func test_settings_screen_closed_without_settings() -> void:
	var screen = load("res://scenes/ui/settings_screen.tscn").instantiate()
	_screen = screen
	var flags: Array = [false]
	screen.closed.connect(func(): flags[0] = true)
	var main_root: Window = Engine.get_main_loop().root
	main_root.add_child(screen)
	assert_bool(flags[0]).is_true()
	await get_tree().process_frame
	assert_bool(is_instance_valid(screen)).is_false()

func test_apply_display_mode_headless_safe() -> void:

	var settings = SettingsAutoload.new()
	var mode_before := DisplayServer.window_get_mode()
	settings.fullscreen = true
	settings.apply_display_mode()
	assert_int(DisplayServer.window_get_mode()).is_equal(mode_before).override_failure_message(
		"в headless apply_display_mode не должен вызывать window_set_mode")
	settings.free()

func test_backpack_single_source() -> void:
	assert_that(HeroInventory.MAX_BACKPACK).is_equal(GameNumbers.MAX_BACKPACK_SIZE)
	# Число — макет 12 (50 ячеек сумки 10×5), a не настройка по вкусу: правится
	# только вместе с INVENTORY_GRID и картой элементов (D-280).
	assert_that(GameNumbers.MAX_BACKPACK_SIZE).is_equal(50)
	assert_that(GameNumbers.INVENTORY_GRID).is_equal(Vector2i(10, 5))
	# Вместимость и сетка сходятся: ровно одна клетка на предмет.
	assert_that(GameNumbers.MAX_BACKPACK_SIZE).is_equal(
		GameNumbers.INVENTORY_GRID.x * GameNumbers.INVENTORY_GRID.y)
