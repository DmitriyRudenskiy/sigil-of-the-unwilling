## MCP command module: 2D.
## Аудит #5: вынос из mcp_interaction_server (протокол/имена команд не меняются).
## `server` инжектит McpInteractionServer._ready.
class_name Mcp2dModule
extends McpCommandModule

var _canvas_draw_node: Node2D = null
var _draw_commands: Array = []

# --- TileMap ---
func _cmd_tilemap(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var action: String = params.get("action", "get_cell")
	if node_path.is_empty():
		_send_response({"error": "node_path is required"})
		return

	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is TileMapLayer:
		_send_response({"error": "Node is not a TileMapLayer: %s (is %s)" % [node_path, node.get_class()]})
		return

	var tilemap: TileMapLayer = node as TileMapLayer

	match action:
		"set_cells":
			var cells: Array = params.get("cells", [])
			var count: int = 0
			for cell in cells:
				var pos: Vector2i = Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))
				var source_id: int = int(cell.get("source_id", 0))
				var atlas_coords: Vector2i = Vector2i(int(cell.get("atlas_x", 0)), int(cell.get("atlas_y", 0)))
				var alt_tile: int = int(cell.get("alt_tile", 0))
				tilemap.set_cell(pos, source_id, atlas_coords, alt_tile)
				count += 1
			_send_response({"success": true, "action": "set_cells", "count": count})
		"get_cell":
			var x: int = int(params.get("x", 0))
			var y: int = int(params.get("y", 0))
			var pos: Vector2i = Vector2i(x, y)
			_send_response({
				"success": true, "action": "get_cell",
				"x": x, "y": y,
				"source_id": tilemap.get_cell_source_id(pos),
				"atlas_coords": _variant_to_json(tilemap.get_cell_atlas_coords(pos)),
				"alt_tile": tilemap.get_cell_alternative_tile(pos)
			})
		"erase_cells":
			var cells: Array = params.get("cells", [])
			var count: int = 0
			for cell in cells:
				tilemap.erase_cell(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
				count += 1
			_send_response({"success": true, "action": "erase_cells", "count": count})
		"get_used_cells":
			var source_filter: int = int(params.get("source_id", -1))
			var used: Array
			if source_filter >= 0:
				used = tilemap.get_used_cells_by_id(source_filter)
			else:
				used = tilemap.get_used_cells()
			_send_response({"success": true, "action": "get_used_cells", "cells": _variant_to_json(used), "count": used.size()})
		_:
			_send_response({"error": "Unknown tilemap action: %s. Use set_cells, get_cell, erase_cells, or get_used_cells" % action})


# --- Add Collision Shape ---

# --- Add Collision Shape ---
func _cmd_add_collision(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "")
	var shape_type: String = params.get("shape_type", "")
	if parent_path.is_empty() or shape_type.is_empty():
		_send_response({"error": "parent_path and shape_type are required"})
		return

	var parent: Node = get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		_send_response({"error": "Parent node not found: %s" % parent_path})
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
				_send_response({"error": "Unknown 3D shape type: %s. Use box, sphere, capsule, cylinder, or ray" % shape_type})
				return
		var col_shape: CollisionShape3D = CollisionShape3D.new()
		col_shape.shape = shape as Shape3D
		if params.has("disabled"):
			col_shape.disabled = bool(params["disabled"])
		parent.add_child(col_shape)
		col_shape.owner = get_tree().edited_scene_root if get_tree().edited_scene_root else get_tree().root
		if params.has("collision_layer"):
			parent.set("collision_layer", int(params["collision_layer"]))
		if params.has("collision_mask"):
			parent.set("collision_mask", int(params["collision_mask"]))
		_send_response({"success": true, "name": col_shape.name, "path": str(col_shape.get_path()), "shape_type": shape_type, "mode": "3d"})
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
				_send_response({"error": "Unknown 2D shape type: %s. Use box, circle, capsule, or segment" % shape_type})
				return
		var col_shape: CollisionShape2D = CollisionShape2D.new()
		col_shape.shape = shape as Shape2D
		if params.has("disabled"):
			col_shape.disabled = bool(params["disabled"])
		parent.add_child(col_shape)
		col_shape.owner = get_tree().edited_scene_root if get_tree().edited_scene_root else get_tree().root
		if params.has("collision_layer"):
			parent.set("collision_layer", int(params["collision_layer"]))
		if params.has("collision_mask"):
			parent.set("collision_mask", int(params["collision_mask"]))
		_send_response({"success": true, "name": col_shape.name, "path": str(col_shape.get_path()), "shape_type": shape_type, "mode": "2d"})


# --- Environment / Post-Processing ---

# ==========================================================================
# Batch 3: 2D Systems + Animation Advanced + Audio Effects
# ==========================================================================

func _cmd_canvas(params: Dictionary) -> void:
	var action: String = params.get("action", "create_layer")
	match action:
		"create_layer":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				_send_response({"error": "Parent not found: %s" % parent_path})
				return
			var cl: CanvasLayer = CanvasLayer.new()
			if params.has("layer"):
				cl.layer = int(params["layer"])
			if params.has("name") and not (params["name"] as String).is_empty():
				cl.name = params["name"]
			parent.add_child(cl)
			_send_response({"success": true, "action": "create_layer", "path": str(cl.get_path())})
		"create_modulate":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				_send_response({"error": "Parent not found: %s" % parent_path})
				return
			var cm: CanvasModulate = CanvasModulate.new()
			if params.has("color"):
				var c: Dictionary = params["color"]
				cm.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
			if params.has("name") and not (params["name"] as String).is_empty():
				cm.name = params["name"]
			parent.add_child(cm)
			_send_response({"success": true, "action": "create_modulate", "path": str(cm.get_path())})
		"configure":
			var node_path: String = params.get("node_path", "")
			var node: Node = get_tree().root.get_node_or_null(node_path)
			if node == null:
				_send_response({"error": "Node not found: %s" % node_path})
				return
			var applied: Array = []
			if node is CanvasLayer:
				var cl2: CanvasLayer = node as CanvasLayer
				if params.has("layer"):
					cl2.layer = int(params["layer"])
					applied.append("layer")
				if params.has("offset"):
					var o: Dictionary = params["offset"]
					cl2.offset = Vector2(float(o.get("x", 0)), float(o.get("y", 0)))
					applied.append("offset")
				if params.has("visible"):
					cl2.visible = bool(params["visible"])
					applied.append("visible")
			elif node is CanvasModulate:
				if params.has("color"):
					var c: Dictionary = params["color"]
					(node as CanvasModulate).color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
					applied.append("color")
			else:
				_send_response({"error": "Node is not a CanvasLayer or CanvasModulate: %s" % node.get_class()})
				return
			_send_response({"success": true, "action": "configure", "applied": applied})
		_:
			_send_response({"error": "Unknown canvas action: %s" % action})

func _cmd_canvas_draw(params: Dictionary) -> void:
	var action: String = params.get("action", "line")
	if action == "clear":
		_draw_commands.clear()
		if _canvas_draw_node != null and is_instance_valid(_canvas_draw_node):
			_canvas_draw_node.queue_redraw()
		_send_response({"success": true, "action": "clear"})
		return
	if not action in ["line", "rect", "circle", "polygon", "text"]:
		_send_response({"error": "Unknown canvas_draw action: %s" % action})
		return
	# Ensure draw node
	if _canvas_draw_node == null or not is_instance_valid(_canvas_draw_node):
		var parent_path: String = params.get("parent_path", "/root")
		var parent: Node = get_tree().root.get_node_or_null(parent_path)
		if parent == null:
			_send_response({"error": "Parent not found: %s" % parent_path})
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
	_send_response({"success": true, "action": action})

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

func _cmd_light_2d(params: Dictionary) -> void:
	var action: String = params.get("action", "create_point")
	var parent_path: String = params.get("parent_path", "/root")
	var parent: Node = get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		_send_response({"error": "Parent not found: %s" % parent_path})
		return
	match action:
		"create_point":
			var light: PointLight2D = PointLight2D.new()
			if params.has("color"):
				var c: Dictionary = params["color"]
				light.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
			if params.has("energy"):
				light.energy = float(params["energy"])
			# Create a simple gradient texture for the light
			var tex: GradientTexture2D = GradientTexture2D.new()
			tex.width = 128
			tex.height = 128
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.gradient = Gradient.new()
			light.texture = tex
			if params.has("range"):
				light.texture_scale = float(params["range"])
			if params.has("name") and not (params["name"] as String).is_empty():
				light.name = params["name"]
			parent.add_child(light)
			_send_response({"success": true, "action": "create_point", "path": str(light.get_path())})
		"create_directional":
			var light: DirectionalLight2D = DirectionalLight2D.new()
			if params.has("color"):
				var c: Dictionary = params["color"]
				light.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
			if params.has("energy"):
				light.energy = float(params["energy"])
			if params.has("name") and not (params["name"] as String).is_empty():
				light.name = params["name"]
			parent.add_child(light)
			_send_response({"success": true, "action": "create_directional", "path": str(light.get_path())})
		"create_occluder":
			var occ: LightOccluder2D = LightOccluder2D.new()
			var poly: OccluderPolygon2D = OccluderPolygon2D.new()
			var packed: PackedVector2Array = PackedVector2Array()
			for p in params.get("points", []):
				packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			poly.polygon = packed
			occ.occluder = poly
			if params.has("name") and not (params["name"] as String).is_empty():
				occ.name = params["name"]
			parent.add_child(occ)
			_send_response({"success": true, "action": "create_occluder", "path": str(occ.get_path()), "point_count": packed.size()})
		_:
			_send_response({"error": "Unknown light_2d action: %s" % action})

func _cmd_parallax(params: Dictionary) -> void:
	var action: String = params.get("action", "create_background")
	match action:
		"create_background":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				_send_response({"error": "Parent not found: %s" % parent_path})
				return
			var bg: ParallaxBackground = ParallaxBackground.new()
			if params.has("name") and not (params["name"] as String).is_empty():
				bg.name = params["name"]
			parent.add_child(bg)
			_send_response({"success": true, "action": "create_background", "path": str(bg.get_path())})
		"add_layer":
			var parent_path: String = params.get("parent_path", "")
			var parent: Node = get_tree().root.get_node_or_null(parent_path)
			if parent == null or not parent is ParallaxBackground:
				_send_response({"error": "ParallaxBackground not found: %s" % parent_path})
				return
			var layer: ParallaxLayer = ParallaxLayer.new()
			if params.has("motion_scale"):
				var ms: Dictionary = params["motion_scale"]
				layer.motion_scale = Vector2(float(ms.get("x", 1)), float(ms.get("y", 1)))
			if params.has("motion_offset"):
				var mo: Dictionary = params["motion_offset"]
				layer.motion_offset = Vector2(float(mo.get("x", 0)), float(mo.get("y", 0)))
			if params.has("mirroring"):
				var mi: Dictionary = params["mirroring"]
				layer.motion_mirroring = Vector2(float(mi.get("x", 0)), float(mi.get("y", 0)))
			if params.has("name") and not (params["name"] as String).is_empty():
				layer.name = params["name"]
			parent.add_child(layer)
			_send_response({"success": true, "action": "add_layer", "path": str(layer.get_path())})
		"configure":
			var node_path: String = params.get("node_path", "")
			var node: Node = get_tree().root.get_node_or_null(node_path)
			if node == null:
				_send_response({"error": "Node not found: %s" % node_path})
				return
			var applied: Array = []
			if node is ParallaxBackground:
				var pbg: ParallaxBackground = node as ParallaxBackground
				if params.has("scroll_offset"):
					var so: Dictionary = params["scroll_offset"]
					pbg.scroll_offset = Vector2(float(so.get("x", 0)), float(so.get("y", 0)))
					applied.append("scroll_offset")
				if params.has("scroll_base_offset"):
					var sbo: Dictionary = params["scroll_base_offset"]
					pbg.scroll_base_offset = Vector2(float(sbo.get("x", 0)), float(sbo.get("y", 0)))
					applied.append("scroll_base_offset")
			elif node is ParallaxLayer:
				var pl: ParallaxLayer = node as ParallaxLayer
				if params.has("motion_scale"):
					var ms2: Dictionary = params["motion_scale"]
					pl.motion_scale = Vector2(float(ms2.get("x", 1)), float(ms2.get("y", 1)))
					applied.append("motion_scale")
				if params.has("motion_offset"):
					var mo2: Dictionary = params["motion_offset"]
					pl.motion_offset = Vector2(float(mo2.get("x", 0)), float(mo2.get("y", 0)))
					applied.append("motion_offset")
				if params.has("mirroring"):
					var mi2: Dictionary = params["mirroring"]
					pl.motion_mirroring = Vector2(float(mi2.get("x", 0)), float(mi2.get("y", 0)))
					applied.append("mirroring")
			else:
				_send_response({"error": "Node is not a ParallaxBackground or ParallaxLayer: %s" % node.get_class()})
				return
			_send_response({"success": true, "action": "configure", "applied": applied})
		_:
			_send_response({"error": "Unknown parallax action: %s" % action})

func _cmd_shape_2d(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		_send_response({"error": "Node not found: %s" % node_path})
		return
	var action: String = params.get("action", "get_points")
	match action:
		"add_point":
			var p: Dictionary = params.get("point", {})
			var pt: Vector2 = Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
			if node is Line2D:
				(node as Line2D).add_point(pt)
			elif node is Polygon2D:
				var polygon: PackedVector2Array = (node as Polygon2D).polygon
				polygon.append(pt)
				(node as Polygon2D).polygon = polygon
			_send_response({"success": true, "action": "add_point"})
		"set_points":
			var pts: Array = params.get("points", [])
			var packed: PackedVector2Array = PackedVector2Array()
			for p in pts:
				packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			if node is Line2D:
				(node as Line2D).points = packed
			elif node is Polygon2D:
				(node as Polygon2D).polygon = packed
			_send_response({"success": true, "action": "set_points", "count": packed.size()})
		"clear":
			if node is Line2D:
				(node as Line2D).clear_points()
			elif node is Polygon2D:
				(node as Polygon2D).polygon = PackedVector2Array()
			_send_response({"success": true, "action": "clear"})
		"get_points":
			var pts: PackedVector2Array
			if node is Line2D:
				pts = (node as Line2D).points
			elif node is Polygon2D:
				pts = (node as Polygon2D).polygon
			else:
				_send_response({"error": "Node is not Line2D or Polygon2D"})
				return
			var result: Array = []
			for p in pts:
				result.append({"x": p.x, "y": p.y})
			_send_response({"success": true, "action": "get_points", "points": result})
		_:
			_send_response({"error": "Unknown shape_2d action: %s" % action})

func _cmd_path_2d(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				_send_response({"error": "Parent not found: %s" % parent_path})
				return
			var path_node: Path2D = Path2D.new()
			path_node.curve = Curve2D.new()
			if params.has("name") and not (params["name"] as String).is_empty():
				path_node.name = params["name"]
			if params.has("points"):
				for p in params["points"]:
					path_node.curve.add_point(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			parent.add_child(path_node)
			_send_response({"success": true, "action": "create", "path": str(path_node.get_path()), "point_count": path_node.curve.point_count})
		"add_point":
			var node_path: String = params.get("node_path", "")
			var node: Node = get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path2D:
				_send_response({"error": "Path2D not found: %s" % node_path})
				return
			var p: Dictionary = params.get("point", {})
			(node as Path2D).curve.add_point(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			_send_response({"success": true, "action": "add_point", "point_count": (node as Path2D).curve.point_count})
		"get_points":
			var node_path: String = params.get("node_path", "")
			var node: Node = get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path2D:
				_send_response({"error": "Path2D not found: %s" % node_path})
				return
			var pts: Array = []
			for i in (node as Path2D).curve.point_count:
				var pt: Vector2 = (node as Path2D).curve.get_point_position(i)
				pts.append({"x": pt.x, "y": pt.y})
			_send_response({"success": true, "action": "get_points", "points": pts})
		_:
			_send_response({"error": "Unknown path_2d action: %s" % action})

func _cmd_physics_2d(params: Dictionary) -> void:
	var action: String = params.get("action", "ray")
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState2D = get_viewport().world_2d.direct_space_state
	match action:
		"ray":
			var from_d: Dictionary = params.get("from", {})
			var to_d: Dictionary = params.get("to", {})
			var from: Vector2 = Vector2(float(from_d.get("x", 0)), float(from_d.get("y", 0)))
			var to: Vector2 = Vector2(float(to_d.get("x", 0)), float(to_d.get("y", 0)))
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
			if params.has("collision_mask"):
				query.collision_mask = int(params["collision_mask"])
			var result: Dictionary = space.intersect_ray(query)
			if result.is_empty():
				_send_response({"success": true, "action": "ray", "hit": false})
			else:
				_send_response({"success": true, "action": "ray", "hit": true, "position": _variant_to_json(result["position"]), "normal": _variant_to_json(result["normal"]), "collider": str(result.get("collider", ""))})
		"overlap":
			var node_path: String = params.get("node_path", "")
			var node: Node = get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Area2D:
				_send_response({"error": "Area2D not found: %s" % node_path})
				return
			var bodies: Array = (node as Area2D).get_overlapping_bodies()
			var result: Array = []
			for b in bodies:
				result.append({"name": b.name, "path": str(b.get_path())})
			_send_response({"success": true, "action": "overlap", "bodies": result})
		"point_query":
			var pos_d: Dictionary = params.get("position", params.get("point", {}))
			var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
			query.position = Vector2(float(pos_d.get("x", 0)), float(pos_d.get("y", 0)))
			query.collide_with_areas = bool(params.get("collide_with_areas", true))
			query.collide_with_bodies = bool(params.get("collide_with_bodies", true))
			if params.has("collision_mask"):
				query.collision_mask = int(params["collision_mask"])
			var hits: Array = space.intersect_point(query, int(params.get("max_results", 32)))
			var out: Array = []
			for h in hits:
				out.append({"collider": str(h.get("collider", "")), "rid": str(h.get("rid", ""))})
			_send_response({"success": true, "action": "point_query", "count": out.size(), "results": out})
		"shape_query":
			var shape_type: String = params.get("shape_type", "circle")
			var shape: Shape2D = null
			if shape_type == "rectangle":
				var rect: RectangleShape2D = RectangleShape2D.new()
				var sz: Dictionary = params.get("size", {"x": 10, "y": 10})
				rect.size = Vector2(float(sz.get("x", 10)), float(sz.get("y", 10)))
				shape = rect
			else:
				var circ: CircleShape2D = CircleShape2D.new()
				circ.radius = float(params.get("radius", 10.0))
				shape = circ
			var sq: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			sq.shape = shape
			var spos_d: Dictionary = params.get("position", {})
			var xf: Transform2D = Transform2D.IDENTITY
			xf.origin = Vector2(float(spos_d.get("x", 0)), float(spos_d.get("y", 0)))
			sq.transform = xf
			sq.collide_with_areas = bool(params.get("collide_with_areas", true))
			sq.collide_with_bodies = bool(params.get("collide_with_bodies", true))
			if params.has("collision_mask"):
				sq.collision_mask = int(params["collision_mask"])
			var shits: Array = space.intersect_shape(sq, int(params.get("max_results", 32)))
			var sout: Array = []
			for h in shits:
				sout.append({"collider": str(h.get("collider", "")), "rid": str(h.get("rid", ""))})
			_send_response({"success": true, "action": "shape_query", "count": sout.size(), "results": sout})
		_:
			_send_response({"error": "Unknown physics_2d action: %s" % action})
