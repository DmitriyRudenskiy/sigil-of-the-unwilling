extends "res://tests/gut_base.gd"
## GUT-инвариант: целостность тайлкета (порт tools/check_tileset.gd).
## Проверяет, что текстура листа тайлов загружается, и
## TileAtlas.build_hex_tileset() даёт хотя бы один источник.

const SHEET_PATH := "res://assets/tiles/world_tiles.jpeg"


func test_tileset_integrity() -> void:
	var tex := load(SHEET_PATH)
	assert_true(tex is Texture2D, "world tile texture loads (%s)" % SHEET_PATH)

	var ts := TileAtlas.build_hex_tileset()
	assert_not_null(ts, "TileAtlas.build_hex_tileset() != null")
	assert_gt(ts.get_source_count(), 0, "tileset source_count > 0 (got %d)" % ts.get_source_count())
