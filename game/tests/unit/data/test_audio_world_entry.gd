extends GdUnitTestSuite

const WORLD_SCENE := "res://scenes/World.tscn"
const AudioCues = preload("res://scripts/data/AudioCues.gd")

const MAX_SECONDS := 6.0
const POLL := 0.5

var _world: Node = null

func after_test() -> void:
	if _world != null and is_instance_valid(_world):
		_world.free()
	_world = null

func test_world_entry_starts_world_music() -> void:
	var sm: Node = get_tree().root.get_node_or_null("/root/SoundManager")
	assert_that(sm).is_not_null()

	var world_packed: PackedScene = load(WORLD_SCENE)
	assert_that(world_packed).is_not_null()
	if world_packed == null:
		return

	var world: Node = world_packed.instantiate()
	_world = world
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

	assert_bool(ok).is_true()
