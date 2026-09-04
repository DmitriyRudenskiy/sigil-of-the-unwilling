extends "res://tests/gut_base.gd"
## Audio-pass: вход в мир запускает music_world.
##
## Загружает World.tscn (полный bootstrap), ждёт до 6с, пока
## SoundManager.last_music_path не станет music_world.
##
## ВАЖНО: ищем SoundManager по пути в рантайме (идентификаторы autoloads
## недоступны на этапе компиляции тестов).

const WORLD_SCENE := "res://scenes/World.tscn"
const AudioCues = preload("res://scripts/data/AudioCues.gd")

const MAX_SECONDS := 6.0
const POLL := 0.5


func test_world_entry_starts_world_music() -> void:
	var sm: Node = get_tree().root.get_node_or_null("/root/SoundManager")
	assert_not_null(sm, "/root/SoundManager in tree (autoload отключён?)")

	var world_packed: PackedScene = load(WORLD_SCENE)
	assert_not_null(world_packed, "World.tscn загружается")
	if world_packed == null:
		return

	var world: Node = world_packed.instantiate()
	get_tree().root.add_child(world)

	var expected: String = AudioCues.path(&"music_world")
	var elapsed := 0.0
	var ok := false
	while elapsed < MAX_SECONDS:
		await get_tree().create_timer(POLL).timeout
		elapsed += POLL
		if sm.last_music_path == expected:
			ok = true
			break

	assert_true(ok, "world music started. last_music_path='%s'" % str(sm.last_music_path))
	world.queue_free()
