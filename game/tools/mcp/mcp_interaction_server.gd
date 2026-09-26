extends Node
const GameLogger := preload("res://scripts/core/GameLogger.gd")

# MCP Interaction Server - TCP server for game interaction
# Runs as an autoload inside the Godot game, accepting JSON commands over TCP.
# No class_name to avoid autoload conflict.
# Command handlers live in mcp_commands_*.gd groups (see _handlers below).

var _server: TCPServer
var _client: StreamPeerTCP
var _buffer: String = ""
var _busy: bool = false
var _busy_since: float = 0.0
var _current_id: Variant = null
# Port: MCP_PORT env → ProjectSettings "mcp/port" → 9090.
static func port() -> int:
	var env := OS.get_environment("MCP_PORT")
	if env.is_valid_int():
		return env.to_int()
	return int(ProjectSettings.get_setting("mcp/port", 9090))

const BUSY_TIMEOUT: float = 120.0
const AUTH_TOKEN_ENV := "MCP_AUTH_TOKEN"
var _auth_token: String = ""

var _grp_input: McpCommandsInput
var _grp_ui: McpCommandsUI
var _grp_system: McpCommandsSystem
var _grp_render: McpCommandsRender
var _handlers: Dictionary = {}

func _ready() -> void:
	# SECURITY: MCP-сервер — инструмент разработки. В релизных сборках
	# TCP-эндпоинт с полным доступом к игре должен быть полностью отключён.
	if not OS.is_debug_build():
		set_process(false)
		return
	# Ensure MCP server keeps processing even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_auth_token = OS.get_environment(AUTH_TOKEN_ENV)
	_grp_input = McpCommandsInput.new(self)
	_grp_ui = McpCommandsUI.new(self)
	_grp_system = McpCommandsSystem.new(self)
	_grp_render = McpCommandsRender.new(self)
	# TASK_19 L1: McpCommandsNetwork (пустая заглушка) удалён.
	for group in [_grp_input, _grp_ui, _grp_system, _grp_render]:
		var cmds: Dictionary = group.get_commands()
		for cmd in cmds:
			_handlers[cmd] = cmds[cmd]
	_server = TCPServer.new()
	var port_ := port()
	var err: int = _server.listen(port_, "127.0.0.1")
	if err != OK:
		push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [port_, err])
		return
	GameLogger.info("Listening on 127.0.0.1:%d" % port_, "MCP")


func _process(_delta: float) -> void:
	if _server == null:
		return

	# TASK_20: тик debug-мешей — frames_left декрементируется, истёкшие освобождаются.
	if _grp_system != null:
		_grp_system.tick_debug_draw()

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
			GameLogger.trace("Client connected", "MCP")

	# Read data from client
	if _client == null:
		return

	_client.poll()
	var status: int = _client.get_status()
	if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
		GameLogger.trace("Client disconnected", "MCP")
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

	# Auth is opt-in: when MCP_AUTH_TOKEN is set, every request must carry it.
	if not _auth_token.is_empty() and str(data.get("token", "")) != _auth_token:
		_send_response_raw({"error": "Unauthorized", "id": req_id})
		return

	if _busy:
		_send_response_raw({"error": "Server busy processing another command. Try again.", "id": req_id})
		return
	_busy = true
	_busy_since = Time.get_ticks_msec() / 1000.0
	_current_id = req_id

	var command: String = data.get("command", "")
	var params: Dictionary = data.get("params", {})

	if not _handlers.has(command):
		_send_response({"error": "Unknown command: %s" % command})
		return
	# TASK_19 M3: центральная проверка сцены (заменяет дубли в командах).
	if not is_inside_tree():
		_send_response({"error": "Server not in scene tree"})
		return
	var handler: Callable = _handlers[command]
	# Awaiting a non-coroutine handler returns immediately, so one path covers sync and async.
	await handler.call(params)

	# TASK_20 safety-net: если хендлер завершился, не отправив ответ (ранний return в команде),
	# сбрасываем _busy сразу, а не через 120-секундный таймаут.
	if _busy:
		push_warning("McpInteractionServer: handler for '%s' did not send a response, force-clearing busy flag" % command)
		_send_response({"error": "Handler did not send response"})


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
		push_warning("McpInteractionServer: no client, response dropped")
		return
	if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_error("McpInteractionServer: client not connected, dropping response and resetting")
		_client.disconnect_from_host()
		_client = null
		_busy = false
		_busy_since = 0.0
		_current_id = null
		return
	var json_str: String = JSON.stringify(data) + "\n"
	var bytes: PackedByteArray = json_str.to_utf8_buffer()
	_client.put_data(bytes)



func _exit_tree() -> void:
	_grp_system._clear_debug_draw()
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	if _server != null:
		_server.stop()
		_server = null
	GameLogger.trace("Stopped", "MCP")
