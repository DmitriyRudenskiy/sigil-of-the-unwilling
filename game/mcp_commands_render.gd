class_name McpCommandsRender
extends McpCommandsBase

func get_commands() -> Dictionary:
	return {
		"get_camera": _cmd_get_camera,
		"set_camera": _cmd_set_camera,
		"csg": _cmd_csg,
		"multimesh": _cmd_multimesh,
		"procedural_mesh": _cmd_procedural_mesh,
		"light_3d": _cmd_light_3d,
		"mesh_instance": _cmd_mesh_instance,
		"gridmap": _cmd_gridmap,
		"3d_effects": _cmd_3d_effects,
		"gi": _cmd_gi,
		"path_3d": _cmd_path_3d,
		"sky": _cmd_sky,
		"camera_attributes": _cmd_camera_attributes,
		"navigation_3d": _cmd_navigation_3d,
		"physics_3d": _cmd_physics_3d,
		"canvas": _cmd_canvas,
		"light_2d": _cmd_light_2d,
		"parallax": _cmd_parallax,
		"shape_2d": _cmd_shape_2d,
		"path_2d": _cmd_path_2d,
		"physics_2d": _cmd_physics_2d,
		"animation_tree": _cmd_animation_tree,
		"animation_control": _cmd_animation_control,
		"skeleton_ik": _cmd_skeleton_ik,
		"audio_effect": _cmd_audio_effect,
		"audio_bus_layout": _cmd_audio_bus_layout,
		"audio_spatial": _cmd_audio_spatial,
		"get_audio": _cmd_get_audio,
		"audio_play": _cmd_audio_play,
		"audio_bus": _cmd_audio_bus,
		"set_shader_param": _cmd_set_shader_param,
		"environment": _cmd_environment,
		"bone_pose": _cmd_bone_pose,
		"tilemap": _cmd_tilemap,
		"render_settings": _cmd_render_settings,
		"resource": _cmd_resource,
	}

func _cmd_get_camera(_params: Dictionary) -> void:
	var result: Dictionary = {"success": true}

	var cam2d: Camera2D = server.get_viewport().get_camera_2d()
	if cam2d != null:
		result["camera_2d"] = {
			"position": {"x": cam2d.global_position.x, "y": cam2d.global_position.y},
			"rotation": cam2d.global_rotation,
			"zoom": {"x": cam2d.zoom.x, "y": cam2d.zoom.y},
			"path": str(cam2d.get_path())
		}

	var cam3d: Camera3D = server.get_viewport().get_camera_3d()
	if cam3d != null:
		result["camera_3d"] = {
			"position": {"x": cam3d.global_position.x, "y": cam3d.global_position.y, "z": cam3d.global_position.z},
			"rotation": {"x": rad_to_deg(cam3d.global_rotation.x), "y": rad_to_deg(cam3d.global_rotation.y), "z": rad_to_deg(cam3d.global_rotation.z)},
			"fov": cam3d.fov,
			"path": str(cam3d.get_path())
		}

	if cam2d == null and cam3d == null:
		result["error"] = "No active camera found"
		result["success"] = false

	server._send_response(result)


# --- Set Camera ---


func _cmd_set_camera(params: Dictionary) -> void:
	var cam2d: Camera2D = server.get_viewport().get_camera_2d()
	var cam3d: Camera3D = server.get_viewport().get_camera_3d()

	if cam2d == null and cam3d == null:
		server._send_response({"error": "No active camera found"})
		return

	if cam2d != null:
		if params.has("position"):
			var pos: Dictionary = params["position"]
			cam2d.global_position = Vector2(float(pos.get("x", cam2d.global_position.x)), float(pos.get("y", cam2d.global_position.y)))
		if params.has("rotation"):
			var rot: Dictionary = params["rotation"]
			cam2d.global_rotation = deg_to_rad(float(rot.get("z", rad_to_deg(cam2d.global_rotation))))
		if params.has("zoom"):
			var z: Dictionary = params["zoom"]
			cam2d.zoom = Vector2(float(z.get("x", cam2d.zoom.x)), float(z.get("y", cam2d.zoom.y)))
		server._send_response({"success": true, "camera": "2d", "position": McpSerialization.variant_to_json(cam2d.global_position), "zoom": McpSerialization.variant_to_json(cam2d.zoom)})
		return

	if cam3d != null:
		if params.has("position"):
			var pos: Dictionary = params["position"]
			cam3d.global_position = Vector3(float(pos.get("x", cam3d.global_position.x)), float(pos.get("y", cam3d.global_position.y)), float(pos.get("z", cam3d.global_position.z)))
		if params.has("rotation"):
			var rot: Dictionary = params["rotation"]
			cam3d.global_rotation = Vector3(deg_to_rad(float(rot.get("x", rad_to_deg(cam3d.global_rotation.x)))), deg_to_rad(float(rot.get("y", rad_to_deg(cam3d.global_rotation.y)))), deg_to_rad(float(rot.get("z", rad_to_deg(cam3d.global_rotation.z)))))
		if params.has("fov"):
			cam3d.fov = float(params["fov"])
		server._send_response({"success": true, "camera": "3d", "position": McpSerialization.variant_to_json(cam3d.global_position), "rotation": McpSerialization.variant_to_json(cam3d.global_rotation)})
		return


# --- Raycast ---


