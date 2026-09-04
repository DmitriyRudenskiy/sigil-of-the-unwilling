extends Node

const MAX_BUFFER_SIZE := 1_048_576  # 1 MB per client
const MAX_LINE_SIZE := 65_536  # 64 KB per command
const IDLE_TIMEOUT_SEC := 30.0
const _Platform = preload("res://scripts/core/Platform.gd")
const _BattleEmulator = preload("res://scripts/autoload/BattleEmulator.gd")
const _CityStateSerializer = preload("res://scripts/autoload/CityStateSerializer.gd")
const _WorldStateSerializer = preload("res://scripts/autoload/WorldStateSerializer.gd")

# R2 (world-controller-decoupling): эмуляторы/сериализаторы вынесены из этого
# монолика в отдельные классы (слабая связность). Инициализируются в _init,
# а не в _ready — чтобы доступ по _COMMANDS был всегда (тесты/первые запросы).
var _battle_emulator = null
var _city_serializer = null
var _world_serializer = null
# _COMMANDS нельзя const (Callable(self,...) не константное выражение в Godot),
# поэтому инициализация в _init, затем _route_command делает lookup.
var _COMMANDS: Dictionary = {}

var server: TCPServer
# Cached controllers — avoid O(n) full tree walk on every request
var _world_ctrl_cache: Node = null
var _battle_ctrl_cache: Node = null
var _world_ctrl_script: Script = null
var _battle_ctrl_script: Script = null
# Схемы обязательных полей/типов для аргументов команд (валидация до
# маршрутизации, R2). Пустая схема = аргументы не проверяются (валидируются
# в хендлере). Инициализация в _init, т.к. константный словарь с типами не
# константное выражение в Godot.
var _ARG_SCHEMAS: Dictionary = {}
var peers: Array[StreamPeerTCP] = []
var buffers: Dictionary = {}
var _last_activity: Dictionary = {}  # peer -> unix timestamp

# --- Метрики производительности ---
const SLOW_THRESHOLD_MS := 50.0  # порог "медленного" запроса
var _request_count: int = 0
var _total_time_ms: float = 0.0
var _slow_count: int = 0

func _init():
	_battle_emulator = _BattleEmulator.new()
	_city_serializer = _CityStateSerializer.new()
	_world_serializer = _WorldStateSerializer.new()
	_world_serializer.setup(self, _city_serializer)
	# _validate_args проверяет только поля, которые нельзя выразить одной
	# проверкой в хендлере; MOVE_TO — канонический пример «обязательное поле
	# + тип» из spec socket-command-validation.
	_ARG_SCHEMAS = {
		"MOVE_TO": {"x": ["int", "float"], "y": ["int", "float"]},
	}
	_COMMANDS = {
		"START_GAME": Callable(self, "_cmd_start_game"),
		"GET_STATE": Callable(self, "_cmd_get_state"),
		"MOVE_TO": Callable(self, "_cmd_move_to"),
		"END_TURN": Callable(self, "_cmd_end_turn"),
		"HERO_DIE": Callable(self, "_cmd_hero_die"),
		"SAVE_GAME": Callable(self, "_cmd_save_game"),
		"LOAD_GAME": Callable(self, "_cmd_load_game"),
		"COLLECT_HERE": Callable(self, "_cmd_collect_here"),
		"CITY_BUILD": Callable(self, "_cmd_city_build"),
		"CITY_LEVEL": Callable(self, "_cmd_city_level"),
		"CITY_HIRE": Callable(self, "_cmd_city_hire"),
		"CITY_CLOSE": Callable(self, "_cmd_city_close"),
		"RETREAT": Callable(self, "_cmd_retreat"),
		"FORCE_RETREAT": Callable(self, "_cmd_force_retreat"),
		"GET_SPELLS": Callable(self, "_cmd_get_spells"),
		"CAST_SPELL": Callable(self, "_cmd_cast_spell"),
		"EMULATE_BATTLE": Callable(self, "_cmd_emulate_battle"),
		"CAST_IN_BATTLE": Callable(self, "_cmd_cast_in_battle"),
		"SEQUENCE_BATTLE": Callable(self, "_cmd_sequence_battle"),
		"BATTLE_SPELL": Callable(self, "_cmd_battle_spell"),
		"SPELL_REGISTRY": Callable(self, "_cmd_spell_registry"),
		"GET_METRICS": Callable(self, "_cmd_get_metrics"),
	}

