extends Node
## SocketController — External Control Interface (TASK_ADDENDUM_11)
##
## Framing: [uint32 LE length][JSON UTF-8]
## Only starts if --test-server[=PORT] is present.

class_name SocketController

const DEFAULT_PORT := 9080
const LOG_PATH := "user://socket_log.txt"

var server: TCPServer = null
var client: StreamPeerTCP = null
var client_id: int = -1

# Command queue to be processed in the main thread
var command_queue: Array[Dictionary] = []
var response_queue: Array[Dictionary] = []

func _ready() -> void:
	var args := OS.get_cmdline_args()
	var port := DEFAULT_PORT
	var server_enabled := false

	for arg in args:
		if arg.begins_with("--test-server"):
			server_enabled = true
			if "=" in arg:
				port = int(arg.split("=")[1])

	if not server_enabled:
		return

	server = TCPServer.new()
	if server.listen(port) != OK:
		printerr("❌ SocketController: Failed to listen on port %d" % port)
		return

	print("🌐 SocketController: Listening on port %d..." % port)
	_init_log()

func _process(_delta: float) -> void:
	if server == null:
		return

	_handle_connection()
	_process_commands()
	_send_responses()

func _init_log() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_line("--- Socket Log Start: %s ---" % Time.get_datetime_string_from_system())
		file.close()

func _log_command(cmd: String, args: Dictionary, result: Dictionary) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line("[%s] CMD: %s | ARGS: %s | RES: %s" % [Time.get_time_string_from_system(), cmd, JSON.stringify(args), JSON.stringify(result)])
		file.close()

func _handle_connection() -> void:
	if client == null:
		var peer: StreamPeerTCP = server.take_connection()
		if peer != null:
			client = peer
			client_id = client.get_peer_id()
			print("🤝 SocketController: Client connected (%d)" % client_id)
	else:
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			print("🔌 SocketController: Client disconnected")
			client = null
			client_id = -1
			return

		# Read framing: [uint32 length][JSON]
		if client.get_available_bytes() >= 4:
			var len_bytes: PackedByteArray = client.get_data(4)
			var length: int = _decode_u32(len_bytes)
			
			if length > 0 and length < 1048576: # 1MB cap
				if client.get_available_bytes() >= length:
					var body_bytes: PackedByteArray = client.get_data(length)
					var json_str: String = body_bytes.get_string_from_utf8()
					var data: Variant = JSON.parse_string(json_str)
					if data is Dictionary:
						command_queue.append(data as Dictionary)
					else:
						_enqueue_error(-1, "Invalid JSON format")
				else:
					# Partial packet - in a real implementation we'd buffer. 
					# For simple request/response, we'll just drop or wait.
					# Since we are using blocking-like read in _process, 
					# we should probably buffer the read.
					pass

func _decode_u32(bytes: PackedByteArray) -> int:
	# Little Endian
	return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24)

