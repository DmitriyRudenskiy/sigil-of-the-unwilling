# InfoPanel: две колонки кнопок в columns (по 5), красный фон + золотая рамка,
# миникарта — первая панель сайдбара. Структуру менять нельзя (манифест 2026-09-11).
extends BaseTest

const _Scene := preload("res://scenes/ui/info_panel.tscn")
const _Adventure := preload("res://scenes/ui/adventure_ui.tscn")
var _panel: Node = null
var _ui: Node = null

func after_test() -> void:
	for n in [_panel, _ui]:
		if n != null and is_instance_valid(n):
			n.free()
	_panel = null
	_ui = null

func test_button_columns_layout_and_style() -> void:
	_panel = _Scene.instantiate()
	get_tree().root.add_child(_panel)
	await get_tree().process_frame
	var left: Control = _panel.get_node_or_null("columns/btn_col_left")
	var right: Control = _panel.get_node_or_null("columns/btn_col_right")
	assert_that(left).is_not_null()
	assert_that(right).is_not_null()
	assert_int(left.get_child_count()).is_equal(5)
	assert_int(right.get_child_count()).is_equal(5)
	var end_turn: Button = right.get_node_or_null("EndTurnButton")
	assert_that(end_turn).is_not_null()
	# Красный фон и золотая рамка.
	var sb: StyleBox = end_turn.get_theme_stylebox("normal")
	assert_that(sb).is_not_null()
	if sb is StyleBoxFlat:
		var f: StyleBoxFlat = sb as StyleBoxFlat
		assert_float(f.bg_color.r).is_equal_approx(0.52, 0.001)
		assert_float(f.border_color.r).is_equal_approx(0.788235, 0.001)

func test_minimap_is_first_sidebar_panel() -> void:
	_ui = _Adventure.instantiate()
	get_tree().root.add_child(_ui)
	await get_tree().process_frame
	var box: VBoxContainer = _ui.get_node_or_null("RightColumn/Box/PanelsBox")
	assert_that(box).is_not_null()
	assert_str(box.get_child(0).name).is_equal("MinimapPanel")
	assert_str(box.get_child(1).name).is_equal("InfoPanel")
