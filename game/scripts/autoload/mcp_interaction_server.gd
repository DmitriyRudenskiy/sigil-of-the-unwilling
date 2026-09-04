extends Node

# MCP Interaction Server - TCP server for game interaction
# Runs as an autoload inside the Godot game, accepting JSON commands over TCP.
# No class_name to avoid autoload conflict.

var _server: TCPServer
var _client: StreamPeerTCP
var _buffer: String = ""
var _busy: bool = false
var _busy_since: float = 0.0
var _current_id: Variant = null
const PORT: int = 9090
const BUSY_TIMEOUT: float = 120.0
# Аудит #5: доменные command-модули (здесь остаются только транспорт и роутинг).
var _m_input: McpInputModule = McpInputModule.new()
var _m_nodes: McpNodeModule = McpNodeModule.new()
var _m_audio: McpAudioModule = McpAudioModule.new()
var _m_anim: McpAnimModule = McpAnimModule.new()
var _m_3d: Mcp3dModule = Mcp3dModule.new()
var _m_2d: Mcp2dModule = Mcp2dModule.new()
var _m_ui: McpUiModule = McpUiModule.new()
var _m_world: McpWorldModule = McpWorldModule.new()

func _ready() -> void:
	# Слушаем всегда (дизайн godot-mcp): автозагрузка опциональна — сервер
	# появляется только после установки godot-mcp, бинд на loopback:9090.
	# Управляющий Node-сервер сам поднимает игру через run_project (godot -d
	# --path <proj>), без флагов — поэтому флаг-гейт здесь не ставим.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Аудит #5: модули — дети сервера (get_tree() доступен), server-референс для ответов.
	for mod in [_m_input, _m_nodes, _m_audio, _m_anim, _m_3d, _m_2d, _m_ui, _m_world]:
		mod.server = self
		add_child(mod)
	_server = TCPServer.new()
	var err: int = _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [PORT, err])
		return
	print("McpInteractionServer: Listening on 127.0.0.1:%d" % PORT)


func _process(_delta: float) -> void:
	if _server == null:
		return

	# Safety timeout: force-reset _busy if it's been stuck too long
	if _busy and _busy_since > 0.0:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _busy_since
		if elapsed > BUSY_TIMEOUT:
			push_warning("McpInteractionServer: _busy flag stuck for %.1fs, force-resetting" % elapsed)
			_busy = false
			_busy_since = 0.0
			_current_id = null

	# Accept new connections
	if _server.is_connection_available():
		var new_client: StreamPeerTCP = _server.take_connection()
		if new_client != null:
			if _client != null:
				_client.disconnect_from_host()
			_client = new_client
			_buffer = ""
			print("McpInteractionServer: Client connected")

	# Read data from client
	if _client == null:
		return

	_client.poll()
	var status: int = _client.get_status()
	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		print("McpInteractionServer: Client disconnected")
		_client = null
		_buffer = ""
		_busy = false
		_busy_since = 0.0
		_current_id = null
		return

	if status != StreamPeerTCP.STATUS_CONNECTED:
		return

	var available: int = _client.get_available_bytes()
	if available > 0:
		var data: Array = _client.get_data(available)
		if data[0] == OK:
			var bytes: PackedByteArray = data[1]
			_buffer += bytes.get_string_from_utf8()

			# Process complete lines (newline-delimited JSON)
			while _buffer.find("\n") >= 0:
				var newline_pos: int = _buffer.find("\n")
				var line: String = _buffer.substr(0, newline_pos).strip_edges()
				_buffer = _buffer.substr(newline_pos + 1)
				if line.length() > 0:
					_handle_command(line)


