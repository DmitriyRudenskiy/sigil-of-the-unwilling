class_name McpCommandDispatcher
extends RefCounted
## R2 (world-controller-decoupling): owns the flat MCP command registry and
## routing, decoupled from the TCP transport.
## The server node keeps transport + auth + busy state and delegates
## "which commands exist / may run / invoke" to this RefCounted.

var _handlers: Dictionary = {}


## Registers all commands of a group (later groups override earlier names).
func register(group: McpCommandsBase) -> void:
	var cmds: Dictionary = group.get_commands()
	for cmd in cmds:
		_handlers[cmd] = cmds[cmd]


func has(command: String) -> bool:
	return _handlers.has(command)


func command_names() -> Array:
	return _handlers.keys()


func clear() -> void:
	_handlers.clear()


## Routes a command. Returns an error dict when the command is unknown or the
## server is not in the scene tree; otherwise awaits the handler, which sends
## its own response via the server (established group contract).
func dispatch(command: String, params: Dictionary, in_scene_tree: bool) -> Variant:
	if not _handlers.has(command):
		return {"error": "Unknown command: %s" % command}
	# TASK_19 M3: центральная проверка сцены (заменяет дубли в командах).
	if not in_scene_tree:
		return {"error": "Server not in scene tree"}
	var handler: Callable = _handlers[command]
	return await handler.call(params)
