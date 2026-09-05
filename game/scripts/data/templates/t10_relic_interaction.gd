## scripts/data/templates/t10_relic_interaction.gd
class_name T10RelicInteraction
extends RefCounted
## T10: RELIC INTERACTION (аудит #8: вынесен из TemplateEngine).

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var action: String = str(params.get("action", "destroy"))
	match action:
		"destroy":
			if _Utils.has_obj_method(target, "destroy"):
				target.destroy()
				effects.append({"type": "destroy_relic", "target_id": _Utils.get_id(target)})
		"steal":
			if _Utils.has_obj_method(target, "steal"):
				target.steal(caster)
				effects.append({"type": "steal_relic", "target_id": _Utils.get_id(target)})

	if params.has("draw_on_destroy"):
		if _Utils.has_obj_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_on_destroy"]))
		effects.append({"type": "draw", "count": int(params["draw_on_destroy"])})

	return {"result": "success", "effects": effects}
