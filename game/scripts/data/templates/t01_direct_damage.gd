class_name T01DirectDamage
extends RefCounted

const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant,
	secondary: Array[Dictionary] = []
) -> Dictionary:
	var amount: int = int(params.get("amount", 0))
	var target_type: String = str(params.get("target", "ENEMY_UNIT"))
	var effects: Array[Dictionary] = []

	if params.has("amount_dynamic"):
		match str(params["amount_dynamic"]):
			"ally_count": amount = TemplateContext.board_count(caster)
			"enemy_count": amount = TemplateContext.board_count(TemplateContext.get_opponent(state, caster))
			"hand_size": amount = TemplateContext.hand_size(caster)

	var targets := TemplateContext.resolve_targets(target_type, state, caster, target)
	for t in targets:
		if t != null and _Utils.has_obj_method(t, "take_damage"):
			var actual: Variant = t.take_damage(amount)
			effects.append({"type": "damage", "target_id": _Utils.get_id(t), "amount": actual})

	if params.has("apply_status"):
		var status: int = _Enums.parse_status(str(params["apply_status"]))
		var duration: int = int(params.get("status_duration", 1))
		for t in targets:
			if t != null and _Utils.has_obj_method(t, "add_status"):
				t.add_status(status, duration)
				effects.append({"type": "status", "target_id": _Utils.get_id(t), "status": status})

	if params.has("self_damage"):
		var self_dmg: int = int(params["self_damage"])
		if caster != null and _Utils.has_obj_method(caster, "take_damage"):
			caster.take_damage(self_dmg)
			effects.append({"type": "self_damage", "amount": self_dmg})

	return {"result": "success", "effects": effects}
