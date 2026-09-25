extends BaseTest

## ui-icons: все спрайты курсоров из CursorControllerAutoload.MODE_ASSETS загружаются.

func test_mode_cursor_sprites_load() -> void:
	for mode in CursorControllerAutoload.MODE_ASSETS:
		var cfg: Dictionary = CursorControllerAutoload.MODE_ASSETS[mode]
		var path: String = cfg["path"]
		assert_bool(ResourceLoader.exists(path)).is_true()
		assert_bool(load(path) is Texture2D).is_true()

func test_default_cursor_sprite_loads() -> void:
	var tex := load("res://assets/cursors/cursor_default.png")
	assert_bool(tex is Texture2D).is_true()
