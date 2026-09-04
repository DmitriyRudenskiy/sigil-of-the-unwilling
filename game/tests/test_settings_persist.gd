extends "res://tests/gut_base.gd"

const _Settings = preload("res://scripts/autoload/Settings.gd")

var settings: Object
var _ss_settings: Object = null
var _ss_screen: SettingsScreen = null

func before_each() -> void:
	settings = _Settings.new()

func after_each() -> void:
	if settings != null:
		settings.free()
		settings = null
	if _ss_screen != null and is_instance_valid(_ss_screen):
		_ss_screen.queue_free()
		_ss_screen = null
	if _ss_settings != null and is_instance_valid(_ss_settings):
		_ss_settings.free()
		_ss_settings = null


# --- Settings persistence ---

func test_settings_defaults() -> void:
	settings.reset_to_defaults()
	assert_eq(settings.zoom_index, 2, "default zoom_index")
	assert_eq(settings.master_volume, 80, "default master")
	assert_eq(settings.music_volume, 70, "default music")
	assert_eq(settings.sfx_volume, 80, "default sfx")
	assert_false(settings.fullscreen, "default fullscreen")
	assert_true(settings.ui_animations, "default ui_animations")
	assert_true(settings.particles, "default particles")
	assert_false(settings.auto_save, "default auto_save")

func test_settings_set_values() -> void:
	settings.zoom_index = 5
	settings.master_volume = 50
	settings.music_volume = 30
	settings.sfx_volume = 90
	settings.fullscreen = true
	settings.ui_animations = false
	settings.particles = false
	settings.auto_save = true

	assert_eq(settings.zoom_index, 5, "zoom_index set")
	assert_eq(settings.master_volume, 50, "master set")
	assert_eq(settings.music_volume, 30, "music set")
	assert_eq(settings.sfx_volume, 90, "sfx set")
	assert_true(settings.fullscreen, "fullscreen set")
	assert_false(settings.ui_animations, "ui_animations set")
	assert_false(settings.particles, "particles set")
	assert_true(settings.auto_save, "auto_save set")

func test_settings_reset() -> void:
	settings.zoom_index = 8
	settings.master_volume = 100
	settings.reset_to_defaults()
	assert_eq(settings.zoom_index, 2, "reset zoom_index")
	assert_eq(settings.master_volume, 80, "reset master")

func test_settings_save_load() -> void:
	# Set unique values
	settings.zoom_index = 6
	settings.master_volume = 42
	settings.music_volume = 55
	settings.sfx_volume = 67
	settings.fullscreen = true
	settings.ui_animations = false
	settings.particles = true
	settings.auto_save = true

	settings.save()

	# Re-create Settings to simulate reload
	settings._config = ConfigFile.new()
	settings._load()

	assert_eq(settings.zoom_index, 6, "loaded zoom_index")
	assert_eq(settings.master_volume, 42, "loaded master")
	assert_eq(settings.music_volume, 55, "loaded music")
	assert_eq(settings.sfx_volume, 67, "loaded sfx")
	assert_true(settings.fullscreen, "loaded fullscreen")
	assert_false(settings.ui_animations, "loaded ui_animations")
	assert_true(settings.particles, "loaded particles")
	assert_true(settings.auto_save, "loaded auto_save")

	# Clean up test file
	DirAccess.remove_absolute("user://settings.cfg")

func test_settings_mute() -> void:
	settings.is_muted = false
	settings.toggle_mute()
	assert_true(settings.is_muted, "muted after toggle")
	settings.toggle_mute()
	assert_false(settings.is_muted, "unmuted after second toggle")

func test_settings_volume_clamp() -> void:
	settings.set_master_volume(-10)
	assert_eq(settings.master_volume, 0, "clamped to 0")
	settings.set_master_volume(150)
	assert_eq(settings.master_volume, 100, "clamped to 100")
	settings.set_music_volume(50)
	assert_eq(settings.music_volume, 50, "music 50")
	settings.set_sfx_volume(75)
	assert_eq(settings.sfx_volume, 75, "sfx 75")

## Аудит #4: SettingsScreen «Отмена» откатывает громкость к моменту открытия,
## без сохранения на диск.
func test_settings_screen_cancel_restores_volume() -> void:
	_ss_settings = _Settings.new()
	_ss_settings.master_volume = 10
	_ss_settings.music_volume = 20
	_ss_settings.sfx_volume = 30
	_ss_settings.save()  # записать стартовое значение на диск

	_ss_screen = SettingsScreen.new()
	_ss_screen.setup(_ss_settings)
	var main_root: Window = Engine.get_main_loop().root
	main_root.add_child(_ss_screen)
	await get_tree().process_frame  # _ready делает snapshot громкости

	# Имитируем сдвиг слайдера в UI.
	_ss_screen._settings.set_master_volume(95)
	_ss_screen._settings.set_music_volume(85)
	_ss_screen._settings.set_sfx_volume(40)
	assert_eq(_ss_screen._settings.master_volume, 95, "volume changed in UI before cancel")

	# Отмена.
	_ss_screen._on_cancel()
	await get_tree().process_frame

	# Untyped: typed `Settings` (autoload type) не резолвится в headless-запусках GUT.
	var s = _ss_settings
	assert_eq(s.master_volume, 10, "master restored to snapshot on cancel")
	assert_eq(s.music_volume, 20, "music restored to snapshot on cancel")
	assert_eq(s.sfx_volume, 30, "sfx restored to snapshot on cancel")

	# Отмена НЕ должна сохранять — на диске всё ещё стартовое значение.
	s._config = ConfigFile.new()
	s._load()
	assert_eq(s.master_volume, 10, "cancel did not persist to disk")
	assert_eq(s.music_volume, 20, "cancel did not persist music to disk")
	assert_eq(s.sfx_volume, 30, "cancel did not persist sfx to disk")