func _cmd_csg(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	if action == "create":
		var parent_path: String = params.get("parent_path", "/root")
		var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
		if parent == null:
			server._send_response({"error": "Parent not found: %s" % parent_path})
			return
		var csg_type: String = params.get("csg_type", "box")
		var node: CSGShape3D
		match csg_type:
			"box": node = CSGBox3D.new()
			"sphere": node = CSGSphere3D.new()
			"cylinder": node = CSGCylinder3D.new()
			"mesh": node = CSGMesh3D.new()
			"combiner": node = CSGCombiner3D.new()
			_:
				server._send_response({"error": "Unknown CSG type: %s" % csg_type})
				return
		if params.has("operation"):
			match params["operation"]:
				"union": node.operation = CSGShape3D.OPERATION_UNION
				"intersection": node.operation = CSGShape3D.OPERATION_INTERSECTION
				"subtraction": node.operation = CSGShape3D.OPERATION_SUBTRACTION
		if params.has("name") and not (params["name"] as String).is_empty():
			node.name = params["name"]
		if node is CSGBox3D and params.has("size"):
			var box_size: Variant = McpSerialization.json_to_variant(params["size"], "Vector3")
			if box_size is Vector3:
				(node as CSGBox3D).size = box_size
		if node is CSGSphere3D and params.has("radius"):
			(node as CSGSphere3D).radius = float(params["radius"])
		if node is CSGCylinder3D:
			if params.has("radius"):
				(node as CSGCylinder3D).radius = float(params["radius"])
			if params.has("height"):
				(node as CSGCylinder3D).height = float(params["height"])
		parent.add_child(node)
		node.owner = server.get_tree().edited_scene_root if server.get_tree().edited_scene_root else server.get_tree().root
		server._send_response({"success": true, "action": "create", "path": str(node.get_path()), "type": csg_type})
	elif action == "configure":
		var node_path: String = params.get("node_path", "")
		var node: Node = server.get_tree().root.get_node_or_null(node_path)
		if node == null or not node is CSGShape3D:
			server._send_response({"error": "CSGShape3D not found: %s" % node_path})
			return
		if params.has("operation"):
			match params["operation"]:
				"union": (node as CSGShape3D).operation = CSGShape3D.OPERATION_UNION
				"intersection": (node as CSGShape3D).operation = CSGShape3D.OPERATION_INTERSECTION
				"subtraction": (node as CSGShape3D).operation = CSGShape3D.OPERATION_SUBTRACTION
		server._send_response({"success": true, "action": "configure", "path": str(node.get_path())})
	else:
		server._send_response({"error": "Unknown csg action: %s" % action})


func _cmd_multimesh(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
			var mm: MultiMesh = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.instance_count = int(params.get("count", 1))
			var mesh_type: String = params.get("mesh_type", "box")
			match mesh_type:
				"box": mm.mesh = BoxMesh.new()
				"sphere": mm.mesh = SphereMesh.new()
				"cylinder": mm.mesh = CylinderMesh.new()
				_: mm.mesh = BoxMesh.new()
			mmi.multimesh = mm
			if params.has("name") and not (params["name"] as String).is_empty():
				mmi.name = params["name"]
			parent.add_child(mmi)
			server._send_response({"success": true, "action": "create", "path": str(mmi.get_path()), "count": mm.instance_count})
		"set_instance":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is MultiMeshInstance3D:
				server._send_response({"error": "MultiMeshInstance3D not found: %s" % node_path})
				return
			var idx: int = int(params.get("index", 0))
			var tf: Dictionary = params.get("transform", {})
			var origin: Dictionary = tf.get("origin", {})
			var xform: Transform3D = Transform3D.IDENTITY
			xform.origin = Vector3(float(origin.get("x", 0)), float(origin.get("y", 0)), float(origin.get("z", 0)))
			(node as MultiMeshInstance3D).multimesh.set_instance_transform(idx, xform)
			server._send_response({"success": true, "action": "set_instance", "index": idx})
		"get_info":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is MultiMeshInstance3D:
				server._send_response({"error": "MultiMeshInstance3D not found: %s" % node_path})
				return
			var mm = (node as MultiMeshInstance3D).multimesh
			server._send_response({"success": true, "count": mm.instance_count if mm else 0, "visible_count": mm.visible_instance_count if mm else 0})
		_:
			server._send_response({"error": "Unknown multimesh action: %s" % action})


func _cmd_procedural_mesh(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent not found: %s" % parent_path})
		return
	var verts_arr: Array = params.get("vertices", [])
	var verts: PackedVector3Array = PackedVector3Array()
	for v in verts_arr:
		verts.append(Vector3(float(v[0]), float(v[1]), float(v[2])))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if params.has("normals"):
		var norms: PackedVector3Array = PackedVector3Array()
		for n in params["normals"]:
			norms.append(Vector3(float(n[0]), float(n[1]), float(n[2])))
		arrays[Mesh.ARRAY_NORMAL] = norms
	if params.has("uvs"):
		var uvs: PackedVector2Array = PackedVector2Array()
		for uv in params["uvs"]:
			uvs.append(Vector2(float(uv[0]), float(uv[1])))
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if params.has("indices"):
		var indices: PackedInt32Array = PackedInt32Array()
		for idx in params["indices"]:
			indices.append(int(idx))
		arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	if params.has("name") and not (params["name"] as String).is_empty():
		mi.name = params["name"]
	parent.add_child(mi)
	server._send_response({"success": true, "path": str(mi.get_path()), "vertex_count": verts.size()})


func _cmd_light_3d(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	if action == "create":
		var parent_path: String = params.get("parent_path", "/root")
		var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
		if parent == null:
			server._send_response({"error": "Parent not found: %s" % parent_path})
			return
		var light_type: String = params.get("light_type", "omni")
		var light: Light3D
		match light_type:
			"directional": light = DirectionalLight3D.new()
			"omni": light = OmniLight3D.new()
			"spot": light = SpotLight3D.new()
			_:
				server._send_response({"error": "Unknown light type: %s" % light_type})
				return
		if params.has("color"):
			var c: Dictionary = params["color"]
			light.light_color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)))
		if params.has("energy"):
			light.light_energy = float(params["energy"])
		if params.has("shadows"):
			light.shadow_enabled = bool(params["shadows"])
		if light is OmniLight3D and params.has("range"):
			(light as OmniLight3D).omni_range = float(params["range"])
		if light is SpotLight3D:
			if params.has("range"):
				(light as SpotLight3D).spot_range = float(params["range"])
			if params.has("spot_angle"):
				(light as SpotLight3D).spot_angle = float(params["spot_angle"])
		if params.has("name") and not (params["name"] as String).is_empty():
			light.name = params["name"]
		parent.add_child(light)
		server._send_response({"success": true, "action": "create", "path": str(light.get_path()), "type": light_type})
	elif action == "configure":
		var node_path: String = params.get("node_path", "")
		var node: Node = server.get_tree().root.get_node_or_null(node_path)
		if node == null or not node is Light3D:
			server._send_response({"error": "Light3D not found: %s" % node_path})
			return
		var light: Light3D = node as Light3D
		if params.has("color"):
			var c: Dictionary = params["color"]
			light.light_color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)))
		if params.has("energy"):
			light.light_energy = float(params["energy"])
		if params.has("shadows"):
			light.shadow_enabled = bool(params["shadows"])
		server._send_response({"success": true, "action": "configure", "path": str(node.get_path())})
	else:
		server._send_response({"error": "Unknown light_3d action: %s" % action})


func _cmd_mesh_instance(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent not found: %s" % parent_path})
		return
	var mesh_type: String = params.get("mesh_type", "box")
	var mesh: Mesh
	match mesh_type:
		"box": mesh = BoxMesh.new()
		"sphere": mesh = SphereMesh.new()
		"cylinder": mesh = CylinderMesh.new()
		"capsule": mesh = CapsuleMesh.new()
		"plane": mesh = PlaneMesh.new()
		"quad": mesh = QuadMesh.new()
		_:
			server._send_response({"error": "Unknown mesh type: %s" % mesh_type})
			return
	if params.has("size") and mesh is BoxMesh:
		var s: Dictionary = params["size"]
		(mesh as BoxMesh).size = Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1)))
	if params.has("radius"):
		if mesh is SphereMesh: (mesh as SphereMesh).radius = float(params["radius"])
		elif mesh is CylinderMesh: (mesh as CylinderMesh).top_radius = float(params["radius"])
		elif mesh is CapsuleMesh: (mesh as CapsuleMesh).radius = float(params["radius"])
	if params.has("height"):
		if mesh is CylinderMesh: (mesh as CylinderMesh).height = float(params["height"])
		elif mesh is CapsuleMesh: (mesh as CapsuleMesh).height = float(params["height"])
		elif mesh is SphereMesh: (mesh as SphereMesh).height = float(params["height"])
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	if params.has("material") and params["material"] is String:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var hex: String = params["material"]
		if hex.begins_with("#") or hex.length() == 6 or hex.length() == 8:
			mat.albedo_color = Color.from_string(hex, Color.WHITE)
		mi.material_override = mat
	if params.has("name") and not (params["name"] as String).is_empty():
		mi.name = params["name"]
	parent.add_child(mi)
	server._send_response({"success": true, "path": str(mi.get_path()), "mesh_type": mesh_type})