func _encode_u32(val: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.append(val & 0xFF)
	bytes.append((val >> 8) & 0xFF)
	bytes.append((val >> 16) & 0xFF)
	bytes.append((val >> 24) & 0xFF)
	return bytes

func _process_commands() -> void:
	while command_queue.size() > 0:
		var req: Dictionary = command_queue.pop_front()
		var id: int = req.get("id", -1)
		var cmd: String = req.get("cmd", "")
		var args: Dictionary = req.get("args", {})
		
		var res: Variant = _execute_command(cmd, args)
		
		if res is Dictionary and res.has("error"):
			_enqueue_response(id, false, res)
		else:
			_enqueue_response(id, true, res)
		
		_log_command(cmd, args, res if res is Dictionary else {"result": res})

func _enqueue_response(id: int, ok: bool, result: Variant) -> void:
	var resp: Dictionary = {
		"id": id,
		"ok": ok,
		"result": result if ok else null,
		"error": result if not ok else null
	}
	response_queue.append(resp)

func _enqueue_error(id: int, err: String) -> void:
	_enqueue_response(id, false, err)

func _send_responses() -> void:
	if client == null:
		return
	
	while response_queue.size() > 0:
		var resp: Dictionary = response_queue.pop_front()
		var json_str: String = JSON.stringify(resp)
		var body: PackedByteArray = json_str.to_utf8_buffer()
		var header: PackedByteArray = _encode_u32(body.size())
		
		client.put_data(header)
		client.put_data(body)

# ==================== COMMANDS ====================

func _execute_command(cmd: String, args: Dictionary) -> Variant:
	var wc_node: Node = get_tree().root.find_child("WorldController", true, false)
	if wc_node == null:
		return {"error": "WorldController not found"}
	var wc: WorldController = wc_node as WorldController

	match cmd:
		"ping":
			return {"pong": true, "version": "1.0.0"}
		
		"new_game":
			var seed: int = args.get("seed", 1234)
			wc.restart_game(seed)
			return {"status": "restarted", "seed": seed}
		
		"get_state":
			return _get_game_state(wc)
		
		"get_map_objects":
			return _get_map_objects(wc, args)
		
		"move_to":
			return _cmd_move_to(wc, args)
		
		"collect_here":
			return _cmd_collect_here(wc)
		
		"end_turn":
			wc._on_end_turn()
			return {"status": "turn_ended"}
		
		"wait_hours":
			var h: int = args.get("h", 0)
			return _cmd_wait_hours(wc, h)
		
		"challenge":
			var mid: int = args.get("monster_id", -1)
			return _cmd_challenge(wc, mid)
		
		"get_battle_state":
			return _get_battle_state(wc)
		
		"battle_retreat":
			return _cmd_battle_retreat(wc)
		
		"debug_unlock_all":
			return _cmd_debug_unlock(wc)
		
		"debug_set_mp":
			var v: float = args.get("v", 0.0)
			wc._hero.movement.current_mp = v
			return {"status": "mp_set", "value": v}
		
		_:
			return {"error": "Unknown command: %s" % cmd}

func _get_game_state(wc: WorldController) -> Dictionary:
	var hero: HeroController = wc._hero
	var session: GameSession = wc._session
	var ts = hero.get("time")
	return {
		"hero": {
			"pos": hero.current_cell,
			"mp": hero.movement.current_mp,
			"hour": ts.current_hour if ts else 0.0,
		},
		"collected": {
			"total": hero.inventory.total_items,
			"by_type": hero.inventory.get_counts()
		},
		"battles_fled": hero.stats.get("battles_fled", 0),
		"army": hero.army.get_army_summary(),
		"resources": hero.inventory.get_resources(),
		"date": session.run_seed # Using seed as date for now
	}

func _get_map_objects(wc: WorldController, args: Dictionary) -> Dictionary:
	var map_gen: MapGenerator = wc._map_gen
	var filter_types: Array = args.get("types", [])
	
	var results: Dictionary = {
		"treasure": [],
		"node": [],
		"monster": [],
		"chest": [],
		"scroll": []
	}
	
	# Resources
	for cell in map_gen.resource_cells:
		if filter_types.is_empty() or "node" in filter_types:
			results["node"].append({"pos": cell, "type": map_gen.resource_cells[cell]})
	
	# Enemies
	for cell in map_gen.enemy_stacks:
		if filter_types.is_empty() or "monster" in filter_types:
			results["monster"].append({"pos": cell, "alive": true})
	
	# Chests / Scrolls (these might be in spawner or map_gen)
	# Assuming they are tracked in map_gen or similar.
	# For now, just empty as we need to check where they are stored.
	
	return results

func _cmd_move_to(wc: WorldController, args: Dictionary) -> Dictionary:
	var target: Vector2i = Vector2i(args.get("x", 0), args.get("y", 0))
	var instant: bool = args.get("instant", false)
	
	if instant:
		# Teleport (test mode)
		wc._hero.current_cell = target
		wc._on_hero_moved(target)
		return {"status": "arrived", "pos": target}
	else:
		# Trigger movement logic
		wc._hero.movement.on_map_clicked(target)
		return {"status": "moving"}

func _cmd_collect_here(wc: WorldController) -> Dictionary:
	var cell: Vector2i = wc._hero.current_cell
	var extracted: int = wc.try_extract_resource(cell)
	# Also check interaction controller for other things
	wc.interaction_controller.collect_resource_at(cell)
	wc.interaction_controller.pickup_scroll_at(cell)
	wc.interaction_controller.check_chest_contact(cell)
	return {"status": "collected", "amount": extracted}

func _cmd_wait_hours(wc: WorldController, h: int) -> Dictionary:
	# Simplified wait: subtract MP or just advance time
	var time_sys = wc._hero.get("time")
	if time_sys:
		time_sys.advance_hours(h)
	return {"status": "waited", "hours": h}

func _cmd_challenge(wc: WorldController, mid: int) -> Dictionary:
	# In a real game, we'd find the monster at the hero's cell
	var cell: Vector2i = wc._hero.current_cell
	if wc._map_gen.enemy_stacks.has(cell):
		var enemy_army: Array[UnitStack] = wc._map_gen.enemy_stacks[cell]
		wc.battle_coordinator.start_battle(enemy_army, cell)
		return {"status": "battle_started"}
	return {"error": "No monster here"}

func _get_battle_state(wc: WorldController) -> Dictionary:
	var flow: BattleFlow = wc._battle_flow
	if flow.current_battle == null:
		return {"status": "no_battle"}
	
	return {
		"phase": flow.current_phase,
		"attacker": flow.attacker_stacks,
		"defender": flow.defender_stacks
	}

func _cmd_battle_retreat(wc: WorldController) -> Dictionary:
	wc._battle_flow.retreat()
	return {"status": "retreated"}

func _cmd_debug_unlock(wc: WorldController) -> Dictionary:
	var hero: HeroController = wc._hero
	var skills = hero.get("skills")
	if skills:
		for skill in ["nature_sense", "keen_eye", "navigation", "geology", "alchemy"]:
			skills.set(skill, 3)
	
	var tools = hero.get("tools")
	if tools:
		for tool in ["pickaxe", "shovel", "compass"]:
			tools.add_tool(tool)
	
	# Add workers
	hero.army.add_unit("worker", 1)
	hero.army.add_unit("miner", 1)
	return {"status": "unlocked"}
