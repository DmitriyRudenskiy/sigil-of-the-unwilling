class_name T13TouchCycle
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

	var atk: int = int(params.get("atk", 1))
	var hp: int = int(params.get("hp", 1))
	if _Utils.has_obj_method(target, "modify_perm_stats"):
		target.modify_perm_stats(atk, hp)
		effects.append({"type": "perm_buff", "target_id": _Utils.get_id(target), "atk": atk, "hp": hp})

	return {"result": "success", "effects": effects}
