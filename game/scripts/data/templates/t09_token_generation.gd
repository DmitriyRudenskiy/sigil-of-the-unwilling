## scripts/data/templates/t09_token_generation.gd
class_name T09TokenGeneration
extends RefCounted
## T09: TOKEN GENERATION (аудит #8: вынесен из TemplateEngine).

const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var token_id: String = str(params.get("token_id", "soldier"))
	var count: int = int(params.get("count", 1))
	var atk: int = int(params.get("atk", 1))
	var hp: int = int(params.get("hp", 1))
	var keywords: Array = params.get("keywords", [])

	for i in range(count):
		var uid: String = str(token_id) + "_" + str(i)
		effects.append({"type": "token", "token_id": token_id, "uid": uid, "atk": atk, "hp": hp})
		if _Utils.has_obj_method(caster, "create_token"):
			var unit = caster.create_token(token_id, atk, hp)
			if unit != null:
				for kw in keywords:
					if _Utils.has_obj_method(unit, "add_status"):
						unit.add_status(_Enums.parse_status(str(kw)), -1)

	return {"result": "success", "effects": effects}
