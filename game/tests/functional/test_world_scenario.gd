extends GdUnitTestSuite

# R1 (acceptance): сценарий через реальный WorldController:
# новая игра → сохранение → загрузка → смерть → преемственность.
# Заменяет ручной клик-скрипт: всё, что можно проверить headless-ом.

const _WORLD_SCENE := "res://scenes/World.tscn"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_new_game_save_load_death_succession() -> void:
	var world: Node = load(_WORLD_SCENE).instantiate()
	get_tree().root.add_child(world)
	await _wait(2.0)

	var wc := world as WorldController
	assert_that(wc).is_not_null()
	assert_that(wc.get_hero()).is_not_null()
	if wc == null or wc.get_hero() == null:
		world.queue_free()
		return

	# 1. Сохранение новой игры.
	assert_bool(wc.save_game()).is_true()

	# 2. Загрузка сохранённого состояния.
	var data := wc.load_game()
	assert_that(data).is_not_null()
	wc.apply_save(data)
	await _wait(0.3)
	assert_that(wc.get_hero()).is_not_null()
	if wc.get_hero() == null:
		world.queue_free()
		return

	# 3. Смерть героя с допустимым преемником.
	var hero := wc.get_hero()
	var f := Follower.new()
	f.uid = 1
	f.path = hero.path_id
	hero.followers = [f]
	hero.is_alive = false
	GameEventBus.hero_died.emit(&"battle")
	await _wait(0.3)
	assert_bool(wc.is_death_sequence_open()).is_true()

	# 4. Преемственность: новый герой установлен, последователь закрыт.
	var old_hero := wc.get_hero()
	wc._execute_succession()
	await _wait(0.3)
	assert_bool(wc.is_death_sequence_open()).is_false()
	var new_hero := wc.get_hero()
	assert_that(new_hero).is_not_null()
	if new_hero != null:
		assert_bool(new_hero.is_alive).is_true()
		assert_bool(new_hero != old_hero).is_true()

	world.queue_free()
	await get_tree().process_frame
