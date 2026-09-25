extends BaseTest

## ui-icons: для отсутствующего файла иконки возвращается fallback-текстура,
## а публичные API (ResourceRegistry/BuildingDefs) не падают на неизвестных id.

func test_missing_icon_returns_fallback() -> void:
	var tex := ThemeConfig.icon_texture("res://assets/ui/icons/resources/no_such_resource_xyz.png")
	assert_that(tex).is_not_null()
	assert_bool(tex is Texture2D).is_true()
	assert_bool(tex == load(ThemeConfig.ICON_FALLBACK)).is_true()

func test_fallback_file_exists_and_loads() -> void:
	assert_bool(ResourceLoader.exists(ThemeConfig.ICON_FALLBACK)).is_true()
	assert_bool(load(ThemeConfig.ICON_FALLBACK) is Texture2D).is_true()

func test_registry_unknown_id_falls_back() -> void:
	var reg := ResourceRegistry.new()
	reg.ensure_definitions()
	var tex := reg.get_icon(&"no_such_resource_xyz")
	assert_that(tex).is_not_null()
	assert_bool(tex == load(ThemeConfig.ICON_FALLBACK)).is_true()

func test_building_unknown_id_falls_back() -> void:
	var tex := BuildingDefs.get_icon(&"no_such_building_xyz")
	assert_that(tex).is_not_null()
	assert_bool(tex == load(ThemeConfig.ICON_FALLBACK)).is_true()
