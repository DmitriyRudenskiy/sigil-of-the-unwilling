#extends GdUnitTestSuite
# tests/unit/combat/test_battle_unit_view.gd
# [AI]: сгенерировано по задаче 8.3 tasks.md.
# Привязка картинки к бою: состояние = имя дорожки, `walk` двигает по полу,
# удар — один проход, `turn` не трогает масштаб и pivot, гибель — только цвет,
# отклик цели приходит на контактном кадре атакующего (задачи 8.2–8.4).
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
## Как собраны настоящие дорожки `attack`: 4 кадра по 12 к/с, контактный кадр —
## третий, значит отклик цели обязан прийти через 3/12 = 0.25 с.
const ATTACK_SPEED := 12.0
const ATTACK_COUNT := 4
const CONTACT_SECONDS := 0.25


func _view(side: int, speed := FRAME_SPEED, count := FRAME_COUNT) -> BattleUnitView:
	var view := auto_free(load("res://scenes/battle_unit.tscn").instantiate()) as BattleUnitView
	view.unit = _unit(side)
	add_child(view)
	view.sprite.sprite_frames = _frames(speed, count)
	view.position = Vector2(400, 700)
	return view


func _unit(side: int, slot: int = 0) -> BattleUnit:
	return BattleUnit.new(BattleFactory.stats(&"knight", 100, 10, 5, 10), side, slot)


## Поле без витрины: `_ready` не должен тянуть данные ростеров там, где их
## подставляет тест.
func _field() -> BattleField:
	var field := auto_free(BattleField.new()) as BattleField
	field.auto_cycle = false
	add_child(field)
	return field


func _frames(speed := FRAME_SPEED, count := FRAME_COUNT) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	for state: String in STATES:
		var name := StringName(state)
		var is_attack := state == "attack"
		frames.add_animation(name)
		frames.set_animation_loop(name, state in LOOPING)
		frames.set_animation_speed(name, ATTACK_SPEED if is_attack else speed)
		for _frame in (ATTACK_COUNT if is_attack else count):
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
	# `animation_finished` эмитится только у непрокрученной дорожки — он и есть
	# доказательство «один проход», ждать приходится ровно до конца кадра.
	await await_signal_on(view.sprite, &"animation_finished")
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


## Задача 8.4: синхронизация считается по номеру кадра и скорости дорожки.
func test_contact_delay_is_the_contact_frame_over_track_speed() -> void:
	var view := _view(BattleUnit.SIDE_PLAYER)
	assert_float(view.contact_delay()).is_equal_approx(CONTACT_SECONDS, 0.0001)
	# Дорожки нет — задержки нет, поле не зависает в ожидании несуществующего кадра.
	assert_float(view.contact_delay(&"fly")).is_equal(0.0)


func test_hit_starts_on_the_contact_frame_not_before() -> void:
	var field := _field()
	var attacker := field.spawn(_unit(BattleUnit.SIDE_PLAYER))
	var victim := field.spawn(_unit(BattleUnit.SIDE_ENEMY))
	attacker.sprite.sprite_frames = _frames()
	victim.sprite.sprite_frames = _frames()
	var action := BattleAction.attack(attacker.unit, victim.unit)
	action.damage[victim.unit.uid()] = 10
	field.on_action(action)
	assert_str(String(victim.sprite.animation)).is_not_equal("hit")
	await await_millis(int(CONTACT_SECONDS * 1000.0) - 100)
	assert_str(String(victim.sprite.animation)).is_not_equal("hit")
	await await_millis(200)
	assert_str(String(victim.sprite.animation)).is_equal("hit")


## Сигнал ядра, а не вызов метода: `action_performed` — единственный путь, каким
## картинка узнаёт о бое (9.3 подключает к нему `CombatState`).
func test_action_signal_from_the_core_lands_on_the_contact_frame() -> void:
	var field := _field()
	var combat := BattleFactory.state(
		BattleFactory.roster([BattleFactory.stats(&"knight", 100, 10, 5, 90)]),
		[BattleFactory.stats(&"foe", 500, 1, 0, 10)],
		5
	)
	field.attach(combat)
	assert_bool(field.auto_cycle).is_false()
	for unit in combat.alive(BattleUnit.SIDE_PLAYER):
		field.spawn(unit).sprite.sprite_frames = _frames()
	var foe: BattleUnit = combat.alive(BattleUnit.SIDE_ENEMY)[0]
	var foe_view := field.spawn(foe)
	foe_view.sprite.sprite_frames = _frames()
	combat.perform(BattleAction.attack(combat.current, foe))
	assert_str(String(foe_view.sprite.animation)).is_not_equal("hit")
	await await_millis(int(CONTACT_SECONDS * 1000.0) + 150)
	assert_str(String(foe_view.sprite.animation)).is_equal("hit")

