class_name T17HealClear
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
	var amount: int = int(params.get("amount", 0))
	if _Utils.has_obj_method(target, "heal"):
		target.heal(amount)
		effects.append({"type": "heal", "target_id": _Utils.get_id(target), "amount": amount})
	if _Utils.has_obj_method(target, "clear_debuffs"):
		target.clear_debuffs()
		effects.append({"type": "debuff_clear", "target_id": _Utils.get_id(target)})
	return {"result": "success", "effects": effects}
