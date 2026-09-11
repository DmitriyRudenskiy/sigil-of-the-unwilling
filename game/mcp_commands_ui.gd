class_name McpCommandsUI
extends McpCommandsBase

var _canvas_draw_node: Node2D = null
var _draw_commands: Array = []

func get_commands() -> Dictionary:
	return {
		"screenshot": _cmd_screenshot,
		"get_ui_elements": _cmd_get_ui_elements,
		"ui_theme": _cmd_ui_theme,
		"ui_control": _cmd_ui_control,
		"ui_text": _cmd_ui_text,
		"ui_popup": _cmd_ui_popup,
		"ui_tree": _cmd_ui_tree,
		"ui_item_list": _cmd_ui_item_list,
		"ui_tabs": _cmd_ui_tabs,
		"ui_menu": _cmd_ui_menu,
		"ui_range": _cmd_ui_range,
		"viewport": _cmd_viewport,
		"window": _cmd_window,
		"canvas_draw": _cmd_canvas_draw,
		"video": _cmd_video,
	}

func _cmd_screenshot(_params: Dictionary) -> void:
	# Wait one frame so the viewport is fully rendered
	await server.get_tree().process_frame
	var image: Image = server.get_viewport().get_texture().get_image()
	if image == null:
		server._send_response({"error": "Failed to capture screenshot"})
		return
	var png_buffer: PackedByteArray = image.save_png_to_buffer()
	var base64_str: String = Marshalls.raw_to_base64(png_buffer)
	server._send_response({
		"success": true,
		"data": base64_str,
		"width": image.get_width(),
		"height": image.get_height()
	})


# --- Click ---


func _cmd_get_ui_elements(_params: Dictionary) -> void:
	var elements: Array = []
	_collect_ui_elements(server.get_tree().root, elements)
	server._send_response({"success": true, "elements": elements})


