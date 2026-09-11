extends BaseTest
## Tests for the MCP server dispatcher and serialization (no real TCP).
## _TestServer overrides the response senders to capture them in memory.

const _Srv := preload("res://mcp_interaction_server.gd")

class _TestServer extends _Srv:
	var responses: Array = []

	func _send_response(data: Dictionary) -> void:
		responses.append(data)

	func _send_response_raw(data: Dictionary) -> void:
		responses.append(data)


var _server: _TestServer

func before_test() -> void:
	_server = _TestServer.new()
	add_child(_server)

func after_test() -> void:
	if _server != null and is_instance_valid(_server):
		_server.free()
	_server = null


func test_handlers_registered() -> void:
	var handlers: Dictionary = _server._handlers
	assert_that(handlers.size()).is_greater(90)  # 3D/network dead-weights removed (TASK_18 Phase 5)
	assert_bool(handlers.has("os_info")).is_true()
	assert_bool(handlers.has("eval")).is_true()


func test_scene_path_whitelist() -> void:
	assert_bool(McpCommandsSystem._is_allowed_scene_path("res://scenes/World.tscn")).is_true()
	assert_bool(McpCommandsSystem._is_allowed_scene_path("res://scenes/ui/GameOverScreen.tscn")).is_true()
	assert_bool(McpCommandsSystem._is_allowed_scene_path("res://icon.svg")).is_false()
	assert_bool(McpCommandsSystem._is_allowed_scene_path("res://evil.gd")).is_false()
	assert_bool(McpCommandsSystem._is_allowed_scene_path("res://scenes/../icon.svg")).is_false()
	assert_bool(McpCommandsSystem._is_allowed_scene_path("")).is_false()


func test_port_default_and_env_override() -> void:
	# Default: no env, no ProjectSettings override
	OS.set_environment("MCP_PORT", "")
	assert_int(_Srv.port()).is_equal(9090)
	# Env override
	OS.set_environment("MCP_PORT", "9123")
	assert_int(_Srv.port()).is_equal(9123)
	OS.set_environment("MCP_PORT", "")


func test_handle_command_valid() -> void:
	_server._handle_command("{\"command\": \"os_info\", \"params\": {}}")
	assert_that(_server.responses.size()).is_equal(1)
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).is_empty()


func test_handle_command_unknown() -> void:
	_server._handle_command("{\"command\": \"definitely_not_a_command\"}")
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).contains("Unknown command")


func test_handle_command_invalid_json() -> void:
	_server._handle_command("{not json")
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).contains("Invalid JSON")


func test_handle_command_non_object_json() -> void:
	_server._handle_command("[1, 2]")
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).contains("Expected JSON object")


func test_handle_command_requires_auth_token_when_set() -> void:
	_server._auth_token = "secret"
	_server._handle_command("{\"command\": \"os_info\", \"params\": {}}")
	var rejected: Dictionary = _server.responses[0]
	assert_that(String(rejected.get("error", ""))).is_equal("Unauthorized")
	_server._handle_command("{\"command\": \"os_info\", \"params\": {}, \"token\": \"secret\"}")
	var accepted: Dictionary = _server.responses[1]
	assert_that(String(accepted.get("error", ""))).is_empty()
	_server._auth_token = ""


func test_eval_blocks_dangerous_operations() -> void:
	var sys := McpCommandsSystem.new(_server)
	sys._cmd_eval({"code": "OS.execute(\"ls\", [])"})
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).contains("Blocked operation")
	sys._cmd_eval({"code": "var f = FileAccess.open('user://x', FileAccess.WRITE)"})
	r = _server.responses[1]
	assert_that(String(r.get("error", ""))).contains("Blocked operation")
	sys._cmd_eval({"code": "load('res://x.gd')"})
	r = _server.responses[2]
	assert_that(String(r.get("error", ""))).contains("Blocked operation")


func test_script_attach_blocks_dangerous_operations() -> void:
	var sys := McpCommandsSystem.new(_server)
	sys._cmd_script({"node_path": "/root", "action": "attach", "source": "func _ready(): OS.execute('ls', [])"})
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).contains("Blocked operation")


func test_handle_command_busy_rejects() -> void:
	_server._busy = true
	_server._handle_command("{\"command\": \"os_info\"}")
	var r: Dictionary = _server.responses[0]
	assert_that(String(r.get("error", ""))).contains("busy")
	_server._busy = false


func test_send_response_null_client_no_crash() -> void:
	var plain := _Srv.new()
	add_child(plain)
	plain._client = null
	plain._send_response({"ok": true})
	plain._send_response_raw({"ok": true})
	plain.free()


func test_indent_code() -> void:
	var s := McpCommandsSystem.new(_server)
	# Common indent stripped, every line gets >= 1 tab, 4 spaces == 1 level.
	assert_that(s._indent_code("a\nb")).is_equal("\ta\n\tb\n")
	assert_that(s._indent_code("a\n    b")).is_equal("\ta\n\t\tb\n")
	assert_that(s._indent_code("x")).is_equal("\tx\n")


func test_variant_to_json_scalar_types() -> void:
	assert_that(McpSerialization.variant_to_json(42)).is_equal(42)
	assert_that(McpSerialization.variant_to_json(1.5)).is_equal(1.5)
	assert_that(McpSerialization.variant_to_json(true)).is_equal(true)
	assert_that(McpSerialization.variant_to_json("x")).is_equal("x")
	assert_that(McpSerialization.variant_to_json(null)).is_null()


func test_variant_to_json_composite_types() -> void:
	assert_that(McpSerialization.variant_to_json(Vector2i(1, 2))).is_equal({"x": 1, "y": 2})
	assert_that(McpSerialization.variant_to_json([1, 2])).is_equal([1, 2])
	assert_that(McpSerialization.variant_to_json({"a": 1})).is_equal({"a": 1})
	var v2: Variant = McpSerialization.variant_to_json(Vector2(1.0, 2.0))
	assert_that(float((v2 as Dictionary)["x"])).is_equal(1.0)


func test_json_to_variant_with_type_hint() -> void:
	var v: Variant = McpSerialization.json_to_variant("[1, 2, 3]", "Array")
	assert_bool(v is Array).is_true()
	var p: Variant = McpSerialization.json_to_variant("{\"x\": 1, \"y\": 2}", "Vector2i")
	assert_that(p).is_equal(Vector2i(1, 2))
	var d: Variant = McpSerialization.json_to_variant("{\"x\": 5}", "Dictionary")
	assert_bool(d is Dictionary).is_true()
	assert_that(int((d as Dictionary)["x"])).is_equal(5)