func _handle_command(json_str: String) -> void:
	var json: JSON = JSON.new()
	var parse_err: int = json.parse(json_str)
	if parse_err != OK:
		_send_response_raw({"error": "Invalid JSON: %s" % json.get_error_message()})
		return

	var data: Variant = json.data
	if not data is Dictionary:
		_send_response_raw({"error": "Expected JSON object"})
		return

	var req_id: Variant = data.get("id", null)

	if _busy:
		_send_response_raw({"error": "Server busy processing another command. Try again.", "id": req_id})
		return
	_busy = true
	_busy_since = Time.get_ticks_msec() / 1000.0
	_current_id = req_id

	var command: String = data.get("command", "")
	var params: Dictionary = data.get("params", {})

	match command:
		# Async commands (use await)
		"screenshot":
			await _m_nodes._cmd_screenshot()
		"click":
			await _m_input._cmd_click(params)
		"key_press":
			await _m_input._cmd_key_press(params)
		"eval":
			await _m_nodes._cmd_eval(params)
		"wait":
			await _m_nodes._cmd_wait(params)
		# Sync commands
		"mouse_move":
			_m_input._cmd_mouse_move(params)
		"get_ui_elements":
			_m_nodes._cmd_get_ui_elements()
		"get_scene_tree":
			_m_nodes._cmd_get_scene_tree()
		"get_property":
			_m_nodes._cmd_get_property(params)
		"set_property":
			_m_nodes._cmd_set_property(params)
		"call_method":
			_m_nodes._cmd_call_method(params)
		"get_node_info":
			_m_nodes._cmd_get_node_info(params)
		"instantiate_scene":
			_m_nodes._cmd_instantiate_scene(params)
		"remove_node":
			_m_nodes._cmd_remove_node(params)
		"change_scene":
			_m_nodes._cmd_change_scene(params)
		"pause":
			_m_nodes._cmd_pause(params)
		"get_performance":
			_m_nodes._cmd_get_performance(params)
		"connect_signal":
			_m_nodes._cmd_connect_signal(params)
		"disconnect_signal":
			_m_nodes._cmd_disconnect_signal(params)
		"emit_signal":
			_m_nodes._cmd_emit_signal(params)
		"play_animation":
			_m_anim._cmd_play_animation(params)
		"tween_property":
			_m_anim._cmd_tween_property(params)
		"get_nodes_in_group":
			_m_nodes._cmd_get_nodes_in_group(params)
		"find_nodes_by_class":
			_m_nodes._cmd_find_nodes_by_class(params)
		"reparent_node":
			_m_nodes._cmd_reparent_node(params)
		# Enhanced input commands
		"key_hold":
			_m_input._cmd_key_hold(params)
		"key_release":
			_m_input._cmd_key_release(params)
		"scroll":
			_m_input._cmd_scroll(params)
		"mouse_drag":
			await _m_input._cmd_mouse_drag(params)
		"gamepad":
			_m_input._cmd_gamepad(params)
		# Advanced runtime commands
		"get_camera":
			_m_3d._cmd_get_camera()
		"set_camera":
			_m_3d._cmd_set_camera(params)
		"raycast":
			await _m_3d._cmd_raycast(params)
		"get_audio":
			_m_audio._cmd_get_audio()
		"spawn_node":
			_m_nodes._cmd_spawn_node(params)
		"set_shader_param":
			_m_nodes._cmd_set_shader_param(params)
		"audio_play":
			_m_audio._cmd_audio_play(params)
		"audio_bus":
			_m_audio._cmd_audio_bus(params)
		"navigate_path":
			await _m_3d._cmd_navigate_path(params)
		"tilemap":
			_m_2d._cmd_tilemap(params)
		"add_collision":
			_m_2d._cmd_add_collision(params)
		"environment":
			_m_3d._cmd_environment(params)
		"manage_group":
			_m_nodes._cmd_manage_group(params)
		"create_timer":
			_m_nodes._cmd_create_timer(params)
		"set_particles":
			_m_world._cmd_set_particles(params)
		"create_animation":
			_m_anim._cmd_create_animation(params)
		"serialize_state":
			_m_world._cmd_serialize_state(params)
		"physics_body":
			_m_3d._cmd_physics_body(params)
		"create_joint":
			_m_3d._cmd_create_joint(params)
		"bone_pose":
			_m_3d._cmd_bone_pose(params)
		"ui_theme":
			_m_ui._cmd_ui_theme(params)
		"viewport":
			_m_ui._cmd_viewport(params)
		"debug_draw":
			_m_3d._cmd_debug_draw(params)
		# Batch 1: Networking + Input + System + Signals + Script
		"http_request":
			await _m_world._cmd_http_request(params)
		"websocket":
			_m_world._cmd_websocket(params)
		"multiplayer":
			_m_world._cmd_multiplayer(params)
		"rpc":
			_m_world._cmd_rpc(params)
		"touch":
			await _m_input._cmd_touch(params)
		"input_state":
			_m_input._cmd_input_state(params)
		"input_action":
			_m_input._cmd_input_action(params)
		"list_signals":
			_m_nodes._cmd_list_signals(params)
		"await_signal":
			await _m_nodes._cmd_await_signal(params)
		"script":
			_m_nodes._cmd_script(params)
		"window":
			_m_world._cmd_window(params)
		"os_info":
			_m_world._cmd_os_info()
		"time_scale":
			_m_world._cmd_time_scale(params)
		"process_mode":
			_m_world._cmd_process_mode(params)
		"world_settings":
			_m_world._cmd_world_settings(params)
		# Batch 2: 3D Rendering + Lighting + Sky + Physics
		"csg":
			_m_3d._cmd_csg(params)
		"multimesh":
			_m_3d._cmd_multimesh(params)
		"procedural_mesh":
			_m_3d._cmd_procedural_mesh(params)
		"light_3d":
			_m_3d._cmd_light_3d(params)
		"mesh_instance":
			_m_3d._cmd_mesh_instance(params)
		"gridmap":
			_m_3d._cmd_gridmap(params)
		"3d_effects":
			_m_3d._cmd_3d_effects(params)
		"gi":
			_m_3d._cmd_gi(params)
		"path_3d":
			_m_3d._cmd_path_3d(params)
		"sky":
			_m_3d._cmd_sky(params)
		"camera_attributes":
			_m_3d._cmd_camera_attributes(params)
		"navigation_3d":
			await _m_3d._cmd_navigation_3d(params)
		"physics_3d":
			await _m_3d._cmd_physics_3d(params)
		# Batch 3: 2D Systems + Animation + Audio
		"canvas":
			_m_2d._cmd_canvas(params)
		"canvas_draw":
			_m_2d._cmd_canvas_draw(params)
		"light_2d":
			_m_2d._cmd_light_2d(params)
		"parallax":
			_m_2d._cmd_parallax(params)
		"shape_2d":
			_m_2d._cmd_shape_2d(params)
		"path_2d":
			_m_2d._cmd_path_2d(params)
		"physics_2d":
			await _m_2d._cmd_physics_2d(params)
		"animation_tree":
			_m_anim._cmd_animation_tree(params)
		"animation_control":
			_m_anim._cmd_animation_control(params)
		"skeleton_ik":
			_m_anim._cmd_skeleton_ik(params)
		"audio_effect":
			_m_audio._cmd_audio_effect(params)
		"audio_bus_layout":
			_m_audio._cmd_audio_bus_layout(params)
		"audio_spatial":
			_m_audio._cmd_audio_spatial(params)
		# Batch 4: Locale (runtime)
		"locale":
			_m_world._cmd_locale(params)
		# Batch 5: UI Controls + Rendering + Resource
		"ui_control":
			_m_ui._cmd_ui_control(params)
		"ui_text":
			_m_ui._cmd_ui_text(params)
		"ui_popup":
			_m_ui._cmd_ui_popup(params)
		"ui_tree":
			_m_ui._cmd_ui_tree(params)
		"ui_item_list":
			_m_ui._cmd_ui_item_list(params)
		"ui_tabs":
			_m_ui._cmd_ui_tabs(params)
		"ui_menu":
			_m_ui._cmd_ui_menu(params)
		"ui_range":
			_m_ui._cmd_ui_range(params)
		"render_settings":
			_m_world._cmd_render_settings(params)
		"resource":
			_m_world._cmd_resource(params)
		"video":
			_m_world._cmd_video(params)
		"terrain":
			_m_3d._cmd_terrain(params)
		_:
			_send_response({"error": "Unknown command: %s" % command})


# Send response and clear busy flag
func _send_response(data: Dictionary) -> void:
	_busy = false
	_busy_since = 0.0
	if _current_id != null and not data.has("id"):
		data["id"] = _current_id
	_current_id = null
	_send_response_raw(data)


# Send response without clearing busy flag (used when rejecting during busy state)
func _send_response_raw(data: Dictionary) -> void:
	if _client == null:
		return
	var json_str: String = JSON.stringify(data) + "\n"
	var bytes: PackedByteArray = json_str.to_utf8_buffer()
	_client.put_data(bytes)


func _exit_tree() -> void:
	# Аудит #5: cleanup модулей — явный вызов (порядок _exit_tree у детей не гарантирует).
	_m_3d._clear_debug_draw()
	_m_world._close_websocket()
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	if _server != null:
		_server.stop()
		_server = null
	print("McpInteractionServer: Stopped")
