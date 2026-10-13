extends BaseTest

# Путь берём из TileAtlas — единственный источник (константа теста дублировала
# путь и молча протухла при миграции jpeg→webp, docs/13 §8.4).

func test_tileset_integrity() -> void:
	var tex := load(TileAtlas.SHEET_PATH)
	assert_bool(tex is Texture2D).is_true()

	var ts := TileAtlas.build_hex_tileset()
	assert_that(ts).is_not_null()
	assert_int(ts.get_source_count()).is_greater(0)