func _ready():
	# Порт нужен только сценариям/тестам. Без флага — не слушаем: иначе
	# второй инстанс процесса (оконная игра + тест-сервер) падает в EADDRINUSE.
	if not _Platform.is_socket_server():
		GameLogger.trace("Socket server disabled (no --test-server/--socket-server flag)", "SocketServer")
	else:
		server = TCPServer.new()
		var err = server.listen(9095)
		if err == OK:
			GameLogger.info("✅ Listening on 127.0.0.1:9095", "SocketServer")
		else:
			# Порт занят (второй инстанс) — не фатально: работаем без сервера.
			GameLogger.warn("⚠️ Failed to listen on 9095: %s — running without socket server" % err, "SocketServer")
			server = null

	# Invalidate controller cache on scene tree changes (RF-07)
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)

func _on_tree_changed(_node: Node) -> void:
	_world_ctrl_cache = null
	_battle_ctrl_cache = null

func _process(_delta):
	if server == null:
		return
	# Accept new connections
	if server.is_connection_available():
		var peer = server.take_connection()
		peers.append(peer)
		buffers[peer] = ""
		_last_activity[peer] = Time.get_unix_time_from_system()
		
	var to_remove = []
	for peer in peers:
		peer.poll()
		var status = peer.get_status()
		
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = peer.get_available_bytes()
			if available > 0:
				var res = peer.get_data(available)
				if res[0] == OK:
					buffers[peer] += res[1].get_string_from_utf8()
					_last_activity[peer] = Time.get_unix_time_from_system()
					# R7b: защита от memory exhaustion
					if buffers[peer].length() > MAX_BUFFER_SIZE:
						push_warning("[SocketServer] Buffer overflow from peer, disconnecting")
						to_remove.append(peer)
						continue
					# Process messages separated by newline
					while "\n" in buffers[peer]:
						var idx = buffers[peer].find("\n")
						var line = buffers[peer].substr(0, idx)
						buffers[peer] = buffers[peer].substr(idx + 1)
						if line.length() > 0:
							var t0 := Time.get_ticks_usec()
							var resp = _route_command(line)
							var elapsed_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
							_request_count += 1
							_total_time_ms += elapsed_ms
							if elapsed_ms > SLOW_THRESHOLD_MS:
								_slow_count += 1
								GameLogger.trace("Slow request: %.1f ms | %s" % [elapsed_ms, _extract_action(line)], "SocketServer")
							else:
								GameLogger.trace("%.2f ms | %s" % [elapsed_ms, _extract_action(line)], "SocketServer")
							peer.put_data((JSON.stringify(resp) + "\n").to_utf8_buffer())
							
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			to_remove.append(peer)

		# R7a: idle timeout — disconnect peers with no recent activity
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var last_active = _last_activity.get(peer, 0)
			if Time.get_unix_time_from_system() - last_active > IDLE_TIMEOUT_SEC:
				to_remove.append(peer)
				continue
			
	# Remove disconnected clients
	for peer in to_remove:
		peers.erase(peer)
		buffers.erase(peer)
		peer.disconnect_from_host()

# ==================== COMMAND ROUTING ====================

func _route_command(line: String) -> Dictionary:
	if line.length() > MAX_LINE_SIZE:
		return {"error": "Command too large"}
	var req = JSON.parse_string(line)
	if req == null or not (req is Dictionary):
		return {"error": "Invalid JSON"}
	var action = req.get("action")
	if not (action is String) or action.is_empty():
		return {"error": "Field 'action' is required and must be a string"}

	# Валидация аргументов против схемы (требование spec: malformed input
	# never crashes, wrong type rejected) — до маршрутизации, до поиска
	# контроллеров (detached-инстанс в test_socket_routing не имеет дерева).
	var vres := _validate_args(req, _ARG_SCHEMAS.get(action, {}))
	if not vres.is_empty():
		return vres

	# Find active controllers in the scene tree (cached, lazy-load scripts to avoid autoload deps)
	_ensure_scripts_loaded()
	var world_ctrl = _get_cached_controller(_world_ctrl_script, true)
	var battle_ctrl = _get_cached_controller(_battle_ctrl_script, false)

	var handler = _COMMANDS.get(action)
	if not handler.is_valid():
		return {"error": "Unknown action: %s" % action}
	return handler.call(req, world_ctrl, battle_ctrl)

