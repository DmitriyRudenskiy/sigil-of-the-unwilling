extends Node
const GameLogger := preload("res://scripts/core/game_logger.gd")

# MCP Interaction Server - TCP server for game interaction
# Runs as an autoload inside the Godot game, accepting JSON commands over TCP.
# No class_name to avoid autoload conflict.
# R2 (world-controller-decoupling): this node is transport only (TCP, auth,
# busy state, explicit start/stop lifecycle). The command registry/routing
# lives in McpCommandDispatcher; command logic in mcp_commands_*.gd groups.

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


# T-240: явный opt-in. Автозагрузка в `main` нужна тестовой инфраструктуре, но
# «автозагрузка включена» не должна означать «слушает порт»: любой запуск игры
# разработчика (`godot --path game`) поднимал TCP-эндпоинт с полным доступом к
# игре. Слушает только тот процесс, которому это явно приказали (env MCP_ENABLE=1
# ставит tests/mcp/conftest.py — единственный легитимный хозяин сервера).
const ENABLE_ENV := "MCP_ENABLE"


static func enabled_by_env() -> bool:
	return OS.get_environment(ENABLE_ENV) == "1"

const BUSY_TIMEOUT: float = 120.0
const AUTH_TOKEN_ENV := "MCP_AUTH_TOKEN"
var _auth_token: String = ""

# T-172: отказ bind() был необратим. `start()` возвращал false, `_process`
# молчал (`if not _started: return`), порт не поднимался НИКОГДА, а тестовый
# стенд/wait_ready ждал 180 с и терял тест. Два следствия:
#   1) наблюдаемость — boot-трейс в файл (env MCP_BOOT_TRACE), который стенд
#      печатает в текст отказа: «Godot не дошёл до автозагрузки» и «listen
#      вернул 4096» были неотличимы ни друг от друга, ни от медленного старта;
#   2) обратимость — limited retry: порт, который держит умирающий Godot
#      предыдущего теста, освобождается за десятки мс, повторная попытка
#      дешёвая и прекращается по лимиту попыток.
const BOOT_TRACE_ENV := "MCP_BOOT_TRACE"
const RETRY_INTERVAL_MSEC := 1000
const MAX_BIND_ATTEMPTS := 30

var _dispatcher: McpCommandDispatcher
var _groups: Array[McpCommandsBase] = []
var _started: bool = false
var _bind_attempts: int = 0
var _last_bind_error: int = OK
var _retry_due_msec: int = 0
var _gave_up_traced: bool = false
# T-172: retry-цикл живёт в `_process`, поэтому явная `stop()` не может быть
# отменена им ничем — ни включённым `_process`, ни истёкшим сроком повторной
# попытки. Флаг — инвариант, а не следствие `set_process(false)`.
var _stop_requested: bool = false


static func boot_trace_path() -> String:
	return OS.get_environment(BOOT_TRACE_ENV)


## Строка boot-трейса: миллисекунды движка + pid (в прогоне несколько Godot).
## Пишет только debug-сборка и только когда стенд назвал путь; отсутствие
## файла после успешного старта = механизм трейса сломан, а не «Godot молчал».
func _trace(msg: String) -> void:
	var path := boot_trace_path()
	if path.is_empty() or not OS.is_debug_build():
		return
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		# READ_WRITE не создаёт файл (проверено на 4.7): первая строка пишется WRITE.
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%d pid=%d %s" % [Time.get_ticks_msec(), OS.get_process_id(), msg])
	f.close()


# --- T-172: читаемое состояние транспорта (для тестов и диагностики) ---------
func is_started() -> bool:
	return _started


func bind_attempts() -> int:
	return _bind_attempts


func last_bind_error() -> int:
	return _last_bind_error

func _ready() -> void:
	# SECURITY: MCP-сервер — инструмент разработки. В релизных сборках TCP-эндпоинт
	# с полным доступом к игре отключён (OS.is_debug_build), а в debug-сборке он всё
	# равно молчит, пока его явно не включит тестовый стенд (MCP_ENABLE, T-240).
	# TASK_19 L1: McpCommandsNetwork (пустая заглушка) удалён.
	_dispatcher = McpCommandDispatcher.new()
	_groups = [
		McpCommandsInput.new(self),
		McpCommandsUI.new(self),
		McpCommandsSystem.new(self),
		McpCommandsRender.new(self),
	]
	# T-240: реестр команд отделён от транспорта. Закрытый порт не должен превращать
	# диспетчер в пустой (eval/script при этом остаются gated внутри
	# McpCommandsSystem по OS.is_debug_build, TASK_19 H1).
	_dispatcher.clear()
	for group in _groups:
		_dispatcher.register(group)
	_trace("ready: enabled=%s port=%d debug=%s" % [
		str(enabled_by_env()), port(), str(OS.is_debug_build())])
	start()


