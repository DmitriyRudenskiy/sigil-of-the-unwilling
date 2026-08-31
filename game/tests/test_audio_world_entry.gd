extends SceneTree
## Standalone-тест audio-pass: вход в мир запускает music_world.
##
## Загружает World.tscn (полный bootstrap), ждёт до 6с, пока
## SoundManager.last_music_path не станет music_world, затем выходит.
##
## ВАЖНО: в -s-режиме основной скрипт компилируется ДО регистрации
## autoloads, поэтому идентификатор SoundManager здесь недоступен —
## ищем узел по пути в рантайме.
##
## Запуск:
##   godot --headless --path game -s tests/test_audio_world_entry.gd

const WORLD_SCENE := "res://scenes/World.tscn"
const AudioCues = preload("res://data/AudioCues.gd")

const MAX_SECONDS := 6.0
const POLL := 0.5


func _init() -> void:
	print("\n🎵 Audio World-Entry Test")
	# Отложенный старт: в -s-режиме autoloads (SoundManager и др.)
	# инициализируются после _init.
	call_deferred("_run")


func _run() -> void:
	var sm: Node = get_root().get_node_or_null("/root/SoundManager")
	if sm == null:
		print("❌ /root/SoundManager not in tree (autoload отключён?)")
		call_deferred("quit", 1)
		return

	var world_packed: PackedScene = load(WORLD_SCENE)
	if world_packed == null:
		print("❌ Cannot load %s" % WORLD_SCENE)
		call_deferred("quit", 1)
		return

	var world: Node = world_packed.instantiate()
	get_root().add_child(world)

	var expected: String = AudioCues.path(&"music_world")
	var elapsed := 0.0
	var ok := false
	while elapsed < MAX_SECONDS:
		await create_timer(POLL).timeout
		elapsed += POLL
		if sm.last_music_path == expected:
			ok = true
			break

	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  Audio World-Entry Test Results")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	if ok:
		print("  ✅ World entry started world music (%s)" % expected)
	else:
		print("  ❌ world music not started. last_music_path='%s'" % sm.last_music_path)
		call_deferred("quit", 1)
		return
	call_deferred("quit", 0)
