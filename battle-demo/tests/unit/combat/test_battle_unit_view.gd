#extends GdUnitTestSuite
# tests/unit/combat/test_battle_unit_view.gd
# [AI]: сгенерировано по задаче 8.3 tasks.md, проверено человеком.
# Привязка картинки к бою: состояние = имя дорожки, `walk` двигает по полу,
# удар — один проход, `turn` не трогает масштаб и pivot, гибель — только цвет.
#
# Дорожки подставляются заглушкой: пиксели собираются из принятых клипов
# (`tools/build_sprite_frames.py`) и не лежат в репо, а проверяется здесь контракт
# слоя — какие свойства он берёт из дорожки, а какие задаёт сам.

extends GdUnitTestSuite

## Как ставит цикл пайплайн: бегут только `idle` и `walk`.
const LOOPING := ["idle", "walk"]
const STATES := ["idle", "walk", "attack", "hit", "turn"]
## Быстрая заглушка: дорожка из двух кадров кончается за ~0.03 с, поэтому
## «проигрался один раз» проверяется кадром, а не догадкой.
const FRAME_SPEED := 60.0
const FRAME_COUNT := 2


func _view(side: int) -> BattleUnitView:
	var view := auto_free(load("res://scenes/battle_unit.tscn").instantiate()) as BattleUnitView
	view.unit = BattleUnit.new(BattleFactory.stats(&"knight", 100, 10, 5, 10), side, 0)
	add_child(view)
	view.sprite.sprite_frames = _frames()
	view.position = Vector2(400, 700)
	return view


func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for state: String in STATES:
		var name := StringName(state)
		frames.add_animation(name)
		frames.set_animation_loop(name, state in LOOPING)
		frames.set_animation_speed(name, FRAME_SPEED)
		for _frame in FRAME_COUNT:
			frames.add_frame(name, texture)
	return frames


func test_bind_starts_idle_and_faces_the_enemy_line() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	assert_str(String(view.sprite.animation)).is_equal("idle")
	assert_bool(view.sprite.flip_h).is_false()


func test_enemy_side_is_mirrored() -> void:
	assert_bool(_view(BattleUnit.SIDE_ENEMY).sprite.flip_h).is_true()


func test_state_selects_the_track() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	view.play(&"attack")
	assert_str(String(view.sprite.animation)).is_equal("attack")
	assert_bool(view.sprite.is_playing()).is_true()


func test_unknown_state_keeps_the_unit_on_its_track() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	view.play(&"attack")
	view.play(&"fly")
	assert_str(String(view.sprite.animation)).is_equal("attack")


func test_attack_is_played_once() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	view.play(&"attack")
	for _frame in 10:
		await await_idle_frame()
	assert_bool(view.sprite.is_playing()).is_false()
	assert_str(String(view.sprite.animation)).is_equal("attack")


func test_walk_moves_player_right_and_enemy_left() -> void:
	var player := _view(BattleUnit.SIDE_PLAYER)
	var enemy := _view(BattleUnit.SIDE_ENEMY)
	player.play(&"walk")
	enemy.play(&"walk")
	for _frame in 10:
		await await_idle_frame()
	assert_float(player.position.x).is_greater(400.0)
	assert_float(enemy.position.x).is_less(400.0)


func test_turn_keeps_scale_and_pivot() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	var scale_before := view.scale
	var pivot_before := view.sprite.offset
	var y_before := view.position.y
	view.play(&"turn")
	for _frame in 10:
		await await_idle_frame()
	assert_vector(view.scale).is_equal(scale_before)
	assert_vector(view.sprite.offset).is_equal(pivot_before)
	assert_float(view.position.y).is_equal(y_before)


func test_death_stops_on_the_last_frame_and_desaturates() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	view.play(&"attack")
	view.unit.died = true
	await await_idle_frame()
	assert_bool(view.sprite.is_playing()).is_false()
	assert_str(String(view.sprite.animation)).is_equal("attack")
	assert_bool(view.modulate.is_equal_approx(BattleUnitView.DEAD_MODULATE)).is_true()