func _cmd_ui_theme(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is Control:
		server._send_response({"error": "Node is not a Control: %s (is %s)" % [node_path, node.get_class()]})
		return

	var ctrl: Control = node as Control
	var overrides: Dictionary = params.get("overrides", {})
	var applied: Array = []

	# Color overrides
	var colors: Dictionary = overrides.get("colors", {})
	for name in colors:
		var c: Dictionary = colors[name]
		ctrl.add_theme_color_override(name, Color(float(c.get("r", 0)), float(c.get("g", 0)), float(c.get("b", 0)), float(c.get("a", 1))))
		applied.append("color:" + name)

	# Constant overrides
	var constants: Dictionary = overrides.get("constants", {})
	for name in constants:
		ctrl.add_theme_constant_override(name, int(constants[name]))
		applied.append("constant:" + name)

	# Font size overrides
	var font_sizes: Dictionary = overrides.get("fontSizes", overrides.get("font_sizes", {}))
	for name in font_sizes:
		ctrl.add_theme_font_size_override(name, int(font_sizes[name]))
		applied.append("font_size:" + name)

	server._send_response({"success": true, "node_path": node_path, "applied": applied})


# --- Viewport ---


func _cmd_ui_control(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is Control:
		server._send_response({"error": "Control not found: %s" % node_path})
		return
	var ctrl: Control = node as Control
	var action: String = params.get("action", "get_info")
	match action:
		"grab_focus":
			ctrl.grab_focus()
			server._send_response({"success": true, "action": "grab_focus"})
		"release_focus":
			ctrl.release_focus()
			server._send_response({"success": true, "action": "release_focus"})
		"configure":
			var applied: Array = []
			if params.has("tooltip"):
				ctrl.tooltip_text = str(params["tooltip"])
				applied.append("tooltip")
			if params.has("mouse_filter"):
				match params["mouse_filter"]:
					"stop": ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
					"pass": ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
					"ignore": ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				applied.append("mouse_filter")
			if params.has("min_size"):
				var s: Dictionary = params["min_size"]
				ctrl.custom_minimum_size = Vector2(float(s.get("x", 0)), float(s.get("y", 0)))
				applied.append("min_size")
			if params.has("anchor_preset"):
				var preset: int = _resolve_anchor_preset(params["anchor_preset"])
				if preset < 0:
					server._send_response({"error": "Invalid anchor_preset: %s" % str(params["anchor_preset"])})
					return
				ctrl.set_anchors_and_offsets_preset(preset as Control.LayoutPreset)
				applied.append("anchor_preset")
			server._send_response({"success": true, "action": "configure", "applied": applied})
		"get_info":
			server._send_response({"success": true, "size": McpSerialization.variant_to_json(ctrl.size), "position": McpSerialization.variant_to_json(ctrl.position), "has_focus": ctrl.has_focus(), "visible": ctrl.visible, "tooltip": ctrl.tooltip_text, "mouse_filter": ctrl.mouse_filter})
		_:
			server._send_response({"error": "Unknown ui_control action: %s" % action})


func _cmd_ui_text(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get")
	match action:
		"get":
			var text: String = ""
			if node is LineEdit: text = (node as LineEdit).text
			elif node is TextEdit: text = (node as TextEdit).text
			elif node is RichTextLabel: text = (node as RichTextLabel).text
			else:
				server._send_response({"error": "Node is not a text control"})
				return
			server._send_response({"success": true, "text": text})
		"set":
			var text: String = str(params.get("text", ""))
			if node is LineEdit: (node as LineEdit).text = text
			elif node is TextEdit: (node as TextEdit).text = text
			elif node is RichTextLabel: (node as RichTextLabel).text = text
			else:
				server._send_response({"error": "Node is not a text control (LineEdit/TextEdit/RichTextLabel): %s" % node.get_class()})
				return
			server._send_response({"success": true, "action": "set"})
		"append":
			var text: String = str(params.get("text", ""))
			if node is TextEdit: (node as TextEdit).text += text
			elif node is RichTextLabel: (node as RichTextLabel).append_text(text)
			elif node is LineEdit: (node as LineEdit).text += text
			else:
				server._send_response({"error": "Node is not a text control (LineEdit/TextEdit/RichTextLabel): %s" % node.get_class()})
				return
			server._send_response({"success": true, "action": "append"})
		"clear":
			if node is LineEdit: (node as LineEdit).text = ""
			elif node is TextEdit: (node as TextEdit).text = ""
			elif node is RichTextLabel: (node as RichTextLabel).clear()
			else:
				server._send_response({"error": "Node is not a text control (LineEdit/TextEdit/RichTextLabel): %s" % node.get_class()})
				return
			server._send_response({"success": true, "action": "clear"})
		"bbcode":
			if node is RichTextLabel:
				(node as RichTextLabel).bbcode_enabled = true
				(node as RichTextLabel).text = str(params.get("text", ""))
			else:
				server._send_response({"error": "Node is not a RichTextLabel: %s" % node.get_class()})
				return
			server._send_response({"success": true, "action": "bbcode"})
		_:
			server._send_response({"error": "Unknown ui_text action: %s" % action})


func _cmd_ui_popup(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is Window:
		server._send_response({"error": "Window/Popup not found: %s" % node_path})
		return
	var win: Window = node as Window
	var action: String = params.get("action", "popup_centered")
	match action:
		"popup_centered":
			if params.has("size"):
				var s: Dictionary = params["size"]
				win.popup_centered(Vector2i(int(s.get("x", 200)), int(s.get("y", 100))))
			else:
				win.popup_centered()
			server._send_response({"success": true, "action": "popup_centered"})
		"popup":
			win.popup()
			server._send_response({"success": true, "action": "popup"})
		"hide":
			win.hide()
			server._send_response({"success": true, "action": "hide"})
		"get_info":
			server._send_response({"success": true, "visible": win.visible, "title": win.title, "size": McpSerialization.variant_to_json(win.size)})
		_:
			server._send_response({"error": "Unknown ui_popup action: %s" % action})


func _cmd_ui_tree(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is Tree:
		server._send_response({"error": "Tree not found: %s" % node_path})
		return
	var tree: Tree = node as Tree
	var action: String = params.get("action", "get_items")
	match action:
		"get_items":
			var items: Array = []
			var root: TreeItem = tree.get_root()
			if root != null:
				_collect_tree_items(root, items, 0)
			server._send_response({"success": true, "action": "get_items", "items": items})
		"add":
			var text: String = str(params.get("text", "Item"))
			var root: TreeItem = tree.get_root()
			if root == null:
				root = tree.create_item()
			var item: TreeItem = tree.create_item(root)
			item.set_text(int(params.get("column", 0)), text)
			server._send_response({"success": true, "action": "add", "text": text})
		_:
			server._send_response({"error": "Unknown ui_tree action: %s" % action})


func _cmd_ui_item_list(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get_items")
	if node is ItemList:
		var il: ItemList = node as ItemList
		match action:
			"get_items":
				var items: Array = []
				for i in il.item_count:
					items.append({"index": i, "text": il.get_item_text(i), "selected": il.is_selected(i)})
				server._send_response({"success": true, "items": items})
			"select":
				il.select(int(params.get("index", 0)))
				server._send_response({"success": true, "action": "select"})
			"add":
				il.add_item(str(params.get("text", "Item")))
				server._send_response({"success": true, "action": "add"})
			"remove":
				il.remove_item(int(params.get("index", 0)))
				server._send_response({"success": true, "action": "remove"})
			"clear":
				il.clear()
				server._send_response({"success": true, "action": "clear"})
			_:
				server._send_response({"error": "Unknown ui_item_list action: %s" % action})
	elif node is OptionButton:
		var ob: OptionButton = node as OptionButton
		match action:
			"get_items":
				var items: Array = []
				for i in ob.item_count:
					items.append({"index": i, "text": ob.get_item_text(i)})
				server._send_response({"success": true, "items": items, "selected": ob.selected})
			"select":
				ob.select(int(params.get("index", 0)))
				server._send_response({"success": true, "action": "select"})
			"add":
				ob.add_item(str(params.get("text", "Item")))
				server._send_response({"success": true, "action": "add"})
			_:
				server._send_response({"error": "Unknown action for OptionButton: %s" % action})
	else:
		server._send_response({"error": "Node is not ItemList or OptionButton"})


func _cmd_ui_tabs(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get_tabs")
	if node is TabContainer:
		var tc: TabContainer = node as TabContainer
		match action:
			"get_tabs":
				var tabs: Array = []
				for i in tc.get_tab_count():
					tabs.append({"index": i, "title": tc.get_tab_title(i)})
				server._send_response({"success": true, "tabs": tabs, "current": tc.current_tab})
			"set_current":
				tc.current_tab = int(params.get("index", 0))
				server._send_response({"success": true, "action": "set_current"})
			"set_title":
				tc.set_tab_title(int(params.get("index", 0)), str(params.get("title", "")))
				server._send_response({"success": true, "action": "set_title"})
			_:
				server._send_response({"error": "Unknown ui_tabs action: %s" % action})
	elif node is TabBar:
		var tb: TabBar = node as TabBar
		match action:
			"get_tabs":
				var tabs: Array = []
				for i in tb.tab_count:
					tabs.append({"index": i, "title": tb.get_tab_title(i)})
				server._send_response({"success": true, "tabs": tabs, "current": tb.current_tab})
			"set_current":
				tb.current_tab = int(params.get("index", 0))
				server._send_response({"success": true, "action": "set_current"})
			_:
				server._send_response({"error": "Unknown ui_tabs action: %s" % action})
	else:
		server._send_response({"error": "Node is not TabContainer or TabBar"})


func _cmd_ui_menu(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is PopupMenu:
		server._send_response({"error": "PopupMenu not found: %s" % node_path})
		return
	var menu: PopupMenu = node as PopupMenu
	var action: String = params.get("action", "get_items")
	match action:
		"get_items":
			var items: Array = []
			for i in menu.item_count:
				items.append({"index": i, "text": menu.get_item_text(i), "checked": menu.is_item_checked(i), "disabled": menu.is_item_disabled(i), "id": menu.get_item_id(i)})
			server._send_response({"success": true, "items": items})
		"add":
			var text: String = str(params.get("text", "Item"))
			var id: int = int(params.get("id", -1))
			menu.add_item(text, id)
			server._send_response({"success": true, "action": "add"})
		"remove":
			menu.remove_item(int(params.get("index", 0)))
			server._send_response({"success": true, "action": "remove"})
		"set_checked":
			menu.set_item_checked(int(params.get("index", 0)), bool(params.get("checked", true)))
			server._send_response({"success": true, "action": "set_checked"})
		"clear":
			menu.clear()
			server._send_response({"success": true, "action": "clear"})
		_:
			server._send_response({"error": "Unknown ui_menu action: %s" % action})


func _cmd_ui_range(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get")
	if node is Range:
		var r: Range = node as Range
		if action == "get":
			server._send_response({"success": true, "value": r.value, "min": r.min_value, "max": r.max_value, "step": r.step})
			return
		if params.has("value"): r.value = float(params["value"])
		if params.has("min_value"): r.min_value = float(params["min_value"])
		if params.has("max_value"): r.max_value = float(params["max_value"])
		if params.has("step"): r.step = float(params["step"])
		server._send_response({"success": true, "action": "set", "value": r.value})
	elif node is ColorPicker:
		var cp: ColorPicker = node as ColorPicker
		if action == "get":
			var c: Color = cp.color
			server._send_response({"success": true, "color": {"r": c.r, "g": c.g, "b": c.b, "a": c.a}})
			return
		if params.has("color"):
			var cd: Dictionary = params["color"]
			cp.color = Color(float(cd.get("r", 0)), float(cd.get("g", 0)), float(cd.get("b", 0)), float(cd.get("a", 1)))
		server._send_response({"success": true, "action": "set"})
	else:
		server._send_response({"error": "Node is not Range or ColorPicker"})


func _cmd_viewport(params: Dictionary) -> void:
	var action: String = params.get("action", "create")

	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent node not found: %s" % parent_path})
				return
			var viewport: SubViewport = SubViewport.new()
			if params.has("width") and params.has("height"):
				viewport.size = Vector2i(int(params["width"]), int(params["height"]))
			if params.has("transparent_bg"):
				viewport.transparent_bg = bool(params["transparent_bg"])
			if params.has("msaa"):
				viewport.msaa_2d = int(params["msaa"]) as Viewport.MSAA
				viewport.msaa_3d = int(params["msaa"]) as Viewport.MSAA
			if params.has("name") and params["name"] is String and not (params["name"] as String).is_empty():
				viewport.name = params["name"]
			var container: SubViewportContainer = SubViewportContainer.new()
			container.add_child(viewport)
			parent.add_child(container)
			server._send_response({"success": true, "action": "create", "viewport_path": str(viewport.get_path()), "container_path": str(container.get_path()), "size": McpSerialization.variant_to_json(viewport.size)})
		"configure":
			var node_path: String = params.get("node_path", "")
			if node_path.is_empty():
				server._send_response({"error": "node_path is required for configure"})
				return
			var vp: Node = server.get_tree().root.get_node_or_null(node_path)
			if vp == null or not vp is SubViewport:
				server._send_response({"error": "SubViewport not found: %s" % node_path})
				return
			var sv: SubViewport = vp as SubViewport
			if params.has("width") and params.has("height"):
				sv.size = Vector2i(int(params["width"]), int(params["height"]))
			if params.has("transparent_bg"):
				sv.transparent_bg = bool(params["transparent_bg"])
			if params.has("msaa"):
				sv.msaa_2d = int(params["msaa"]) as Viewport.MSAA
				sv.msaa_3d = int(params["msaa"]) as Viewport.MSAA
			server._send_response({"success": true, "action": "configure", "size": McpSerialization.variant_to_json(sv.size), "transparent_bg": sv.transparent_bg})
		"get":
			var node_path: String = params.get("node_path", "")
			if node_path.is_empty():
				server._send_response({"error": "node_path is required for get"})
				return
			var vp: Node = server.get_tree().root.get_node_or_null(node_path)
			if vp == null or not vp is SubViewport:
				server._send_response({"error": "SubViewport not found: %s" % node_path})
				return
			var sv: SubViewport = vp as SubViewport
			server._send_response({"success": true, "action": "get", "size": McpSerialization.variant_to_json(sv.size), "transparent_bg": sv.transparent_bg, "msaa_2d": sv.msaa_2d, "msaa_3d": sv.msaa_3d})
		_:
			server._send_response({"error": "Unknown viewport action: %s. Use create, configure, or get" % action})


# --- Debug Draw ---


func _cmd_window(params: Dictionary) -> void:
	var action: String = params.get("action", "get")
	var win: Window = server.get_tree().root
	if action == "get":
		server._send_response({"success": true, "size": {"x": win.size.x, "y": win.size.y}, "position": {"x": win.position.x, "y": win.position.y}, "fullscreen": win.mode == Window.MODE_FULLSCREEN, "borderless": win.borderless, "title": win.title})
		return
	if params.has("width") and params.has("height"):
		win.size = Vector2i(int(params["width"]), int(params["height"]))
	if params.has("fullscreen"):
		win.mode = Window.MODE_FULLSCREEN if bool(params["fullscreen"]) else Window.MODE_WINDOWED
	if params.has("borderless"):
		win.borderless = bool(params["borderless"])
	if params.has("title"):
		win.title = str(params["title"])
	if params.has("position"):
		var p: Dictionary = params["position"]
		win.position = Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))
	if params.has("vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(params["vsync"]) else DisplayServer.VSYNC_DISABLED)
	server._send_response({"success": true, "action": "set", "size": {"x": win.size.x, "y": win.size.y}})


func _cmd_canvas_draw(params: Dictionary) -> void:
	var action: String = params.get("action", "line")
	if action == "clear":
		_draw_commands.clear()
		if _canvas_draw_node != null and is_instance_valid(_canvas_draw_node):
			_canvas_draw_node.queue_redraw()
		server._send_response({"success": true, "action": "clear"})
		return
	if not action in ["line", "rect", "circle", "polygon", "text"]:
		server._send_response({"error": "Unknown canvas_draw action: %s" % action})
		return
	# Ensure draw node
	if _canvas_draw_node == null or not is_instance_valid(_canvas_draw_node):
		var parent_path: String = params.get("parent_path", "/root")
		var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
		if parent == null:
			server._send_response({"error": "Parent not found: %s" % parent_path})
			return
		_canvas_draw_node = Node2D.new()
		_canvas_draw_node.name = "_McpCanvasDraw"
		_canvas_draw_node.set_script(_create_draw_script())
		parent.add_child(_canvas_draw_node)
		_canvas_draw_node.set("draw_commands", _draw_commands)
	var color_d: Dictionary = params.get("color", {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0})
	var color: Color = Color(float(color_d.get("r", 1)), float(color_d.get("g", 1)), float(color_d.get("b", 1)), float(color_d.get("a", 1)))
	_draw_commands.append({"action": action, "params": params, "color": color})
	_canvas_draw_node.set("draw_commands", _draw_commands)
	_canvas_draw_node.queue_redraw()
	server._send_response({"success": true, "action": action})


func _cmd_video(params: Dictionary) -> void:
	var action: String = params.get("action", "play")
	if action == "create":
		var parent_path: String = params.get("parent_path", "/root")
		var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
		if parent == null:
			server._send_response({"error": "Parent not found: %s" % parent_path})
			return
		var vp: VideoStreamPlayer = VideoStreamPlayer.new()
		var video_path: String = params.get("video_path", "")
		if not video_path.is_empty():
			if not ResourceLoader.exists(video_path):
				server._send_response({"error": "Video resource not found: %s" % video_path})
				return
			var stream: Resource = ResourceLoader.load(video_path)
			if not stream is VideoStream:
				server._send_response({"error": "Resource is not a VideoStream: %s" % video_path})
				return
			vp.stream = stream
		if params.has("volume"):
			vp.volume = float(params["volume"])
		if params.has("autoplay"):
			vp.autoplay = bool(params["autoplay"])
		if params.has("loop") and "loop" in vp:
			vp.set("loop", bool(params["loop"]))
		if params.has("name") and not (params["name"] as String).is_empty():
			vp.name = params["name"]
		parent.add_child(vp)
		if vp.autoplay:
			vp.play()
		server._send_response({"success": true, "action": "create", "path": str(vp.get_path())})
		return
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is VideoStreamPlayer:
		server._send_response({"error": "VideoStreamPlayer not found: %s" % node_path})
		return
	var player: VideoStreamPlayer = node as VideoStreamPlayer
	match action:
		"play":
			player.play()
			server._send_response({"success": true, "action": "play"})
		"pause":
			player.paused = true
			server._send_response({"success": true, "action": "pause"})
		"resume":
			player.paused = false
			server._send_response({"success": true, "action": "resume"})
		"stop":
			player.stop()
			server._send_response({"success": true, "action": "stop"})
		"seek":
			player.stream_position = float(params.get("position", 0.0))
			server._send_response({"success": true, "action": "seek", "position": player.stream_position})
		"get_status":
			server._send_response({"success": true, "action": "get_status", "is_playing": player.is_playing(), "paused": player.paused, "position": player.stream_position, "length": player.get_stream_length()})
		_:
			server._send_response({"error": "Unknown video action: %s" % action})


func _collect_ui_elements(node: Node, elements: Array) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		if ctrl.visible and ctrl.get_global_rect().size.x > 0:
			var info: Dictionary = {
				"name": ctrl.name,
				"type": ctrl.get_class(),
				"path": str(ctrl.get_path()),
				"position": {"x": ctrl.global_position.x, "y": ctrl.global_position.y},
				"size": {"width": ctrl.size.x, "height": ctrl.size.y},
			}
			# Get text content for common text-bearing nodes
			if ctrl is Label:
				info["text"] = (ctrl as Label).text
			elif ctrl is Button:
				info["text"] = (ctrl as Button).text
			elif ctrl is LineEdit:
				info["text"] = (ctrl as LineEdit).text
			elif ctrl is RichTextLabel:
				info["text"] = (ctrl as RichTextLabel).get_parsed_text()

			elements.append(info)

	for child: Node in node.get_children():
		_collect_ui_elements(child, elements)


# --- Get Scene Tree ---


func _resolve_anchor_preset(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	if value is String:
		var names: Dictionary = {
			"top_left": Control.PRESET_TOP_LEFT,
			"top_right": Control.PRESET_TOP_RIGHT,
			"bottom_left": Control.PRESET_BOTTOM_LEFT,
			"bottom_right": Control.PRESET_BOTTOM_RIGHT,
			"center_left": Control.PRESET_CENTER_LEFT,
			"center_top": Control.PRESET_CENTER_TOP,
			"center_right": Control.PRESET_CENTER_RIGHT,
			"center_bottom": Control.PRESET_CENTER_BOTTOM,
			"center": Control.PRESET_CENTER,
			"left_wide": Control.PRESET_LEFT_WIDE,
			"top_wide": Control.PRESET_TOP_WIDE,
			"right_wide": Control.PRESET_RIGHT_WIDE,
			"bottom_wide": Control.PRESET_BOTTOM_WIDE,
			"vcenter_wide": Control.PRESET_VCENTER_WIDE,
			"hcenter_wide": Control.PRESET_HCENTER_WIDE,
			"full_rect": Control.PRESET_FULL_RECT,
		}
		var key: String = (value as String).to_lower()
		if names.has(key):
			return names[key]
	return -1


func _collect_tree_items(item: TreeItem, result: Array, depth: int) -> void:
	var col: int = 0
	result.append({"text": item.get_text(col), "depth": depth, "collapsed": item.collapsed})
	var child: TreeItem = item.get_first_child()
	while child != null:
		_collect_tree_items(child, result, depth + 1)
		child = child.get_next()


func _create_draw_script() -> GDScript:
	var s: GDScript = GDScript.new()
	s.source_code = """extends Node2D
var draw_commands: Array = []
func _draw():
	for cmd in draw_commands:
		var p = cmd.params
		var c = cmd.color
		match cmd.action:
			"line":
				var f = p.get("from", {})
				var t = p.get("to", {})
				draw_line(Vector2(float(f.get("x",0)),float(f.get("y",0))),Vector2(float(t.get("x",0)),float(t.get("y",0))),c,float(p.get("width",2)))
			"rect":
				var r = p.get("rect", {})
				draw_rect(Rect2(float(r.get("x",0)),float(r.get("y",0)),float(r.get("w",10)),float(r.get("h",10))),c,bool(p.get("filled",true)))
			"circle":
				var ct = p.get("center", {})
				draw_circle(Vector2(float(ct.get("x",0)),float(ct.get("y",0))),float(p.get("radius",10)),c)
			"polygon":
				var pts = p.get("points", [])
				var pv = PackedVector2Array()
				for pt in pts:
					pv.append(Vector2(float(pt.get("x",0)),float(pt.get("y",0))))
				if pv.size() >= 3:
					draw_colored_polygon(pv, c)
			"text":
				var pos = p.get("position", p.get("pos", {}))
				draw_string(ThemeDB.fallback_font, Vector2(float(pos.get("x",0)),float(pos.get("y",0))), str(p.get("text","")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(p.get("font_size",16)), c)
"""
	s.reload()
	return s
