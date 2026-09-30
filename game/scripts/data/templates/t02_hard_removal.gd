class_name T02HardRemoval
extends RefCounted

const _Utils = preload("res://scripts/data/spell_utils.gd")

static func handle(
	params: Dictionary, _state: Variant,
	caster: Variant, target: Variant,
	_secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var ignore_ward: bool = bool(params.get("ignore_ward", false))
	var exile: bool = bool(params.get("exile", false))

	if not ignore_ward and _Utils.has_obj_method(target, "has_ward") and target.has_ward():
		if _Utils.has_obj_method(target, "remove_ward"):
			target.remove_ward()
		effects.append({"type": "blocked_by_ward", "target_id": _Utils.get_id(target)})
		return {"result": "ward_blocked", "effects": effects}

	if exile:
		if _Utils.has_obj_method(target, "exile"):
			target.exile()
			effects.append({"type": "exile", "target_id": _Utils.get_id(target)})
	else:
		if _Utils.has_obj_method(target, "destroy"):
			target.destroy()
			effects.append({"type": "destroy", "target_id": _Utils.get_id(target)})

	if params.has("draw_on_kill"):
		if _Utils.has_obj_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_on_kill"]))
		effects.append({"type": "draw", "count": int(params["draw_on_kill"])})

	if params.has("create_token_on_kill"):
		if _Utils.has_obj_method(caster, "create_token"):
			var token_id: String = str(params["create_token_on_kill"])
			caster.create_token(token_id, 1, 1)
		effects.append({"type": "token", "token_id": str(params["create_token_on_kill"])})

	return {"result": "success", "effects": effects}
