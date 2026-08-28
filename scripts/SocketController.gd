extends Node

const MAX_BUFFER_SIZE := 1_048_576  # 1 MB per client
const MAX_LINE_SIZE := 65_536  # 64 KB per command
const IDLE_TIMEOUT_SEC := 30.0

var server: TCPServer
# Cached controllers — avoid O(n) full tree walk on every request
var _world_ctrl_cache: Node = null
var _battle_ctrl_cache: Node = null
var _world_ctrl_script: Script = null
var _battle_ctrl_script: Script = null
var peers: Array[StreamPeerTCP] = []
var buffers: Dictionary = {}
var _last_activity: Dictionary = {}  # peer -> unix timestamp

# --- Метрики производительности ---
const SLOW_THRESHOLD_MS := 50.0  # порог "медленного" запроса
var _request_count: int = 0
var _total_time_ms: float = 0.0
var _slow_count: int = 0

func _ready():
	server = TCPServer.new()
	var err = server.listen(9095)
	if err == OK:
		print("[SocketServer] ✅ Listening on 127.0.0.1:9095")
	else:
		print("[SocketServer] ❌ Failed to listen: ", err)

	# Invalidate controller cache on scene tree changes (RF-07)
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)

func _on_tree_changed(_node: Node) -> void:
	_world_ctrl_cache = null
	_battle_ctrl_cache = null

func _process(_delta):
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
								push_warning("[SocketServer] Slow request: %.1f ms | %s" % [elapsed_ms, _extract_action(line)])
							else:
								print("[SocketServer] %.2f ms | %s" % [elapsed_ms, _extract_action(line)])
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
	
	# Find active controllers in the scene tree (cached, lazy-load scripts to avoid autoload deps)
	_ensure_scripts_loaded()
	var world_ctrl = _get_cached_controller(_world_ctrl_script, true)
	var battle_ctrl = _get_cached_controller(_battle_ctrl_script, false)
	
	if world_ctrl == null:
		print("[SocketServer] DEBUG: WorldController not found in scene tree")
	else:
		print("[SocketServer] DEBUG: WorldController found: ", world_ctrl.name)
	
	match action:
		"START_GAME":
			return _start_game()
		"GET_STATE":
			return _get_state(world_ctrl, battle_ctrl)
		"MOVE_TO":
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			var x = req.get("x")
			var y = req.get("y")
			if not (x is int or x is float) or not (y is int or y is float):
				return {"error": "Fields 'x' and 'y' must be numbers"}
			var tx := int(x)
			var ty := int(y)
			return _move_to(world_ctrl, tx, ty)
		"END_TURN":
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			return _end_turn(world_ctrl)
		"RETREAT":
			if battle_ctrl == null:
				return {"error": "Not in Battle mode"}
			return _retreat(battle_ctrl)
		"GET_METRICS":
			return get_metrics()
		_:
			return {"error": "Unknown action: %s" % action}

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
	# Re-search
	var found = _find_controller(script)
	if is_world:
		_world_ctrl_cache = found
	else:
		_battle_ctrl_cache = found
	return found

func _ensure_scripts_loaded() -> void:
	if _world_ctrl_script != null and _battle_ctrl_script != null:
		return
	_world_ctrl_script = load("res://scripts/WorldController.gd")
	_battle_ctrl_script = load("res://scripts/BattleController.gd")

func _start_game() -> Dictionary:
	if get_node_or_null("/root/World"):
		return {"status": "already_started"}
	var world_scene = load("res://scenes/World.tscn")
	var world = world_scene.instantiate()
	get_tree().root.add_child(world)
	return {"status": "game_started"}

# ==================== API METHODS ====================

func _get_state(world_ctrl, battle_ctrl) -> Dictionary:
	var state = {"mode": "unknown"}
	
	if world_ctrl:
		state.mode = "world"
		var hero = world_ctrl.get_hero()
		var map_gen = world_ctrl.get_map_gen()
		
		if hero:
			state.hero_pos = {"x": hero.current_cell.x, "y": hero.current_cell.y}
			state.move_points = hero.move_points
			state.max_move_points = hero.get_daily_movement_points()
			state.basic_resources = hero.resources.resources.duplicate()
			state.strategic_resources = hero.strategic_resources.get_all()
		
		if map_gen:
			# Map resources
			var res_nodes = []
			for cell in map_gen.resource_cells:
				res_nodes.append({"x": cell.x, "y": cell.y, "type": map_gen.resource_cells[cell]})
			state.map_resources = res_nodes
			
			# Map enemies
			var enemies = []
			if map_gen.enemy_stacks:
				for cell in map_gen.enemy_stacks:
					var army: Array = map_gen.enemy_stacks[cell]
					var composition = ""
					if army.size() > 0:
						var parts = []
						for stack in army:
							if stack.has_method("get_key"):
								parts.append("%s x%d" % [stack.get_key(), stack.count])
						composition = ", ".join(parts)
					else:
						composition = "Empty"
					
					enemies.append({
						"x": cell.x, 
						"y": cell.y, 
						"composition": composition
					})
			state.map_enemies = enemies
		
	elif battle_ctrl:
		state.mode = "battle"
		var bstate = battle_ctrl.get_battle_state()
		if bstate:
			state.battle_over = bstate.battle_over
			state.is_player_turn = bstate.is_player_turn
		
	return state

func _move_to(world_ctrl, x: int, y: int) -> Dictionary:
	var hero = world_ctrl.get_hero()
	if hero == null:
		return {"error": "Hero not initialized"}
	var map = world_ctrl.get_map_gen()
	if map == null:
		return {"error": "Map not initialized"}
	var target := Vector2i(x, y)
	if not map.is_in_bounds(target):
		return {"error": "Out of bounds: (%d, %d)" % [x, y]}
	var success: bool = hero.move_to_cell(target)
	if success:
		return {"status": "moving", "target": {"x": x, "y": y}}
	return {"error": "Cannot move to (%d, %d): unreachable or no MP" % [x, y]}

func _end_turn(world_ctrl) -> Dictionary:
	world_ctrl.do_end_turn()
	return {"status": "turn_ended"}

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
