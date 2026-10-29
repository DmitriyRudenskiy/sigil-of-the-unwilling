extends BaseTest

## Вырезы арт-комплекта владельца на поле (3.9).
##
## Почему вырез, а не походка. Носитель движения один (`CharacterFrames`), и у него
## два вида материала: дорожки кадров комплекта и одиночная поза-вырез. Арт владельца
## пришёл позами, поэтому его юниты стоят своим вырезом, а движение и отдача делаются
## над позой процедурно. Генерировать дорожки из статики здесь нечем: кадры дорожки
## обязаны совпасть силуэтом, иначе на поле мерцание.
##
## Почему именно эти три ключа. Левая сторона референса владельца — пять вырезов 3.1,
## из которых юнит есть у трёх (`swordsmen`, `archers`, `knights`); `paladin` и
## `battle_dwarf` ждут ключа юнита и по правилу «нет совпадения силуэта — нет фигуры»
## остаются портретом.

const _ViewScene := preload("res://scenes/battle_view.tscn")

## Ключи, чей вырез лежит в `assets/units/figures/`.
const KEYS := ["swordsmen", "archers", "knights"]

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


func _unit(key: String, atk: bool = true) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new(key, key.left(0).to_upper(), 5, 3, 5, 3, 2), 5))
	u.uid = _next_uid
	_next_uid += 1
	u.cell = Vector2i(2, 2)
	u.side = BattleState.Side.ATTACKER if atk else BattleState.Side.DEFENDER
	return u


func _sprite_of(u: BattleState.BattleUnit) -> Node2D:
	return _view._sprites_by_uid.get(u.uid) as Node2D


## Вырез обязан лежать в реестре и на диске: путь в таблицу без файла молча вернул
## бы юнита на походку комплекта, и расхождение никто бы не увидел.
func test_owner_keys_have_their_cutout() -> void:
	for key: String in KEYS:
		var path := str(CharacterFrames.STILL_FIGURES.get(key, ""))
		assert_that(path).is_not_empty().override_failure_message("%s: вырез не зарегистрирован" % key)
		assert_bool(ResourceLoader.exists(path)).is_true().override_failure_message(
			"%s: файл выреза %s не найден" % [key, path])
		assert_bool(UnitRegistry.UNITS_BASE.has(key)).is_true().override_failure_message(
			"%s: ключа нет в реестре юнитов — вырез некому выдать" % key)


## Юнит стоит своим вырезом, а не портретом и не чужой походкой: `Figure` с текстурой,
## `Anim` скрыт, буква-заглушка убрана (второй картинки того же юнита не будет).
func test_owner_unit_stands_on_its_cutout() -> void:
	for key: String in KEYS:
		var u := _unit(key)
		_view.create_unit_sprite(u)
		var node := _sprite_of(u)
		assert_that(node).is_not_null()
		var fig: Sprite2D = node.get_node("Figure")
		assert_that(fig.texture).is_not_null().override_failure_message(
			"%s: вырез не показан" % key)
		assert_that(fig.texture.resource_path).is_equal(
			str(CharacterFrames.STILL_FIGURES[key])
		).override_failure_message("%s: показана не картинка владельца" % key)
		assert_that(node.get_node("Anim").visible).is_false().override_failure_message(
			"%s: походка комплекта видна под вырезом владельца" % key)
		assert_that(node.get_node("Initial").visible).is_false().override_failure_message(
			"%s: буква-заглушка осталась поверх выреза" % key)


## Опора и рост — общие с дорожками: нижний край кадра (линия стоп) в позиции узла,
## высота силуэта одинакова у всех вырезов, хотя кадры пришли разными (495–569 px).
## Проверяется геометрия, а не константа смещения: `offset` — в единицах текстуры,
## у каждого кадра он свой, и равенство констант ничего про стопы не говорит.
func test_cutouts_share_anchor_and_height() -> void:
	var heights := {}
	for key: String in KEYS:
		var u := _unit(key)
		_view.create_unit_sprite(u)
		var fig: Sprite2D = _sprite_of(u).get_node("Figure")
		var feet := (fig.offset.y + fig.texture.get_height() / 2.0) * fig.scale.y
		assert_float(feet).is_equal_approx(0.0, 0.01).override_failure_message(
			"%s: стопы не в позиции узла, смещены на %.1f px" % [key, feet])
		heights[key] = fig.scale.y * float(fig.texture.get_height())
	for key: String in heights:
		assert_float(heights[key]).is_equal_approx(CharacterFrames.STILL_HEIGHT, 0.01) \
			.override_failure_message("%s: рост выреза %.1f px вне меры ряда" % [key, heights[key]])


