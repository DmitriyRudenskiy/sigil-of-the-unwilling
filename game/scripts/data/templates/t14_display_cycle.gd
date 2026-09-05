## scripts/data/templates/t14_display_cycle.gd
class_name T14DisplayCycle
extends RefCounted
## T14: DISPLAY CYCLE (аудит #8: вынесен из TemplateEngine).

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []

	if params.has("cost_reduction"):
		var amount: int = int(params["cost_reduction"])
		effects.append({"type": "cost_reduce", "amount": amount})
		if _Utils.has_obj_method(caster, "set_next_spell_discount"):
			caster.set_next_spell_discount(amount)

	if params.has("influence"):
		var inf: String = str(params["influence"])
		effects.append({"type": "influence", "color": inf})
		if _Utils.has_obj_method(caster, "add_influence"):
			caster.add_influence(inf)

	if params.has("trigger"):
		var trigger_type: String = str(params["trigger"])
		effects.append({"type": "trigger", "trigger_type": trigger_type})

	return {"result": "success", "effects": effects}
