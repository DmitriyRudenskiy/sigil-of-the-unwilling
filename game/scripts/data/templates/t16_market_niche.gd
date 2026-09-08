class_name T16MarketNiche
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var action: String = str(params.get("action", ""))

	match action:
		"draw_from_market":
			var cost: int = int(params.get("market_cost", 0))
			if caster != null and _Utils.has_attr(caster, "current_power") and caster.current_power >= cost:
				caster.current_power -= cost
				effects.append({"type": "market_draw", "cost": cost})
		"trigger_on_discard":
			var effect: String = str(params.get("trigger_effect", ""))
			var amount: int = int(params.get("trigger_amount", 0))
			effects.append({"type": "discard_trigger", "effect": effect, "amount": amount})

	return {"result": "success", "effects": effects}
