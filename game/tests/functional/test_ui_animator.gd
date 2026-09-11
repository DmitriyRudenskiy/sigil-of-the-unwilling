extends BaseTest


var _buttons: Array[Node] = []

func after_test() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.free()
	_buttons.clear()

func _make_button() -> Button:
	var btn := Button.new()
	btn.size = Vector2(100, 32)
	add_child(btn)
	_buttons.append(btn)
	return btn

func test_setup_button_still_connects_each_signal() -> void:
	var btn := _make_button()
	UIAnimator.setup_button(btn)
	assert_that(btn.mouse_entered.get_connections().size()).is_equal(1)
	assert_that(btn.mouse_exited.get_connections().size()).is_equal(1)
	assert_that(btn.button_down.get_connections().size()).is_equal(1)
	assert_that(btn.button_up.get_connections().size()).is_equal(1)
	assert_that(btn.pivot_offset).is_equal(btn.size / 2.0)

func test_setup_button_twice_connects_each_signal_once() -> void:
	var btn := _make_button()
	UIAnimator.setup_button(btn)
	UIAnimator.setup_button(btn)
	assert_that(btn.mouse_entered.get_connections().size()).is_equal(1)
	assert_that(btn.mouse_exited.get_connections().size()).is_equal(1)
	assert_that(btn.button_down.get_connections().size()).is_equal(1)
	assert_that(btn.button_up.get_connections().size()).is_equal(1)
