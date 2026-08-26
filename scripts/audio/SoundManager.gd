extends Node
class_name SoundManager

var master_bus: AudioBusLayout
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer

func _ready() -> void:
    # Initialize pools
    for i in 8:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        sfx_players.append(p)
        
    music_player = AudioStreamPlayer.new()
    music_player.bus = "Music"
    add_child(music_player)

func play_sfx(path: String) -> void:
    if not ResourceLoader.exists(path): return
    var stream = load(path)
    for p in sfx_players:
        if not p.playing:
            p.stream = stream
            p.play()
            return

func play_music(path: String) -> void:
    if not ResourceLoader.exists(path): return
    music_player.stream = load(path)
    music_player.play()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_M:
        toggle_mute()

func toggle_mute() -> void:
    var idx := AudioServer.get_bus_index("Master")
    AudioServer.set_bus_mute(idx, !AudioServer.is_bus_mute(idx))
