class_name McpSerialization
extends RefCounted
## JSON <-> Godot Variant conversion for the MCP server (extracted from mcp_interaction_server.gd).

static func variant_to_json(value: Variant) -> Variant:
	if value == null:
		return null
	if value is bool or value is int or value is float or value is String:
		return value
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Vector3i:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is Quaternion:
		return {"x": value.x, "y": value.y, "z": value.z, "w": value.w}
	if value is Basis:
		return {
			"x": variant_to_json(value.x),
			"y": variant_to_json(value.y),
			"z": variant_to_json(value.z)
		}
	if value is Transform3D:
		return {
			"basis": variant_to_json(value.basis),
			"origin": variant_to_json(value.origin)
		}
	if value is Transform2D:
		return {
			"x": variant_to_json(value.x),
			"y": variant_to_json(value.y),
			"origin": variant_to_json(value.origin)
		}
	if value is Rect2:
		return {"position": variant_to_json(value.position), "size": variant_to_json(value.size)}
	if value is AABB:
		return {"position": variant_to_json(value.position), "size": variant_to_json(value.size)}
	if value is NodePath:
		return str(value)
	if value is StringName:
		return str(value)
	# Packed arrays - serialize as JSON arrays instead of str() fallback
	if value is PackedByteArray:
		var arr: Array = []
		for item in value:
			arr.append(item)
		return arr
	if value is PackedInt32Array or value is PackedInt64Array:
		var arr: Array = []
		for item in value:
			arr.append(item)
		return arr
	if value is PackedFloat32Array or value is PackedFloat64Array:
		var arr: Array = []
		for item in value:
			arr.append(item)
		return arr
	if value is PackedStringArray:
		var arr: Array = []
		for item in value:
			arr.append(item)
		return arr
	if value is PackedVector2Array:
		var arr: Array = []
		for item in value:
			arr.append({"x": item.x, "y": item.y})
		return arr
	if value is PackedVector3Array:
		var arr: Array = []
		for item in value:
			arr.append({"x": item.x, "y": item.y, "z": item.z})
		return arr
	if value is PackedColorArray:
		var arr: Array = []
		for item in value:
			arr.append({"r": item.r, "g": item.g, "b": item.b, "a": item.a})
		return arr
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(variant_to_json(item))
		return arr
	if value is Dictionary:
		var dict: Dictionary = {}
		for key in value:
			dict[str(key)] = variant_to_json(value[key])
		return dict
	if value is Object:
		if value is Node:
			return {"_type": "Node", "class": value.get_class(), "name": (value as Node).name, "path": str((value as Node).get_path())}
		if value is Resource:
			return {"_type": "Resource", "class": value.get_class(), "path": (value as Resource).resource_path}
		return {"_type": "Object", "class": value.get_class(), "id": value.get_instance_id()}
	# Fallback: convert to string
	return str(value)



static func json_to_variant(value: Variant, type_hint: String = "") -> Variant:
	if value == null:
		return null
	if value is String and type_hint != "" and type_hint != "String":
		var trimmed: String = (value as String).strip_edges()
		if trimmed.begins_with("{") or trimmed.begins_with("["):
			var parser: JSON = JSON.new()
			if parser.parse(trimmed) == OK:
				value = parser.data
	if value is Dictionary:
		var dict: Dictionary = value
		# Explicit type hints take priority
		match type_hint:
			"Vector2":
				return Vector2(float(dict.get("x", 0)), float(dict.get("y", 0)))
			"Vector2i":
				return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
			"Vector3":
				return Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
			"Vector3i":
				return Vector3i(int(dict.get("x", 0)), int(dict.get("y", 0)), int(dict.get("z", 0)))
			"Color":
				return Color(float(dict.get("r", 0)), float(dict.get("g", 0)), float(dict.get("b", 0)), float(dict.get("a", 1)))
			"Quaternion":
				return Quaternion(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)), float(dict.get("w", 1)))
			"Rect2":
				var pos: Dictionary = dict.get("position", {"x": 0, "y": 0})
				var sz: Dictionary = dict.get("size", {"x": 0, "y": 0})
				return Rect2(float(pos.get("x", 0)), float(pos.get("y", 0)), float(sz.get("x", 0)), float(sz.get("y", 0)))
			"AABB":
				var aabb_pos: Dictionary = dict.get("position", {"x": 0, "y": 0, "z": 0})
				var aabb_sz: Dictionary = dict.get("size", {"x": 0, "y": 0, "z": 0})
				return AABB(
					Vector3(float(aabb_pos.get("x", 0)), float(aabb_pos.get("y", 0)), float(aabb_pos.get("z", 0))),
					Vector3(float(aabb_sz.get("x", 0)), float(aabb_sz.get("y", 0)), float(aabb_sz.get("z", 0)))
				)
			"Basis":
				var bx: Dictionary = dict.get("x", {"x": 1, "y": 0, "z": 0})
				var by: Dictionary = dict.get("y", {"x": 0, "y": 1, "z": 0})
				var bz: Dictionary = dict.get("z", {"x": 0, "y": 0, "z": 1})
				return Basis(
					Vector3(float(bx.get("x", 0)), float(bx.get("y", 0)), float(bx.get("z", 0))),
					Vector3(float(by.get("x", 0)), float(by.get("y", 0)), float(by.get("z", 0))),
					Vector3(float(bz.get("x", 0)), float(bz.get("y", 0)), float(bz.get("z", 0)))
				)
			"Transform3D":
				var basis_dict: Dictionary = dict.get("basis", {})
				var origin_dict: Dictionary = dict.get("origin", {"x": 0, "y": 0, "z": 0})
				var basis: Basis = json_to_variant(basis_dict, "Basis") if basis_dict.size() > 0 else Basis.IDENTITY
				var origin: Vector3 = Vector3(float(origin_dict.get("x", 0)), float(origin_dict.get("y", 0)), float(origin_dict.get("z", 0)))
				return Transform3D(basis, origin)
			"Transform2D":
				var tx: Dictionary = dict.get("x", {"x": 1, "y": 0})
				var ty: Dictionary = dict.get("y", {"x": 0, "y": 1})
				var t_origin: Dictionary = dict.get("origin", {"x": 0, "y": 0})
				return Transform2D(
					Vector2(float(tx.get("x", 0)), float(tx.get("y", 0))),
					Vector2(float(ty.get("x", 0)), float(ty.get("y", 0))),
					Vector2(float(t_origin.get("x", 0)), float(t_origin.get("y", 0)))
				)
		# Auto-detect from dict keys
		if dict.has("basis") and dict.has("origin"):
			return json_to_variant(dict, "Transform3D")
		if dict.has("r") and dict.has("g") and dict.has("b"):
			return Color(float(dict.get("r", 0)), float(dict.get("g", 0)), float(dict.get("b", 0)), float(dict.get("a", 1)))
		if dict.has("x") and dict.has("y") and dict.has("z") and dict.has("w"):
			return Quaternion(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)), float(dict.get("w", 1)))
		if dict.has("position") and dict.has("size"):
			var pos_dict: Dictionary = dict["position"]
			var size_dict: Dictionary = dict["size"]
			if pos_dict.has("z") or size_dict.has("z"):
				return json_to_variant(dict, "AABB")
			return json_to_variant(dict, "Rect2")
		if dict.has("x") and dict.has("y") and dict.has("z"):
			return Vector3(float(dict.get("x", 0)), float(dict.get("y", 0)), float(dict.get("z", 0)))
		if dict.has("x") and dict.has("y") and dict.size() == 2:
			return Vector2(float(dict.get("x", 0)), float(dict.get("y", 0)))
		return value
	return value

