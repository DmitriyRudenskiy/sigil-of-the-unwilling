class_name T04Countermagic
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, _state: Variant,
	caster: Variant, target: Variant,
	_secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null or not _Utils.has_obj_method(target, "cancel"):
		return {"result": "no_target", "effects": effects}

	if params.has("cost_max"):
		if _Utils.has_obj_method(target, "get_cost") and target.get_cost() > int(params["cost_max"]):
			return {"result": "cost_too_high", "effects": effects}

	if params.has("targets_ally_only") and bool(params["targets_ally_only"]):
		if not _Utils.has_obj_method(target, "targets_ally") or not target.targets_ally():
			return {"result": "not_targeting_ally", "effects": effects}

	target.cancel()
	effects.append({"type": "counter", "target_id": _Utils.get_id(target)})

	if params.has("draw_on_counter"):
		if _Utils.has_obj_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_on_counter"]))
		effects.append({"type": "draw", "count": int(params["draw_on_counter"])})

	return {"result": "success", "effects": effects}
