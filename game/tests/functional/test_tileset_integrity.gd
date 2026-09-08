extends GdUnitTestSuite

const SHEET_PATH := "res://assets/tiles/world_tiles.jpeg"


func test_tileset_integrity() -> void:
	var tex := load(SHEET_PATH)
	assert_bool(tex is Texture2D).is_true()

	var ts := TileAtlas.build_hex_tileset()
	assert_that(ts).is_not_null()
	assert_int(ts.get_source_count()).is_greater(0)
