extends BaseTest

const _WORLD_SCENE := "res://scenes/World.tscn"
const TestWait := preload("res://tests/helpers/wait_helpers.gd")

var _world: Node = null

func after_test() -> void:
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
		await get_tree().process_frame
	_world = null

func test_new_game_save_load_death_succession() -> void:
	var world: Node = load(_WORLD_SCENE).instantiate()
	_world = world
	get_tree().root.add_child(world)

	var wc := world as WorldController
	assert_that(wc).is_not_null()

	assert_bool(await TestWait.wait_for(
		func(): return wc != null and wc.get_hero() != null and wc._save_svc != null
	)).is_true()
	assert_that(wc.get_hero()).is_not_null()
	if wc == null or wc.get_hero() == null:
		return

	assert_bool(wc.save_game()).is_true()

	var data := wc.load_game()
	assert_that(data).is_not_null()
	wc.apply_save(data)
	assert_bool(await TestWait.wait_for(func(): return wc.get_hero() != null)).is_true()
	assert_that(wc.get_hero()).is_not_null()
	if wc.get_hero() == null:
		return

	var hero := wc.get_hero()
	var f := Follower.new()
	f.uid = 1
	f.path = hero.path_id
	hero.followers = [f]
	hero.is_alive = false
	GameEventBus.hero_died.emit(&"battle")
	assert_bool(await TestWait.wait_for(func(): return wc.is_death_sequence_open())).is_true()
	assert_bool(wc.is_death_sequence_open()).is_true()

	var old_hero := wc.get_hero()
	wc._execute_succession()
	assert_bool(await TestWait.wait_for(func(): return not wc.is_death_sequence_open())).is_true()
	assert_bool(wc.is_death_sequence_open()).is_false()
	var new_hero := wc.get_hero()
	assert_that(new_hero).is_not_null()
	if new_hero != null:
		assert_bool(new_hero.is_alive).is_true()
		assert_bool(new_hero != old_hero).is_true()
