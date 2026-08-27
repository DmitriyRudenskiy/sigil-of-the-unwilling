extends Node

const MAX_BUFFER_SIZE := 1_048_576  # 1 MB per client

var server: TCPServer
var peers: Array[StreamPeerTCP] = []
var buffers: Dictionary = {}

func _ready():
	server = TCPServer.new()
	var err = server.listen(9090)
	if err == OK:
		print("[SocketServer] ✅ Listening on 127.0.0.1:9090")
	else:
		print("[SocketServer] ❌ Failed to listen: ", err)

func _process(_delta):
	# Accept new connections
	if server.is_connection_available():
		var peer = server.take_connection()
		peers.append(peer)
		buffers[peer] = ""
		
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
							var resp = _route_command(line)
							peer.put_data((JSON.stringify(resp) + "\n").to_utf8_buffer())
							
		elif status != StreamPeerTCP.STATUS_CONNECTING:
			to_remove.append(peer)
			
	# Remove disconnected clients
	for peer in to_remove:
		peers.erase(peer)
		buffers.erase(peer)
		peer.disconnect_from_host()

# ==================== COMMAND ROUTING ====================

func _route_command(line: String) -> Dictionary:
	var req = JSON.parse_string(line)
	if req == null or not (req is Dictionary):
		return {"error": "Invalid JSON"}
	var action = req.get("action")
	if not (action is String) or action.is_empty():
		return {"error": "Field 'action' is required and must be a string"}
	
	# Find active controllers in the scene tree
	var world_ctrl = _find_controller(WorldController)
	var battle_ctrl = _find_controller(BattleController)
	
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
			if not (x is int) or not (y is int):
				return {"error": "Fields 'x' and 'y' must be integers"}
			return _move_to(world_ctrl, x, y)
		"END_TURN":
			if world_ctrl == null or not world_ctrl.is_world_visible():
				return {"error": "Not in World mode"}
			return _end_turn(world_ctrl)
		"RETREAT":
			if battle_ctrl == null:
				return {"error": "Not in Battle mode"}
			return _retreat(battle_ctrl)
		_:
			return {"error": "Unknown action: %s" % action}

func _find_controller(type: Variant) -> Variant:
	# Recursive search through full scene tree
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if is_instance_of(node, type):
			return node
		for child in node.get_children():
			stack.append(child)
	return null

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
