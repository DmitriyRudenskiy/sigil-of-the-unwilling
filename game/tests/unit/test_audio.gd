extends BaseTest




var settings: Object
var sm: Object

func before_test() -> void:
	settings = SettingsAutoload.new()
	sm = SoundManagerAutoload.new()

	for _b in ["SFX", "Music"]:
		if AudioServer.get_bus_index(_b) == -1:
			var _i := AudioServer.get_bus_count()
			AudioServer.add_bus(_i)
			AudioServer.set_bus_name(_i, _b)

func after_test() -> void:
	if sm != null:
		sm.free()
		sm = null
	if settings != null:
		settings.free()
		settings = null

func test_cues_cover_required_events() -> void:
	for cue in [&"ui_click", &"ui_hover", &"hero_step", &"village_captured",
			&"resource_collected", &"battle_hit", &"spell_cast",
			&"battle_victory", &"battle_defeat"]:
		assert_bool(AudioCues.has(cue)).is_true()
	for cue in [&"music_menu", &"music_world", &"music_battle"]:
		assert_bool(AudioCues.has(cue)).is_true()

func test_cue_paths_exist() -> void:
	for cue in AudioCues.CUES.keys():
		var path: String = AudioCues.path(cue)
		assert_bool(ResourceLoader.exists(path)).is_true()

func test_unknown_cue_path_empty() -> void:
	assert_that(AudioCues.path(&"no_such_cue")).is_equal("")

func test_missing_sfx_path_no_crash() -> void:
	sm.play_sfx("res://assets/audio/sfx/definitely_missing.wav")
	assert_that(sm.last_sfx_path).is_equal("res://assets/audio/sfx/definitely_missing.wav")

func test_missing_music_path_no_crash() -> void:
	sm.play_music("res://assets/audio/music/definitely_missing.mp3")
	assert_that(sm.last_music_path).is_equal("res://assets/audio/music/definitely_missing.mp3")

func test_unknown_cue_no_crash() -> void:
	sm.play_sfx_cue(&"no_such_cue")
	sm.play_music_cue(&"no_such_cue")
	assert_that(sm.last_sfx_path).is_equal("")
	assert_that(sm.last_music_path).is_equal("")

func test_music_cue_records_last_path() -> void:
	sm.play_music_cue(&"music_menu")
	assert_that(sm.last_music_path).is_equal(AudioCues.path(&"music_menu"))

	sm.play_sfx_cue(&"ui_click")
	assert_that(sm.last_sfx_path).is_equal(AudioCues.path(&"ui_click"))

func test_stop_music_no_crash() -> void:
	sm.stop_music()
	assert_bool(sm._music_loop == false).is_true()

func _db(pct: int) -> float:
	return linear_to_db(pct / 100.0)

func test_buses_exist_by_name() -> void:
	assert_bool(AudioServer.get_bus_index("Master") != -1).is_true()
	assert_bool(AudioServer.get_bus_index("Music") != -1).is_true()
	assert_bool(AudioServer.get_bus_index("SFX") != -1).is_true()

func test_volume_mapping_by_bus_name() -> void:
	settings.is_muted = false
	settings.master_volume = 50
	settings.music_volume = 20
	settings.sfx_volume = 80
	settings._apply_audio()

	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))).is_equal_approx(_db(50), 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))).is_equal_approx(_db(20), 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))).is_equal_approx(_db(80), 0.01)

func test_mute_silences_all_buses() -> void:
	settings.is_muted = false
	settings.master_volume = 100
	settings.music_volume = 100
	settings.sfx_volume = 100
	settings._apply_audio()
	settings.toggle_mute()
	settings._apply_audio()

	assert_bool(settings.is_muted).is_true()
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))).is_equal_approx(-80.0, 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))).is_equal_approx(-80.0, 0.01)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))).is_equal_approx(-80.0, 0.01)

func test_volume_change_live() -> void:
	settings.is_muted = false
	settings.music_volume = 70
	settings._apply_audio()
	settings.set_music_volume(30)
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))).is_equal_approx(_db(30), 0.01)
	assert_that(settings.music_volume).is_equal(30)
