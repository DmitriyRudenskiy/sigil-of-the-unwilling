extends BaseTest

## Анимированные фигурки на поле боя: юнит стоит в своей клетке и играет дорожки
## комплекта `battle-demo` вместо портрета юнита.
##
## Почему таблица неполная — и почему это не баг. В `CharacterFrames.ANIMATED` только
## те юниты, кому кадр подходит силуэтом: всадники, драконы и нежить анимированного
## носителя не имеют, поэтому остаются портретом. Молча подставить вместо них
## человеческую фигуру означало бы соврать игроку о том, кто стоит в клетке, так что
## отсутствие ключа здесь — осознанный контракт, а не забытая строка. Тест фиксирует
## обе половины контракта: у маппинга обязана быть полная дорожка, у остальной сотни
## обязан сохраняться портрет.

const _ViewScene := preload("res://scenes/battle_view.tscn")

## Обязательные дорожки носителя: стойка, шаг, удар. `hit` — необязательная: у части
## комплекта кадра получения удара нет (priest), и вместо него остаётся цветовая
## вспышка. Требовать её — значит заставлять сочинять кадры вместо приёма существующих.
const TRACKS := [&"idle", &"walk", &"attack"]

## Дорожки, которые обязаны зацикливаться: стойка и шаг. Удар — одноразовый, его
## возврат в `idle` проверяется отдельно (`test_one_shot_track_returns_to_idle`).
const LOOPING := [&"idle", &"walk"]
const ONE_SHOT := [&"attack"]

var _view: BattleView


func before_test() -> void:
	CharacterFrames.clear_cache()
	_view = _ViewScene.instantiate()
	add_child(_view)
	_view.setup()


func after_test() -> void:
	if is_instance_valid(_view):
		_view.free()
	CharacterFrames.clear_cache()


var _next_uid := 1


func _unit(key: String) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new(key, key.left(0).to_upper(), 5, 3, 5, 3, 2), 5))
	# uid нужен реестру спрайтов вью; счётчик, а не хэш ключа — два юнита одного теста
	# не должны перетирать друг друга.
	u.uid = _next_uid
	_next_uid += 1
	u.cell = Vector2i(2, 2)
	return u


func _sprite_of(u: BattleState.BattleUnit) -> Node2D:
	return _view._sprites_by_uid.get(u.uid) as Node2D


## Ключ таблицы — это ключ юнита из реестра, а не вымышленное имя: опечатка в строке
## молча оставила бы юнита портретом навсегда.
func test_animated_keys_are_registered_units() -> void:
	for key: String in CharacterFrames.ANIMATED:
		assert_bool(UnitRegistry.UNITS_BASE.has(key)).is_true().override_failure_message(
			"ключ «%s» нет в UnitRegistry.UNITS_BASE — таблица сочинена, а не сведена с реестром" % key
		)


## Каждый маппинг обязан дать ресурс со всеми дорожками: `.tres` без дорожки `walk`
## (или без кадров в ней) роняет бой на первом же шаге.
func test_every_mapped_unit_has_full_tracks() -> void:
	for key: String in CharacterFrames.ANIMATED:
		var frames := CharacterFrames.frames_for(key)
		assert_that(frames).is_not_null().override_failure_message(
			"%s → %s: кадр-ресурс не загрузился" % [key, CharacterFrames.ANIMATED[key]])
		if frames == null:
			continue
		for track: StringName in TRACKS:
			assert_bool(frames.has_animation(track)).is_true().override_failure_message(
				"%s: нет дорожки %s" % [key, track])
			assert_bool(frames.get_frame_count(track) > 0).is_true().override_failure_message(
				"%s: дорожка %s пустая" % [key, track])
		for track: StringName in LOOPING:
			assert_bool(frames.get_animation_loop(track)).is_true().override_failure_message(
				"%s: %s не зациклена — юнит замернет на последнем кадре" % [key, track])
		for track: StringName in ONE_SHOT:
			assert_bool(not frames.get_animation_loop(track)).is_true().override_failure_message(
				"%s: %s зациклена — удар повторяется без команды" % [key, track])


