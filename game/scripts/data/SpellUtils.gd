## scripts/data/SpellUtils.gd
class_name SpellUtils
extends RefCounted
## Shared reflection utilities for spell handlers.
## Deduplicates _has_method / _has_attr / _get_id across SpellResolver,
## TemplateEngine, and template handlers (scripts/data/templates/).


## Имя has_method занято нативным Object.has_method — используем has_obj_method.
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
