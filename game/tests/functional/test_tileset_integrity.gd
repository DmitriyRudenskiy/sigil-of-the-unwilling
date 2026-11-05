extends BaseTest

# Путь берём из TileAtlas — единственный источник (константа теста дублировала
# путь и молча протухла при миграции jpeg→webp, docs/13 §8.4).

func test_tileset_integrity() -> void:
	var tex := load(TileAtlas.SHEET_PATH)
	assert_bool(tex is Texture2D).is_true()

	var ts := TileAtlas.build_hex_tileset()
	assert_that(ts).is_not_null()
	assert_int(ts.get_source_count()).is_greater(0)

	# Ориентация гексов закреплена кодом, а не умолчаниями Godot (T-341):
	# HEXAGON + STACKED + OFFSET_AXIS_HORIZONTAL = pointy-top, нечётные ряды
	# вправо — та же odd-r-схема, что читает HexUtils (shift_right = true).
	assert_int(ts.tile_shape).is_equal(TileSet.TILE_SHAPE_HEXAGON)
	assert_int(ts.tile_layout).is_equal(TileSet.TILE_LAYOUT_STACKED)
	assert_int(ts.tile_offset_axis).is_equal(TileSet.TILE_OFFSET_AXIS_HORIZONTAL)
