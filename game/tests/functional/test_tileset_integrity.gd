extends BaseTest

## Целостность тайлсета карты после перехода на процедурный лист (**T-344**):
## ориентация решётки, пропорция клетки и шаг рядов проверяются по самому
## тайлсету и по `map_to_local`, потому что ровно эти три числа решают, стыкуются
## ли соты. Манифеста больше нет — читать координаты «из данных» не откуда.

## Сравнение с допуском: `is_equal_approx` в Godot 4 epsilon не принимает.
static func _near(a: float, b: float, eps: float) -> bool:
	return absf(a - b) <= eps


## Пропорция bounding box pointy-top-гекса: h/w = 2/√3.
const EXPECTED_RATIO := 2.0 / sqrt(3.0)


func test_tileset_integrity() -> void:
	var ts := HexCellArt.build_hex_tileset()
	assert_that(ts).is_not_null()
	assert_that(ts.get_source_count()).is_greater(0)

	# Ориентация гексов закреплена кодом, а не умолчаниями Godot (T-341):
	# HEXAGON + STACKED + OFFSET_AXIS_HORIZONTAL = pointy-top, нечётные ряды
	# вправо — та же odd-r-схема, что читает HexUtils (shift_right = true).
	assert_int(ts.tile_shape).is_equal(TileSet.TILE_SHAPE_HEXAGON)
	assert_int(ts.tile_layout).is_equal(TileSet.TILE_LAYOUT_STACKED)
	assert_int(ts.tile_offset_axis).is_equal(TileSet.TILE_OFFSET_AXIS_HORIZONTAL)

	# Пропорция клетки (AC 1 из T-344, урок T-343): квадратная клетка при
	# pointy-top даёт щель на каждой второй границе биомов — «ступенчатые стыки».
	var ratio := float(ts.tile_size.y) / float(ts.tile_size.x)
	assert_that(_near(ratio, EXPECTED_RATIO, 0.01)).is_true()


## Шаг решётки измеряется движком, а не вычитается из константы: зонд
## `map_to_local` ловит и неверную ориентацию, и потерю сдвига нечётного ряда
## (Godot STACKED сдвигает нечётные ряды — odd-r; глобальная калибровка
## `HexGrid.calibrate` меряет только знак сдвига, а не его величину).
func test_lattice_step_matches_hex_geometry() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = HexCellArt.build_hex_tileset()
	add_child(layer)
	var hex := Vector2(HexCellArt.HEX_SIZE)
	var origin := layer.map_to_local(Vector2i(0, 0))
	var east := layer.map_to_local(Vector2i(1, 0))
	var south := layer.map_to_local(Vector2i(0, 1))

	# Сосед по столбцу — ровно на ширину гекса, по одной горизонтали.
	assert_that(_near((east - origin).x, hex.x, 0.01)).is_true()
	assert_that(_near((east - origin).y, 0.0, 0.01)).is_true()
	# Следующий ряд — на 0.75·h вниз и на полгекса вправо (нечётный ряд).
	assert_that(_near((south - origin).y, hex.y * 0.75, 0.01)).is_true()
	assert_that(_near((south - origin).x, hex.x * 0.5, 0.01)).is_true()


## Слои обязаны делить решётку с базой до пикселя: у растительности и дорог свои
## листы и свои картинки, но та же клетка. Разъезд — это деревья не над своей
## землёй и дороги не над своей дорогой (проверка дешёвая, дефект был бы молча).
func test_overlay_layers_share_base_lattice() -> void:
	var base := HexCellArt.build_hex_tileset()
	for other in [MapObjects.build_tileset(), MapRoads.build_tileset()]:
		assert_that(other).is_not_null()
		assert_int(other.tile_shape).is_equal(base.tile_shape)
		assert_int(other.tile_layout).is_equal(base.tile_layout)
		assert_int(other.tile_offset_axis).is_equal(base.tile_offset_axis)
		assert_that(other.tile_size).is_equal(base.tile_size)
