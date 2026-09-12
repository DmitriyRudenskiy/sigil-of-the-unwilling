class_name SerializationUtils
extends RefCounted

static func vec2i_to_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}

static func vec2i_from_dict(d: Dictionary, default := Vector2i.ZERO) -> Vector2i:
	return Vector2i(int(d.get("x", default.x)), int(d.get("y", default.y)))
