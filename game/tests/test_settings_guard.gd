extends GdUnitTestSuite

const _Settings = preload("res://scripts/autoload/Settings.gd")

func test_settings_screen_closed_without_settings() -> void:
	var screen = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	var flags: Array = [false]
	screen.closed.connect(func(): flags[0] = true)
	var main_root: Window = Engine.get_main_loop().root
	main_root.add_child(screen)
	assert_bool(flags[0]).is_true()
	await get_tree().process_frame
	assert_bool(is_instance_valid(screen)).is_false()

func test_apply_display_mode_headless_safe() -> void:
	var settings = _Settings.new()
	settings.apply_display_mode()
	assert_bool(true).is_true()
	settings.free()

func test_backpack_single_source() -> void:
	assert_that(HeroInventory.MAX_BACKPACK).is_equal(GameNumbers.MAX_BACKPACK_SIZE)
	assert_that(GameNumbers.MAX_BACKPACK_SIZE).is_equal(16)
