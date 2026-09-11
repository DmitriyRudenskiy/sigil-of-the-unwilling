extends GdUnitTestSuite
## WorldInput: click / right-click / wheel handling and overlay guards.

class _StubHero extends HeroController:
	var clicked: Array = []
	var cancels := 0

	func on_map_clicked(cell: Vector2i) -> void:
		clicked.append(cell)

	func cancel_planned_path() -> void:
		cancels += 1


class _StubMap extends MapGenerator:
	var valid := true
	var to_map_result := Vector2i(3, 4)

	func has_valid_tilemap() -> bool:
		return valid

	func local_to_map(_pos: Vector2) -> Vector2i:
		return to_map_result


class _StubCamera extends WorldCamera:
	var zoom_delta := 0

	func step_zoom(dir: int) -> void:
		zoom_delta += dir


class _StubWorld extends Node:
	var terminal_ := false
	var death_open_ := false

	func is_terminal() -> bool:
		return terminal_

	func is_death_sequence_open() -> bool:
		return death_open_


var _input: WorldInput
var _hero: _StubHero
var _map: _StubMap
var _camera: _StubCamera
var _world: _StubWorld

func before_test() -> void:
	_hero = _StubHero.new()
	_map = _StubMap.new()
	_map.map_width = 10
	_map.map_height = 10
	_camera = _StubCamera.new()
	_world = _StubWorld.new()
	_input = WorldInput.new()
	_input.map = _map
	_input.hero = _hero
	_input.camera = _camera
	_input.world = _world
	add_child(_input)


func after_test() -> void:
	for n in [_input, _hero, _map, _camera, _world]:
		if n != null and is_instance_valid(n):
			n.free()
	_input = null
	_hero = null
	_map = null
	_camera = null
	_world = null


func _mouse(btn: int, pressed: bool = true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = pressed
	return e


func test_wheel_zooms() -> void:
	_input._unhandled_input(_mouse(MOUSE_BUTTON_WHEEL_UP))
	_input._unhandled_input(_mouse(MOUSE_BUTTON_WHEEL_UP))
	_input._unhandled_input(_mouse(MOUSE_BUTTON_WHEEL_DOWN))
	assert_that(_camera.zoom_delta).is_equal(1)


func test_right_click_cancels_path() -> void:
	_input._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	assert_that(_hero.cancels).is_equal(1)


func test_left_click_in_bounds_reaches_hero() -> void:
	_input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	assert_that(_hero.clicked.size()).is_equal(1)
	assert_that(_hero.clicked[0]).is_equal(Vector2i(3, 4))


func test_left_click_out_of_bounds_ignored() -> void:
	_map.to_map_result = Vector2i(99, 99)
	_input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	assert_that(_hero.clicked.size()).is_equal(0)


func test_left_click_without_tilemap_ignored() -> void:
	_map.valid = false
	_input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	assert_that(_hero.clicked.size()).is_equal(0)


func test_input_ignored_when_terminal() -> void:
	_world.terminal_ = true
	_input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	_input._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	assert_that(_hero.clicked.size()).is_equal(0)
	assert_that(_hero.cancels).is_equal(0)


func test_input_ignored_when_death_sequence_open() -> void:
	_world.death_open_ = true
	_input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	assert_that(_hero.clicked.size()).is_equal(0)


func test_released_button_ignored() -> void:
	_input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	assert_that(_hero.clicked.size()).is_equal(0)
