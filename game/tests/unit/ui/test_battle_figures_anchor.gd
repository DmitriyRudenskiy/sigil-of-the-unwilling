extends BaseTest

## Опора и масштаб ряда (3.3): стопы — в центр клетки, рост ряда — один.
##
## Почему тест считает геометрию, а не сравнивает константы. У носителей разные
## единицы: у выреза `offset` задан в пикселях текстуры и домножается на `scale`,
## у дорожек комплекта кадр с припуском под стопами (ступни в канвасе на y = 448,
## а не на нижнем краю). Равенство `offset` или `scale` ничего не говорит о том,
## где на поле стоят ноги, — поэтому проверка одна для всех: линия стоп в
## координатах клетки.
##
## Портреты здесь не проверяются: они не фигуры ряда, их носитель — заглушка
## ключа без опорной точки (мера ряда касается вырезов и дорожек).

const _ViewScene := preload("res://scenes/battle_view.tscn")

## Канвас комплекта и линия ступней в нём (ADR-008: холст 512×512, ступни (256, 448)).
const KIT_CANVAS := Vector2(512.0, 512.0)
const KIT_FEET := Vector2(256.0, 448.0)

## Допуск ряда, world px: доли пикселя от округления координат клетки, не «на глаз».
const ROW_TOLERANCE := 1.0

var _view: BattleView
var _next_uid := 1


func before_test() -> void:
	CharacterFrames.clear_cache()
	_view = _ViewScene.instantiate()
	add_child(_view)
	_view.setup()


func after_test() -> void:
	if is_instance_valid(_view):
		_view.free()
	CharacterFrames.clear_cache()


func _unit(key: String, cell: Vector2i) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new(key, key.left(0).to_upper(), 5, 3, 5, 3, 2), 5))
	u.uid = _next_uid
	_next_uid += 1
	u.cell = cell
	return u


## Линия стоп носителя в локальных координатах узла: (0, 0) — значит стопы ровно
## в центре клетки, куда поставлен узел.
func _feet_local(node: Node2D) -> Vector2:
	if node.has_meta("still"):
		var fig: Sprite2D = node.get_node("Figure")
		# Вырез нарезан впритык (проверяется выше), поэтому линия стоп — нижний край
		# кадра. При `centered = true` центр кадра лежит в `offset`, а не его левый
		# край, поэтому к высоте прибавляется половина высоты, а половина ширины — нет.
		var drop := float(fig.texture.get_height()) / 2.0
		return Vector2(fig.offset.x, fig.offset.y + drop) * fig.scale
	var an: AnimatedSprite2D = node.get_node("Anim")
	return (an.offset + KIT_FEET) * an.scale


func _feet_of(u: BattleState.BattleUnit) -> Vector2:
	var node := _view._sprites_by_uid.get(u.uid) as Node2D
	return node.position + _feet_local(node)


## Премисса опоры вырезов: арт нарезан впритык, нижняя строка пикселей и есть
## стопы. Пересохранят с припуском — правило «низ кадра в клетку» уедет вверх, и
## тест обязан покраснеть, а не молча поставить фигуру на пятки.
func test_cutouts_are_cut_tight() -> void:
	for key: String in CharacterFrames.still_figures:
		var tex: Texture2D = CharacterFrames.still_texture_for(key)
		assert_that(tex).is_not_null()
		var img := tex.get_image()
		var h := img.get_height()
		var opaque := 0
		for x in img.get_width():
			if img.get_pixel(x, h - 1).a > 0.0:
				opaque += 1
		assert_that(opaque).is_greater(0).override_failure_message(
			"%s: нижняя строка кадра пуста — вырез не впритык, опора считается не от стоп" % key)


## Стопы — в центр клетки у обоих носителей: и у выреза, и у дорожек комплекта.
func test_feet_stand_in_the_cell_center() -> void:
	var cases := {
		"swordsmen": Vector2i(1, 3),
		"champions": Vector2i(2, 4),
		"wolves": Vector2i(3, 5),
	}
	for key: String in cases:
		var u := _unit(key, cases[key])
		_view.create_unit_sprite(u)
		var node := _view._sprites_by_uid.get(u.uid) as Node2D
		var feet := _feet_local(node)
		assert_float(feet.x).is_equal_approx(0.0, ROW_TOLERANCE).override_failure_message(
			"%s: фигура смещена по x на %.1f px от центра клетки" % [key, feet.x])
		assert_float(feet.y).is_equal_approx(0.0, ROW_TOLERANCE).override_failure_message(
			"%s: стопы не в центре клетки, смещение %.1f px по y" % [key, feet.y])


## Ряд читается одной линией: смешанные носители (вырез и дорожки) в одном ряду
## стоят стопами на одном уровне. Разъедутся — ряд будет выглядеть толпой разного
## роста, даже если каждая фигура по отдельности «нормальная».
func test_row_feet_line_is_horizontal() -> void:
	var row := 3
	var units: Array = []
	for pair in [["swordsmen", 0], ["champions", 1], ["wolves", 2], ["knights", 3]]:
		var u := _unit(String(pair[0]), Vector2i(int(pair[1]), row))
		_view.create_unit_sprite(u)
		units.append(u)
		var node := _view._sprites_by_uid.get(u.uid) as Node2D
		assert_float(node.position.y).is_equal_approx(
			_view.field_point(Vector2i(0, row)).y, ROW_TOLERANCE
		).override_failure_message("%s: клетка ряда легла не на свою линию" % String(pair[0]))
	var feet_y := []
	for u: BattleState.BattleUnit in units:
		feet_y.append(_feet_of(u).y)
	var spread: float = feet_y.max() - feet_y.min()
	assert_float(spread).is_less_equal(ROW_TOLERANCE).override_failure_message(
		"стопы ряда разъехались на %.2f px (допуск %.1f)" % [spread, ROW_TOLERANCE])
