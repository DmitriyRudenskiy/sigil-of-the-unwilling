extends BaseTest

# Переключатель носителя листа тайлов (`TileAtlas.sheet_path`, T-341): по умолчанию
# рисуется атлас, резервный лист из кадра включается env-переменной. Тест обязан
# трогать окружение сам и возвращать его обратно — иначе он отравит следующий
# тест-файл в том же процессе (GdUnit гоняет файлы в одном Godot).


func test_default_is_the_atlas() -> void:
	OS.set_environment(TileAtlas.KIT_ENV, "0")
	assert_that(TileAtlas.sheet_path()).is_equal(TileAtlas.SHEET_PATH)


func test_env_turns_on_the_kit_sheet() -> void:
	OS.set_environment(TileAtlas.KIT_ENV, "1")
	assert_that(TileAtlas.sheet_path()).is_equal(TileAtlas.KIT_SHEET_PATH)


func test_hex_tileset_builds_from_the_kit_sheet() -> void:
	# Раскладка общая (`world_map_atlas.json`), поэтому лист из кадра обязан
	# дать тот же тайлсет, что и атлас: та же форма соты и столько же тайлов.
	OS.set_environment(TileAtlas.KIT_ENV, "1")
	var kit: TileSet = TileAtlas.new().build_hex()
	OS.set_environment(TileAtlas.KIT_ENV, "0")
	var atlas: TileSet = TileAtlas.new().build_hex()
	assert_int(kit.tile_shape).is_equal(atlas.tile_shape)
	var kit_src: TileSetAtlasSource = kit.get_source(TileAtlas.SOURCE_ID)
	var atlas_src: TileSetAtlasSource = atlas.get_source(TileAtlas.SOURCE_ID)
	assert_int(kit_src.get_tiles_count()).is_equal(atlas_src.get_tiles_count())
	assert_bool(kit_src.get_texture() != null).is_true()


func after_test() -> void:
	OS.set_environment(TileAtlas.KIT_ENV, "")
