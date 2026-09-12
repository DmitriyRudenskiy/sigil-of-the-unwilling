class_name McpCommandsBase
extends RefCounted
## Base class for MCP command groups.
## A group owns a set of MCP commands: get_commands() maps command name -> bound Callable.
## All command methods take (params: Dictionary) and send their reply via server._send_response().

var server: Node  # McpInteractionServer


func _init(s: Node) -> void:
	server = s


## Map of command name -> Callable.
func get_commands() -> Dictionary:
	return {}


## Rejects the request unless the server is in the scene tree. Returns false if rejected.
func _require_scene_tree() -> bool:
	if not server.is_inside_tree():
		# TASK_20: _send_response (не raw) — гарантированно сбрасывает _busy, исключая deadlock.
		server._send_response({"error": "Server not in scene tree"})
		return false
	return true


## Execute a command by name. Returns the handler result (or an error dict).
func execute(command: String, params: Dictionary) -> Variant:
	var handler: Callable = get_commands().get(command, Callable())
	if not handler.is_valid():
		return {"error": "Unknown command: %s" % command}
	# TASK_19 M3: центральная проверка — отдельные команды её не дублируют.
	if not _require_scene_tree():
		return null
	return await handler.call(params)


## Shared helper: collect nodes of a class under a root (used by render + system groups).
## Iterative DFS (TASK_18 R8): no stack overflow on deep trees, no infinite
## recursion if a cycle is ever introduced into the node tree.
func _find_by_class_recursive(root: Node, class_filter: String, results: Array) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.get_class() == class_filter or node.is_class(class_filter):
			results.append({
				"name": node.name,
				"type": node.get_class(),
				"path": str(node.get_path())
			})
		for child: Node in node.get_children():
			stack.push_back(child)