## Геометрия ADR-008: холст 512 при масштабе 0.25 даёт силуэт 128 px (клетка 96),
## точка опоры — ступни (256, 448). Числа зафиксированы, потому что вместе они дают
## фигуру ровно в своей клетке; по отдельности любая правка выглядит безвредной.
func test_geometry_matches_the_field() -> void:
	assert_float(CharacterFrames.SCALE * 512.0).is_equal_approx(128.0, 0.001)
	assert_vector(CharacterFrames.FEET_OFFSET).is_equal(Vector2(-256, -448))


## Маппинг даёт фигуру: `Anim` виден и играет стойку, портрет и буква-заглушка убраны
## (вторая картинка того же юнита поверх фигуры — мусор, а не подпись).
func test_mapped_unit_plays_instead_of_showing_portrait() -> void:
	var u := _unit("swordsmen")
	_view.create_unit_sprite(u)
	var node := _sprite_of(u)
	assert_that(node).is_not_null()
	var anim: AnimatedSprite2D = node.get_node("Anim")
	assert_bool(anim.visible).is_true().override_failure_message("анимация юнита не показана")
	assert_that(anim.animation).is_equal(&"idle") \
		.override_failure_message("юнит не в стойке: %s" % str(anim.animation))
	assert_that(anim.sprite_frames).is_not_null()
	assert_that(node.get_node("Initial").visible).is_false().override_failure_message(
		"буква-заглушка осталась поверх фигурки")
	assert_that(node.get_node("Figure").texture).is_null().override_failure_message(
		"портрет остался под анимированной фигуркой")


## Юнит вне таблицы остаётся портретом — молча и без падения.
func test_unmapped_unit_keeps_portrait() -> void:
	var u := _unit("beholder")
	_view.create_unit_sprite(u)
	var node := _sprite_of(u)
	assert_that(node).is_not_null()
	assert_that(_view._sprites_by_uid.size()).is_equal(1)
	assert_that(node.get_node("Anim").sprite_frames).is_null().override_failure_message(
		"у %s появилась анимация, которой в таблице нет" % u.get_key())
	assert_that(node.get_node("Figure").texture).is_not_null().override_failure_message(
		"портрет пропал — у юнита не осталось никакого изображения")


## Шаг играет походку, удар — получение удара там, где для него есть кадры. Юнит без
## такой дорожки (druid → priest) не имеет ни упасть, ни ошибки: остаётся вспышка.
func test_move_and_hit_play_their_tracks() -> void:
	var u := _unit("swordsmen")
	var d := _unit("archers")
	var leaf := _unit("druid")
	for unit in [u, d, leaf]:
		_view.create_unit_sprite(unit)
	_view.animate_move(u, [u.cell, Vector2i(4, 2)])
	var an := _sprite_of(u).get_node("Anim") as AnimatedSprite2D
	assert_that(an.animation).is_equal(&"walk") \
		.override_failure_message("на шаге не включена дорожка walk: %s" % str(an.animation))
	_view.flash_unit(d)
	var dn := _sprite_of(d).get_node("Anim") as AnimatedSprite2D
	assert_that(dn.animation).is_equal(&"hit") \
		.override_failure_message("на ударе не включена дорожка hit: %s" % str(dn.animation))
	_view.flash_unit(leaf)
	var ln := _sprite_of(leaf).get_node("Anim") as AnimatedSprite2D
	assert_that(ln.animation).is_equal(&"idle").override_failure_message(
		"юнит без дорожки hit должен остаться в стойке, а не играть то, чего нет")


## Одноразовая дорожка обязана вернуться в стойку по своему концу, а не остаться
## последним кадром замаха. Проверка временем, а не ручной эмиссией сигнала: ручная
## эмиссия не обязана совпадать с тем, как движок сам завершает трек.
func test_one_shot_track_returns_to_idle() -> void:
	var an := AnimatedSprite2D.new()
	an.sprite_frames = CharacterFrames.frames_for("swordsmen")
	an.centered = false
	add_child(an)
	_view._play_once(an, &"attack")
	assert_that(an.animation).is_equal(&"attack")
	# 4 кадра по 0.125 с при 8 fps = 0.5 с дорожки; запас — на квантование кадров.
	await await_millis(1200)
	assert_that(an.animation).is_equal(&"idle") \
		.override_failure_message("после конца attack дорожка не вернулась в idle")
	an.queue_free()