func _cmd_gridmap(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is GridMap:
		server._send_response({"error": "GridMap not found: %s" % node_path})
		return
	var gm: GridMap = node as GridMap
	var action: String = params.get("action", "get_used")
	match action:
		"set_cell":
			gm.set_cell_item(Vector3i(int(params.get("x", 0)), int(params.get("y", 0)), int(params.get("z", 0))), int(params.get("item", 0)), int(params.get("orientation", 0)))
			server._send_response({"success": true, "action": "set_cell"})
		"get_cell":
			var item: int = gm.get_cell_item(Vector3i(int(params.get("x", 0)), int(params.get("y", 0)), int(params.get("z", 0))))
			server._send_response({"success": true, "action": "get_cell", "item": item})
		"clear":
			gm.clear()
			server._send_response({"success": true, "action": "clear"})
		"get_used":
			var cells: Array = gm.get_used_cells()
			var result: Array = []
			for c in cells.slice(0, 100):
				result.append({"x": c.x, "y": c.y, "z": c.z})
			server._send_response({"success": true, "action": "get_used", "cells": result, "total": cells.size()})
		_:
			server._send_response({"error": "Unknown gridmap action: %s" % action})


func _cmd_3d_effects(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent not found: %s" % parent_path})
		return
	var effect_type: String = params.get("effect_type", "")
	var node: Node3D
	match effect_type:
		"reflection_probe": node = ReflectionProbe.new()
		"decal": node = Decal.new()
		"fog_volume": node = FogVolume.new()
		_:
			server._send_response({"error": "Unknown effect type: %s" % effect_type})
			return
	if params.has("size"):
		var s: Dictionary = params["size"]
		var size_v: Vector3 = Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1)))
		if node is ReflectionProbe: (node as ReflectionProbe).size = size_v
		elif node is Decal: (node as Decal).size = size_v
		elif node is FogVolume: (node as FogVolume).size = size_v
	if params.has("name") and not (params["name"] as String).is_empty():
		node.name = params["name"]
	parent.add_child(node)
	server._send_response({"success": true, "path": str(node.get_path()), "effect_type": effect_type})


func _cmd_gi(params: Dictionary) -> void:
	var parent_path: String = params.get("parent_path", "/root")
	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent not found: %s" % parent_path})
		return
	var gi_type: String = params.get("gi_type", "voxel_gi")
	var node: VisualInstance3D
	match gi_type:
		"voxel_gi": node = VoxelGI.new()
		"lightmap_gi": node = LightmapGI.new()
		_:
			server._send_response({"error": "Unknown GI type: %s" % gi_type})
			return
	if params.has("size") and node is VoxelGI:
		var s: Dictionary = params["size"]
		(node as VoxelGI).size = Vector3(float(s.get("x", 10)), float(s.get("y", 10)), float(s.get("z", 10)))
	if params.has("name") and not (params["name"] as String).is_empty():
		node.name = params["name"]
	parent.add_child(node)
	server._send_response({"success": true, "path": str(node.get_path()), "gi_type": gi_type})


func _cmd_path_3d(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var path_node: Path3D = Path3D.new()
			path_node.curve = Curve3D.new()
			if params.has("name") and not (params["name"] as String).is_empty():
				path_node.name = params["name"]
			if params.has("points"):
				for p in params["points"]:
					path_node.curve.add_point(Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0))))
			parent.add_child(path_node)
			server._send_response({"success": true, "action": "create", "path": str(path_node.get_path()), "point_count": path_node.curve.point_count})
		"add_point":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path3D:
				server._send_response({"error": "Path3D not found: %s" % node_path})
				return
			var p: Dictionary = params.get("point", {})
			(node as Path3D).curve.add_point(Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0))))
			server._send_response({"success": true, "action": "add_point", "point_count": (node as Path3D).curve.point_count})
		"get_points":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path3D:
				server._send_response({"error": "Path3D not found: %s" % node_path})
				return
			var pts: Array = []
			for i in (node as Path3D).curve.point_count:
				var pt: Vector3 = (node as Path3D).curve.get_point_position(i)
				pts.append({"x": pt.x, "y": pt.y, "z": pt.z})
			server._send_response({"success": true, "action": "get_points", "points": pts})
		"set_points":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path3D:
				server._send_response({"error": "Path3D not found: %s" % node_path})
				return
			var curve: Curve3D = (node as Path3D).curve
			if curve == null:
				curve = Curve3D.new()
				(node as Path3D).curve = curve
			curve.clear_points()
			for p in params.get("points", []):
				curve.add_point(Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0))))
			server._send_response({"success": true, "action": "set_points", "point_count": curve.point_count})
		_:
			server._send_response({"error": "Unknown path_3d action: %s" % action})


