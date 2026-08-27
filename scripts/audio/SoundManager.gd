extends Node
class_name SoundManager

const SFX_POOL := 8

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var _rr := 0

func _ready() -> void:
	# Verify bus existence
	if AudioServer.get_bus_index("SFX") == -1:
		push_warning("SoundManager: bus 'SFX' not found")
	if AudioServer.get_bus_index("Music") == -1:
		push_warning("SoundManager: bus 'Music' not found")

	# Initialize SFX pool
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		sfx_players.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)

func play_sfx(path: String) -> void:
	var stream := _cached_stream(path)
	if stream == null:
		return
	var p: AudioStreamPlayer = sfx_players[_rr % SFX_POOL]
	_rr += 1
	p.stream = stream
	p.play()

func play_music(path: String) -> void:
	var stream := _cached_stream(path)
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()

func _cached_stream(path: String) -> AudioStream:
	if not _stream_cache.has(path):
		if not ResourceLoader.exists(path):
			push_warning("SoundManager: no file %s" % path)
			return null
		_stream_cache[path] = load(path)
	return _stream_cache[path]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_mute"):
		toggle_mute()
		get_viewport().set_input_as_handled()

func toggle_mute() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(idx, not AudioServer.is_bus_mute(idx))
