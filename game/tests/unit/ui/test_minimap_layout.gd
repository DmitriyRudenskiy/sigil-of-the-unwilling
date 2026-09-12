extends BaseTest
## Геометрия миникарты = prototype_map.html: поля 24/32, рамка 3, карта 4:3,
## компас n/s ±2, w/e ±9, сайдбар clamp(300, 25vw, 430).

func _make_panel() -> MinimapPanel:
	var p: MinimapPanel = auto_free(load("res://scenes/ui/MinimapPanel.tscn").instantiate())
	add_child(p)
	return p

func test_sidebar_width_clamp() -> void:
	assert_float(UILayout.sidebar_width(1000.0)).is_equal(300.0)
	assert_float(UILayout.sidebar_width(1280.0)).is_equal(320.0)
	assert_float(UILayout.sidebar_width(1920.0)).is_equal(430.0)

func test_map_is_4_3_inside_padding() -> void:
	var p := _make_panel()
	p.size = Vector2(430.0, 200.0)
	await get_tree().process_frame
	var box: Control = p.get_node("MapBox")
	var expect_w := 430.0 - 2.0 * (UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H)
	assert_float(box.position.x).is_equal(UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_H)
	assert_float(box.position.y).is_equal(UILayout.MINIMAP_BORDER + UILayout.MINIMAP_PAD_V)
	assert_float(box.size.x).is_equal_approx(expect_w, 0.51)
	assert_float(box.size.y).is_equal_approx(expect_w / UILayout.MINIMAP_ASPECT, 0.51)
	# cmin.y задаётся один раз в _ready из ширины viewport (см. шапку MinimapPanel.gd).
	var vp_w := p.get_viewport().get_visible_rect().size.x
	assert_float(p.custom_minimum_size.y).is_equal_approx(
		UILayout.minimap_panel_height(UILayout.sidebar_width(vp_w) - MinimapPanel.COLUMN_INSET), 0.51)

func test_compass_centers_match_prototype() -> void:
	# Кнопки центрируются в номинальных CSS-коробках (24x22): Godot Button с font 17
	# имеет мин. высоту ~32px, поэтому проверяем центры, а не края.
	var p := _make_panel()
	p.size = Vector2(430.0, 200.0)
	await get_tree().process_frame
	var panel_h := UILayout.minimap_panel_height(430.0)
	var cb := UILayout.COMPASS_BTN
	var n: Control = p.get_node("N")
	var s: Control = p.get_node("S")
	var w: Control = p.get_node("W")
	var e: Control = p.get_node("E")
	var ncy := UILayout.MINIMAP_BORDER + UILayout.COMPASS_NS_INSET + cb.y * 0.5
	var scy := panel_h - UILayout.MINIMAP_BORDER - UILayout.COMPASS_NS_INSET - cb.y * 0.5
	var wcx := UILayout.MINIMAP_BORDER + UILayout.COMPASS_WE_INSET + cb.x * 0.5
	var ecx := 430.0 - UILayout.MINIMAP_BORDER - UILayout.COMPASS_WE_INSET - cb.x * 0.5
	assert_float(n.position.y + n.size.y * 0.5).is_equal_approx(ncy, 0.51)
	assert_float(s.position.y + s.size.y * 0.5).is_equal_approx(scy, 0.51)
	assert_float(w.position.x + w.size.x * 0.5).is_equal_approx(wcx, 0.51)
	assert_float(e.position.x + e.size.x * 0.5).is_equal_approx(ecx, 0.51)
	assert_float(n.position.x + n.size.x * 0.5).is_equal_approx(215.0, 0.51)
	assert_float(w.position.y + w.size.y * 0.5).is_equal_approx(panel_h * 0.5, 0.51)
