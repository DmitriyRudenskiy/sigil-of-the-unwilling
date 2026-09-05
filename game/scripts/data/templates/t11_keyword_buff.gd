## scripts/data/templates/t11_keyword_buff.gd
class_name T11KeywordBuff
extends RefCounted
## T11: KEYWORD BUFF (аудит #8: вынесен из TemplateEngine).

const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
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
