class_name McpCommandsNetwork
extends McpCommandsBase

var _websocket: WebSocketPeer = null

func get_commands() -> Dictionary:
	return {
		"http_request": _cmd_http_request,
		"websocket": _cmd_websocket,
		"multiplayer": _cmd_multiplayer,
		"rpc": _cmd_rpc,
	}

func _cmd_http_request(params: Dictionary) -> void:
	var url: String = params.get("url", "")
	if url.is_empty():
		server._send_response({"error": "url is required"})
		return
	var method_str: String = params.get("method", "GET").to_upper()
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = float(params.get("timeout", 30))
	server.add_child(http)
	var headers: PackedStringArray = PackedStringArray()
	if params.has("headers"):
		var h: Dictionary = params["headers"]
		for k in h:
			headers.append("%s: %s" % [k, str(h[k])])
	var method_enum: int = HTTPClient.METHOD_GET
	match method_str:
		"POST": method_enum = HTTPClient.METHOD_POST
		"PUT": method_enum = HTTPClient.METHOD_PUT
		"DELETE": method_enum = HTTPClient.METHOD_DELETE
	var body: String = params.get("body", "")
	var err: int = http.request(url, headers, method_enum, body)
	if err != OK:
		http.queue_free()
		server._send_response({"error": "HTTP request failed to start: %d" % err})
		return
	var result: Array = await http.request_completed
	http.queue_free()
	server._send_response({"success": true, "status_code": result[1], "body": result[3].get_string_from_utf8()})


func _cmd_websocket(params: Dictionary) -> void:
	var action: String = params.get("action", "")
	match action:
		"connect":
			var url: String = params.get("url", "")
			if url.is_empty():
				server._send_response({"error": "url is required for connect"})
				return
			_websocket = WebSocketPeer.new()
			var err: int = _websocket.connect_to_url(url)
			if err != OK:
				server._send_response({"error": "WebSocket connect failed: %d" % err})
				_websocket = null
				return
			server._send_response({"success": true, "action": "connect", "url": url})
		"disconnect":
			if _websocket != null:
				_websocket.close()
				_websocket = null
			server._send_response({"success": true, "action": "disconnect"})
		"send":
			if _websocket == null:
				server._send_response({"error": "No WebSocket connection"})
				return
			_websocket.poll()
			var msg: String = params.get("message", "")
			_websocket.send_text(msg)
			server._send_response({"success": true, "action": "send"})
		"status":
			if _websocket == null:
				server._send_response({"success": true, "status": "disconnected"})
				return
			_websocket.poll()
			server._send_response({"success": true, "status": _websocket.get_ready_state()})
		_:
			server._send_response({"error": "Unknown websocket action: %s" % action})


func _cmd_multiplayer(params: Dictionary) -> void:
	var action: String = params.get("action", "")
	match action:
		"create_server":
			var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
			var port: int = int(params.get("port", 7000))
			var max_cl: int = int(params.get("max_clients", 32))
			var err: int = peer.create_server(port, max_cl)
			if err != OK:
				server._send_response({"error": "Failed to create server: %d" % err})
				return
			server.multiplayer.multiplayer_peer = peer
			server._send_response({"success": true, "action": "create_server", "port": port})
		"create_client":
			var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
			var address: String = params.get("address", "127.0.0.1")
			var port: int = int(params.get("port", 7000))
			var err: int = peer.create_client(address, port)
			if err != OK:
				server._send_response({"error": "Failed to create client: %d" % err})
				return
			server.multiplayer.multiplayer_peer = peer
			server._send_response({"success": true, "action": "create_client", "address": address, "port": port})
		"disconnect":
			server.multiplayer.multiplayer_peer = null
			server._send_response({"success": true, "action": "disconnect"})
		"status":
			var peer = server.multiplayer.multiplayer_peer
			if peer == null:
				server._send_response({"success": true, "connected": false})
				return
			server._send_response({"success": true, "connected": true, "unique_id": server.multiplayer.get_unique_id(), "is_server": server.multiplayer.is_server()})
		_:
			server._send_response({"error": "Unknown multiplayer action: %s" % action})


func _cmd_rpc(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "call")
	var method: String = params.get("method", "")
	if method.is_empty():
		server._send_response({"error": "method is required"})
		return
	if action == "call":
		var args: Array = params.get("args", [])
		node.rpc(method, args)
		server._send_response({"success": true, "action": "call", "method": method})
	elif action == "configure":
		var config: Dictionary = {}
		if params.has("mode"):
			var m: Variant = params["mode"]
			if m is String:
				match (m as String).to_lower():
					"any_peer": config["rpc_mode"] = MultiplayerAPI.RPC_MODE_ANY_PEER
					"authority": config["rpc_mode"] = MultiplayerAPI.RPC_MODE_AUTHORITY
			else:
				config["rpc_mode"] = int(m)
		if params.has("sync"):
			var sync_val: Variant = params["sync"]
			if sync_val is String:
				config["call_local"] = (sync_val as String).to_lower() == "call_local"
			else:
				config["call_local"] = bool(sync_val)
		if params.has("channel"):
			config["channel"] = int(params["channel"])
		node.rpc_config(method, config)
		server._send_response({"success": true, "action": "configure", "method": method, "config": config})
	else:
		server._send_response({"error": "Unknown rpc action: %s" % action})


func _close_websocket() -> void:
	if _websocket != null:
		_websocket.close()
		_websocket = null
