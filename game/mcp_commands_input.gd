class_name McpCommandsInput
extends McpCommandsBase

func _init(s: Node) -> void:
	server = s
	_init_key_map()

var _key_map: Dictionary
var _held_keys: Dictionary = {}

func get_commands() -> Dictionary:
	return {
		"click": _cmd_click,
		"key_press": _cmd_key_press,
		"key_hold": _cmd_key_hold,
		"key_release": _cmd_key_release,
		"mouse_move": _cmd_mouse_move,
		"mouse_drag": _cmd_mouse_drag,
		"scroll": _cmd_scroll,
		"gamepad": _cmd_gamepad,
		"touch": _cmd_touch,
		"input_state": _cmd_input_state,
		"input_action": _cmd_input_action,
	}

func _cmd_click(params: Dictionary) -> void:
	if not _require_scene_tree():
		return
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var button: int = int(params.get("button", MOUSE_BUTTON_LEFT))

	var pos: Vector2 = Vector2(x, y)

	# Mouse button press
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.position = pos
	press_event.global_position = pos
	press_event.button_index = button as MouseButton
	press_event.pressed = true
	Input.parse_input_event(press_event)

	# Wait a frame then release
	await server.get_tree().process_frame

	var release_event: InputEventMouseButton = InputEventMouseButton.new()
	release_event.position = pos
	release_event.global_position = pos
	release_event.button_index = button as MouseButton
	release_event.pressed = false
	Input.parse_input_event(release_event)

	server._send_response({"success": true, "clicked": {"x": x, "y": y, "button": button}})


# --- Key Press ---


func _cmd_key_press(params: Dictionary) -> void:
	if not _require_scene_tree():
		return
	var action: String = params.get("action", "")
	var key: String = params.get("key", "")
	var pressed: bool = params.get("pressed", true)

	if action.length() > 0:
		# Simulate an action press/release
		if pressed:
			Input.action_press(action)
		else:
			Input.action_release(action)
		server._send_response({"success": true, "action": action, "pressed": pressed})
		return

	if key.length() > 0:
		var keycode: int = _string_to_keycode(key)
		if keycode == KEY_NONE:
			server._send_response({"error": "Unknown key: %s" % key})
			return

		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode as Key
		event.physical_keycode = keycode as Key
		event.pressed = pressed
		Input.parse_input_event(event)

		if pressed:
			# Auto-release after a frame
			await server.get_tree().process_frame
			var release_event: InputEventKey = InputEventKey.new()
			release_event.keycode = keycode as Key
			release_event.physical_keycode = keycode as Key
			release_event.pressed = false
			Input.parse_input_event(release_event)

		server._send_response({"success": true, "key": key, "pressed": pressed})
		return

	server._send_response({"error": "Must provide 'key' or 'action' parameter"})


# --- Mouse Move ---


func _cmd_key_hold(params: Dictionary) -> void:
	var action: String = params.get("action", "")
	var key: String = params.get("key", "")

	if action.length() > 0:
		Input.action_press(action)
		_held_keys["action:" + action] = true
		server._send_response({"success": true, "held": action, "type": "action"})
		return

	if key.length() > 0:
		var keycode: int = _string_to_keycode(key)
		if keycode == KEY_NONE:
			server._send_response({"error": "Unknown key: %s" % key})
			return
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode as Key
		event.physical_keycode = keycode as Key
		event.pressed = true
		Input.parse_input_event(event)
		_held_keys["key:" + key.to_upper()] = keycode
		server._send_response({"success": true, "held": key, "type": "key"})
		return

	server._send_response({"error": "Must provide 'key' or 'action' parameter"})


# --- Key Release ---


