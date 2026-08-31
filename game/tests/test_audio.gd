extends "res://tests/test_base.gd"
## Audio-pass (capability: audio):
## - карта AudioCues полна, все пути существуют;
## - graceful degradation: missing file / unknown cue / headless → без crash;
## - Settings._apply_audio() мапит по именам шин (баг индексов);
## - mute → -80 dB.

const _Settings = preload("res://scripts/autoload/Settings.gd")
const _SoundManager = preload("res://scripts/autoload/SoundManager.gd")
const AudioCues = preload("res://scripts/data/AudioCues.gd")

var settings: Object
var sm: Object


func before_each() -> void:
	settings = _Settings.new()
	sm = _SoundManager.new()


func after_each() -> void:
	if sm != null:
		sm.free()
		sm = null
	if settings != null:
		settings.free()
		settings = null


# --- AudioCues ---

func test_cues_cover_required_events() -> void:
	for cue in [&"ui_click", &"ui_hover", &"hero_step", &"village_captured",
			&"resource_collected", &"battle_hit", &"spell_cast",
			&"battle_victory", &"battle_defeat"]:
		assert_true(AudioCues.has(cue), "sfx cue %s exists" % str(cue))
	for cue in [&"music_menu", &"music_world", &"music_battle"]:
		assert_true(AudioCues.has(cue), "music cue %s exists" % str(cue))


func test_cue_paths_exist() -> void:
	for cue in AudioCues.CUES.keys():
		var path: String = AudioCues.path(cue)
		assert_true(ResourceLoader.exists(path), "asset exists: %s" % path)


func test_unknown_cue_path_empty() -> void:
	assert_eq(AudioCues.path(&"no_such_cue"), "", "unknown cue → empty path")


# --- SoundManager graceful degradation ---

func test_missing_sfx_path_no_crash() -> void:
	sm.play_sfx("res://assets/audio/sfx/definitely_missing.wav")
	assert_true(true, "play_sfx(missing) did not crash")


func test_missing_music_path_no_crash() -> void:
	sm.play_music("res://assets/audio/music/definitely_missing.mp3")
	assert_true(true, "play_music(missing) did not crash")


func test_unknown_cue_no_crash() -> void:
	sm.play_sfx_cue(&"no_such_cue")
	sm.play_music_cue(&"no_such_cue")
	assert_true(true, "unknown cue did not crash")


func test_music_cue_records_last_path() -> void:
	sm.play_music_cue(&"music_menu")
	assert_eq(sm.last_music_path, AudioCues.path(&"music_menu"), "last_music_path recorded")

	sm.play_sfx_cue(&"ui_click")
	assert_eq(sm.last_sfx_path, AudioCues.path(&"ui_click"), "last_sfx_path recorded")


func test_stop_music_no_crash() -> void:
	sm.stop_music()
	assert_true(true, "stop_music() did not crash")


# --- Settings: bus mapping by name ---

func _db(pct: int) -> float:
	return linear_to_db(pct / 100.0)


func test_buses_exist_by_name() -> void:
	assert_true(AudioServer.get_bus_index("Master") != -1, "Master bus")
	assert_true(AudioServer.get_bus_index("Music") != -1, "Music bus")
	assert_true(AudioServer.get_bus_index("SFX") != -1, "SFX bus")


func test_volume_mapping_by_bus_name() -> void:
	# Баг-проверка: порядок шин [Master, SFX, Music] — Music/SFX не должны путаться.
	settings.is_muted = false
	settings.master_volume = 50
	settings.music_volume = 20
	settings.sfx_volume = 80
	settings._apply_audio()

	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), _db(50), 0.01, "master db")
	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), _db(20), 0.01, "music db")
	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), _db(80), 0.01, "sfx db")


func test_mute_silences_all_buses() -> void:
	settings.is_muted = false
	settings.master_volume = 100
	settings.music_volume = 100
	settings.sfx_volume = 100
	settings._apply_audio()
	settings.toggle_mute()  # → is_muted = true
	settings._apply_audio()

	assert_true(settings.is_muted, "toggle_mute sets is_muted")
	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")), -80.0, 0.01, "Master muted db")
	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), -80.0, 0.01, "Music muted db")
	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), -80.0, 0.01, "SFX muted db")


func test_volume_change_live() -> void:
	settings.is_muted = false
	settings.music_volume = 70
	settings._apply_audio()
	settings.set_music_volume(30)  # сеттер сам применяет
	assert_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), _db(30), 0.01, "music live db")
	assert_eq(settings.music_volume, 30, "music_volume persisted in Settings")
