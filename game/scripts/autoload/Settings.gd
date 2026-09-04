extends Node
## Autoload — persistent settings (zoom, audio, flags).
## Saved to user://settings.cfg via ConfigFile.

const _Platform = preload("res://scripts/core/Platform.gd")

const SECTION := "settings"
const FILE := "user://settings.cfg"

# --- Defaults ---
const DEFAULT_ZOOM_INDEX := 2  # 1.0
const DEFAULT_MASTER_VOL := 80
const DEFAULT_MUSIC_VOL := 70
const DEFAULT_SFX_VOL := 80
const DEFAULT_FULLSCREEN := false
const DEFAULT_UI_ANIMATIONS := true
const DEFAULT_PARTICLES := true
const DEFAULT_AUTO_SAVE := false

# --- ZOOM_LEVELS: single literal in GameSettings (audit #6), alias here. ---
const ZOOM_LEVELS := GameSettings.ZOOM_LEVELS

# --- Current values ---
var zoom_index: int = DEFAULT_ZOOM_INDEX
var master_volume: int = DEFAULT_MASTER_VOL
var music_volume: int = DEFAULT_MUSIC_VOL
var sfx_volume: int = DEFAULT_SFX_VOL
var fullscreen: bool = DEFAULT_FULLSCREEN
var ui_animations: bool = DEFAULT_UI_ANIMATIONS
var particles: bool = DEFAULT_PARTICLES
var auto_save: bool = DEFAULT_AUTO_SAVE

# Mute state
var is_muted: bool = false

var _config := ConfigFile.new()


func _ready() -> void:
	_load()
	_apply_audio()
	apply_display_mode()


func apply_display_mode() -> void:
	# РФ7-1: сохранённый полноэкранный режим реально применяется
	if _Platform.is_headless():
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)


func get_zoom() -> float:
	var idx: int = clampi(zoom_index, 0, ZOOM_LEVELS.size() - 1)
	return ZOOM_LEVELS[idx]


func step_zoom(direction: int) -> int:
	# Returns the change in index (0 if at boundary)
	var prev := zoom_index
	zoom_index = clampi(zoom_index + direction, 0, ZOOM_LEVELS.size() - 1)
	return zoom_index - prev


func set_zoom(value: float) -> void:
	for i in ZOOM_LEVELS.size():
		if absf(ZOOM_LEVELS[i] - value) < 0.01:
			zoom_index = i
			return
	zoom_index = DEFAULT_ZOOM_INDEX


# --- Persistence ---

func _load() -> void:
	if _config.load(FILE) != OK:
		return
	zoom_index = _config.get_value(SECTION, "zoom_index", DEFAULT_ZOOM_INDEX)
	master_volume = _config.get_value(SECTION, "master_volume", DEFAULT_MASTER_VOL)
	music_volume = _config.get_value(SECTION, "music_volume", DEFAULT_MUSIC_VOL)
	sfx_volume = _config.get_value(SECTION, "sfx_volume", DEFAULT_SFX_VOL)
	fullscreen = _config.get_value(SECTION, "fullscreen", DEFAULT_FULLSCREEN)
	ui_animations = _config.get_value(SECTION, "ui_animations", DEFAULT_UI_ANIMATIONS)
	particles = _config.get_value(SECTION, "particles", DEFAULT_PARTICLES)
	auto_save = _config.get_value(SECTION, "auto_save", DEFAULT_AUTO_SAVE)
	is_muted = _config.get_value(SECTION, "muted", false)


func save() -> void:
	_config.set_value(SECTION, "zoom_index", zoom_index)
	_config.set_value(SECTION, "master_volume", master_volume)
	_config.set_value(SECTION, "music_volume", music_volume)
	_config.set_value(SECTION, "sfx_volume", sfx_volume)
	_config.set_value(SECTION, "fullscreen", fullscreen)
	_config.set_value(SECTION, "ui_animations", ui_animations)
	_config.set_value(SECTION, "particles", particles)
	_config.set_value(SECTION, "auto_save", auto_save)
	_config.set_value(SECTION, "muted", is_muted)
	_config.save(FILE)


func reset_to_defaults() -> void:
	zoom_index = DEFAULT_ZOOM_INDEX
	master_volume = DEFAULT_MASTER_VOL
	music_volume = DEFAULT_MUSIC_VOL
	sfx_volume = DEFAULT_SFX_VOL
	fullscreen = DEFAULT_FULLSCREEN
	ui_animations = DEFAULT_UI_ANIMATIONS
	particles = DEFAULT_PARTICLES
	auto_save = DEFAULT_AUTO_SAVE
	_apply_audio()
	# Аудит #24: reset — немедленное сохранение дефолтов.
	save()


# --- Audio ---

func _apply_audio() -> void:
	# По имени шины, а не индексу: порядок в default_bus_layout.tres —
	# [Master, SFX, Music], индексная запись путала Music/SFX громкости.
	_set_bus("Master", _db_from_percent(master_volume if not is_muted else 0))
	_set_bus("Music", _db_from_percent(music_volume if not is_muted else 0))
	_set_bus("SFX", _db_from_percent(sfx_volume if not is_muted else 0))


func _set_bus(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)


func toggle_mute() -> void:
	is_muted = not is_muted
	_apply_audio()
	# Аудит #24: mute — немедленное сохранение (это действие, не черновик экрана).
	save()


func set_master_volume(val: int) -> void:
	master_volume = clampi(val, 0, 100)
	_apply_audio()


func set_music_volume(val: int) -> void:
	music_volume = clampi(val, 0, 100)
	_apply_audio()


func set_sfx_volume(val: int) -> void:
	sfx_volume = clampi(val, 0, 100)
	_apply_audio()


static func _db_from_percent(pct: int) -> float:
	if pct <= 0:
		return -80.0
	return linear_to_db(float(pct) / 100.0)
