class_name T19Portal
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, _state: Variant,
	_caster: Variant, target: Variant,
	_secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}
	if _Utils.has_obj_method(target, "displace"):
		var to: String = str(params.get("to", "town"))
		target.displace(to)
		effects.append({"type": "displace", "target_id": _Utils.get_id(target), "to": to})
	return {"result": "success", "effects": effects}
