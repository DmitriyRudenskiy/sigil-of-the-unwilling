class_name SpellUtils
extends RefCounted

static func has_obj_method(obj: Variant, method: String) -> bool:
	if obj == null:
		return false
	if obj is Object:
		return obj.has_method(method)
	return false

static func has_attr(obj: Variant, attr: String) -> bool:
	if obj == null:
		return false
	if obj is Dictionary:
		return obj.has(attr)
	return false

static func get_id(obj: Variant) -> String:
	if obj == null:
		return ""
	if has_obj_method(obj, "get_id"):
		return obj.get_id()
	return str(obj)