func _cmd_key_release(params: Dictionary) -> void:
	var action: String = params.get("action", "")
	var key: String = params.get("key", "")

	if action.length() > 0:
		Input.action_release(action)
		_held_keys.erase("action:" + action)
		server._send_response({"success": true, "released": action, "type": "action"})
		return

	if key.length() > 0:
		var keycode: int = _string_to_keycode(key)
		if keycode == KEY_NONE:
			server._send_response({"error": "Unknown key: %s" % key})
			return
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode as Key
		event.physical_keycode = keycode as Key
		event.pressed = false
		Input.parse_input_event(event)
		_held_keys.erase("key:" + key.to_upper())
		server._send_response({"success": true, "released": key, "type": "key"})
		return

	server._send_response({"error": "Must provide 'key' or 'action' parameter"})


# --- Scroll ---


func _cmd_mouse_move(params: Dictionary) -> void:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var relative_x: float = float(params.get("relative_x", 0))
	var relative_y: float = float(params.get("relative_y", 0))

	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = Vector2(x, y)
	event.global_position = Vector2(x, y)
	event.relative = Vector2(relative_x, relative_y)
	Input.parse_input_event(event)

	server._send_response({"success": true, "position": {"x": x, "y": y}})


# --- Get UI Elements ---


func _cmd_mouse_drag(params: Dictionary) -> void:
	var from_x: float = float(params.get("from_x", 0))
	var from_y: float = float(params.get("from_y", 0))
	var to_x: float = float(params.get("to_x", 0))
	var to_y: float = float(params.get("to_y", 0))
	var button: int = int(params.get("button", MOUSE_BUTTON_LEFT))
	var steps: int = int(params.get("steps", 10))
	if steps < 1:
		steps = 1

	var from_pos: Vector2 = Vector2(from_x, from_y)
	var to_pos: Vector2 = Vector2(to_x, to_y)

	# Press at start position
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.position = from_pos
	press_event.global_position = from_pos
	press_event.button_index = button as MouseButton
	press_event.pressed = true
	Input.parse_input_event(press_event)

	# Lerp position over steps frames
	for i in steps:
		await server.get_tree().process_frame
		var t: float = float(i + 1) / float(steps)
		var current_pos: Vector2 = from_pos.lerp(to_pos, t)
		var move_event: InputEventMouseMotion = InputEventMouseMotion.new()
		move_event.position = current_pos
		move_event.global_position = current_pos
		move_event.relative = (to_pos - from_pos) / float(steps)
		move_event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
		Input.parse_input_event(move_event)

	# Release at end position
	var release_event: InputEventMouseButton = InputEventMouseButton.new()
	release_event.position = to_pos
	release_event.global_position = to_pos
	release_event.button_index = button as MouseButton
	release_event.pressed = false
	Input.parse_input_event(release_event)

	server._send_response({"success": true, "from": {"x": from_x, "y": from_y}, "to": {"x": to_x, "y": to_y}, "steps": steps})


# --- Gamepad ---


func _cmd_scroll(params: Dictionary) -> void:
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var direction: String = params.get("direction", "up")
	var amount: int = int(params.get("amount", 1))

	var button_index: int = MOUSE_BUTTON_WHEEL_UP
	match direction:
		"down":
			button_index = MOUSE_BUTTON_WHEEL_DOWN
		"left":
			button_index = MOUSE_BUTTON_WHEEL_LEFT
		"right":
			button_index = MOUSE_BUTTON_WHEEL_RIGHT

	for i in amount:
		var press_event: InputEventMouseButton = InputEventMouseButton.new()
		press_event.position = Vector2(x, y)
		press_event.global_position = Vector2(x, y)
		press_event.button_index = button_index as MouseButton
		press_event.pressed = true
		press_event.factor = 1.0
		Input.parse_input_event(press_event)

		var release_event: InputEventMouseButton = InputEventMouseButton.new()
		release_event.position = Vector2(x, y)
		release_event.global_position = Vector2(x, y)
		release_event.button_index = button_index as MouseButton
		release_event.pressed = false
		Input.parse_input_event(release_event)

	server._send_response({"success": true, "direction": direction, "amount": amount, "position": {"x": x, "y": y}})


# --- Mouse Drag ---