## R2 explicit lifecycle: idempotent start. Returns false in release builds
## or when the port is busy (EADDRINUSE) — the server stays in a clean
## not-started state instead of half-initialised globals.
## T-240: returns false и без opt-in (MCP_ENABLE=1) — в любом debug-запуске
## порта не будет, пока его явно не поднял тестовый стенд.
func start() -> bool:
	if _started:
		return true
	if not OS.is_debug_build():
		push_warning("McpInteractionServer: dev tool, disabled in release builds")
		set_process(false)
		return false
	if not enabled_by_env():
		push_warning(
			"McpInteractionServer: autoload is present but the TCP endpoint stays "
			+ "closed without %s=1 (T-240). Set it only in the MCP test harness."
			% ENABLE_ENV)
		set_process(false)
		return false
	# Ensure MCP server keeps processing even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stop_requested = false
	# T-172: `_process` — единственный исполнитель bind-ретраев, и он обязан быть
	# включён до первой попытки (иначе отказ listen остался бы финальным).
	set_process(true)
	_auth_token = OS.get_environment(AUTH_TOKEN_ENV)
	_server = TCPServer.new()
	var port_ := port()
	var err: int = _server.listen(port_, "127.0.0.1")
	_bind_attempts += 1
	_last_bind_error = err
	_retry_due_msec = Time.get_ticks_msec() + RETRY_INTERVAL_MSEC
	_trace("listen attempt=%d port=%d err=%d" % [_bind_attempts, port_, err])
	if err == ERR_ALREADY_IN_USE:
		# EADDRINUSE: понятная ошибка + чистое состояние (без утечки peers).
		push_error(
			"McpInteractionServer: port %d is already in use (EADDRINUSE). "
			+ "Stop the other Godot/MCP instance or set MCP_PORT to a free port." % port_)
		_server = null
		return false
	if err != OK:
		push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [port_, err])
		_server = null
		return false
	_started = true
	GameLogger.info("Listening on 127.0.0.1:%d" % port_, "MCP")
	return true


## T-172: вторая (и далее) попытка bind для отказа, который живёт меньше
## секунды — порт отпускает умирающий Godot предыдущего теста. Лимит попыток
## обязателен: вечный ретрай превратил бы «порт занят соседом» в бесконечное
## ожидание вместо диагноза в трейсе.
func _retry_bind_if_due() -> void:
	if _stop_requested:
		return
	if not OS.is_debug_build() or not enabled_by_env():
		return
	if _bind_attempts >= MAX_BIND_ATTEMPTS:
		if not _gave_up_traced:
			_gave_up_traced = true
			_trace("gave up after %d attempts, last err=%d" % [_bind_attempts, _last_bind_error])
			push_error(
				"McpInteractionServer: bind retry exhausted after %d attempts (last err=%d)"
				% [_bind_attempts, _last_bind_error])
		return
	if Time.get_ticks_msec() < _retry_due_msec:
		return
	_trace("bind retry scheduled after %d ms" % RETRY_INTERVAL_MSEC)
	start()


## R2 explicit lifecycle: idempotent stop. Releases all transport state and
## lets groups free their resources (debug meshes etc.) via shutdown().
func stop() -> void:
	# T-172: явная остановка не должна быть отменена retry-циклом: `_process`
	# иначе увидел бы `_started == false` и поднял порт заново.
	_stop_requested = true
	set_process(false)
	if _client != null:
		_client.disconnect_from_host()
		_client = null
	_buffer = ""
	_busy = false
	_busy_since = 0.0
	_current_id = null
	if _server != null:
		_server.stop()
		_server = null
	_started = false
	for group in _groups:
		group.shutdown()
	GameLogger.trace("Stopped", "MCP")


func _process(_delta: float) -> void:
	if not _started:
		_retry_bind_if_due()
		return
	if _server == null:
		return

	# TASK_20: тик групп (debug-меша и пр.) — frames_left декрементируется.
	for group in _groups:
		group.tick()

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

	# R2: реестр команд и роутинг — в диспетчере, а не в транспорте.
	var result: Variant = await _dispatcher.dispatch(command, params, is_inside_tree())

	# TASK_20 safety-net: если хендлер завершился, не отправив ответ (ранний
	# return в команде), сбрасываем _busy сразу, а не через 120-секундный
	# таймаут. Ошибки диспетчера (unknown command / no scene tree) — в ответ.
	if _busy:
		if result is Dictionary:
			_send_response(result)
		else:
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
	stop()
