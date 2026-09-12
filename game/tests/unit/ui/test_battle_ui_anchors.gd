extends BaseTest
## Регрессия: anchors_preset — только метаданные редактора.
## В рантайме важны свойства anchor_*: bottom_bar должен быть во всю ширину снизу.
const _Scene := preload("res://scenes/ui/BattleUI.tscn")
var _ui: Node = null

func after_test() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.free()
		_ui = null

func test_bottom_bar_spans_full_width_at_bottom() -> void:
	_ui = _Scene.instantiate()
	get_tree().root.add_child(_ui)
	await get_tree().process_frame
	var bar: Control = _ui.get_node("bottom_bar")
	var vp := get_viewport().get_visible_rect().size
	assert_float(bar.anchor_top).is_equal(1.0)
	assert_float(bar.anchor_bottom).is_equal(1.0)
	assert_float(bar.anchor_right).is_equal(1.0)
	assert_float(bar.size.x).is_equal_approx(vp.x, 1.0)
	assert_float(bar.global_position.y + bar.size.y).is_equal_approx(vp.y, 1.0)
