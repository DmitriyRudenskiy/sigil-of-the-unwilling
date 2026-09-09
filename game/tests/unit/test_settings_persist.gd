extends GdUnitTestSuite

const _Settings = preload("res://scripts/autoload/Settings.gd")

var settings: Object
var _ss_settings: Object = null
var _ss_screen: SettingsScreen = null

func before_test() -> void:
	settings = _Settings.new()

func after_test() -> void:
	if settings != null:
		settings.free()
		settings = null
	if _ss_screen != null and is_instance_valid(_ss_screen):
		_ss_screen.queue_free()
		_ss_screen = null
	if _ss_settings != null and is_instance_valid(_ss_settings):
		_ss_settings.free()
		_ss_settings = null



func test_settings_defaults() -> void:
	settings.reset_to_defaults()
	assert_that(settings.zoom_index).is_equal(2)
	assert_that(settings.master_volume).is_equal(80)
	assert_that(settings.music_volume).is_equal(70)
	assert_that(settings.sfx_volume).is_equal(80)
	assert_bool(settings.fullscreen).is_false()
	assert_bool(settings.ui_animations).is_true()
	assert_bool(settings.particles).is_true()
	assert_bool(settings.auto_save).is_false()

func test_settings_set_values() -> void:
	settings.zoom_index = 5
	settings.master_volume = 50
	settings.music_volume = 30
	settings.sfx_volume = 90
	settings.fullscreen = true
	settings.ui_animations = false
	settings.particles = false
	settings.auto_save = true

	assert_that(settings.zoom_index).is_equal(5)
	assert_that(settings.master_volume).is_equal(50)
	assert_that(settings.music_volume).is_equal(30)
	assert_that(settings.sfx_volume).is_equal(90)
	assert_bool(settings.fullscreen).is_true()
	assert_bool(settings.ui_animations).is_false()
	assert_bool(settings.particles).is_false()
	assert_bool(settings.auto_save).is_true()

func test_settings_reset() -> void:
	settings.zoom_index = 8
	settings.master_volume = 100
	settings.reset_to_defaults()
	assert_that(settings.zoom_index).is_equal(2)
	assert_that(settings.master_volume).is_equal(80)

func test_settings_save_load() -> void:
	settings.zoom_index = 6
	settings.master_volume = 42
	settings.music_volume = 55
	settings.sfx_volume = 67
	settings.fullscreen = true
	settings.ui_animations = false
	settings.particles = true
	settings.auto_save = true

	settings.save()

	settings._config = ConfigFile.new()
	settings._load()

	assert_that(settings.zoom_index).is_equal(6)
	assert_that(settings.master_volume).is_equal(42)
	assert_that(settings.music_volume).is_equal(55)
	assert_that(settings.sfx_volume).is_equal(67)
	assert_bool(settings.fullscreen).is_true()
	assert_bool(settings.ui_animations).is_false()
	assert_bool(settings.particles).is_true()
	assert_bool(settings.auto_save).is_true()

	DirAccess.remove_absolute("user://settings.cfg")

func test_settings_mute() -> void:
	settings.is_muted = false
	settings.toggle_mute()
	assert_bool(settings.is_muted).is_true()
	settings.toggle_mute()
	assert_bool(settings.is_muted).is_false()

func test_settings_volume_clamp() -> void:
	settings.set_master_volume(-10)
	assert_that(settings.master_volume).is_equal(0)
	settings.set_master_volume(150)
	assert_that(settings.master_volume).is_equal(100)
	settings.set_music_volume(50)
	assert_that(settings.music_volume).is_equal(50)
	settings.set_sfx_volume(75)
	assert_that(settings.sfx_volume).is_equal(75)

func test_settings_screen_cancel_restores_volume() -> void:
	_ss_settings = _Settings.new()
	_ss_settings.master_volume = 10
	_ss_settings.music_volume = 20
	_ss_settings.sfx_volume = 30
	_ss_settings.save()  

	_ss_screen = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	_ss_screen.setup(_ss_settings)
	var main_root: Window = Engine.get_main_loop().root
	main_root.add_child(_ss_screen)
	await get_tree().process_frame  

	_ss_screen._settings.set_master_volume(95)
	_ss_screen._settings.set_music_volume(85)
	_ss_screen._settings.set_sfx_volume(40)
	assert_that(_ss_screen._settings.master_volume).is_equal(95)

	_ss_screen._on_cancel()
	await get_tree().process_frame

	var s = _ss_settings
	assert_that(s.master_volume).is_equal(10)
	assert_that(s.music_volume).is_equal(20)
	assert_that(s.sfx_volume).is_equal(30)

	s._config = ConfigFile.new()
	s._load()
	assert_that(s.master_volume).is_equal(10)
	assert_that(s.music_volume).is_equal(20)
	assert_that(s.sfx_volume).is_equal(30)
