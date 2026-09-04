## MCP command module: UI.
## Аудит #5: вынос из mcp_interaction_server (протокол/имена команд не меняются).
## `server` инжектит McpInteractionServer._ready.
class_name McpUiModule
extends McpCommandModule

# --- UI Theme ---
func _cmd_ui_theme(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		_send_response({"error": "node_path is required"})
		return

	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is Control:
		_send_response({"error": "Node is not a Control: %s (is %s)" % [node_path, node.get_class()]})
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

	_send_response({"success": true, "node_path": node_path, "applied": applied})


# --- Viewport ---

# --- Viewport ---
func _cmd_viewport(params: Dictionary) -> void:
	var action: String = params.get("action", "create")

	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				_send_response({"error": "Parent node not found: %s" % parent_path})
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
			_send_response({"success": true, "action": "create", "viewport_path": str(viewport.get_path()), "container_path": str(container.get_path()), "size": _variant_to_json(viewport.size)})
		"configure":
			var node_path: String = params.get("node_path", "")
			if node_path.is_empty():
				_send_response({"error": "node_path is required for configure"})
				return
			var vp: Node = get_tree().root.get_node_or_null(node_path)
			if vp == null or not vp is SubViewport:
				_send_response({"error": "SubViewport not found: %s" % node_path})
				return
			var sv: SubViewport = vp as SubViewport
			if params.has("width") and params.has("height"):
				sv.size = Vector2i(int(params["width"]), int(params["height"]))
			if params.has("transparent_bg"):
				sv.transparent_bg = bool(params["transparent_bg"])
			if params.has("msaa"):
				sv.msaa_2d = int(params["msaa"]) as Viewport.MSAA
				sv.msaa_3d = int(params["msaa"]) as Viewport.MSAA
			_send_response({"success": true, "action": "configure", "size": _variant_to_json(sv.size), "transparent_bg": sv.transparent_bg})
		"get":
			var node_path: String = params.get("node_path", "")
			if node_path.is_empty():
				_send_response({"error": "node_path is required for get"})
				return
			var vp: Node = get_tree().root.get_node_or_null(node_path)
			if vp == null or not vp is SubViewport:
				_send_response({"error": "SubViewport not found: %s" % node_path})
				return
			var sv: SubViewport = vp as SubViewport
			_send_response({"success": true, "action": "get", "size": _variant_to_json(sv.size), "transparent_bg": sv.transparent_bg, "msaa_2d": sv.msaa_2d, "msaa_3d": sv.msaa_3d})
		_:
			_send_response({"error": "Unknown viewport action: %s. Use create, configure, or get" % action})


# --- Debug Draw ---

# ==========================================================================
# Batch 5: UI Controls + Rendering + Resource Runtime
# ==========================================================================

func _cmd_ui_control(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null or not node is Control:
		_send_response({"error": "Control not found: %s" % node_path})
		return
	var ctrl: Control = node as Control
	var action: String = params.get("action", "get_info")
	match action:
		"grab_focus":
			ctrl.grab_focus()
			_send_response({"success": true, "action": "grab_focus"})
		"release_focus":
			ctrl.release_focus()
			_send_response({"success": true, "action": "release_focus"})
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
					_send_response({"error": "Invalid anchor_preset: %s" % str(params["anchor_preset"])})
					return
				ctrl.set_anchors_and_offsets_preset(preset as Control.LayoutPreset)
				applied.append("anchor_preset")
			_send_response({"success": true, "action": "configure", "applied": applied})
		"get_info":
			_send_response({"success": true, "size": _variant_to_json(ctrl.size), "position": _variant_to_json(ctrl.position), "has_focus": ctrl.has_focus(), "visible": ctrl.visible, "tooltip": ctrl.tooltip_text, "mouse_filter": ctrl.mouse_filter})
		_:
			_send_response({"error": "Unknown ui_control action: %s" % action})

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

func _cmd_ui_text(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get")
	match action:
		"get":
			var text: String = ""
			if node is LineEdit: text = (node as LineEdit).text
			elif node is TextEdit: text = (node as TextEdit).text
			elif node is RichTextLabel: text = (node as RichTextLabel).text
			else:
				_send_response({"error": "Node is not a text control"})
				return
			_send_response({"success": true, "text": text})
		"set":
			var text: String = str(params.get("text", ""))
			if node is LineEdit: (node as LineEdit).text = text
			elif node is TextEdit: (node as TextEdit).text = text
			elif node is RichTextLabel: (node as RichTextLabel).text = text
			else:
				_send_response({"error": "Node is not a text control (LineEdit/TextEdit/RichTextLabel): %s" % node.get_class()})
				return
			_send_response({"success": true, "action": "set"})
		"append":
			var text: String = str(params.get("text", ""))
			if node is TextEdit: (node as TextEdit).text += text
			elif node is RichTextLabel: (node as RichTextLabel).append_text(text)
			elif node is LineEdit: (node as LineEdit).text += text
			else:
				_send_response({"error": "Node is not a text control (LineEdit/TextEdit/RichTextLabel): %s" % node.get_class()})
				return
			_send_response({"success": true, "action": "append"})
		"clear":
			if node is LineEdit: (node as LineEdit).text = ""
			elif node is TextEdit: (node as TextEdit).text = ""
			elif node is RichTextLabel: (node as RichTextLabel).clear()
			else:
				_send_response({"error": "Node is not a text control (LineEdit/TextEdit/RichTextLabel): %s" % node.get_class()})
				return
			_send_response({"success": true, "action": "clear"})
		"bbcode":
			if node is RichTextLabel:
				(node as RichTextLabel).bbcode_enabled = true
				(node as RichTextLabel).text = str(params.get("text", ""))
			else:
				_send_response({"error": "Node is not a RichTextLabel: %s" % node.get_class()})
				return
			_send_response({"success": true, "action": "bbcode"})
		_:
			_send_response({"error": "Unknown ui_text action: %s" % action})

func _cmd_ui_popup(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null or not node is Window:
		_send_response({"error": "Window/Popup not found: %s" % node_path})
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
			_send_response({"success": true, "action": "popup_centered"})
		"popup":
			win.popup()
			_send_response({"success": true, "action": "popup"})
		"hide":
			win.hide()
			_send_response({"success": true, "action": "hide"})
		"get_info":
			_send_response({"success": true, "visible": win.visible, "title": win.title, "size": _variant_to_json(win.size)})
		_:
			_send_response({"error": "Unknown ui_popup action: %s" % action})

func _cmd_ui_tree(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null or not node is Tree:
		_send_response({"error": "Tree not found: %s" % node_path})
		return
	var tree: Tree = node as Tree
	var action: String = params.get("action", "get_items")
	match action:
		"get_items":
			var items: Array = []
			var root: TreeItem = tree.get_root()
			if root != null:
				_collect_tree_items(root, items, 0)
			_send_response({"success": true, "action": "get_items", "items": items})
		"add":
			var text: String = str(params.get("text", "Item"))
			var root: TreeItem = tree.get_root()
			if root == null:
				root = tree.create_item()
			var item: TreeItem = tree.create_item(root)
			item.set_text(int(params.get("column", 0)), text)
			_send_response({"success": true, "action": "add", "text": text})
		_:
			_send_response({"error": "Unknown ui_tree action: %s" % action})

func _collect_tree_items(item: TreeItem, result: Array, depth: int) -> void:
	var col: int = 0
	result.append({"text": item.get_text(col), "depth": depth, "collapsed": item.collapsed})
	var child: TreeItem = item.get_first_child()
	while child != null:
		_collect_tree_items(child, result, depth + 1)
		child = child.get_next()

func _cmd_ui_item_list(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get_items")
	if node is ItemList:
		var il: ItemList = node as ItemList
		match action:
			"get_items":
				var items: Array = []
				for i in il.item_count:
					items.append({"index": i, "text": il.get_item_text(i), "selected": il.is_selected(i)})
				_send_response({"success": true, "items": items})
			"select":
				il.select(int(params.get("index", 0)))
				_send_response({"success": true, "action": "select"})
			"add":
				il.add_item(str(params.get("text", "Item")))
				_send_response({"success": true, "action": "add"})
			"remove":
				il.remove_item(int(params.get("index", 0)))
				_send_response({"success": true, "action": "remove"})
			"clear":
				il.clear()
				_send_response({"success": true, "action": "clear"})
			_:
				_send_response({"error": "Unknown ui_item_list action: %s" % action})
	elif node is OptionButton:
		var ob: OptionButton = node as OptionButton
		match action:
			"get_items":
				var items: Array = []
				for i in ob.item_count:
					items.append({"index": i, "text": ob.get_item_text(i)})
				_send_response({"success": true, "items": items, "selected": ob.selected})
			"select":
				ob.select(int(params.get("index", 0)))
				_send_response({"success": true, "action": "select"})
			"add":
				ob.add_item(str(params.get("text", "Item")))
				_send_response({"success": true, "action": "add"})
			_:
				_send_response({"error": "Unknown action for OptionButton: %s" % action})
	else:
		_send_response({"error": "Node is not ItemList or OptionButton"})

func _cmd_ui_tabs(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get_tabs")
	if node is TabContainer:
		var tc: TabContainer = node as TabContainer
		match action:
			"get_tabs":
				var tabs: Array = []
				for i in tc.get_tab_count():
					tabs.append({"index": i, "title": tc.get_tab_title(i)})
				_send_response({"success": true, "tabs": tabs, "current": tc.current_tab})
			"set_current":
				tc.current_tab = int(params.get("index", 0))
				_send_response({"success": true, "action": "set_current"})
			"set_title":
				tc.set_tab_title(int(params.get("index", 0)), str(params.get("title", "")))
				_send_response({"success": true, "action": "set_title"})
			_:
				_send_response({"error": "Unknown ui_tabs action: %s" % action})
	elif node is TabBar:
		var tb: TabBar = node as TabBar
		match action:
			"get_tabs":
				var tabs: Array = []
				for i in tb.tab_count:
					tabs.append({"index": i, "title": tb.get_tab_title(i)})
				_send_response({"success": true, "tabs": tabs, "current": tb.current_tab})
			"set_current":
				tb.current_tab = int(params.get("index", 0))
				_send_response({"success": true, "action": "set_current"})
			_:
				_send_response({"error": "Unknown ui_tabs action: %s" % action})
	else:
		_send_response({"error": "Node is not TabContainer or TabBar"})

func _cmd_ui_menu(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null or not node is PopupMenu:
		_send_response({"error": "PopupMenu not found: %s" % node_path})
		return
	var menu: PopupMenu = node as PopupMenu
	var action: String = params.get("action", "get_items")
	match action:
		"get_items":
			var items: Array = []
			for i in menu.item_count:
				items.append({"index": i, "text": menu.get_item_text(i), "checked": menu.is_item_checked(i), "disabled": menu.is_item_disabled(i), "id": menu.get_item_id(i)})
			_send_response({"success": true, "items": items})
		"add":
			var text: String = str(params.get("text", "Item"))
			var id: int = int(params.get("id", -1))
			menu.add_item(text, id)
			_send_response({"success": true, "action": "add"})
		"remove":
			menu.remove_item(int(params.get("index", 0)))
			_send_response({"success": true, "action": "remove"})
		"set_checked":
			menu.set_item_checked(int(params.get("index", 0)), bool(params.get("checked", true)))
			_send_response({"success": true, "action": "set_checked"})
		"clear":
			menu.clear()
			_send_response({"success": true, "action": "clear"})
		_:
			_send_response({"error": "Unknown ui_menu action: %s" % action})

func _cmd_ui_range(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get")
	if node is Range:
		var r: Range = node as Range
		if action == "get":
			_send_response({"success": true, "value": r.value, "min": r.min_value, "max": r.max_value, "step": r.step})
			return
		if params.has("value"): r.value = float(params["value"])
		if params.has("min_value"): r.min_value = float(params["min_value"])
		if params.has("max_value"): r.max_value = float(params["max_value"])
		if params.has("step"): r.step = float(params["step"])
		_send_response({"success": true, "action": "set", "value": r.value})
	elif node is ColorPicker:
		var cp: ColorPicker = node as ColorPicker
		if action == "get":
			var c: Color = cp.color
			_send_response({"success": true, "color": {"r": c.r, "g": c.g, "b": c.b, "a": c.a}})
			return
		if params.has("color"):
			var cd: Dictionary = params["color"]
			cp.color = Color(float(cd.get("r", 0)), float(cd.get("g", 0)), float(cd.get("b", 0)), float(cd.get("a", 1)))
		_send_response({"success": true, "action": "set"})
	else:
		_send_response({"error": "Node is not Range or ColorPicker"})
