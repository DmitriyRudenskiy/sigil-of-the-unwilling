class_name WorldCamera
extends Camera2D
## Камера мира: движение, edge scroll, zoom, следование.

const CAM_SPEED := 600.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.0
const EDGE := 20

var _zoom_level: float = 1.0


func _ready() -> void:
	position_smoothing_enabled = true


func _process(delta: float) -> void:
	var mv := Vector2.ZERO

	if Input.is_action_pressed("camera_left"):
		mv.x -= 1
	if Input.is_action_pressed("camera_right"):
		mv.x += 1
	if Input.is_action_pressed("camera_up"):
		mv.y -= 1
	if Input.is_action_pressed("camera_down"):
		mv.y += 1

	var vp := get_viewport()
	var over_ui := false
	if vp.has_method("gui_get_hovered_control"):
		over_ui = vp.gui_get_hovered_control() != null

	if not over_ui:
		var mp := vp.get_mouse_position()
		var vs := vp.get_visible_rect().size

		if mp.x < EDGE:
			mv.x -= 1
		elif mp.x > vs.x - EDGE:
			mv.x += 1
		if mp.y < EDGE:
			mv.y -= 1
		elif mp.y > vs.y - EDGE:
			mv.y += 1

	if mv != Vector2.ZERO:
		position += mv.normalized() * CAM_SPEED * delta / _zoom_level


func apply_zoom(delta: float) -> void:
	_zoom_level = clampf(_zoom_level + delta, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(_zoom_level, _zoom_level)


func center_on(world_pos: Vector2) -> void:
	position = world_pos


func follow(node: Node2D) -> void:
	if node != null:
		position = node.position
