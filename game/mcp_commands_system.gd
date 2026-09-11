class_name McpCommandsSystem
extends McpCommandsBase

## Operations that must not be reachable from eval/script commands (TASK_18 R3).
const EVAL_BLOCKED_PATTERNS: Array[String] = [
	"OS.execute", "OS.shell_open", "FileAccess.open",
	"DirAccess.open", "ResourceLoader.load", "load(",
	"get_tree().quit", "get_tree().change_scene(",
]

var _debug_draw_node: Node = null
var _debug_meshes: Array = []

## Returns the first blocked pattern found in code, or "" if the code is clean.
func _find_blocked_pattern(code: String) -> String:
	for pattern in EVAL_BLOCKED_PATTERNS:
		if code.contains(pattern):
			return pattern
	return ""

func get_commands() -> Dictionary:
	return {
		"eval": _cmd_eval,
		"get_scene_tree": _cmd_get_scene_tree,
		"get_property": _cmd_get_property,
		"set_property": _cmd_set_property,
		"call_method": _cmd_call_method,
		"get_node_info": _cmd_get_node_info,
		"instantiate_scene": _cmd_instantiate_scene,
		"remove_node": _cmd_remove_node,
		"change_scene": _cmd_change_scene,
		"pause": _cmd_pause,
		"get_performance": _cmd_get_performance,
		"wait": _cmd_wait,
		"connect_signal": _cmd_connect_signal,
		"disconnect_signal": _cmd_disconnect_signal,
		"emit_signal": _cmd_emit_signal,
		"play_animation": _cmd_play_animation,
		"tween_property": _cmd_tween_property,
		"get_nodes_in_group": _cmd_get_nodes_in_group,
		"find_nodes_by_class": _cmd_find_nodes_by_class,
		"reparent_node": _cmd_reparent_node,
		"spawn_node": _cmd_spawn_node,
		"create_timer": _cmd_create_timer,
		"set_particles": _cmd_set_particles,
		"create_animation": _cmd_create_animation,
		"serialize_state": _cmd_serialize_state,
		"physics_body": _cmd_physics_body,
		"create_joint": _cmd_create_joint,
		"manage_group": _cmd_manage_group,
		"add_collision": _cmd_add_collision,
		"debug_draw": _cmd_debug_draw,
		"list_signals": _cmd_list_signals,
		"await_signal": _cmd_await_signal,
		"script": _cmd_script,
		"os_info": _cmd_os_info,
		"time_scale": _cmd_time_scale,
		"process_mode": _cmd_process_mode,
		"world_settings": _cmd_world_settings,
		"raycast": _cmd_raycast,
		"navigate_path": _cmd_navigate_path,
		"terrain": _cmd_terrain,
		"locale": _cmd_locale,
	}

func _cmd_eval(params: Dictionary) -> void:
	var code: String = params.get("code", "")
	if code.is_empty():
		server._send_response({"error": "No code provided"})
		return
	var blocked: String = _find_blocked_pattern(code)
	if not blocked.is_empty():
		server._send_response({"error": "Blocked operation: %s" % blocked})
		return

	# Wrap user code in a function so we can capture the return value
	var script_source: String = """extends Node

func execute():
	var __result = null
	__result = await _run()
	return __result

func _run():
%s
""" % [_indent_code(code)]

	var script: GDScript = GDScript.new()
	script.source_code = script_source
	var err: int = script.reload()
	if err != OK:
		server._send_response({"error": "Failed to compile GDScript (error %d). Check syntax." % err})
		return

	var temp_node: Node = Node.new()
	temp_node.set_script(script)
	# Allow eval to work even when game is paused
	temp_node.process_mode = Node.PROCESS_MODE_ALWAYS
	server.add_child(temp_node)

	var result: Variant = null
	if temp_node.has_method("execute"):
		result = await temp_node.execute()

	temp_node.queue_free()
	server._send_response({"success": true, "result": McpSerialization.variant_to_json(result)})


func _cmd_get_scene_tree(_params: Dictionary) -> void:
	var tree: Dictionary = _build_tree_node(server.get_tree().root)
	server._send_response({"success": true, "tree": tree})


