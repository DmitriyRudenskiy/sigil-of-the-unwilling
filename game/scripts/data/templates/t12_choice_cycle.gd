class_name T12ChoiceCycle
extends RefCounted

const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _Utils = preload("res://scripts/data/SpellUtils.gd")
const _S := _Enums.StatusType

static func handle(
	params: Dictionary, _state: Variant,
	caster: Variant, target: Variant,
	_secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var draw_count: int = int(params.get("draw", 1))
	if _Utils.has_obj_method(caster, "draw_cards"):
		caster.draw_cards(draw_count)
	effects.append({"type": "draw", "count": draw_count})

	if params.has("secondary"):
		var sec: String = str(params["secondary"])
		match sec:
			"DEAL_1_DAMAGE":
				if target != null and _Utils.has_obj_method(target, "take_damage"):
					target.take_damage(1)
					effects.append({"type": "damage", "target_id": _Utils.get_id(target), "amount": 1})
			"BUFF_1_1":
				if target != null and _Utils.has_obj_method(target, "modify_temp_stats"):
					target.modify_temp_stats(1, 1)
					effects.append({"type": "buff", "target_id": _Utils.get_id(target), "atk": 1, "hp": 1})
			"HEAL_2":
				if target != null and _Utils.has_obj_method(target, "heal"):
					target.heal(2)
					effects.append({"type": "heal", "target_id": _Utils.get_id(target), "amount": 2})
			"GAIN_1_ARMOR":
				if target != null and _Utils.has_obj_method(target, "add_status"):
					target.add_status(_S.ARMORED, 1)
					effects.append({"type": "keyword", "target_id": _Utils.get_id(target), "keyword": "ARMORED"})

	return {"result": "success", "effects": effects}
