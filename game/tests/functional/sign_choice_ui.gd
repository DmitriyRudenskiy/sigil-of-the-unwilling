extends BaseTest

## T-002: экран выбора Знака — 8 кнопок (по одной на Знак каталога), id кнопок
## Sign_<id>; клик-поведение (pending_sign_id + переход) — MCP e2e (test_sign_choice).


func test_scene_has_eight_sign_buttons():
	var scene: PackedScene = load("res://scenes/ui/sign_choice.tscn")
	assert_bool(scene != null).is_true()
	var ui = make_node(scene)
	var root: VBoxContainer = ui.get_node("Overlay/Scroll/Root")
	var count := 0
	for id in Signs.ids():
		var btn = root.get_node_or_null("Sign_%s" % id)
		assert_bool(btn is Button).is_true()
		count += 1
	assert_int(count).is_equal(8)
	assert_bool(root.get_node_or_null("BackButton") is Button).is_true()
