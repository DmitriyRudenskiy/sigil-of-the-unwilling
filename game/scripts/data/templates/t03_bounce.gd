class_name T03Bounce
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

	var target_type: String = str(params.get("target", "ALLY_UNIT"))
	if target_type == "ALLY_UNIT":
		if caster != null and _Utils.has_obj_method(caster, "owns_unit") and not caster.owns_unit(target):
			return {"result": "invalid_target", "effects": effects}

	if _Utils.has_obj_method(target, "return_to_hand"):
		target.return_to_hand()
		effects.append({"type": "bounce", "target_id": _Utils.get_id(target)})

	if params.has("replay_free") and bool(params["replay_free"]):
		effects.append({"type": "replay_free", "target_id": _Utils.get_id(target)})

	if params.has("draw_after"):
		if _Utils.has_obj_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_after"]))
		effects.append({"type": "draw", "count": int(params["draw_after"])})

	return {"result": "success", "effects": effects}
