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


## Whether the given command suspends (its implementation uses await).
func is_async(command: String) -> bool:
	return false


## Execute a command by name. Returns the handler result (or an error dict).
func execute(command: String, params: Dictionary) -> Variant:
	var handler: Callable = get_commands().get(command, Callable())
	if not handler.is_valid():
		return {"error": "Unknown command: %s" % command}
	return await handler.call(params)


## Shared helper: collect nodes of a class under a root (used by render + system groups).
func _find_by_class_recursive(node: Node, class_filter: String, results: Array) -> void:
	if node.get_class() == class_filter or node.is_class(class_filter):
		results.append({
			"name": node.name,
			"type": node.get_class(),
			"path": str(node.get_path())
		})
	for child in node.get_children():
		_find_by_class_recursive(child, class_filter, results)