## Валидирует аргументы `args` против схемы `{field: [type_names]}` (типы
## заданы именами: "int", "float", "String"...). Возвращает {"error": ...}
## при провале (отсутствие поля / неверный тип), иначе null.
func _validate_args(args: Dictionary, schema: Dictionary) -> Dictionary:
	if schema.is_empty():
		return {}
	for field in schema:
		if not args.has(field):
			return {"error": "Field '%s' is required" % field}
		var value = args[field]
		var allowed_types: Array = schema[field]
		var type_ok := false
		for type_name in allowed_types:
			if _value_has_type(value, type_name):
				type_ok = true
				break
		if not type_ok:
			return {"error": "Field '%s' must be of type %s" % [field, str(allowed_types)]}
	return {}

## Проверка типа через literal-`is` (runtime-тип в `is` не компилируется).
func _value_has_type(value: Variant, type_name: String) -> bool:
	if type_name == "int":
		return value is int
	if type_name == "float":
		return value is float
	if type_name == "String":
		return value is String
	if type_name == "bool":
		return value is bool
	if type_name == "Vector2i":
		return value is Vector2i
	return false

func _find_controller(script: Script) -> Node:
	# Recursive search through full scene tree (script-avoid autoload compile deps)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.get_script() == script:
			return node
		for child in node.get_children():
			stack.append(child)
	return null

func _get_cached_controller(script: Script, is_world: bool) -> Variant:
	var cached := _world_ctrl_cache if is_world else _battle_ctrl_cache
	if cached != null and is_instance_valid(cached) and cached.is_inside_tree():
		return cached
	var found = _find_controller(script)
	if is_world:
		_world_ctrl_cache = found
	else:
		_battle_ctrl_cache = found
	return found

func _ensure_scripts_loaded() -> void:
	if _world_ctrl_script != null and _battle_ctrl_script != null:
		return
	_world_ctrl_script = load("res://scripts/world/WorldController.gd")
	_battle_ctrl_script = load("res://scripts/systems/BattleController.gd")


# ==================== COMMAND HANDLERS ====================

func _cmd_start_game(_req, _wc, _bc) -> Dictionary:
	return _world_serializer.start_game()

func _cmd_get_state(_req, wc, bc) -> Dictionary:
	return _world_serializer.get_state(wc, bc)

func _cmd_move_to(req, wc, _bc) -> Dictionary:
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	if wc.has_method("is_terminal") and wc.is_terminal():
		return {"error": "Game over"}
	var x = req.get("x")
	var y = req.get("y")
	if not (x is int or x is float) or not (y is int or y is float):
		return {"error": "Fields 'x' and 'y' must be numbers"}
	return _world_serializer.move_to(wc, int(x), int(y))

func _cmd_end_turn(req, wc, _bc) -> Dictionary:
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	if wc.has_method("is_terminal") and wc.is_terminal():
		return {"error": "Game over"}
	return _world_serializer.end_turn(wc)

func _cmd_hero_die(_req, wc, _bc) -> Dictionary:
	# endgame (тест-only): честная цепочка смерти героя — та же,
	# что в WorldBattleCoordinator при потере боя (mark_combat_dead
	# + hero_died). DETERMINISTIC-путь к сценарию 11 без случайного боя.
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	var die_hero = wc.get_hero()
	if die_hero == null:
		return {"error": "Hero not initialized"}
	die_hero.set_combat_hp(0)
	die_hero.mark_combat_dead()
	GameEventBus.hero_died.emit(&"battle")
	return {"status": "hero_dead"}

func _cmd_save_game(_req, wc, _bc) -> Dictionary:
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	return _world_serializer.save_game(wc)

func _cmd_load_game(_req, wc, _bc) -> Dictionary:
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	return _world_serializer.load_game(wc)