func _cmd_get_property(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	if node_path.is_empty() or property.is_empty():
		server._send_response({"error": "node_path and property are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var value: Variant = node.get(property)
	server._send_response({"success": true, "value": McpSerialization.variant_to_json(value), "property": property, "node_path": node_path})


# --- Set Property ---


func _cmd_set_property(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	if node_path.is_empty() or property.is_empty():
		server._send_response({"error": "node_path and property are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var raw_value: Variant = params.get("value", null)
	var type_hint: String = params.get("type_hint", "")
	var value: Variant
	if type_hint.is_empty():
		value = _json_to_variant_for_property(node, property, raw_value)
	else:
		value = McpSerialization.json_to_variant(raw_value, type_hint)
	node.set(property, value)
	server._send_response({"success": true, "node_path": node_path, "property": property, "value": McpSerialization.variant_to_json(node.get(property))})


# --- Call Method ---


func _cmd_call_method(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var method_name: String = params.get("method", "")
	if node_path.is_empty() or method_name.is_empty():
		server._send_response({"error": "node_path and method are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node.has_method(method_name):
		server._send_response({"error": "Method not found: %s on node %s" % [method_name, node_path]})
		return

	var args: Array = params.get("args", [])
	var result: Variant = node.callv(method_name, args)
	server._send_response({"success": true, "result": McpSerialization.variant_to_json(result)})


# --- Get Node Info ---


func _cmd_get_node_info(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var properties: Array = []
	for prop in node.get_property_list():
		var prop_dict: Dictionary = prop
		if prop_dict.get("usage", 0) & PROPERTY_USAGE_EDITOR:
			properties.append({
				"name": prop_dict.get("name", ""),
				"type": prop_dict.get("type", 0),
				"value": McpSerialization.variant_to_json(node.get(prop_dict.get("name", "")))
			})

	var signals: Array = []
	for sig in node.get_signal_list():
		var sig_dict: Dictionary = sig
		signals.append(sig_dict.get("name", ""))

	var methods: Array = []
	for m in node.get_method_list():
		var m_dict: Dictionary = m
		if not str(m_dict.get("name", "")).begins_with("_"):
			methods.append(m_dict.get("name", ""))

	var children: Array = []
	for child in node.get_children():
		children.append({
			"name": child.name,
			"type": child.get_class(),
			"path": str(child.get_path())
		})

	server._send_response({
		"success": true,
		"class": node.get_class(),
		"name": node.name,
		"path": str(node.get_path()),
		"properties": properties,
		"signals": signals,
		"methods": methods,
		"children": children
	})


# --- Instantiate Scene ---


func _cmd_instantiate_scene(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	var parent_path: String = params.get("parent_path", "/root")
	if scene_path.is_empty():
		server._send_response({"error": "scene_path is required"})
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		server._send_response({"error": "Failed to load scene: %s" % scene_path})
		return

	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent node not found: %s" % parent_path})
		return

	var instance: Node = packed.instantiate()
	parent.add_child(instance)
	server._send_response({"success": true, "instance_name": instance.name, "instance_path": str(instance.get_path())})


# --- Remove Node ---


func _cmd_remove_node(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var node_name: String = node.name
	node.queue_free()
	server._send_response({"success": true, "removed": node_name})


# --- Change Scene ---


func _cmd_change_scene(params: Dictionary) -> void:
	var scene_path: String = params.get("scene_path", "")
	if scene_path.is_empty():
		server._send_response({"error": "scene_path is required"})
		return

	var err: int = server.get_tree().change_scene_to_file(scene_path)
	if err != OK:
		server._send_response({"error": "Failed to change scene. Error code: %d" % err})
		return

	server._send_response({"success": true, "scene": scene_path})


# --- Pause ---


func _cmd_pause(params: Dictionary) -> void:
	var paused: bool = params.get("paused", true)
	server.get_tree().paused = paused
	server._send_response({"success": true, "paused": paused})


# --- Get Performance ---


func _cmd_get_performance(_params: Dictionary) -> void:
	server._send_response({
		"success": true,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_frame_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
		"memory_static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"object_node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"object_orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"render_total_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_total_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	})


# --- Wait N Frames ---


func _cmd_wait(params: Dictionary) -> void:
	var frames: int = int(params.get("frames", 1))
	var frame_type: String = str(params.get("frame_type", "render")).to_lower()
	var use_physics: bool = frame_type == "physics" or bool(params.get("physics", false))
	for i in frames:
		if use_physics:
			await server.get_tree().physics_frame
		else:
			await server.get_tree().process_frame
	server._send_response({"success": true, "waited_frames": frames, "frame_type": "physics" if use_physics else "render"})


# --- Helper: Convert Godot Variant to JSON-safe value ---


func _cmd_connect_signal(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")
	var target_path: String = params.get("target_path", "")
	var method_name: String = params.get("method", "")
	if node_path.is_empty() or signal_name.is_empty() or target_path.is_empty() or method_name.is_empty():
		server._send_response({"error": "node_path, signal_name, target_path, and method are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Source node not found: %s" % node_path})
		return

	var target: Node = server.get_tree().root.get_node_or_null(target_path)
	if target == null:
		server._send_response({"error": "Target node not found: %s" % target_path})
		return

	if not node.has_signal(signal_name):
		server._send_response({"error": "Signal '%s' not found on node %s" % [signal_name, node_path]})
		return

	if not target.has_method(method_name):
		server._send_response({"error": "Method '%s' not found on target %s" % [method_name, target_path]})
		return

	if node.is_connected(signal_name, Callable(target, method_name)):
		server._send_response({"error": "Signal already connected"})
		return

	node.connect(signal_name, Callable(target, method_name))
	server._send_response({"success": true, "signal": signal_name, "from": node_path, "to": target_path, "method": method_name})


# --- Disconnect Signal ---


func _cmd_disconnect_signal(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")
	var target_path: String = params.get("target_path", "")
	var method_name: String = params.get("method", "")
	if node_path.is_empty() or signal_name.is_empty() or target_path.is_empty() or method_name.is_empty():
		server._send_response({"error": "node_path, signal_name, target_path, and method are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Source node not found: %s" % node_path})
		return

	var target: Node = server.get_tree().root.get_node_or_null(target_path)
	if target == null:
		server._send_response({"error": "Target node not found: %s" % target_path})
		return

	var callable: Callable = Callable(target, method_name)
	if not node.is_connected(signal_name, callable):
		server._send_response({"error": "Signal is not connected"})
		return

	node.disconnect(signal_name, callable)
	server._send_response({"success": true, "disconnected": signal_name, "from": node_path, "to": target_path, "method": method_name})


# --- Emit Signal ---


func _cmd_emit_signal(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")
	if node_path.is_empty() or signal_name.is_empty():
		server._send_response({"error": "node_path and signal_name are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node.has_signal(signal_name):
		server._send_response({"error": "Signal '%s' not found on node %s" % [signal_name, node_path]})
		return

	var args: Array = params.get("args", [])
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	node.callv("emit_signal", call_args)
	server._send_response({"success": true, "emitted": signal_name, "node": node_path, "arg_count": args.size()})


# --- Play Animation ---


func _cmd_play_animation(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is AnimationPlayer:
		server._send_response({"error": "Node is not an AnimationPlayer: %s (is %s)" % [node_path, node.get_class()]})
		return

	var anim_player: AnimationPlayer = node as AnimationPlayer
	var action: String = params.get("action", "play")

	match action:
		"play":
			var animation: String = params.get("animation", "")
			if animation.is_empty():
				server._send_response({"error": "animation name is required for play action"})
				return
			if not anim_player.has_animation(animation):
				server._send_response({"error": "Animation '%s' not found. Available: %s" % [animation, str(anim_player.get_animation_list())]})
				return
			anim_player.play(animation)
			server._send_response({"success": true, "action": "play", "animation": animation})
		"stop":
			anim_player.stop()
			server._send_response({"success": true, "action": "stop"})
		"pause":
			anim_player.pause()
			server._send_response({"success": true, "action": "pause"})
		"get_list":
			var anims: Array = []
			for anim_name in anim_player.get_animation_list():
				anims.append(str(anim_name))
			server._send_response({"success": true, "animations": anims, "current": anim_player.current_animation, "playing": anim_player.is_playing()})
		_:
			server._send_response({"error": "Unknown animation action: %s. Use play, stop, pause, or get_list" % action})


# --- Tween Property ---


func _cmd_tween_property(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	if node_path.is_empty() or property.is_empty():
		server._send_response({"error": "node_path and property are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var final_value: Variant = _json_to_variant_for_property(node, property, params.get("final_value", null))
	var duration: float = float(params.get("duration", 1.0))
	var trans_type: int = int(params.get("trans_type", 0))  # Tween.TRANS_LINEAR
	var ease_type: int = int(params.get("ease_type", 2))  # Tween.EASE_IN_OUT

	var tween: Tween = server.create_tween()
	var tweener: PropertyTweener = tween.tween_property(node, property, final_value, duration)
	if tweener == null:
		tween.kill()
		server._send_response({"error": "tween_property failed: value type does not match property '%s' on %s" % [property, node.get_class()]})
		return
	tweener.set_trans(trans_type).set_ease(ease_type)
	server._send_response({"success": true, "node": node_path, "property": property, "duration": duration})


# --- Get Nodes In Group ---


func _cmd_get_nodes_in_group(params: Dictionary) -> void:
	var group_name: String = params.get("group", "")
	if group_name.is_empty():
		server._send_response({"error": "group is required"})
		return

	var nodes: Array = server.get_tree().get_nodes_in_group(group_name)
	var result: Array = []
	for node in nodes:
		result.append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(node.get_path())
		})
	server._send_response({"success": true, "group": group_name, "count": result.size(), "nodes": result})


# --- Find Nodes By Class ---


func _cmd_find_nodes_by_class(params: Dictionary) -> void:
	var class_filter: String = params.get("class_name", "")
	if class_filter.is_empty():
		server._send_response({"error": "class_name is required"})
		return

	var root_path: String = params.get("root_path", "/root")
	var root_node: Node = server.get_tree().root.get_node_or_null(root_path)
	if root_node == null:
		server._send_response({"error": "Root node not found: %s" % root_path})
		return

	var found: Array = []
	_find_by_class_recursive(root_node, class_filter, found)
	server._send_response({"success": true, "class_name": class_filter, "count": found.size(), "nodes": found})


func _cmd_reparent_node(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var new_parent_path: String = params.get("new_parent_path", "")
	if node_path.is_empty() or new_parent_path.is_empty():
		server._send_response({"error": "node_path and new_parent_path are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var new_parent: Node = server.get_tree().root.get_node_or_null(new_parent_path)
	if new_parent == null:
		server._send_response({"error": "New parent not found: %s" % new_parent_path})
		return

	var keep_global: bool = params.get("keep_global_transform", true)
	node.reparent(new_parent, keep_global)
	server._send_response({"success": true, "node": node.name, "new_parent": new_parent_path, "new_path": str(node.get_path())})


# --- Key Hold (no auto-release) ---


func _cmd_spawn_node(params: Dictionary) -> void:
	var type_name: String = params.get("type", "")
	var node_name: String = params.get("name", "")
	var parent_path: String = params.get("parent_path", "/root")

	if type_name.is_empty():
		server._send_response({"error": "type is required"})
		return

	if not ClassDB.class_exists(type_name):
		server._send_response({"error": "Unknown class: %s" % type_name})
		return

	if not ClassDB.is_parent_class(type_name, "Node") and type_name != "Node":
		server._send_response({"error": "Class '%s' is not a Node type" % type_name})
		return

	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent node not found: %s" % parent_path})
		return

	var instance: Node = ClassDB.instantiate(type_name) as Node
	if instance == null:
		server._send_response({"error": "Failed to instantiate: %s" % type_name})
		return

	if node_name.length() > 0:
		instance.name = node_name

	# Apply properties if provided
	var properties: Dictionary = params.get("properties", {})
	for prop_name in properties:
		var raw_value: Variant = properties[prop_name]
		var value: Variant = _json_to_variant_for_property(instance, prop_name, raw_value)
		instance.set(prop_name, value)

	parent.add_child(instance)
	server._send_response({"success": true, "name": instance.name, "type": type_name, "path": str(instance.get_path())})


# --- Set Shader Parameter ---


func _cmd_create_timer(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	var wait_time: float = float(params.get("wait_time", 1.0))
	var one_shot: bool = params.get("one_shot", false)
	var autostart: bool = params.get("autostart", false)

	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent node not found: %s" % parent_path})
		return

	var timer: Timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	timer.autostart = autostart
	if params.has("name") and params["name"] is String and not (params["name"] as String).is_empty():
		timer.name = params["name"]
	parent.add_child(timer)
	if autostart:
		timer.start()
	server._send_response({"success": true, "path": str(timer.get_path()), "name": timer.name, "wait_time": timer.wait_time, "one_shot": timer.one_shot, "autostart": autostart})


# --- Set Particles ---


func _cmd_set_particles(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not (node is GPUParticles2D or node is GPUParticles3D):
		server._send_response({"error": "Node is not a GPUParticles node: %s (is %s)" % [node_path, node.get_class()]})
		return

	# Set direct particle properties
	if params.has("emitting"):
		node.set("emitting", bool(params["emitting"]))
	if params.has("amount"):
		node.set("amount", int(params["amount"]))
	if params.has("lifetime"):
		node.set("lifetime", float(params["lifetime"]))
	if params.has("one_shot"):
		node.set("one_shot", bool(params["one_shot"]))
	if params.has("speed_scale"):
		node.set("speed_scale", float(params["speed_scale"]))
	if params.has("explosiveness"):
		node.set("explosiveness", float(params["explosiveness"]))
	if params.has("randomness"):
		node.set("randomness", float(params["randomness"]))

	# Configure process material
	if params.has("process_material"):
		var mat_params: Dictionary = params["process_material"]
		var mat: ParticleProcessMaterial = node.get("process_material") as ParticleProcessMaterial
		if mat == null:
			mat = ParticleProcessMaterial.new()
			node.set("process_material", mat)
		if mat_params.has("direction"):
			var d: Dictionary = mat_params["direction"]
			mat.direction = Vector3(float(d.get("x", 0)), float(d.get("y", -1)), float(d.get("z", 0)))
		if mat_params.has("spread"):
			mat.spread = float(mat_params["spread"])
		if mat_params.has("gravity"):
			var g: Dictionary = mat_params["gravity"]
			mat.gravity = Vector3(float(g.get("x", 0)), float(g.get("y", -9.8)), float(g.get("z", 0)))
		if mat_params.has("initial_velocity_min"):
			mat.initial_velocity_min = float(mat_params["initial_velocity_min"])
		if mat_params.has("initial_velocity_max"):
			mat.initial_velocity_max = float(mat_params["initial_velocity_max"])
		if mat_params.has("color"):
			var c: Dictionary = mat_params["color"]
			mat.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
		if mat_params.has("scale_min"):
			mat.scale_min = float(mat_params["scale_min"])
		if mat_params.has("scale_max"):
			mat.scale_max = float(mat_params["scale_max"])

	server._send_response({
		"success": true, "node_path": node_path,
		"emitting": node.get("emitting"), "amount": node.get("amount"),
		"lifetime": node.get("lifetime"), "one_shot": node.get("one_shot"),
		"speed_scale": node.get("speed_scale")
	})


# --- Create Animation ---


func _cmd_create_animation(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var anim_name: String = params.get("animation_name", "")
	if node_path.is_empty() or anim_name.is_empty():
		server._send_response({"error": "node_path and animation_name are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is AnimationPlayer:
		server._send_response({"error": "Node is not an AnimationPlayer: %s (is %s)" % [node_path, node.get_class()]})
		return

	var anim_player: AnimationPlayer = node as AnimationPlayer
	var anim: Animation = Animation.new()
	anim.length = float(params.get("length", 1.0))
	var loop_mode: int = int(params.get("loop_mode", 0))
	anim.loop_mode = loop_mode as Animation.LoopMode

	var tracks: Array = params.get("tracks", [])
	var track_count: int = 0
	for track_data in tracks:
		var track_type_str: String = track_data.get("type", "value")
		var track_path: String = track_data.get("path", "")
		if track_path.is_empty():
			continue

		var track_type: int = Animation.TYPE_VALUE
		match track_type_str:
			"value":
				track_type = Animation.TYPE_VALUE
			"method":
				track_type = Animation.TYPE_METHOD
			"bezier":
				track_type = Animation.TYPE_BEZIER
			"audio":
				track_type = Animation.TYPE_AUDIO

		var idx: int = anim.add_track(track_type)
		anim.track_set_path(idx, NodePath(track_path))

		var keys: Array = track_data.get("keys", [])
		for key_data in keys:
			var time: float = float(key_data.get("time", 0.0))
			match track_type:
				Animation.TYPE_VALUE:
					var value: Variant = McpSerialization.json_to_variant(key_data.get("value", null), key_data.get("type_hint", ""))
					anim.track_insert_key(idx, time, value)
					if key_data.has("transition"):
						var key_idx: int = anim.track_find_key(idx, time, Animation.FIND_MODE_APPROX)
						if key_idx >= 0:
							anim.track_set_key_transition(idx, key_idx, float(key_data["transition"]))
				Animation.TYPE_METHOD:
					var method_name: String = key_data.get("method", "")
					var args: Array = key_data.get("args", [])
					anim.track_insert_key(idx, time, {"method": method_name, "args": args})
				Animation.TYPE_BEZIER:
					var value: float = float(key_data.get("value", 0.0))
					anim.bezier_track_insert_key(idx, time, value)
				Animation.TYPE_AUDIO:
					var stream_path: String = key_data.get("stream", "")
					if not stream_path.is_empty():
						var stream: AudioStream = load(stream_path) as AudioStream
						if stream != null:
							anim.audio_track_insert_key(idx, time, stream)
		track_count += 1

	# Add to library (use default "" library if it exists, otherwise create it)
	var lib_name: String = params.get("library", "")
	var lib: AnimationLibrary = null
	if anim_player.has_animation_library(lib_name):
		lib = anim_player.get_animation_library(lib_name)
	else:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library(lib_name, lib)
	lib.add_animation(anim_name, anim)

	server._send_response({"success": true, "animation_name": anim_name, "length": anim.length, "loop_mode": loop_mode, "track_count": track_count})


# --- Serialize State ---


func _cmd_serialize_state(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "/root")
	var action: String = params.get("action", "save")
	var max_depth: int = int(params.get("max_depth", 5))

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	match action:
		"save":
			var state: Dictionary = _serialize_node(node, max_depth, 0)
			server._send_response({"success": true, "action": "save", "state": state})
		"load":
			var data: Dictionary = params.get("data", {})
			if data.is_empty():
				server._send_response({"error": "data is required for load action"})
				return
			var count: int = _deserialize_node(node, data)
			server._send_response({"success": true, "action": "load", "restored_count": count})
		_:
			server._send_response({"error": "Unknown serialize action: %s. Use save or load" % action})


func _cmd_physics_body(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not (node is PhysicsBody2D or node is PhysicsBody3D):
		server._send_response({"error": "Node is not a PhysicsBody: %s (is %s)" % [node_path, node.get_class()]})
		return

	# Set common physics properties
	if params.has("gravity_scale") and node.get("gravity_scale") != null:
		node.set("gravity_scale", float(params["gravity_scale"]))
	if params.has("mass") and node.get("mass") != null:
		node.set("mass", float(params["mass"]))
	if params.has("freeze") and node.get("freeze") != null:
		node.set("freeze", bool(params["freeze"]))
	if params.has("sleeping") and node.get("sleeping") != null:
		node.set("sleeping", bool(params["sleeping"]))
	if params.has("linear_damp") and node.get("linear_damp") != null:
		node.set("linear_damp", float(params["linear_damp"]))
	if params.has("angular_damp") and node.get("angular_damp") != null:
		node.set("angular_damp", float(params["angular_damp"]))

	# Velocity (2D vs 3D)
	if params.has("linear_velocity"):
		var lv: Dictionary = params["linear_velocity"]
		if node is PhysicsBody3D:
			node.set("linear_velocity", Vector3(float(lv.get("x", 0)), float(lv.get("y", 0)), float(lv.get("z", 0))))
		else:
			node.set("linear_velocity", Vector2(float(lv.get("x", 0)), float(lv.get("y", 0))))
	if params.has("angular_velocity"):
		var av: Variant = params["angular_velocity"]
		if node is PhysicsBody3D and av is Dictionary:
			node.set("angular_velocity", Vector3(float(av.get("x", 0)), float(av.get("y", 0)), float(av.get("z", 0))))
		else:
			node.set("angular_velocity", float(av))

	# Physics material (friction, bounce)
	if params.has("friction") or params.has("bounce"):
		var phys_mat: PhysicsMaterial = node.get("physics_material_override") as PhysicsMaterial
		if phys_mat == null:
			phys_mat = PhysicsMaterial.new()
			node.set("physics_material_override", phys_mat)
		if params.has("friction"):
			phys_mat.friction = float(params["friction"])
		if params.has("bounce"):
			phys_mat.bounce = float(params["bounce"])

	# Build response
	var result: Dictionary = {"success": true, "node_path": node_path, "class": node.get_class()}
	if node.get("mass") != null:
		result["mass"] = node.get("mass")
	if node.get("gravity_scale") != null:
		result["gravity_scale"] = node.get("gravity_scale")
	if node.get("linear_velocity") != null:
		result["linear_velocity"] = McpSerialization.variant_to_json(node.get("linear_velocity"))
	if node.get("angular_velocity") != null:
		result["angular_velocity"] = McpSerialization.variant_to_json(node.get("angular_velocity"))
	server._send_response(result)


# --- Create Joint ---


func _cmd_create_joint(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "")
	var joint_type: String = params.get("joint_type", "")
	if parent_path.is_empty() or joint_type.is_empty():
		server._send_response({"error": "parent_path and joint_type are required"})
		return

	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent node not found: %s" % parent_path})
		return

	var node_a: String = params.get("node_a_path", "")
	var node_b: String = params.get("node_b_path", "")
	var joint: Node = null

	match joint_type:
		"pin_2d":
			var j: PinJoint2D = PinJoint2D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			if params.has("softness"):
				j.softness = float(params["softness"])
			joint = j
		"spring_2d":
			var j: DampedSpringJoint2D = DampedSpringJoint2D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			if params.has("length"):
				j.length = float(params["length"])
			if params.has("rest_length"):
				j.rest_length = float(params["rest_length"])
			if params.has("stiffness"):
				j.stiffness = float(params["stiffness"])
			if params.has("damping"):
				j.damping = float(params["damping"])
			joint = j
		"groove_2d":
			var j: GrooveJoint2D = GrooveJoint2D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			if params.has("length"):
				j.length = float(params["length"])
			if params.has("initial_offset"):
				j.initial_offset = float(params["initial_offset"])
			joint = j
		"pin_3d":
			var j: PinJoint3D = PinJoint3D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			joint = j
		"hinge_3d":
			var j: HingeJoint3D = HingeJoint3D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			joint = j
		"cone_3d":
			var j: ConeTwistJoint3D = ConeTwistJoint3D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			joint = j
		"slider_3d":
			var j: SliderJoint3D = SliderJoint3D.new()
			if not node_a.is_empty():
				j.node_a = NodePath(node_a)
			if not node_b.is_empty():
				j.node_b = NodePath(node_b)
			joint = j
		_:
			server._send_response({"error": "Unknown joint type: %s. Use pin_2d, spring_2d, groove_2d, pin_3d, hinge_3d, cone_3d, or slider_3d" % joint_type})
			return

	parent.add_child(joint)
	server._send_response({"success": true, "joint_type": joint_type, "name": joint.name, "path": str(joint.get_path())})


# --- Bone Pose ---


func _cmd_manage_group(params: Dictionary) -> void:
	var action: String = params.get("action", "")
	var group_name: String = params.get("group", "")

	if action == "clear_group":
		if group_name.is_empty():
			server._send_response({"error": "group is required for clear_group"})
			return
		var nodes: Array = server.get_tree().get_nodes_in_group(group_name)
		for node in nodes:
			node.remove_from_group(group_name)
		server._send_response({"success": true, "action": "clear_group", "group": group_name, "removed_count": nodes.size()})
		return

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	match action:
		"add":
			if group_name.is_empty():
				server._send_response({"error": "group is required for add"})
				return
			node.add_to_group(group_name)
			server._send_response({"success": true, "action": "add", "node_path": node_path, "group": group_name})
		"remove":
			if group_name.is_empty():
				server._send_response({"error": "group is required for remove"})
				return
			node.remove_from_group(group_name)
			server._send_response({"success": true, "action": "remove", "node_path": node_path, "group": group_name})
		"get_groups":
			var groups: Array = []
			for g in node.get_groups():
				groups.append(str(g))
			server._send_response({"success": true, "action": "get_groups", "node_path": node_path, "groups": groups})
		_:
			server._send_response({"error": "Unknown group action: %s. Use add, remove, get_groups, or clear_group" % action})


# --- Create Timer ---


func _cmd_add_collision(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "")
	var shape_type: String = params.get("shape_type", "")
	if parent_path.is_empty() or shape_type.is_empty():
		server._send_response({"error": "parent_path and shape_type are required"})
		return

	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent node not found: %s" % parent_path})
		return

	var is_3d: bool = parent.get_class().ends_with("3D") or parent is PhysicsBody3D or parent is Area3D
	var shape_params: Dictionary = params.get("shape_params", {})
	var shape: Resource = null

	if is_3d:
		match shape_type:
			"box":
				var s: BoxShape3D = BoxShape3D.new()
				s.size = Vector3(float(shape_params.get("size_x", 1)), float(shape_params.get("size_y", 1)), float(shape_params.get("size_z", 1)))
				shape = s
			"sphere":
				var s: SphereShape3D = SphereShape3D.new()
				s.radius = float(shape_params.get("radius", 0.5))
				shape = s
			"capsule":
				var s: CapsuleShape3D = CapsuleShape3D.new()
				s.radius = float(shape_params.get("radius", 0.5))
				s.height = float(shape_params.get("height", 2.0))
				shape = s
			"cylinder":
				var s: CylinderShape3D = CylinderShape3D.new()
				s.radius = float(shape_params.get("radius", 0.5))
				s.height = float(shape_params.get("height", 2.0))
				shape = s
			"ray":
				var s: SeparationRayShape3D = SeparationRayShape3D.new()
				s.length = float(shape_params.get("length", 1.0))
				shape = s
			_:
				server._send_response({"error": "Unknown 3D shape type: %s. Use box, sphere, capsule, cylinder, or ray" % shape_type})
				return
		var col_shape: CollisionShape3D = CollisionShape3D.new()
		col_shape.shape = shape as Shape3D
		if params.has("disabled"):
			col_shape.disabled = bool(params["disabled"])
		parent.add_child(col_shape)
		col_shape.owner = server.get_tree().edited_scene_root if server.get_tree().edited_scene_root else server.get_tree().root
		if params.has("collision_layer"):
			parent.set("collision_layer", int(params["collision_layer"]))
		if params.has("collision_mask"):
			parent.set("collision_mask", int(params["collision_mask"]))
		server._send_response({"success": true, "name": col_shape.name, "path": str(col_shape.get_path()), "shape_type": shape_type, "mode": "3d"})
	else:
		match shape_type:
			"box":
				var s: RectangleShape2D = RectangleShape2D.new()
				s.size = Vector2(float(shape_params.get("size_x", 1)), float(shape_params.get("size_y", 1)))
				shape = s
			"circle":
				var s: CircleShape2D = CircleShape2D.new()
				s.radius = float(shape_params.get("radius", 0.5))
				shape = s
			"capsule":
				var s: CapsuleShape2D = CapsuleShape2D.new()
				s.radius = float(shape_params.get("radius", 0.5))
				s.height = float(shape_params.get("height", 2.0))
				shape = s
			"segment":
				var s: SegmentShape2D = SegmentShape2D.new()
				s.a = Vector2(float(shape_params.get("a_x", 0)), float(shape_params.get("a_y", 0)))
				s.b = Vector2(float(shape_params.get("b_x", 1)), float(shape_params.get("b_y", 0)))
				shape = s
			_:
				server._send_response({"error": "Unknown 2D shape type: %s. Use box, circle, capsule, or segment" % shape_type})
				return
		var col_shape: CollisionShape2D = CollisionShape2D.new()
		col_shape.shape = shape as Shape2D
		if params.has("disabled"):
			col_shape.disabled = bool(params["disabled"])
		parent.add_child(col_shape)
		col_shape.owner = server.get_tree().edited_scene_root if server.get_tree().edited_scene_root else server.get_tree().root
		if params.has("collision_layer"):
			parent.set("collision_layer", int(params["collision_layer"]))
		if params.has("collision_mask"):
			parent.set("collision_mask", int(params["collision_mask"]))
		server._send_response({"success": true, "name": col_shape.name, "path": str(col_shape.get_path()), "shape_type": shape_type, "mode": "2d"})


# --- Environment / Post-Processing ---


func _cmd_debug_draw(params: Dictionary) -> void:
	var action: String = params.get("action", "line")
	var color_dict: Dictionary = params.get("color", {"r": 1.0, "g": 0.0, "b": 0.0})
	var color: Color = Color(float(color_dict.get("r", 1)), float(color_dict.get("g", 0)), float(color_dict.get("b", 0)), float(color_dict.get("a", 1)))
	var duration: int = int(params.get("duration", 0))

	if action == "clear":
		_clear_debug_draw()
		server._send_response({"success": true, "action": "clear"})
		return

	# Ensure we have a debug draw parent
	if _debug_draw_node == null or not is_instance_valid(_debug_draw_node):
		_debug_draw_node = Node3D.new()
		_debug_draw_node.name = "_McpDebugDraw"
		server.get_tree().root.add_child(_debug_draw_node)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED

	match action:
		"line":
			var from_dict: Dictionary = params.get("from", {})
			var to_dict: Dictionary = params.get("to", {})
			var from_pos: Vector3 = Vector3(float(from_dict.get("x", 0)), float(from_dict.get("y", 0)), float(from_dict.get("z", 0)))
			var to_pos: Vector3 = Vector3(float(to_dict.get("x", 0)), float(to_dict.get("y", 0)), float(to_dict.get("z", 0)))
			var im: ImmediateMesh = ImmediateMesh.new()
			im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
			im.surface_add_vertex(from_pos)
			im.surface_add_vertex(to_pos)
			im.surface_end()
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = im
			_debug_draw_node.add_child(mi)
			_debug_meshes.append({"node": mi, "frames_left": duration})
			server._send_response({"success": true, "action": "line"})
		"sphere":
			var center_dict: Dictionary = params.get("center", {})
			var center: Vector3 = Vector3(float(center_dict.get("x", 0)), float(center_dict.get("y", 0)), float(center_dict.get("z", 0)))
			var radius: float = float(params.get("radius", 0.5))
			var sphere_mesh: SphereMesh = SphereMesh.new()
			sphere_mesh.radius = radius
			sphere_mesh.height = radius * 2.0
			sphere_mesh.material = mat
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = sphere_mesh
			mi.global_position = center
			_debug_draw_node.add_child(mi)
			_debug_meshes.append({"node": mi, "frames_left": duration})
			server._send_response({"success": true, "action": "sphere"})
		"box":
			var center_dict: Dictionary = params.get("center", {})
			var center: Vector3 = Vector3(float(center_dict.get("x", 0)), float(center_dict.get("y", 0)), float(center_dict.get("z", 0)))
			var size_dict: Dictionary = params.get("size", {"x": 1, "y": 1, "z": 1})
			var box_size: Vector3 = Vector3(float(size_dict.get("x", 1)), float(size_dict.get("y", 1)), float(size_dict.get("z", 1)))
			var box_mesh: BoxMesh = BoxMesh.new()
			box_mesh.size = box_size
			box_mesh.material = mat
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = box_mesh
			mi.global_position = center
			_debug_draw_node.add_child(mi)
			_debug_meshes.append({"node": mi, "frames_left": duration})
			server._send_response({"success": true, "action": "box"})
		_:
			server._send_response({"error": "Unknown debug draw action: %s. Use line, sphere, box, or clear" % action})


func _cmd_list_signals(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var signals: Array = []
	for sig in node.get_signal_list():
		var connections: Array = []
		for conn in node.get_signal_connection_list(sig["name"]):
			connections.append({"callable": str(conn["callable"]), "flags": conn["flags"]})
		signals.append({"name": sig["name"], "args": str(sig["args"]), "connections": connections})
	server._send_response({"success": true, "node_path": node_path, "signals": signals})


func _cmd_await_signal(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")
	var timeout: float = float(params.get("timeout", 10))
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	if not node.has_signal(signal_name):
		server._send_response({"error": "Signal not found: %s on %s" % [signal_name, node_path]})
		return
	var timer: SceneTreeTimer = server.get_tree().create_timer(timeout)
	var result: Array = [false, []]
	var cb: Callable = func():
		result[0] = true
	node.connect(signal_name, cb, CONNECT_ONE_SHOT)
	while not result[0] and timer.time_left > 0:
		await server.get_tree().process_frame
	if node.is_connected(signal_name, cb):
		node.disconnect(signal_name, cb)
	if result[0]:
		server._send_response({"success": true, "signal_name": signal_name, "received": true})
	else:
		server._send_response({"success": true, "signal_name": signal_name, "received": false, "timeout": true})


func _cmd_script(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get_source")
	match action:
		"get_source":
			var s = node.get_script()
			if s == null:
				server._send_response({"success": true, "has_script": false})
				return
			server._send_response({"success": true, "has_script": true, "source": s.source_code if s is GDScript else "", "path": s.resource_path})
		"attach":
			var source: String = params.get("source", "")
			if source.is_empty():
				server._send_response({"error": "source is required for attach"})
				return
			var blocked: String = _find_blocked_pattern(source)
			if not blocked.is_empty():
				server._send_response({"error": "Blocked operation: %s" % blocked})
				return
			var s: GDScript = GDScript.new()
			s.source_code = source
			var err: int = s.reload()
			if err != OK:
				server._send_response({"error": "Script compile error: %d" % err})
				return
			node.set_script(s)
			server._send_response({"success": true, "action": "attach", "node_path": node_path})
		"detach":
			node.set_script(null)
			server._send_response({"success": true, "action": "detach", "node_path": node_path})
		_:
			server._send_response({"error": "Unknown script action: %s" % action})


func _cmd_os_info(_params: Dictionary) -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	server._send_response({"success": true, "os_name": OS.get_name(), "locale": OS.get_locale(), "screen_size": {"x": screen_size.x, "y": screen_size.y}, "video_adapter": RenderingServer.get_video_adapter_name(), "processor_count": OS.get_processor_count()})


func _cmd_time_scale(params: Dictionary) -> void:
	var action: String = params.get("action", "get")
	if action == "set":
		Engine.time_scale = float(params.get("time_scale", 1.0))
	server._send_response({"success": true, "time_scale": Engine.time_scale, "ticks_msec": Time.get_ticks_msec(), "fps": Engine.get_frames_per_second()})


func _cmd_process_mode(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var mode_str: String = params.get("mode", "inherit")
	var mode_val: int = Node.PROCESS_MODE_INHERIT
	match mode_str:
		"pausable": mode_val = Node.PROCESS_MODE_PAUSABLE
		"when_paused": mode_val = Node.PROCESS_MODE_WHEN_PAUSED
		"always": mode_val = Node.PROCESS_MODE_ALWAYS
		"disabled": mode_val = Node.PROCESS_MODE_DISABLED
	node.process_mode = mode_val
	server._send_response({"success": true, "node_path": node_path, "mode": mode_str})


func _cmd_world_settings(params: Dictionary) -> void:
	var action: String = params.get("action", "get")
	if action == "set":
		if params.has("gravity"):
			ProjectSettings.set_setting("physics/3d/default_gravity", float(params["gravity"]))
		if params.has("physics_fps"):
			Engine.physics_ticks_per_second = int(params["physics_fps"])
	server._send_response({"success": true, "gravity": ProjectSettings.get_setting("physics/3d/default_gravity"), "physics_fps": Engine.physics_ticks_per_second})


# ==========================================================================
# Batch 2: 3D Rendering + Lighting + Sky + Physics
# ==========================================================================


func _cmd_raycast(params: Dictionary) -> void:
	var from_dict: Dictionary = params.get("from", {})
	var to_dict: Dictionary = params.get("to", {})
	var collision_mask: int = int(params.get("collision_mask", 0xFFFFFFFF))

	# Determine 2D vs 3D based on whether z is present
	var is_3d: bool = from_dict.has("z") or to_dict.has("z")

	if is_3d:
		var from_pos: Vector3 = Vector3(float(from_dict.get("x", 0)), float(from_dict.get("y", 0)), float(from_dict.get("z", 0)))
		var to_pos: Vector3 = Vector3(float(to_dict.get("x", 0)), float(to_dict.get("y", 0)), float(to_dict.get("z", 0)))

		# Wait a frame to ensure physics state is available
		await server.get_tree().process_frame

		var space_state: PhysicsDirectSpaceState3D = server.get_viewport().world_3d.direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos, collision_mask)
		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			server._send_response({"success": true, "hit": false, "mode": "3d"})
		else:
			server._send_response({
				"success": true, "hit": true, "mode": "3d",
				"position": McpSerialization.variant_to_json(result["position"]),
				"normal": McpSerialization.variant_to_json(result["normal"]),
				"collider_path": str(result["collider"].get_path()) if result.has("collider") and result["collider"] is Node else "",
				"collider_class": result["collider"].get_class() if result.has("collider") else "",
			})
	else:
		var from_pos: Vector2 = Vector2(float(from_dict.get("x", 0)), float(from_dict.get("y", 0)))
		var to_pos: Vector2 = Vector2(float(to_dict.get("x", 0)), float(to_dict.get("y", 0)))

		await server.get_tree().process_frame

		var space_state: PhysicsDirectSpaceState2D = server.get_viewport().world_2d.direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos, collision_mask)
		var result: Dictionary = space_state.intersect_ray(query)

		if result.is_empty():
			server._send_response({"success": true, "hit": false, "mode": "2d"})
		else:
			server._send_response({
				"success": true, "hit": true, "mode": "2d",
				"position": McpSerialization.variant_to_json(result["position"]),
				"normal": McpSerialization.variant_to_json(result["normal"]),
				"collider_path": str(result["collider"].get_path()) if result.has("collider") and result["collider"] is Node else "",
				"collider_class": result["collider"].get_class() if result.has("collider") else "",
			})


# --- Get Audio ---


func _cmd_navigate_path(params: Dictionary) -> void:
	var start_dict: Dictionary = params.get("start", {})
	var end_dict: Dictionary = params.get("end", {})
	var optimize: bool = params.get("optimize", true)

	if start_dict.is_empty() or end_dict.is_empty():
		server._send_response({"error": "start and end are required"})
		return

	# Wait a frame to ensure navigation map is ready
	await server.get_tree().process_frame

	var is_3d: bool = start_dict.has("z") or end_dict.has("z")

	if is_3d:
		var start_pos: Vector3 = Vector3(float(start_dict.get("x", 0)), float(start_dict.get("y", 0)), float(start_dict.get("z", 0)))
		var end_pos: Vector3 = Vector3(float(end_dict.get("x", 0)), float(end_dict.get("y", 0)), float(end_dict.get("z", 0)))
		var map_rid: RID = server.get_tree().root.get_world_3d().get_navigation_map()
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, start_pos, end_pos, optimize)
		var total_length: float = 0.0
		for i in range(1, path.size()):
			total_length += path[i - 1].distance_to(path[i])
		server._send_response({"success": true, "mode": "3d", "path": McpSerialization.variant_to_json(path), "point_count": path.size(), "total_length": total_length})
	else:
		var start_pos: Vector2 = Vector2(float(start_dict.get("x", 0)), float(start_dict.get("y", 0)))
		var end_pos: Vector2 = Vector2(float(end_dict.get("x", 0)), float(end_dict.get("y", 0)))
		var map_rid: RID = server.get_tree().root.get_world_2d().get_navigation_map()
		var path: PackedVector2Array = NavigationServer2D.map_get_path(map_rid, start_pos, end_pos, optimize)
		var total_length: float = 0.0
		for i in range(1, path.size()):
			total_length += path[i - 1].distance_to(path[i])
		server._send_response({"success": true, "mode": "2d", "path": McpSerialization.variant_to_json(path), "point_count": path.size(), "total_length": total_length})


# --- TileMap ---


func _cmd_terrain(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	if action == "create":
		var parent_path: String = params.get("parent_path", "/root")
		var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
		if parent == null:
			server._send_response({"error": "Parent not found: %s" % parent_path})
			return
		var width: int = max(2, int(params.get("width", 16)))
		var depth: int = max(2, int(params.get("depth", 16)))
		var max_height: float = float(params.get("max_height", 1.0))
		var height_data: Array = params.get("height_data", [])
		var heights: Array = []
		for i in range(width * depth):
			var h: float = float(height_data[i]) * max_height if i < height_data.size() else 0.0
			heights.append(h)
		var colors: Array = []
		for i in range(width * depth):
			colors.append(Color.WHITE)
		var mi: MeshInstance3D = MeshInstance3D.new()
		if params.has("name") and not (params["name"] as String).is_empty():
			mi.name = params["name"]
		mi.set_meta("terrain_width", width)
		mi.set_meta("terrain_depth", depth)
		mi.set_meta("terrain_heights", heights)
		mi.set_meta("terrain_colors", colors)
		parent.add_child(mi)
		_terrain_rebuild(mi)
		server._send_response({"success": true, "action": "create", "path": str(mi.get_path()), "width": width, "depth": depth})
		return
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is MeshInstance3D or not node.has_meta("terrain_width"):
		server._send_response({"error": "Terrain node not found: %s" % node_path})
		return
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	var t_width: int = mesh_node.get_meta("terrain_width")
	var t_depth: int = mesh_node.get_meta("terrain_depth")
	var t_heights: Array = mesh_node.get_meta("terrain_heights")
	var t_colors: Array = mesh_node.get_meta("terrain_colors")
	match action:
		"get_height":
			var gx: int = int(params.get("x", 0))
			var gz: int = int(params.get("z", 0))
			if gx < 0 or gx >= t_width or gz < 0 or gz >= t_depth:
				server._send_response({"error": "Coordinate out of bounds"})
				return
			server._send_response({"success": true, "action": "get_height", "x": gx, "z": gz, "height": t_heights[gz * t_width + gx]})
		"modify":
			var cx: float = float(params.get("x", 0))
			var cz: float = float(params.get("z", 0))
			var radius: float = float(params.get("radius", 1.0))
			var delta: float = float(params.get("height_delta", 0.0))
			for z in range(t_depth):
				for x in range(t_width):
					var d: float = Vector2(x - cx, z - cz).length()
					if d <= radius:
						var falloff: float = 1.0 - (d / radius) if radius > 0.0 else 1.0
						t_heights[z * t_width + x] += delta * falloff
			mesh_node.set_meta("terrain_heights", t_heights)
			_terrain_rebuild(mesh_node)
			server._send_response({"success": true, "action": "modify"})
		"paint":
			var cx: float = float(params.get("x", 0))
			var cz: float = float(params.get("z", 0))
			var radius: float = float(params.get("radius", 1.0))
			var col_d: Dictionary = params.get("color", {"r": 1, "g": 1, "b": 1, "a": 1})
			var col: Color = Color(float(col_d.get("r", 1)), float(col_d.get("g", 1)), float(col_d.get("b", 1)), float(col_d.get("a", 1)))
			for z in range(t_depth):
				for x in range(t_width):
					if Vector2(x - cx, z - cz).length() <= radius:
						t_colors[z * t_width + x] = col
			mesh_node.set_meta("terrain_colors", t_colors)
			_terrain_rebuild(mesh_node)
			server._send_response({"success": true, "action": "paint"})
		_:
			server._send_response({"error": "Unknown terrain action: %s" % action})


func _cmd_locale(params: Dictionary) -> void:
	var action: String = params.get("action", "get")
	match action:
		"get":
			server._send_response({"success": true, "locale": TranslationServer.get_locale()})
		"set":
			var locale: String = params.get("locale", "en")
			TranslationServer.set_locale(locale)
			server._send_response({"success": true, "action": "set", "locale": locale})
		"translate":
			var key: String = params.get("key", "")
			var translated: String = tr(key)
			server._send_response({"success": true, "key": key, "translated": translated})
		_:
			server._send_response({"error": "Unknown locale action: %s" % action})


# ==========================================================================
# Batch 5: UI Controls + Rendering + Resource Runtime
# ==========================================================================


func _build_tree_node(node: Node) -> Dictionary:
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
	}
	var children_arr: Array = []
	for child in node.get_children():
		children_arr.append(_build_tree_node(child))
	if children_arr.size() > 0:
		info["children"] = children_arr
	return info


# --- Key String to Keycode ---


func _indent_code(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	# Убираем общий отступ до переиндентации табами: иначе "Mixed use of
	# tabs and spaces" в debug-режиме ставит игру на паузу (debugger break).
	var min_indent: int = 9999
	for line in lines:
		if line.strip_edges().is_empty():
			continue
		min_indent = mini(min_indent, _leading_ws_len(line))
	if min_indent == 9999:
		min_indent = 0
	var indented: String = ""
	for line in lines:
		if line.strip_edges().is_empty():
			indented += "\n"
			continue
		var body: String = line.substr(min_indent)
		var ws: int = _leading_ws_len(body)
		# Каждая вложенность: 1 таб или до 4 пробелов. Итог: только табы.
		var level: int = 0
		var i: int = 0
		while i < ws:
			if body[i] == "\t":
				i += 1
			else:
				i += mini(4, ws - i)
			level += 1
		indented += "\t".repeat(1 + level) + body.substr(ws) + "\n"
	return indented


func _leading_ws_len(s: String) -> int:
	var n: int = 0
	while n < s.length() and (s[n] == " " or s[n] == "\t"):
		n += 1
	return n


# --- Get Property ---


func _json_to_variant_for_property(node: Node, property: String, value: Variant) -> Variant:
	for prop in node.get_property_list():
		if prop["name"] == property:
			var type_id: int = prop.get("type", 0)
			match type_id:
				TYPE_VECTOR2:
					return McpSerialization.json_to_variant(value, "Vector2")
				TYPE_VECTOR2I:
					return McpSerialization.json_to_variant(value, "Vector2i")
				TYPE_VECTOR3:
					return McpSerialization.json_to_variant(value, "Vector3")
				TYPE_VECTOR3I:
					return McpSerialization.json_to_variant(value, "Vector3i")
				TYPE_COLOR:
					return McpSerialization.json_to_variant(value, "Color")
				TYPE_QUATERNION:
					return McpSerialization.json_to_variant(value, "Quaternion")
				TYPE_RECT2:
					return McpSerialization.json_to_variant(value, "Rect2")
				TYPE_AABB:
					return McpSerialization.json_to_variant(value, "AABB")
				TYPE_BASIS:
					return McpSerialization.json_to_variant(value, "Basis")
				TYPE_TRANSFORM3D:
					return McpSerialization.json_to_variant(value, "Transform3D")
				TYPE_TRANSFORM2D:
					return McpSerialization.json_to_variant(value, "Transform2D")
				TYPE_BOOL:
					if value is String:
						return value.to_lower() == "true"
					return bool(value)
				TYPE_INT:
					return int(value)
				TYPE_FLOAT:
					return float(value)
			break
	# No type info found, use raw value or auto-detect
	return McpSerialization.json_to_variant(value)


# --- Connect Signal ---


# --- Reparent Node ---


func _serialize_node(node: Node, max_depth: int, depth: int) -> Dictionary:
	var result: Dictionary = {
		"class": node.get_class(),
		"name": node.name,
		"path": str(node.get_path()),
	}
	# Capture editor-visible properties
	var props: Dictionary = {}
	for prop in node.get_property_list():
		var prop_dict: Dictionary = prop
		if prop_dict.get("usage", 0) & PROPERTY_USAGE_STORAGE:
			var prop_name: String = prop_dict.get("name", "")
			if prop_name.is_empty() or prop_name.begins_with("_"):
				continue
			props[prop_name] = McpSerialization.variant_to_json(node.get(prop_name))
	result["properties"] = props

	if depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			# Skip the MCP interaction server itself
			if child == self:
				continue
			children.append(_serialize_node(child, max_depth, depth + 1))
		result["children"] = children

	return result


func _deserialize_node(node: Node, data: Dictionary) -> int:
	var count: int = 0
	# Restore properties
	var props: Dictionary = data.get("properties", {})
	for prop_name in props:
		var value: Variant = _json_to_variant_for_property(node, prop_name, props[prop_name])
		node.set(prop_name, value)
	count += 1

	# Restore children
	var children_data: Array = data.get("children", [])
	for child_data in children_data:
		var child_name: String = child_data.get("name", "")
		var child: Node = null
		for c in node.get_children():
			if c.name == child_name:
				child = c
				break
		if child != null:
			count += _deserialize_node(child, child_data)
	return count


# --- Physics Body ---


func _clear_debug_draw() -> void:
	for entry in _debug_meshes:
		if is_instance_valid(entry["node"]):
			entry["node"].queue_free()
	_debug_meshes.clear()
	if _debug_draw_node != null and is_instance_valid(_debug_draw_node):
		_debug_draw_node.queue_free()
		_debug_draw_node = null


# ==========================================================================
# Batch 1: Networking + Input + System + Signals + Script
# ==========================================================================


func _terrain_rebuild(mi: MeshInstance3D) -> void:
	var width: int = mi.get_meta("terrain_width")
	var depth: int = mi.get_meta("terrain_depth")
	var heights: Array = mi.get_meta("terrain_heights")
	var colors: Array = mi.get_meta("terrain_colors")
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(depth - 1):
		for x in range(width - 1):
			var i00: int = z * width + x
			var i10: int = z * width + (x + 1)
			var i01: int = (z + 1) * width + x
			var i11: int = (z + 1) * width + (x + 1)
			var v00: Vector3 = Vector3(x, heights[i00], z)
			var v10: Vector3 = Vector3(x + 1, heights[i10], z)
			var v01: Vector3 = Vector3(x, heights[i01], z + 1)
			var v11: Vector3 = Vector3(x + 1, heights[i11], z + 1)
			for tri in [[i00, v00], [i10, v10], [i01, v01], [i10, v10], [i11, v11], [i01, v01]]:
				st.set_color(colors[tri[0]])
				st.add_vertex(tri[1])
	st.generate_normals()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	st.set_material(mat)
	mi.mesh = st.commit()
