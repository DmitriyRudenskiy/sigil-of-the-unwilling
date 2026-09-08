class_name T07SpellDraw
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant,
	secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var count: int = int(params.get("count", 1))

	if params.has("hand_max"):
		if TemplateContext.hand_size(caster) > int(params["hand_max"]):
			return {"result": "hand_too_large", "effects": effects}

	if params.has("search_filter"):
		var filter: String = str(params["search_filter"])
		effects.append({"type": "search", "filter": filter, "count": count})
	else:
		if _Utils.has_obj_method(caster, "draw_cards"):
			caster.draw_cards(count)
		effects.append({"type": "draw", "count": count})

	if params.has("opponent_draw"):
		var opp: Variant = TemplateContext.get_opponent(state, caster)
		if _Utils.has_obj_method(opp, "draw_cards"):
			opp.draw_cards(int(params["opponent_draw"]))
		effects.append({"type": "opponent_draw", "count": int(params["opponent_draw"])})

	if params.has("scout"):
		effects.append({"type": "scout", "count": int(params["scout"])})

	return {"result": "success", "effects": effects}