## Разворот по стороне не трогает ни опору, ни рост (спека «Поза по стороне»).
func test_facing_keeps_anchor_and_scale() -> void:
	var right := _unit("knights", true)
	var left := _unit("knights", false)
	_view.create_unit_sprite(right)
	_view.create_unit_sprite(left)
	var a: Sprite2D = _sprite_of(right).get_node("Figure")
	var b: Sprite2D = _sprite_of(left).get_node("Figure")
	assert_that(a.flip_h).is_false() \
		.override_failure_message("арт смотрит вправо, противник атакующего справа — зеркало развернуло бы его спиной")
	assert_that(b.flip_h).is_true() \
		.override_failure_message("защищающийся обязан смотреть влево, на противника")
	assert_vector(a.offset).is_equal(b.offset)
	assert_vector(a.scale).is_equal(b.scale)


## Шаг: поза поднимается с опоры и возвращается в покой — голое перемещение было бы
## скольжением статичной картинки (спека «Отклик на движение»).
func test_move_bobs_and_returns_to_rest() -> void:
	var u := _unit("swordsmen")
	_view.create_unit_sprite(u)
	var fig: Sprite2D = _sprite_of(u).get_node("Figure")
	var rest: Vector2 = _sprite_of(u).get_meta("rest")
	var tw := _view.animate_move(u, [u.cell, Vector2i(4, 2)])
	assert_that(tw).is_not_null()
	# Темп пути (0.15 с) короче кадра headless-теста, поэтому сэмпл «по часам»
	# ловил бы позу в произвольной фазе. `custom_step` по шагу перематывает твин
	# детерминированно: пик подъёма — конец первой половины полшага.
	tw.pause()
	tw.custom_step(GameNumbers.BATTLE_MOVE_TWEEN_SEC * 0.5)
	# Мера — экран, а не единицы текстуры: `offset` домножается на `scale`, и без
	# делителя подъём в 5 px давал бы ~1 px на поле (поза есть — не видно).
	assert_float((rest.y - fig.offset.y) * fig.scale.y).is_greater_equal(4.0) \
		.override_failure_message(
			"в пути поза поднялась на экране меньше чем на 4 px — это скольжение")
	tw.play()
	await tw.finished
	assert_vector(fig.offset).is_equal(rest) \
		.override_failure_message("после шага поза не вернулась в покой")


## Отдача от удара: сдвиг назад от противника и возврат в опору. Поза идёт по
## смещению, а не по позиции узла, поэтому не спорит с перемещением.
func test_hit_recoils_and_returns_to_rest() -> void:
	var u := _unit("knights")
	_view.create_unit_sprite(u)
	var fig: Sprite2D = _sprite_of(u).get_node("Figure")
	var rest: Vector2 = _sprite_of(u).get_meta("rest")
	_view.flash_unit(u)
	await await_millis(100)
	assert_float(fig.offset.x).is_less(rest.x - 0.001) \
		.override_failure_message("отдача атакующего обязана уйти назад по x (получено %.1f)" % fig.offset.x)
	assert_float((rest.x - fig.offset.x) * fig.scale.x).is_greater_equal(2.0) \
		.override_failure_message("отдача на экране меньше 2 px — анимация невидима")
	await await_millis(400)
	assert_vector(fig.offset).is_equal(rest) \
		.override_failure_message("после удара поза не вернулась в покой")


## Юнит без выреза не обязан знать о существовании вырезов: у него либо дорожки
## комплекта, либо портрет — второго пути отрисовки не появляется.
func test_units_without_cutout_keep_their_carrier() -> void:
	var animated := _unit("champions")
	var portrait := _unit("beholder")
	_view.create_unit_sprite(animated)
	_view.create_unit_sprite(portrait)
	assert_that(_sprite_of(animated).has_meta("still")).is_false()
	assert_that(_sprite_of(portrait).has_meta("still")).is_false()
	assert_that(_sprite_of(portrait).get_node("Figure").texture).is_not_null()