func _cmd_sky(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	var env: Environment = _get_or_create_environment()
	if env == null:
		server._send_response({"error": "Could not get or create environment"})
		return
	var sky_type: String = params.get("sky_type", "procedural")
	if action == "create" or env.sky == null:
		env.sky = Sky.new()
		env.background_mode = Environment.BG_SKY
	var sky_mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		sky_mat = ProceduralSkyMaterial.new()
	if params.has("top_color"):
		var c: Dictionary = params["top_color"]
		sky_mat.sky_top_color = Color(float(c.get("r", 0.4)), float(c.get("g", 0.6)), float(c.get("b", 1.0)))
	if params.has("bottom_color"):
		var c: Dictionary = params["bottom_color"]
		sky_mat.sky_horizon_color = Color(float(c.get("r", 0.7)), float(c.get("g", 0.8)), float(c.get("b", 0.9)))
	if params.has("ground_color"):
		var c: Dictionary = params["ground_color"]
		sky_mat.ground_bottom_color = Color(float(c.get("r", 0.1)), float(c.get("g", 0.1)), float(c.get("b", 0.1)))
	if params.has("sun_energy"):
		sky_mat.sun_curve = float(params["sun_energy"])
	env.sky.sky_material = sky_mat
	server._send_response({"success": true, "action": action, "sky_type": sky_type})


func _cmd_camera_attributes(params: Dictionary) -> void:
	var action: String = params.get("action", "get")
	var cam: Camera3D = server.get_viewport().get_camera_3d()
	if cam == null:
		server._send_response({"error": "No Camera3D found in viewport"})
		return
	if action == "get":
		var info: Dictionary = {"success": true, "action": "get"}
		if cam.attributes != null:
			info["has_attributes"] = true
		else:
			info["has_attributes"] = false
		server._send_response(info)
		return
	# set
	if cam.attributes == null:
		cam.attributes = CameraAttributesPractical.new()
	var attr: CameraAttributesPractical = cam.attributes as CameraAttributesPractical
	if attr == null:
		server._send_response({"error": "Camera attributes is not CameraAttributesPractical"})
		return
	if params.has("dof_blur_far"):
		attr.dof_blur_far_enabled = true
		attr.dof_blur_far_distance = float(params["dof_blur_far"])
	if params.has("dof_blur_near"):
		attr.dof_blur_near_enabled = true
		attr.dof_blur_near_distance = float(params["dof_blur_near"])
	if params.has("dof_blur_amount"):
		attr.dof_blur_amount = float(params["dof_blur_amount"])
	if params.has("auto_exposure"):
		attr.auto_exposure_enabled = bool(params["auto_exposure"])
	server._send_response({"success": true, "action": "set"})


func _cmd_navigation_3d(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var region: NavigationRegion3D = NavigationRegion3D.new()
			region.navigation_mesh = NavigationMesh.new()
			if params.has("cell_size"):
				region.navigation_mesh.cell_size = float(params["cell_size"])
			if params.has("agent_radius"):
				region.navigation_mesh.agent_radius = float(params["agent_radius"])
			if params.has("agent_height"):
				region.navigation_mesh.agent_height = float(params["agent_height"])
			if params.has("name") and not (params["name"] as String).is_empty():
				region.name = params["name"]
			parent.add_child(region)
			server._send_response({"success": true, "action": "create", "path": str(region.get_path())})
		"bake":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is NavigationRegion3D:
				server._send_response({"error": "NavigationRegion3D not found: %s" % node_path})
				return
			(node as NavigationRegion3D).bake_navigation_mesh()
			await server.get_tree().process_frame
			await server.get_tree().process_frame
			server._send_response({"success": true, "action": "bake"})
		_:
			server._send_response({"error": "Unknown navigation_3d action: %s" % action})


func _cmd_physics_3d(params: Dictionary) -> void:
	var action: String = params.get("action", "ray")
	await server.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = server.get_viewport().world_3d.direct_space_state
	match action:
		"ray":
			var from_d: Dictionary = params.get("from", {})
			var to_d: Dictionary = params.get("to", {})
			var from: Vector3 = Vector3(float(from_d.get("x", 0)), float(from_d.get("y", 0)), float(from_d.get("z", 0)))
			var to: Vector3 = Vector3(float(to_d.get("x", 0)), float(to_d.get("y", 0)), float(to_d.get("z", 0)))
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
			if params.has("collision_mask"):
				query.collision_mask = int(params["collision_mask"])
			var result: Dictionary = space.intersect_ray(query)
			if result.is_empty():
				server._send_response({"success": true, "action": "ray", "hit": false})
			else:
				server._send_response({"success": true, "action": "ray", "hit": true, "position": McpSerialization.variant_to_json(result["position"]), "normal": McpSerialization.variant_to_json(result["normal"]), "collider": str(result.get("collider", ""))})
		"overlap":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Area3D:
				server._send_response({"error": "Area3D not found: %s" % node_path})
				return
			var bodies: Array = (node as Area3D).get_overlapping_bodies()
			var result: Array = []
			for b in bodies:
				result.append({"name": b.name, "path": str(b.get_path())})
			server._send_response({"success": true, "action": "overlap", "bodies": result})
		_:
			server._send_response({"error": "Unknown physics_3d action: %s" % action})


# ==========================================================================
# Batch 3: 2D Systems + Animation Advanced + Audio Effects
# ==========================================================================


func _cmd_canvas(params: Dictionary) -> void:
	var action: String = params.get("action", "create_layer")
	match action:
		"create_layer":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var cl: CanvasLayer = CanvasLayer.new()
			if params.has("layer"):
				cl.layer = int(params["layer"])
			if params.has("name") and not (params["name"] as String).is_empty():
				cl.name = params["name"]
			parent.add_child(cl)
			server._send_response({"success": true, "action": "create_layer", "path": str(cl.get_path())})
		"create_modulate":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var cm: CanvasModulate = CanvasModulate.new()
			if params.has("color"):
				var c: Dictionary = params["color"]
				cm.color = Color(float(c.get("r", 1)), float(c.get("g", 1)), float(c.get("b", 1)), float(c.get("a", 1)))
			if params.has("name") and not (params["name"] as String).is_empty():
				cm.name = params["name"]
			parent.add_child(cm)
			server._send_response({"success": true, "action": "create_modulate", "path": str(cm.get_path())})
		"configure":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null:
				server._send_response({"error": "Node not found: %s" % node_path})
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
				server._send_response({"error": "Node is not a CanvasLayer or CanvasModulate: %s" % node.get_class()})
				return
			server._send_response({"success": true, "action": "configure", "applied": applied})
		_:
			server._send_response({"error": "Unknown canvas action: %s" % action})


func _cmd_light_2d(params: Dictionary) -> void:
	var action: String = params.get("action", "create_point")
	var parent_path: String = params.get("parent_path", "/root")
	var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
	if parent == null:
		server._send_response({"error": "Parent not found: %s" % parent_path})
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
			server._send_response({"success": true, "action": "create_point", "path": str(light.get_path())})
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
			server._send_response({"success": true, "action": "create_directional", "path": str(light.get_path())})
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
			server._send_response({"success": true, "action": "create_occluder", "path": str(occ.get_path()), "point_count": packed.size()})
		_:
			server._send_response({"error": "Unknown light_2d action: %s" % action})


func _cmd_parallax(params: Dictionary) -> void:
	var action: String = params.get("action", "create_background")
	match action:
		"create_background":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var bg: ParallaxBackground = ParallaxBackground.new()
			if params.has("name") and not (params["name"] as String).is_empty():
				bg.name = params["name"]
			parent.add_child(bg)
			server._send_response({"success": true, "action": "create_background", "path": str(bg.get_path())})
		"add_layer":
			var parent_path: String = params.get("parent_path", "")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null or not parent is ParallaxBackground:
				server._send_response({"error": "ParallaxBackground not found: %s" % parent_path})
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
			server._send_response({"success": true, "action": "add_layer", "path": str(layer.get_path())})
		"configure":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null:
				server._send_response({"error": "Node not found: %s" % node_path})
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
				server._send_response({"error": "Node is not a ParallaxBackground or ParallaxLayer: %s" % node.get_class()})
				return
			server._send_response({"success": true, "action": "configure", "applied": applied})
		_:
			server._send_response({"error": "Unknown parallax action: %s" % action})


func _cmd_shape_2d(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
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
			server._send_response({"success": true, "action": "add_point"})
		"set_points":
			var pts: Array = params.get("points", [])
			var packed: PackedVector2Array = PackedVector2Array()
			for p in pts:
				packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			if node is Line2D:
				(node as Line2D).points = packed
			elif node is Polygon2D:
				(node as Polygon2D).polygon = packed
			server._send_response({"success": true, "action": "set_points", "count": packed.size()})
		"clear":
			if node is Line2D:
				(node as Line2D).clear_points()
			elif node is Polygon2D:
				(node as Polygon2D).polygon = PackedVector2Array()
			server._send_response({"success": true, "action": "clear"})
		"get_points":
			var pts: PackedVector2Array
			if node is Line2D:
				pts = (node as Line2D).points
			elif node is Polygon2D:
				pts = (node as Polygon2D).polygon
			else:
				server._send_response({"error": "Node is not Line2D or Polygon2D"})
				return
			var result: Array = []
			for p in pts:
				result.append({"x": p.x, "y": p.y})
			server._send_response({"success": true, "action": "get_points", "points": result})
		_:
			server._send_response({"error": "Unknown shape_2d action: %s" % action})


func _cmd_path_2d(params: Dictionary) -> void:
	var action: String = params.get("action", "create")
	match action:
		"create":
			var parent_path: String = params.get("parent_path", "/root")
			var parent: Node = server.get_tree().root.get_node_or_null(parent_path)
			if parent == null:
				server._send_response({"error": "Parent not found: %s" % parent_path})
				return
			var path_node: Path2D = Path2D.new()
			path_node.curve = Curve2D.new()
			if params.has("name") and not (params["name"] as String).is_empty():
				path_node.name = params["name"]
			if params.has("points"):
				for p in params["points"]:
					path_node.curve.add_point(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			parent.add_child(path_node)
			server._send_response({"success": true, "action": "create", "path": str(path_node.get_path()), "point_count": path_node.curve.point_count})
		"add_point":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path2D:
				server._send_response({"error": "Path2D not found: %s" % node_path})
				return
			var p: Dictionary = params.get("point", {})
			(node as Path2D).curve.add_point(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
			server._send_response({"success": true, "action": "add_point", "point_count": (node as Path2D).curve.point_count})
		"get_points":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Path2D:
				server._send_response({"error": "Path2D not found: %s" % node_path})
				return
			var pts: Array = []
			for i in (node as Path2D).curve.point_count:
				var pt: Vector2 = (node as Path2D).curve.get_point_position(i)
				pts.append({"x": pt.x, "y": pt.y})
			server._send_response({"success": true, "action": "get_points", "points": pts})
		_:
			server._send_response({"error": "Unknown path_2d action: %s" % action})


func _cmd_physics_2d(params: Dictionary) -> void:
	var action: String = params.get("action", "ray")
	await server.get_tree().physics_frame
	var space: PhysicsDirectSpaceState2D = server.get_viewport().world_2d.direct_space_state
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
				server._send_response({"success": true, "action": "ray", "hit": false})
			else:
				server._send_response({"success": true, "action": "ray", "hit": true, "position": McpSerialization.variant_to_json(result["position"]), "normal": McpSerialization.variant_to_json(result["normal"]), "collider": str(result.get("collider", ""))})
		"overlap":
			var node_path: String = params.get("node_path", "")
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null or not node is Area2D:
				server._send_response({"error": "Area2D not found: %s" % node_path})
				return
			var bodies: Array = (node as Area2D).get_overlapping_bodies()
			var result: Array = []
			for b in bodies:
				result.append({"name": b.name, "path": str(b.get_path())})
			server._send_response({"success": true, "action": "overlap", "bodies": result})
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
			server._send_response({"success": true, "action": "point_query", "count": out.size(), "results": out})
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
			server._send_response({"success": true, "action": "shape_query", "count": sout.size(), "results": sout})
		_:
			server._send_response({"error": "Unknown physics_2d action: %s" % action})


func _cmd_animation_tree(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is AnimationTree:
		server._send_response({"error": "AnimationTree not found: %s" % node_path})
		return
	var tree: AnimationTree = node as AnimationTree
	var action: String = params.get("action", "get_state")
	match action:
		"travel":
			var state_name: String = params.get("state_name", "")
			var playback = tree.get("parameters/playback")
			if playback != null:
				playback.travel(state_name)
			server._send_response({"success": true, "action": "travel", "state": state_name})
		"set_param":
			var param_name: String = params.get("param_name", "")
			var param_value = params.get("param_value", 0)
			tree.set("parameters/" + param_name, param_value)
			server._send_response({"success": true, "action": "set_param", "param": param_name})
		"get_state":
			var playback = tree.get("parameters/playback")
			var current: String = ""
			if playback != null:
				current = playback.get_current_node()
			server._send_response({"success": true, "action": "get_state", "current": current})
		_:
			server._send_response({"error": "Unknown animation_tree action: %s" % action})


func _cmd_animation_control(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is AnimationPlayer:
		server._send_response({"error": "AnimationPlayer not found: %s" % node_path})
		return
	var player: AnimationPlayer = node as AnimationPlayer
	var action: String = params.get("action", "get_info")
	match action:
		"seek":
			var pos: float = float(params.get("position", 0))
			player.seek(pos)
			server._send_response({"success": true, "action": "seek", "position": pos})
		"queue":
			var anim: String = params.get("animation_name", "")
			player.queue(anim)
			server._send_response({"success": true, "action": "queue", "animation": anim})
		"set_speed":
			player.speed_scale = float(params.get("speed", 1.0))
			server._send_response({"success": true, "action": "set_speed", "speed": player.speed_scale})
		"stop":
			player.stop()
			server._send_response({"success": true, "action": "stop"})
		"get_info":
			var anims: PackedStringArray = player.get_animation_list()
			server._send_response({"success": true, "action": "get_info", "current": player.current_animation, "playing": player.is_playing(), "animations": Array(anims), "speed_scale": player.speed_scale, "position": player.current_animation_position})
		_:
			server._send_response({"error": "Unknown animation_control action: %s" % action})


func _cmd_skeleton_ik(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is SkeletonIK3D:
		server._send_response({"error": "SkeletonIK3D not found: %s" % node_path})
		return
	var ik: SkeletonIK3D = node as SkeletonIK3D
	var action: String = params.get("action", "start")
	match action:
		"start":
			ik.start()
			server._send_response({"success": true, "action": "start"})
		"stop":
			ik.stop()
			server._send_response({"success": true, "action": "stop"})
		"set_target":
			var t: Dictionary = params.get("target", {})
			var target_tf: Transform3D = Transform3D.IDENTITY
			target_tf.origin = Vector3(float(t.get("x", 0)), float(t.get("y", 0)), float(t.get("z", 0)))
			ik.target = target_tf
			server._send_response({"success": true, "action": "set_target"})
		_:
			server._send_response({"error": "Unknown skeleton_ik action: %s" % action})


func _cmd_audio_effect(params: Dictionary) -> void:
	var bus_name: String = params.get("bus_name", "Master")
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		server._send_response({"error": "Audio bus not found: %s" % bus_name})
		return
	var action: String = params.get("action", "list")
	match action:
		"list":
			var effects: Array = []
			for i in AudioServer.get_bus_effect_count(bus_idx):
				var eff: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
				effects.append({"index": i, "type": eff.get_class(), "enabled": AudioServer.is_bus_effect_enabled(bus_idx, i)})
			server._send_response({"success": true, "action": "list", "bus": bus_name, "effects": effects})
		"add":
			var effect_type: String = params.get("effect_type", "reverb")
			var effect: AudioEffect
			match effect_type:
				"reverb": effect = AudioEffectReverb.new()
				"delay": effect = AudioEffectDelay.new()
				"chorus": effect = AudioEffectChorus.new()
				"eq": effect = AudioEffectEQ6.new()
				"compressor": effect = AudioEffectCompressor.new()
				"limiter": effect = AudioEffectLimiter.new()
				_:
					server._send_response({"error": "Unknown effect type: %s" % effect_type})
					return
			AudioServer.add_bus_effect(bus_idx, effect)
			server._send_response({"success": true, "action": "add", "effect_type": effect_type, "index": AudioServer.get_bus_effect_count(bus_idx) - 1})
		"remove":
			var idx: int = int(params.get("index", 0))
			AudioServer.remove_bus_effect(bus_idx, idx)
			server._send_response({"success": true, "action": "remove", "index": idx})
		"configure":
			var idx: int = int(params.get("index", 0))
			if idx < 0 or idx >= AudioServer.get_bus_effect_count(bus_idx):
				server._send_response({"error": "Effect index out of range: %d" % idx})
				return
			var eff: AudioEffect = AudioServer.get_bus_effect(bus_idx, idx)
			var applied: Array = []
			var props: Dictionary = params.get("properties", {})
			for key in props:
				eff.set(key, props[key])
				applied.append(str(key))
			if params.has("enabled"):
				AudioServer.set_bus_effect_enabled(bus_idx, idx, bool(params["enabled"]))
				applied.append("enabled")
			server._send_response({"success": true, "action": "configure", "index": idx, "applied": applied})
		_:
			server._send_response({"error": "Unknown audio_effect action: %s" % action})


func _cmd_audio_bus_layout(params: Dictionary) -> void:
	var action: String = params.get("action", "list")
	match action:
		"list":
			var buses: Array = []
			for i in AudioServer.bus_count:
				buses.append({"index": i, "name": AudioServer.get_bus_name(i), "volume": AudioServer.get_bus_volume_db(i), "mute": AudioServer.is_bus_mute(i), "solo": AudioServer.is_bus_solo(i), "send": AudioServer.get_bus_send(i), "effect_count": AudioServer.get_bus_effect_count(i)})
			server._send_response({"success": true, "action": "list", "buses": buses})
		"add":
			var bus_name: String = params.get("bus_name", "New Bus")
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			server._send_response({"success": true, "action": "add", "bus_name": bus_name, "index": idx})
		"remove":
			var bus_name: String = params.get("bus_name", "")
			var idx: int = AudioServer.get_bus_index(bus_name)
			if idx <= 0:
				server._send_response({"error": "Cannot remove bus: %s" % bus_name})
				return
			AudioServer.remove_bus(idx)
			server._send_response({"success": true, "action": "remove", "bus_name": bus_name})
		"set_send":
			var bus_name: String = params.get("bus_name", "")
			var send_to: String = params.get("send_to", "Master")
			var idx: int = AudioServer.get_bus_index(bus_name)
			if idx < 0:
				server._send_response({"error": "Bus not found: %s" % bus_name})
				return
			AudioServer.set_bus_send(idx, send_to)
			server._send_response({"success": true, "action": "set_send", "bus": bus_name, "send_to": send_to})
		_:
			server._send_response({"error": "Unknown audio_bus_layout action: %s" % action})


func _cmd_audio_spatial(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null or not node is AudioStreamPlayer3D:
		server._send_response({"error": "AudioStreamPlayer3D not found: %s" % node_path})
		return
	var player: AudioStreamPlayer3D = node as AudioStreamPlayer3D
	var action: String = params.get("action", "get_info")
	if action == "get_info":
		server._send_response({"success": true, "max_distance": player.max_distance, "unit_size": player.unit_size, "max_db": player.max_db, "playing": player.playing})
		return
	if params.has("max_distance"):
		player.max_distance = float(params["max_distance"])
	if params.has("unit_size"):
		player.unit_size = float(params["unit_size"])
	if params.has("max_db"):
		player.max_db = float(params["max_db"])
	server._send_response({"success": true, "action": "configure"})


# ==========================================================================
# Batch 4: Locale (runtime)
# ==========================================================================


func _cmd_get_audio(_params: Dictionary) -> void:
	var buses: Array = []
	for i in AudioServer.bus_count:
		buses.append({
			"name": AudioServer.get_bus_name(i),
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
		})

	var players: Array = []
	_find_audio_players(server.get_tree().root, players)

	server._send_response({"success": true, "buses": buses, "players": players})


func _cmd_audio_play(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var action: String = params.get("action", "play")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		server._send_response({"error": "Node is not an AudioStreamPlayer: %s (is %s)" % [node_path, node.get_class()]})
		return

	# Optionally load a new stream
	if params.has("stream"):
		var stream_path: String = params["stream"]
		var stream: AudioStream = load(stream_path) as AudioStream
		if stream == null:
			server._send_response({"error": "Failed to load audio stream: %s" % stream_path})
			return
		node.set("stream", stream)

	# Set optional properties
	if params.has("volume"):
		var linear_vol: float = float(params["volume"])
		node.set("volume_db", linear_to_db(clampf(linear_vol, 0.0, 1.0)))
	if params.has("pitch"):
		node.set("pitch_scale", float(params["pitch"]))
	if params.has("bus"):
		node.set("bus", params["bus"])

	match action:
		"play":
			var from_pos: float = float(params.get("from_position", 0.0))
			node.call("play", from_pos)
			server._send_response({"success": true, "action": "play", "node_path": node_path})
		"stop":
			node.call("stop")
			server._send_response({"success": true, "action": "stop", "node_path": node_path})
		"pause":
			node.set("stream_paused", true)
			server._send_response({"success": true, "action": "pause", "node_path": node_path})
		"resume":
			node.set("stream_paused", false)
			server._send_response({"success": true, "action": "resume", "node_path": node_path})
		_:
			server._send_response({"error": "Unknown audio action: %s. Use play, stop, pause, or resume" % action})


# --- Audio Bus ---


func _cmd_audio_bus(params: Dictionary) -> void:
	var bus_name: String = params.get("bus_name", "Master")
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		server._send_response({"error": "Audio bus not found: %s" % bus_name})
		return

	if params.has("volume"):
		var linear_vol: float = float(params["volume"])
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clampf(linear_vol, 0.0, 1.0)))
	if params.has("mute"):
		AudioServer.set_bus_mute(bus_idx, bool(params["mute"]))
	if params.has("solo"):
		AudioServer.set_bus_solo(bus_idx, bool(params["solo"]))

	server._send_response({
		"success": true,
		"bus_name": bus_name,
		"volume_db": AudioServer.get_bus_volume_db(bus_idx),
		"mute": AudioServer.is_bus_mute(bus_idx),
		"solo": AudioServer.is_bus_solo(bus_idx)
	})


# --- Navigate Path ---


func _cmd_set_shader_param(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var param_name: String = params.get("param_name", "")
	if node_path.is_empty() or param_name.is_empty():
		server._send_response({"error": "node_path and param_name are required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	var material: Material = null
	# Try material_override first (MeshInstance3D/2D)
	if node.get("material_override") != null:
		material = node.get("material_override")
	# Try surface override material (MeshInstance3D)
	elif node.has_method("get_surface_override_material"):
		material = node.get_surface_override_material(0)
	# Try material property (CanvasItem, e.g. Sprite2D)
	elif node.get("material") != null:
		material = node.get("material")

	if material == null or not material is ShaderMaterial:
		server._send_response({"error": "No ShaderMaterial found on node: %s" % node_path})
		return

	var shader_mat: ShaderMaterial = material as ShaderMaterial
	var raw_value: Variant = params.get("value", null)
	var type_hint: String = params.get("type_hint", "")
	var value: Variant = McpSerialization.json_to_variant(raw_value, type_hint)
	shader_mat.set_shader_parameter(param_name, value)
	server._send_response({"success": true, "node_path": node_path, "param_name": param_name, "value": McpSerialization.variant_to_json(shader_mat.get_shader_parameter(param_name))})


# --- Audio Play ---


func _cmd_environment(params: Dictionary) -> void:
	var action: String = params.get("action", "set")

	# Find existing WorldEnvironment or Camera3D environment
	var env: Environment = null
	var world_env: Node = null

	# Search for WorldEnvironment node
	var found: Array = []
	_find_by_class_recursive(server.get_tree().root, "WorldEnvironment", found)
	if found.size() > 0:
		world_env = server.get_tree().root.get_node_or_null(found[0]["path"])
		if world_env != null:
			env = world_env.get("environment") as Environment

	# Fallback: check Camera3D
	if env == null:
		var cam3d: Camera3D = server.get_viewport().get_camera_3d()
		if cam3d != null and cam3d.get("environment") != null:
			env = cam3d.get("environment") as Environment

	if action == "get":
		if env == null:
			server._send_response({"error": "No Environment resource found"})
			return
		server._send_response(_get_environment_state(env))
		return

	# action == "set": create if needed
	if env == null:
		env = Environment.new()
		var we: WorldEnvironment = WorldEnvironment.new()
		we.environment = env
		server.get_tree().root.add_child(we)
		world_env = we

	# Apply settings
	if params.has("background_mode"):
		env.background_mode = int(params["background_mode"]) as Environment.BGMode
	if params.has("background_color"):
		var c: Dictionary = params["background_color"]
		env.background_color = Color(float(c.get("r", 0)), float(c.get("g", 0)), float(c.get("b", 0)), float(c.get("a", 1)))
	if params.has("ambient_light_color"):
		var c: Dictionary = params["ambient_light_color"]
		env.ambient_light_color = Color(float(c.get("r", 0)), float(c.get("g", 0)), float(c.get("b", 0)), float(c.get("a", 1)))
	if params.has("ambient_light_energy"):
		env.ambient_light_energy = float(params["ambient_light_energy"])
	if params.has("fog_enabled"):
		env.fog_enabled = bool(params["fog_enabled"])
	if params.has("fog_density"):
		env.fog_density = float(params["fog_density"])
	if params.has("fog_light_color"):
		var c: Dictionary = params["fog_light_color"]
		env.fog_light_color = Color(float(c.get("r", 0)), float(c.get("g", 0)), float(c.get("b", 0)), float(c.get("a", 1)))
	if params.has("glow_enabled"):
		env.glow_enabled = bool(params["glow_enabled"])
	if params.has("glow_intensity"):
		env.glow_intensity = float(params["glow_intensity"])
	if params.has("glow_bloom"):
		env.glow_bloom = float(params["glow_bloom"])
	if params.has("tonemap_mode"):
		env.tonemap_mode = int(params["tonemap_mode"]) as Environment.ToneMapper
	if params.has("ssao_enabled"):
		env.ssao_enabled = bool(params["ssao_enabled"])
	if params.has("ssao_radius"):
		env.ssao_radius = float(params["ssao_radius"])
	if params.has("ssao_intensity"):
		env.ssao_intensity = float(params["ssao_intensity"])
	if params.has("ssr_enabled"):
		env.ssr_enabled = bool(params["ssr_enabled"])
	if params.has("brightness"):
		env.adjustment_enabled = true
		env.adjustment_brightness = float(params["brightness"])
	if params.has("contrast"):
		env.adjustment_enabled = true
		env.adjustment_contrast = float(params["contrast"])
	if params.has("saturation"):
		env.adjustment_enabled = true
		env.adjustment_saturation = float(params["saturation"])

	server._send_response(_get_environment_state(env))


func _cmd_bone_pose(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var action: String = params.get("action", "list")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is Skeleton3D:
		server._send_response({"error": "Node is not a Skeleton3D: %s (is %s)" % [node_path, node.get_class()]})
		return

	var skel: Skeleton3D = node as Skeleton3D

	match action:
		"list":
			var bones: Array = []
			for i in skel.get_bone_count():
				bones.append({"index": i, "name": skel.get_bone_name(i), "parent": skel.get_bone_parent(i)})
			server._send_response({"success": true, "action": "list", "bone_count": skel.get_bone_count(), "bones": bones})
		"get":
			var bone_idx: int = _resolve_bone_index(skel, params)
			if bone_idx < 0:
				server._send_response({"error": "Bone not found"})
				return
			server._send_response({
				"success": true, "action": "get", "bone_index": bone_idx,
				"bone_name": skel.get_bone_name(bone_idx),
				"position": McpSerialization.variant_to_json(skel.get_bone_pose_position(bone_idx)),
				"rotation": McpSerialization.variant_to_json(skel.get_bone_pose_rotation(bone_idx)),
				"scale": McpSerialization.variant_to_json(skel.get_bone_pose_scale(bone_idx))
			})
		"set":
			var bone_idx: int = _resolve_bone_index(skel, params)
			if bone_idx < 0:
				server._send_response({"error": "Bone not found"})
				return
			if params.has("position"):
				var p: Dictionary = params["position"]
				skel.set_bone_pose_position(bone_idx, Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0))))
			if params.has("rotation"):
				var r: Dictionary = params["rotation"]
				skel.set_bone_pose_rotation(bone_idx, Quaternion(float(r.get("x", 0)), float(r.get("y", 0)), float(r.get("z", 0)), float(r.get("w", 1))))
			if params.has("scale"):
				var s: Dictionary = params["scale"]
				skel.set_bone_pose_scale(bone_idx, Vector3(float(s.get("x", 1)), float(s.get("y", 1)), float(s.get("z", 1))))
			server._send_response({"success": true, "action": "set", "bone_index": bone_idx, "bone_name": skel.get_bone_name(bone_idx)})
		_:
			server._send_response({"error": "Unknown bone action: %s. Use list, get, or set" % action})


func _cmd_tilemap(params: Dictionary) -> void:
	var node_path: String = params.get("node_path", "")
	var action: String = params.get("action", "get_cell")
	if node_path.is_empty():
		server._send_response({"error": "node_path is required"})
		return

	var node: Node = server.get_tree().root.get_node_or_null(node_path)
	if node == null:
		server._send_response({"error": "Node not found: %s" % node_path})
		return

	if not node is TileMapLayer:
		server._send_response({"error": "Node is not a TileMapLayer: %s (is %s)" % [node_path, node.get_class()]})
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
			server._send_response({"success": true, "action": "set_cells", "count": count})
		"get_cell":
			var x: int = int(params.get("x", 0))
			var y: int = int(params.get("y", 0))
			var pos: Vector2i = Vector2i(x, y)
			server._send_response({
				"success": true, "action": "get_cell",
				"x": x, "y": y,
				"source_id": tilemap.get_cell_source_id(pos),
				"atlas_coords": McpSerialization.variant_to_json(tilemap.get_cell_atlas_coords(pos)),
				"alt_tile": tilemap.get_cell_alternative_tile(pos)
			})
		"erase_cells":
			var cells: Array = params.get("cells", [])
			var count: int = 0
			for cell in cells:
				tilemap.erase_cell(Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))))
				count += 1
			server._send_response({"success": true, "action": "erase_cells", "count": count})
		"get_used_cells":
			var source_filter: int = int(params.get("source_id", -1))
			var used: Array
			if source_filter >= 0:
				used = tilemap.get_used_cells_by_id(source_filter)
			else:
				used = tilemap.get_used_cells()
			server._send_response({"success": true, "action": "get_used_cells", "cells": McpSerialization.variant_to_json(used), "count": used.size()})
		_:
			server._send_response({"error": "Unknown tilemap action: %s. Use set_cells, get_cell, erase_cells, or get_used_cells" % action})


# --- Add Collision Shape ---


func _cmd_render_settings(params: Dictionary) -> void:
	var vp: Viewport = server.get_viewport()
	var action: String = params.get("action", "get")
	if action == "get":
		server._send_response({"success": true, "msaa_2d": vp.msaa_2d, "msaa_3d": vp.msaa_3d, "screen_space_aa": vp.screen_space_aa, "use_taa": vp.use_taa, "scaling_3d_mode": vp.scaling_3d_mode, "scaling_3d_scale": vp.scaling_3d_scale})
		return
	if params.has("msaa_2d"):
		vp.msaa_2d = int(params["msaa_2d"]) as Viewport.MSAA
	if params.has("msaa_3d"):
		vp.msaa_3d = int(params["msaa_3d"]) as Viewport.MSAA
	if params.has("fxaa"):
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(params["fxaa"]) else Viewport.SCREEN_SPACE_AA_DISABLED
	if params.has("taa"):
		vp.use_taa = bool(params["taa"])
	if params.has("scaling_mode"):
		vp.scaling_3d_mode = int(params["scaling_mode"]) as Viewport.Scaling3DMode
	if params.has("scaling_scale"):
		vp.scaling_3d_scale = float(params["scaling_scale"])
	server._send_response({"success": true, "action": "set"})


func _cmd_resource(params: Dictionary) -> void:
	var action: String = params.get("action", "load")
	var res_path: String = params.get("path", "")
	match action:
		"load":
			if not ResourceLoader.exists(res_path):
				server._send_response({"error": "Resource not found: %s" % res_path})
				return
			var res: Resource = ResourceLoader.load(res_path)
			if res == null:
				server._send_response({"error": "Failed to load resource: %s" % res_path})
				return
			server._send_response({"success": true, "action": "load", "path": res_path, "type": res.get_class()})
		"save":
			var node_path: String = params.get("node_path", "")
			var prop: String = params.get("property", "")
			if node_path.is_empty():
				server._send_response({"error": "node_path is required for save"})
				return
			var node: Node = server.get_tree().root.get_node_or_null(node_path)
			if node == null:
				server._send_response({"error": "Node not found: %s" % node_path})
				return
			var res = node.get(prop) if not prop.is_empty() else null
			if res is Resource:
				var err: int = ResourceSaver.save(res, res_path)
				server._send_response({"success": err == OK, "action": "save", "path": res_path})
			else:
				server._send_response({"error": "Property is not a Resource"})
		"exists":
			server._send_response({"success": true, "action": "exists", "path": res_path, "exists": ResourceLoader.exists(res_path)})
		_:
			server._send_response({"error": "Unknown resource action: %s" % action})


func _find_audio_players(node: Node, results: Array) -> void:
	if node is AudioStreamPlayer:
		var p: AudioStreamPlayer = node as AudioStreamPlayer
		results.append({"path": str(p.get_path()), "type": "AudioStreamPlayer", "playing": p.playing, "bus": p.bus})
	elif node is AudioStreamPlayer2D:
		var p: AudioStreamPlayer2D = node as AudioStreamPlayer2D
		results.append({"path": str(p.get_path()), "type": "AudioStreamPlayer2D", "playing": p.playing, "bus": p.bus})
	elif node is AudioStreamPlayer3D:
		var p: AudioStreamPlayer3D = node as AudioStreamPlayer3D
		results.append({"path": str(p.get_path()), "type": "AudioStreamPlayer3D", "playing": p.playing, "bus": p.bus})
	for child: Node in node.get_children():
		_find_audio_players(child, results)


# --- Spawn Node ---


func _get_environment_state(env: Environment) -> Dictionary:
	return {
		"success": true,
		"background_mode": env.background_mode,
		"background_color": McpSerialization.variant_to_json(env.background_color),
		"ambient_light_color": McpSerialization.variant_to_json(env.ambient_light_color),
		"ambient_light_energy": env.ambient_light_energy,
		"fog_enabled": env.fog_enabled,
		"fog_density": env.fog_density,
		"fog_light_color": McpSerialization.variant_to_json(env.fog_light_color),
		"glow_enabled": env.glow_enabled,
		"glow_intensity": env.glow_intensity,
		"glow_bloom": env.glow_bloom,
		"tonemap_mode": env.tonemap_mode,
		"ssao_enabled": env.ssao_enabled,
		"ssao_radius": env.ssao_radius,
		"ssao_intensity": env.ssao_intensity,
		"ssr_enabled": env.ssr_enabled,
		"brightness": env.adjustment_brightness,
		"contrast": env.adjustment_contrast,
		"saturation": env.adjustment_saturation
	}


# --- Manage Group ---


func _resolve_bone_index(skel: Skeleton3D, params: Dictionary) -> int:
	if params.has("bone_index"):
		return int(params["bone_index"])
	if params.has("bone_name"):
		return skel.find_bone(params["bone_name"])
	return -1


# --- UI Theme ---


func _get_or_create_environment() -> Environment:
	var cam: Camera3D = server.get_viewport().get_camera_3d()
	if cam != null and cam.get_environment() != null:
		return cam.get_environment()
	var we: WorldEnvironment = null
	for child: Node in server.get_tree().root.get_children():
		if child is WorldEnvironment:
			we = child as WorldEnvironment
			break
	if we != null and we.environment != null:
		return we.environment
	# Create one
	we = WorldEnvironment.new()
	we.environment = Environment.new()
	server.get_tree().root.add_child(we)
	return we.environment
