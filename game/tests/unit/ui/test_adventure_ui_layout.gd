# TASK_22 (fix): сайдбар не «слетает»: пути панелей RightColumn/Box/PanelsBox/…,
# Box сам — ScrollContainer (вертикаль только), контент EXPAND_FILL по ширине
# (иначе VBox схлопывается в мин. ширину и тексты наезжают друг на друга),
# геометрия колонки = прототип (clamp 300..430, поля 14).
extends BaseTest

const _Scene := preload("res://scenes/ui/AdventureUI.tscn")
var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
		_ui = null

func test_sidebar_paths_and_order() -> void:
	_ui = _Scene.instantiate()
	get_tree().root.add_child(_ui)
	await get_tree().process_frame
	var box: VBoxContainer = _ui.get_node_or_null("RightColumn/Box/PanelsBox")
	assert_that(box).is_not_null()
	var names: Array[String] = []
	for c in box.get_children():
		names.append(c.name)
	assert_str(names[0]).is_equal("InfoPanel")
	assert_str(names[1]).is_equal("MinimapPanel")
	assert_bool(names.has("SkillsPanel")).is_true()
	assert_bool(names.has("HeroStatusPanel")).is_true()
	assert_bool(names.has("GloryBox")).is_true()

func test_sidebar_geometry_matches_prototype() -> void:
	_ui = _Scene.instantiate()
	get_tree().root.add_child(_ui)
	await get_tree().process_frame
	var col: Control = _ui.get_node("RightColumn")
	var vp := get_viewport().get_visible_rect().size.x
	var expect_w := UILayout.sidebar_width(vp) + UILayout.FRAME_GAP - UILayout.FRAME_PADDING
	assert_float(col.size.x).is_equal_approx(expect_w, 1.0)
	assert_float(col.global_position.y).is_equal(UILayout.FRAME_PADDING)
	# Колонка видима и прижата к правому краю.
	assert_bool(col.visible).is_true()
	assert_float(col.global_position.x + col.size.x).is_equal_approx(vp - UILayout.FRAME_PADDING, 1.0)

func test_scroll_vertical_only_and_content_expands() -> void:
	_ui = _Scene.instantiate()
	get_tree().root.add_child(_ui)
	await get_tree().process_frame
	var scroll: ScrollContainer = _ui.get_node("RightColumn/Box")
	assert_int(scroll.horizontal_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
	assert_int(scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)
	var box: Control = _ui.get_node("RightColumn/Box/PanelsBox")
	assert_int(box.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)
	# Контент шире нуля и не шире колонки (не схлопнулся).
	assert_bool(box.size.x > 100.0).is_true()
	assert_bool(box.size.x <= scroll.size.x + 1.0).is_true()
