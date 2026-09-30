class_name T11KeywordBuff
extends RefCounted

const _Enums = preload("res://scripts/data/spell_enums.gd")
const _Utils = preload("res://scripts/data/spell_utils.gd")

static func handle(
	params: Dictionary, _state: Variant,
	_caster: Variant, target: Variant,
	_secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var keyword: String = str(params.get("keyword", ""))
	var duration: int = int(params.get("duration", -1))
	var status: int = _Enums.parse_status(keyword)

	if _Utils.has_obj_method(target, "add_status"):
		target.add_status(status, duration)
		effects.append({"type": "keyword", "target_id": _Utils.get_id(target), "keyword": keyword})

	if params.has("atk") or params.has("hp"):
		var atk: int = int(params.get("atk", 0))
		var hp: int = int(params.get("hp", 0))
		if _Utils.has_obj_method(target, "modify_temp_stats"):
			target.modify_temp_stats(atk, hp)
			effects.append({"type": "buff", "target_id": _Utils.get_id(target), "atk": atk, "hp": hp})

	return {"result": "success", "effects": effects}