func _cmd_gamepad(params: Dictionary) -> void:
	var input_type: String = params.get("type", "button")
	var index: int = int(params.get("index", 0))
	var value: float = float(params.get("value", 0))
	var device: int = int(params.get("device", 0))

	if input_type == "button":
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = device
		event.button_index = index as JoyButton
		event.pressed = value > 0.5
		event.pressure = value
		Input.parse_input_event(event)
		server._send_response({"success": true, "type": "button", "index": index, "pressed": event.pressed, "device": device})
	elif input_type == "axis":
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.device = device
		event.axis = index as JoyAxis
		event.axis_value = value
		Input.parse_input_event(event)
		server._send_response({"success": true, "type": "axis", "index": index, "value": value, "device": device})
	else:
		server._send_response({"error": "Invalid type: %s. Use 'button' or 'axis'" % input_type})


# --- Get Camera ---


func _cmd_touch(params: Dictionary) -> void:
	var action: String = params.get("action", "press")
	var x: float = float(params.get("x", 0))
	var y: float = float(params.get("y", 0))
	var idx: int = int(params.get("index", 0))
	match action:
		"press":
			var ev: InputEventScreenTouch = InputEventScreenTouch.new()
			ev.index = idx
			ev.position = Vector2(x, y)
			ev.pressed = true
			Input.parse_input_event(ev)
			await server.get_tree().process_frame
			server._send_response({"success": true, "action": "press", "x": x, "y": y})
		"release":
			var ev: InputEventScreenTouch = InputEventScreenTouch.new()
			ev.index = idx
			ev.position = Vector2(x, y)
			ev.pressed = false
			Input.parse_input_event(ev)
			await server.get_tree().process_frame
			server._send_response({"success": true, "action": "release", "x": x, "y": y})
		"drag":
			var to_x: float = float(params.get("to_x", x))
			var to_y: float = float(params.get("to_y", y))
			var steps: int = int(params.get("steps", 10))
			var press_ev: InputEventScreenTouch = InputEventScreenTouch.new()
			press_ev.index = idx
			press_ev.position = Vector2(x, y)
			press_ev.pressed = true
			Input.parse_input_event(press_ev)
			for i in range(steps):
				var t: float = float(i + 1) / float(steps)
				var drag_ev: InputEventScreenDrag = InputEventScreenDrag.new()
				drag_ev.index = idx
				drag_ev.position = Vector2(lerp(x, to_x, t), lerp(y, to_y, t))
				Input.parse_input_event(drag_ev)
				await server.get_tree().process_frame
			var rel_ev: InputEventScreenTouch = InputEventScreenTouch.new()
			rel_ev.index = idx
			rel_ev.position = Vector2(to_x, to_y)
			rel_ev.pressed = false
			Input.parse_input_event(rel_ev)
			await server.get_tree().process_frame
			server._send_response({"success": true, "action": "drag", "from": {"x": x, "y": y}, "to": {"x": to_x, "y": to_y}})
		_:
			server._send_response({"error": "Unknown touch action: %s" % action})


func _cmd_input_state(params: Dictionary) -> void:
	var action: String = params.get("action", "query")
	match action:
		"query":
			var mouse_pos: Vector2 = server.get_viewport().get_mouse_position()
			var joypads: Array = Input.get_connected_joypads()
			server._send_response({"success": true, "mouse_position": {"x": mouse_pos.x, "y": mouse_pos.y}, "connected_joypads": joypads.size()})
		"warp_mouse":
			var pos: Vector2 = Vector2(float(params.get("x", 0)), float(params.get("y", 0)))
			Input.warp_mouse(pos)
			server._send_response({"success": true, "action": "warp_mouse", "position": {"x": pos.x, "y": pos.y}})
		"set_mouse_mode":
			var mode_str: String = params.get("mouse_mode", "visible")
			var mode_val: int = Input.MOUSE_MODE_VISIBLE
			match mode_str:
				"hidden": mode_val = Input.MOUSE_MODE_HIDDEN
				"captured": mode_val = Input.MOUSE_MODE_CAPTURED
				"confined": mode_val = Input.MOUSE_MODE_CONFINED
			Input.mouse_mode = mode_val
			server._send_response({"success": true, "action": "set_mouse_mode", "mode": mode_str})
		_:
			server._send_response({"error": "Unknown input_state action: %s" % action})


