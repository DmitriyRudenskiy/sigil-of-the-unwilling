## scripts/data/templates/t06_debuff_control.gd
class_name T06DebuffControl
extends RefCounted
## T06: DEBUFF / CONTROL (аудит #8: вынесен из TemplateEngine).

const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	if params.has("status"):
		var status: int = _Enums.parse_status(str(params["status"]))
		var duration: int = int(params.get("duration", -1))
		if _Utils.has_obj_method(target, "add_status"):
			target.add_status(status, duration)
			effects.append({"type": "status", "target_id": _Utils.get_id(target), "status": status})

	var atk: int = int(params.get("atk", 0))
	var hp: int = int(params.get("hp", 0))
	if atk != 0 or hp != 0:
		var permanent: bool = bool(params.get("permanent", false))
		if permanent and _Utils.has_obj_method(target, "modify_perm_stats"):
			target.modify_perm_stats(atk, hp)
			effects.append({"type": "perm_debuff", "target_id": _Utils.get_id(target), "atk": atk, "hp": hp})
		elif _Utils.has_obj_method(target, "modify_temp_stats"):
			target.modify_temp_stats(atk, hp)
			effects.append({"type": "temp_debuff", "target_id": _Utils.get_id(target), "atk": atk, "hp": hp})

	if params.has("change_control") and bool(params["change_control"]):
		var duration: int = int(params.get("control_duration", 1))
		if _Utils.has_obj_method(target, "change_control"):
			target.change_control(caster, duration)
			effects.append({"type": "steal", "target_id": _Utils.get_id(target), "duration": duration})

	return {"result": "success", "effects": effects}
