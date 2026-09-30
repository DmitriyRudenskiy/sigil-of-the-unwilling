class_name WorldCamera
extends Camera2D

const CAM_SPEED := GameNumbers.CAMERA_SPEED
const EDGE := GameNumbers.CAMERA_EDGE_ZONE
const ZOOM_TWEEN_DURATION := GameNumbers.CAMERA_ZOOM_TWEEN_SEC

var _map_rect: Rect2 = Rect2(0, 0, 10000, 10000)
var _tween: Tween = null
var _settings: Node = null

func setup(settings: Node) -> void:
	_settings = settings

func _get_settings() -> Node:
	return _settings

func _ready() -> void:
	position_smoothing_enabled = true
	if _settings:
		_set_zoom(_settings.get_zoom())

func step_zoom(direction: int) -> void:
	var s := _get_settings()
	if s == null:
		return
	if s.step_zoom(direction) != 0:
		_animate_zoom(s.get_zoom())

func _unhandled_input(event: InputEvent) -> void:
	if _settings == null:
		return
	var s = _settings
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			var delta: int = s.step_zoom(1)
			if delta > 0:
				_animate_zoom(s.get_zoom())
				get_viewport().set_input_as_handled()
				return
		if event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			var delta: int = s.step_zoom(-1)
			if delta < 0:
				_animate_zoom(s.get_zoom())
				get_viewport().set_input_as_handled()
				return

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
		position += mv.normalized() * CAM_SPEED * delta / zoom.x

	_clamp_position()

func set_zoom_level(value: float) -> void:
	_animate_zoom(value)

func _set_zoom(value: float) -> void:
	zoom = Vector2(value, value)
	_clamp_position()

func _animate_zoom(value: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "zoom:x", value, ZOOM_TWEEN_DURATION)
	_tween.tween_property(self, "zoom:y", value, ZOOM_TWEEN_DURATION)
	_tween.tween_callback(func(): _clamp_position())

func set_map_rect(rect: Rect2) -> void:
	_map_rect = rect
	_clamp_position()

func _clamp_position() -> void:
	var vp := get_viewport()
	var vs := vp.get_visible_rect().size
	var half := Vector2(vs.x, vs.y) / (2.0 * zoom.x)

	var cx := _clamp_val(position.x, _map_rect.position.x + half.x, _map_rect.end.x - half.x)
	var cy := _clamp_val(position.y, _map_rect.position.y + half.y, _map_rect.end.y - half.y)

	position.x = cx
	position.y = cy

static func _clamp_val(v: float, mn: float, mx: float) -> float:
	if mn > mx:
		return (mn + mx) / 2.0
	return clampf(v, mn, mx)

func center_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_position()

func follow(node: Node2D) -> void:
	if node != null:
		position = node.position
		_clamp_position()
