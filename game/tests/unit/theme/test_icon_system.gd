extends BaseTest
## Task 11: тесты иконок, курсоров, кэша, fallback

const IR = preload("res://scripts/theme/IconRegistry.gd")
const TC = preload("res://scripts/theme/theme_config.gd")

func test_resource_icons_load() -> void:
	for id in ["wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold"]:
		var tex: Texture2D = IR.resource_texture(id)
		assert_that(tex).is_not_null()
		assert_that(tex.resource_path).ends_with("%s.png" % id)

func test_building_icons_load() -> void:
	for id in ["farm", "mine", "barracks"]:
		var tex: Texture2D = IR.building_texture(id)
		assert_that(tex).is_not_null()
		assert_that(tex.resource_path).ends_with("%s.png" % id)

func test_need_and_school_icons() -> void:
	assert_that(IR.need_texture("rest").resource_path).ends_with("rest.png")
	assert_that(IR.school_texture("fire").resource_path).ends_with("fire.png")

func test_cursor_sprites_load() -> void:
	for mode in ["default", "walk", "collect", "attack", "spell", "talk"]:
		var tex: Texture2D = IR.cursor_texture(mode)
		assert_that(tex).is_not_null().override_failure_message("курсор %s не загрузился" % mode)
		assert_that(tex.get_width()).is_equal(32)

func test_icon_cache() -> void:
	var a: Texture2D = IR.resource_texture("wood")
	var b: Texture2D = IR.resource_texture("wood")
	assert_bool(a == b).override_failure_message("кэш не срабатывает")
	assert_that(IR._cache.size()).is_greater(0)

func test_fallback_icon() -> void:
	var tex: Texture2D = IR.resource_texture("nonexistent_resource")
	assert_that(tex).is_not_null()
	assert_that(tex.resource_path).is_equal(TC.ICON_FALLBACK)
	var b: Texture2D = IR.building_texture("nonexistent_building")
	assert_that(b.resource_path).is_equal(TC.ICON_FALLBACK)

func test_building_defs_get_icon() -> void:
	const BD = preload("res://scripts/data/building_defs.gd")
	var tex: Texture2D = BD.get_icon(&"farm")
	assert_that(tex).is_not_null()
