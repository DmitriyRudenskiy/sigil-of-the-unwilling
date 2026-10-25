class_name BattleUnitView extends Node2D

## Визуальный слой юнита на поле (задача 8.2).
##
## Привязка боя к картинке — это **имя дорожки**: `assets/sprites/<id>.sprite_frames.tres`
## собирается из принятых клипов (`tools/build_sprite_frames.py`), и дорожка
## называется так же, как анимация боя (`idle/walk/attack/hit/turn`). Отдельного
## словаря «событие → анимация» здесь нет и быть не должно.
##
## Холст кадра — 512×512, ступни в (256, 448) (спека «Техническая форма кадра»),
## поэтому узел рисует кадр со сдвигом `(-256, -448)` при `centered = false` и
## `scale = ENGINE_SCALE`: позиция узла = точка опоры на полу, поправок на
## конкретный кадр нет. В 96 px на экране силуэт попадает именно масштаб —
## форма комплекта и размер в бою разведены намеренно.
##
## Гибели как дорожки нет (D10): мёртвый юнит стоит на последнем кадре
## обесцвеченным — `modulate`, а не четвёртая генерация.

const FEET_OFFSET := Vector2(-256, -448)
## 512-й холст комплекта → 128-й холст движка: 96 px силуэта на поле, как было
## до переезда комплекта на форму спеки (ADR-008).
const ENGINE_SCALE := 0.25
const DEAD_MODULATE := Color(0.4, 0.42, 0.48)
## Проход линии: `walk` — единственная дорожка, которая двигает узел по полу.
## Скорость в пикселях секунды до масштаба поля; направление — на противника.
const WALK_SPEED := 120.0

## Кадр, в котором оружие достигает цели (задача 8.4): отклик цели откладывается
## на `(кадр + 1) / скорость дорожки`. Прореженные до 4 кадров дорожки `attack`
## кривую вылета не показывают (размах силуэта по кадрам ±5 px, пик разбросан по
## номерам), поэтому номер закреплён здесь, а не выводится из картинок.
const CONTACT_FRAMES := {&"attack": 2}

## Экземпляр боя. Назначается и до `_ready` (поле собирает юнитов сразу), и после.
var unit: BattleUnit:
	set(value):
		unit = value
		if sprite != null:
			_bind()

var _dead := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.centered = false
	sprite.offset = FEET_OFFSET
	sprite.scale = Vector2.ONE * ENGINE_SCALE
	if unit != null:
		_bind()


func _process(delta: float) -> void:
	if unit == null or _dead:
		return
	if unit.died:
		die()
		return
	if sprite.animation == &"walk" and sprite.is_playing():
		position.x += delta * WALK_SPEED * (1.0 if _faces_right() else -1.0)


## Гибель: обесцвечивание последнего кадра (D10), без смены дорожки.
func die() -> void:
	_dead = true
	sprite.stop()
	modulate = DEAD_MODULATE


func is_alive() -> bool:
	return unit != null and not unit.died


## Задержка до контактного кадра дорожки, секунды. 0.0 — дорожки нет, и отклик
## уходит сразу (молчание дороже: причину видно в `play`).
func contact_delay(track: StringName = &"attack") -> float:
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(track):
		return 0.0
	var count := frames.get_frame_count(track)
	var contact := mini(int(CONTACT_FRAMES.get(track, count - 1)), count - 1)
	return float(contact + 1) / frames.get_animation_speed(track)


## Состояние = дорожка. Дорожки, которой нет в собранном наборе, не роняет поле:
## юнит остаётся на текущей, а причину видно в `push_error`.
func play(state: StringName) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	if not frames.has_animation(state):
		push_error("%s: дорожки %s нет в %s" % [unit.uid(), state, frames.resource_path])
		return
	sprite.animation = state
	sprite.play()


func _bind() -> void:
	# Враг смотрит на линию игрока; разворот — зеркалом, не отдельной генерацией.
	# Он не зависит от дорожек, поэтому и ставится до загрузки набора.
	sprite.flip_h = not _faces_right()
	var path := DataLibrary.sprite_frames_path(unit.stats.id)
	if not FileAccess.file_exists(path):
		# По настоящих данным сюда не попасть: `DataLibrary.validate` не пустит
		# юнита без дорожек (AC 26). Остаётся путём для синтетических юнитов
		# тестов, у которых id свой, а картинки нет.
		push_warning("нет дорожек юнита: %s" % path)
		return
	var frames := load(path) as SpriteFrames
	if frames == null:
		push_error("дорожки не загрузились: %s (нужен --import)" % path)
		return
	sprite.sprite_frames = frames
	play(&"idle")


## Сторона задаёт всё, что отличается у противников картинкой: куда смотреть и
## куда идти. Масштаб и pivot — общие для обеих сторон (задача 8.2).
func _faces_right() -> bool:
	return unit.side == BattleUnit.SIDE_PLAYER
