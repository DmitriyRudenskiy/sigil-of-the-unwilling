"""Settings: дефолты, загрузка/сохранение, битый файл, zoom-клампы.

Работает с user://settings.cfg — файл удаляется до/после каждого теста,
чтобы юнит не влиял на состояние машины.
"""
extends BaseTest

const CFG := "user://settings.cfg"
var _s: SettingsAutoload


func before_test() -> void:
	_remove_cfg()
	_s = SettingsAutoload.new()
	add_child(_s)


func after_test() -> void:
	_s.queue_free()
	await get_tree().process_frame
	_remove_cfg()


func _remove_cfg() -> void:
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))


func test_defaults_on_empty_file() -> void:
	assert_int(_s.zoom_index).is_equal(SettingsAutoload.DEFAULT_ZOOM_INDEX)
	assert_int(_s.master_volume).is_equal(SettingsAutoload.DEFAULT_MASTER_VOL)
	assert_int(_s.music_volume).is_equal(SettingsAutoload.DEFAULT_MUSIC_VOL)
	assert_bool(_s.fullscreen).is_false()
	assert_bool(_s.ui_animations).is_true()
	assert_bool(_s.is_muted).is_false()


func test_save_and_reload_roundtrip() -> void:
	_s.zoom_index = 1
	_s.master_volume = 42
	_s.fullscreen = true
	_s.is_muted = true
	_s.save()

	var reloaded := SettingsAutoload.new()
	add_child(reloaded)
	assert_int(reloaded.zoom_index).is_equal(1)
	assert_int(reloaded.master_volume).is_equal(42)
	assert_bool(reloaded.fullscreen).is_true()
	assert_bool(reloaded.is_muted).is_true()
	reloaded.queue_free()


func test_corrupted_file_keeps_defaults() -> void:
	# Мусор в cfg: ConfigFile.load != OK → дефолты, без краша.
	var f := FileAccess.open(CFG, FileAccess.WRITE)
	f.store_string("this is not a config file\n[[[")
	f.close()

	var fresh := SettingsAutoload.new()
	add_child(fresh)
	assert_int(fresh.master_volume).is_equal(SettingsAutoload.DEFAULT_MASTER_VOL)
	assert_int(fresh.zoom_index).is_equal(SettingsAutoload.DEFAULT_ZOOM_INDEX)
	fresh.queue_free()


func test_step_zoom_clamped() -> void:
	_s.zoom_index = 0
	assert_int(_s.step_zoom(-1)).is_equal(0)
	assert_int(_s.zoom_index).is_equal(0)
	var last: int = SettingsAutoload.ZOOM_LEVELS.size() - 1
	_s.zoom_index = last
	assert_int(_s.step_zoom(1)).is_equal(0)
	assert_int(_s.zoom_index).is_equal(last)


func test_get_zoom_returns_table_value() -> void:
	_s.zoom_index = 1
	assert_float(_s.get_zoom()).is_equal(SettingsAutoload.ZOOM_LEVELS[1])


func test_set_zoom_unknown_falls_back_to_default() -> void:
	_s.set_zoom(3.14159)
	assert_int(_s.zoom_index).is_equal(SettingsAutoload.DEFAULT_ZOOM_INDEX)


func test_reset_to_defaults() -> void:
	_s.master_volume = 1
	_s.fullscreen = true
	_s.reset_to_defaults()
	assert_int(_s.master_volume).is_equal(SettingsAutoload.DEFAULT_MASTER_VOL)
	assert_bool(_s.fullscreen).is_false()
