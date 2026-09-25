extends BaseTest

## ui-icons: все иконки ресурсов/зданий/потребностей/школ загружаются как Texture2D,
## и публичные API (ResourceRegistry.get_icon / BuildingDefs.get_icon) возвращают текстуры.

const RESOURCE_ICONS := ["wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold"]
const BUILDING_ICONS := ["farm", "mine", "smithy", "tavern", "barracks"]
const NEED_ICONS := ["rest", "social", "inspiration"]
const SCHOOL_ICONS := ["air", "fire", "water", "earth"]

func test_resource_icons_load() -> void:
	for id in RESOURCE_ICONS:
		var path: String = ThemeConfig.ICON_DIR_RESOURCES + id + ".png"
		assert_bool(ResourceLoader.exists(path)).is_true()
		assert_bool(load(path) is Texture2D).is_true()

func test_building_icons_load() -> void:
	for id in BUILDING_ICONS:
		var path: String = ThemeConfig.ICON_DIR_BUILDINGS + id + ".png"
		assert_bool(ResourceLoader.exists(path)).is_true()
		assert_bool(load(path) is Texture2D).is_true()

func test_need_and_school_icons_load() -> void:
	for id in NEED_ICONS:
		var path: String = ThemeConfig.ICON_DIR_NEEDS + id + ".png"
		assert_bool(load(path) is Texture2D).is_true()
	for id in SCHOOL_ICONS:
		var path: String = ThemeConfig.ICON_DIR_SCHOOLS + id + ".png"
		assert_bool(load(path) is Texture2D).is_true()

func test_resource_registry_get_icon() -> void:
	var reg := ResourceRegistry.new()
	reg.ensure_definitions()
	var tex := reg.get_icon(&"wood")
	assert_that(tex).is_not_null()
	assert_bool(tex is Texture2D).is_true()

func test_building_defs_get_icon() -> void:
	var tex := BuildingDefs.get_icon(&"farm")
	assert_that(tex).is_not_null()
	assert_bool(tex is Texture2D).is_true()
