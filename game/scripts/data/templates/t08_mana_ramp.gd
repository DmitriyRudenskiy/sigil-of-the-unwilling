class_name T08ManaRamp
extends RefCounted

const _Utils = preload("res://scripts/data/spell_utils.gd")

static func handle(
	params: Dictionary, _state: Variant,
	caster: Variant, _target: Variant,
	_secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var power: int = int(params.get("power", 1))

	if _Utils.has_obj_method(caster, "add_max_power"):
		caster.add_max_power(power)
	effects.append({"type": "ramp", "amount": power})

	if params.has("influence"):
		var inf: String = str(params["influence"])
		if _Utils.has_obj_method(caster, "add_influence"):
			caster.add_influence(inf)
		effects.append({"type": "influence", "color": inf})

	return {"result": "success", "effects": effects}