func _cmd_collect_here(_req, wc, _bc) -> Dictionary:
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	var hero = wc.get_hero()
	if hero == null:
		return {"error": "Hero not initialized"}
	var ic = wc.interaction_controller
	if ic == null:
		return {"error": "No interaction controller"}
	var removed = ic.collect_resource_at(hero.current_cell)
	return {"status": "collected" if removed else "nothing_here"}

func _cmd_city_build(req, wc, _bc) -> Dictionary:
	return _city_serializer.city_action(wc, req, "build")

func _cmd_city_level(req, wc, _bc) -> Dictionary:
	return _city_serializer.city_action(wc, req, "level")

func _cmd_city_hire(req, wc, _bc) -> Dictionary:
	return _city_serializer.city_action(wc, req, "hire")

func _cmd_city_close(_req, wc, _bc) -> Dictionary:
	if wc == null or not wc.is_world_visible():
		return {"error": "Not in World mode"}
	var ui_mgr = wc.get_ui_manager()
	if ui_mgr == null:
		return {"error": "No UI manager (city screen unavailable)"}
	ui_mgr.close_city_screen()
	return {"status": "closed", "city_screen_open": ui_mgr.city_overlay_open()}

func _cmd_retreat(_req, _wc, bc) -> Dictionary:
	if bc == null:
		return {"error": "Not in Battle mode"}
	return _retreat(bc)

func _cmd_force_retreat(_req, _wc, bc) -> Dictionary:
	# Аварийный выход из зависшего боя (например, скрипт-ошибка рванула
	# ход и отступление до WAITING_INPUT не доходит). В обход
	# стейт-машины завершает бой отступлением игрока.
	if bc == null:
		return {"error": "Not in Battle mode"}
	var fb = bc.get_battle_state()
	if fb == null or fb.battle_over:
		return {"error": "Battle already over"}
	bc.force_retreat()
	return {"status": "forced_retreat"}

func _cmd_get_spells(_req, _wc, _bc) -> Dictionary:
	return _battle_emulator.get_spells()

func _cmd_cast_spell(req, _wc, _bc) -> Dictionary:
	return _battle_emulator.cast_spell(req.get("args", {}))

func _cmd_emulate_battle(req, _wc, _bc) -> Dictionary:
	return _battle_emulator.emulate_battle(req.get("args", {}))

func _cmd_cast_in_battle(req, _wc, _bc) -> Dictionary:
	return _battle_emulator.cast_in_battle(req.get("args", {}))

func _cmd_sequence_battle(req, _wc, _bc) -> Dictionary:
	return _battle_emulator.sequence_battle(req.get("args", {}))

func _cmd_battle_spell(req, _wc, _bc) -> Dictionary:
	return _battle_emulator.battle_spell(req.get("args", {}))

func _cmd_spell_registry(_req, _wc, _bc) -> Dictionary:
	return _battle_emulator.spell_registry()

func _cmd_get_metrics(_req, _wc, _bc) -> Dictionary:
	return get_metrics()


func _retreat(battle_ctrl) -> Dictionary:
	var bstate = battle_ctrl.get_battle_state()
	if bstate == null:
		return {"error": "Battle state not initialized"}
	if bstate.battle_over:
		return {"error": "Battle already over"}
	battle_ctrl.do_retreat()
	return {"status": "retreating"}


# ==================== METRICS ====================

## Парсинг action из JSON-строки для лога.
func _extract_action(line: String) -> String:
	var req = JSON.parse_string(line)
	if req is Dictionary and req.has("action"):
		return str(req["action"])
	return "UNKNOWN"

## Возвращает сводную статистику по обработанным запросам.
func get_metrics() -> Dictionary:
	var avg: float = 0.0
	if _request_count > 0:
		avg = _total_time_ms / float(_request_count)
	return {
		"total_requests": _request_count,
		"total_time_ms": roundf(_total_time_ms * 100.0) / 100.0,
		"avg_ms": roundf(avg * 100.0) / 100.0,
		"slow_requests": _slow_count,
		"slow_threshold_ms": SLOW_THRESHOLD_MS,
		"connected_peers": peers.size(),
	}
