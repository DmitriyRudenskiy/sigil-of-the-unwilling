class_name T18Revive
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant,
	secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}
	if _Utils.has_obj_method(target, "revive"):
		var amount: int = int(params.get("amount", 1))
		target.revive(amount)
		effects.append({"type": "revive", "target_id": _Utils.get_id(target), "amount": amount})
	return {"result": "success", "effects": effects}
