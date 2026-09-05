## scripts/data/templates/t13_touch_cycle.gd
class_name T13TouchCycle
extends RefCounted
## T13: TOUCH CYCLE (аудит #8: вынесен из TemplateEngine).

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var atk: int = int(params.get("atk", 1))
	var hp: int = int(params.get("hp", 1))
	if _Utils.has_obj_method(target, "modify_perm_stats"):
		target.modify_perm_stats(atk, hp)
		effects.append({"type": "perm_buff", "target_id": _Utils.get_id(target), "atk": atk, "hp": hp})

	return {"result": "success", "effects": effects}
