class_name T15DispelDraw
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant,
	secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var discard_count: int = int(params.get("discard", 1))
	var draw_count: int = int(params.get("draw", 1))

	if TemplateContext.hand_size(caster) < discard_count:
		return {"result": "not_enough_cards", "effects": effects}

	if params.has("discard_target") and target != null:
		if _Utils.has_obj_method(caster, "discard_card"):
			caster.discard_card(target)
		effects.append({"type": "discard", "card_id": _Utils.get_id(target)})
	else:
		for i in range(discard_count):
			effects.append({"type": "discard", "auto": true})
			if _Utils.has_obj_method(caster, "discard_random"):
				caster.discard_random()

	if _Utils.has_obj_method(caster, "draw_cards"):
		caster.draw_cards(draw_count)
	effects.append({"type": "draw", "count": draw_count})

	if params.has("shuffle_back") and bool(params["shuffle_back"]):
		effects.append({"type": "shuffle"})

	return {"result": "success", "effects": effects}
