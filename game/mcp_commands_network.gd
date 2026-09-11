class_name McpCommandsNetwork
extends McpCommandsBase

## Experimental debug-only group (TASK_18 YAGNI): the http/websocket/multiplayer/rpc
## commands were removed because no game feature or test uses them. The class is kept
## as an empty group so the server dispatcher shape stays stable.
func get_commands() -> Dictionary:
	return {}
