extends Node

const _Platform = preload("res://scripts/core/Platform.gd")
const AudioCues = preload("res://scripts/data/AudioCues.gd")

const SFX_POOL := 8

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer

var last_sfx_path: String = ""
var last_music_path: String = ""

var _stream_cache: Dictionary = {}
var _rr := 0
var _music_loop := true

func _ready() -> void:
	if _Platform.is_headless():
		return

	if AudioServer.get_bus_index("SFX") == -1:
		push_warning("SoundManager: bus 'SFX' not found")
	if AudioServer.get_bus_index("Music") == -1:
		push_warning("SoundManager: bus 'Music' not found")

	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		sfx_players.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

func play_sfx(path: String) -> void:
	last_sfx_path = path
	var stream := _cached_stream(path)
	if stream == null:
		return
	if sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = sfx_players[_rr % SFX_POOL]
	_rr = (_rr + 1) % SFX_POOL
	p.stream = stream
	p.play()

func play_sfx_cue(cue: StringName) -> void:
	var path: String = AudioCues.path(cue)
	if path.is_empty():
		push_warning("SoundManager: unknown sfx cue '%s'" % str(cue))
		return
	play_sfx(path)

func play_music(path: String, loop: bool = true) -> void:
	last_music_path = path
	var stream := _cached_stream(path)
	if stream == null:
		return
	if music_player == null:
		return
	_music_loop = loop
	music_player.stream = stream
	music_player.play()

func play_music_cue(cue: StringName) -> void:
	var path: String = AudioCues.path(cue)
	if path.is_empty():
		push_warning("SoundManager: unknown music cue '%s'" % str(cue))
		return
	play_music(path)

func stop_music() -> void:
	_music_loop = false
	if music_player != null:
		music_player.stop()

func _on_music_finished() -> void:
	if _music_loop and music_player != null:
		music_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute"):
		toggle_mute()
		get_viewport().set_input_as_handled()

func toggle_mute() -> void:

	var settings: Object = Services.resolve(&"settings")
	if settings != null:
		settings.toggle_mute()

func _cached_stream(path: String) -> AudioStream:
	if not _stream_cache.has(path):
		if not ResourceLoader.exists(path):
			push_warning("SoundManager: no file %s" % path)
			return null
		_stream_cache[path] = load(path)
	return _stream_cache[path]
