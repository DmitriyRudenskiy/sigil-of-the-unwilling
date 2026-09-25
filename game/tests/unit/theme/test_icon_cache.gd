extends BaseTest

## ui-icons: ThemeConfig.icon_texture() кэширует загруженные текстуры
## (повторный вызов — тот же экземпляр, повторная загрузка с диска не происходит).

const PATH := "res://assets/ui/icons/resources/wood.png"

func test_second_call_returns_same_instance() -> void:
	var a := ThemeConfig.icon_texture(PATH)
	var b := ThemeConfig.icon_texture(PATH)
	assert_that(a).is_not_null()
	assert_bool(a == b).is_true()

func test_cache_grows() -> void:
	var before := ThemeConfig._icon_cache.size()
	ThemeConfig.icon_texture(PATH)
	ThemeConfig.icon_texture(ThemeConfig.ICON_DIR_RESOURCES + "gems.png")
	assert_int(ThemeConfig._icon_cache.size()).is_greater_equal(before)

func test_cache_hits_do_not_reload() -> void:
	ThemeConfig.icon_texture(PATH)
	var cached: Texture2D = ThemeConfig._icon_cache[PATH] as Texture2D
	ThemeConfig.icon_texture(PATH)
	assert_bool((ThemeConfig._icon_cache[PATH] as Texture2D) == cached).is_true()