func _cmd_input_action(params: Dictionary) -> void:
	var action: String = params.get("action", "")
	match action:
		"set_strength":
			var action_name: String = params.get("action_name", "")
			var strength: float = float(params.get("strength", 1.0))
			Input.action_press(action_name, strength)
			server._send_response({"success": true, "action": "set_strength", "action_name": action_name, "strength": strength})
		"add_action":
			var action_name: String = params.get("action_name", "")
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			if params.has("key"):
				var ev: InputEventKey = InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(params["key"])
				InputMap.action_add_event(action_name, ev)
			server._send_response({"success": true, "action": "add_action", "action_name": action_name})
		"remove_action":
			var action_name: String = params.get("action_name", "")
			if InputMap.has_action(action_name):
				InputMap.erase_action(action_name)
			server._send_response({"success": true, "action": "remove_action", "action_name": action_name})
		"list":
			var actions: Array = InputMap.get_actions()
			server._send_response({"success": true, "actions": actions})
		_:
			server._send_response({"error": "Unknown input_action action: %s" % action})


func _init_key_map() -> void:
	_key_map = {
		"A": KEY_A, "B": KEY_B, "C": KEY_C, "D": KEY_D,
		"E": KEY_E, "F": KEY_F, "G": KEY_G, "H": KEY_H,
		"I": KEY_I, "J": KEY_J, "K": KEY_K, "L": KEY_L,
		"M": KEY_M, "N": KEY_N, "O": KEY_O, "P": KEY_P,
		"Q": KEY_Q, "R": KEY_R, "S": KEY_S, "T": KEY_T,
		"U": KEY_U, "V": KEY_V, "W": KEY_W, "X": KEY_X,
		"Y": KEY_Y, "Z": KEY_Z,
		"0": KEY_0, "1": KEY_1, "2": KEY_2, "3": KEY_3,
		"4": KEY_4, "5": KEY_5, "6": KEY_6, "7": KEY_7,
		"8": KEY_8, "9": KEY_9,
		"SPACE": KEY_SPACE, "ENTER": KEY_ENTER, "RETURN": KEY_ENTER,
		"ESCAPE": KEY_ESCAPE, "ESC": KEY_ESCAPE,
		"TAB": KEY_TAB, "BACKSPACE": KEY_BACKSPACE,
		"DELETE": KEY_DELETE, "INSERT": KEY_INSERT,
		"HOME": KEY_HOME, "END": KEY_END,
		"PAGEUP": KEY_PAGEUP, "PAGE_UP": KEY_PAGEUP,
		"PAGEDOWN": KEY_PAGEDOWN, "PAGE_DOWN": KEY_PAGEDOWN,
		"UP": KEY_UP, "DOWN": KEY_DOWN, "LEFT": KEY_LEFT, "RIGHT": KEY_RIGHT,
		"SHIFT": KEY_SHIFT, "CTRL": KEY_CTRL, "CONTROL": KEY_CTRL,
		"ALT": KEY_ALT, "CAPSLOCK": KEY_CAPSLOCK, "CAPS_LOCK": KEY_CAPSLOCK,
		"F1": KEY_F1, "F2": KEY_F2, "F3": KEY_F3, "F4": KEY_F4,
		"F5": KEY_F5, "F6": KEY_F6, "F7": KEY_F7, "F8": KEY_F8,
		"F9": KEY_F9, "F10": KEY_F10, "F11": KEY_F11, "F12": KEY_F12,
	}


func _string_to_keycode(key_str: String) -> int:
	var upper: String = key_str.to_upper()
	if _key_map.has(upper):
		return _key_map[upper]
	if key_str.length() == 1:
		return key_str.unicode_at(0)
	return KEY_NONE


# --- Eval: Execute arbitrary GDScript at runtime ---
