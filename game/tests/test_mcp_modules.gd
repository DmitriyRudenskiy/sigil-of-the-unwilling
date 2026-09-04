extends GutTest

# Аудит #5: mcp_interaction_server расколот на доменные модули — протокол
# и роутинг сохраняются: JSON-команда по TCP доезжает до своего модуля
# и получает ответ (end-to-end, loopback:9090).

const _Server = preload("res://scripts/autoload/mcp_interaction_server.gd")
const _PORT := 9090

var _srv
var _client: StreamPeerTCP


func _make_server() -> void:
	_srv = _Server.new()
	add_child(_srv)  # _ready: модули + listen
	_client = StreamPeerTCP.new()
	_client.connect_to_host("127.0.0.1", _PORT)  # один раз, дальше — поллинг
	var ok: bool = false
	for i in range(60):
		await get_tree().process_frame
		_client.poll()  # без poll() статус в headless не сдвигается
		if _client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			ok = true
			break
	assert_true(ok, "клиент подключился к MCP-серверу (порт %d)" % _PORT)
	# Стабилизируем соединение: первая put_data сразу после handshake
	# в headless-лупбеке может утонуть (наблюдено), серверу нужно время
	# на take_connection.
	for i in range(10):
		await get_tree().process_frame


func _send_cmd(cmd: String, params: Dictionary = {}) -> Dictionary:
	var payload: PackedByteArray = (JSON.stringify({"command": cmd, "params": params}) + "\n").to_utf8_buffer()
	# put_data буферизует несённые байты внутри StreamPeer — один вызов,
	# без повторных отпрасток (дубль сломал бы newline-фрейминг).
	assert_true(_client.put_data(payload) != -1, "put_data на '%s'" % cmd)
	var buf: String = ""
	for i in range(120):
		await get_tree().process_frame
		_client.poll()
		if _client.get_available_bytes() > 0:
			var rd: Array = _client.get_data(_client.get_available_bytes())
			buf += rd[1].get_string_from_utf8()
			if buf.contains("\n"):
				var j := JSON.new()
				assert_true(j.parse(buf.strip_edges()) == OK, "ответ-JSON на '%s': %s" % [cmd, buf])
				return j.data
	assert_false(true, "ответ на '%s' не пришёл" % cmd)
	return {}


func test_every_module_routes_a_command() -> void:
	await _make_server()
	# По команде на каждый модуль: ответ есть => роутинг до модуля работает.
	var cases: Array = [
		["mouse_move", {"x": 1, "y": 2}],
		["get_performance", {}],
		["get_audio", {}],
		["tween_property", {}],
		["get_camera", {}],
		["tilemap", {}],
		["viewport", {}],
		["os_info", {}],
	]
	for c in cases:
		var resp: Dictionary = await _send_cmd(c[0], c[1])
		assert_false(resp.is_empty(), "роутинг: '%s' получил ответ" % c[0])

	# Unknown command — default-ветка, не модули.
	var unknown: Dictionary = await _send_cmd("no_such_command")
	assert_true(String(unknown.get("error", "")).begins_with("Unknown command"),
		"default-ветка жива")

	# key_press (async-ветка match, input-модуль).
	var kp: Dictionary = await _send_cmd("key_press", {"key": "w"})
	assert_false(kp.is_empty(), "key_press отвечает")


func test_modules_are_children_with_server_injected() -> void:
	await _make_server()
	var mods: Array = [_srv._m_input, _srv._m_nodes, _srv._m_audio, _srv._m_anim,
		_srv._m_3d, _srv._m_2d, _srv._m_ui, _srv._m_world]
	for mod in mods:
		assert_true(mod.is_inside_tree(), "модуль в дереве")
		assert_eq(mod.server, _srv, "server-референс инжектнут")


func after_each():
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	if _srv != null:
		_srv.free()  # _exit_tree: stop listener
		_srv = null
	# Даём слоту порта освободиться.
	await get_tree().process_frame
