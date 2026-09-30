class_name T05CombatTrick
extends RefCounted

const _Utils = preload("res://scripts/data/spell_utils.gd")

static func handle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant, secondary: Array[Dictionary] = []
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var target_type: String = str(params.get("target", "ALLY_UNIT"))
	var targets := TemplateContext.resolve_targets(target_type, state, caster, target)

	var atk: int = int(params.get("atk", 0))
	var hp: int = int(params.get("hp", 0))

	if params.has("atk_dynamic"):
		match str(params["atk_dynamic"]):
			"ally_count": atk = TemplateContext.board_count(caster)
			"enemy_count": atk = TemplateContext.board_count(TemplateContext.get_opponent(state, caster))
	if params.has("hp_dynamic"):
		match str(params["hp_dynamic"]):
			"ally_count": hp = TemplateContext.board_count(caster)
			"enemy_count": hp = TemplateContext.board_count(TemplateContext.get_opponent(state, caster))

	for t in targets:
		if t != null and _Utils.has_obj_method(t, "modify_temp_stats"):
			t.modify_temp_stats(atk, hp)
			effects.append({"type": "buff", "target_id": _Utils.get_id(t), "atk": atk, "hp": hp})

	if params.has("heal"):
		for t in targets:
			if t != null and _Utils.has_obj_method(t, "heal"):
				t.heal(int(params["heal"]))
				effects.append({"type": "heal", "target_id": _Utils.get_id(t), "amount": int(params["heal"])})

	for sec in secondary:
		var sec_type: String = str(sec.get("effect", ""))
		match sec_type:
			"DRAW":
				if _Utils.has_obj_method(caster, "draw_cards"):
					caster.draw_cards(int(sec.get("count", 1)))
				effects.append({"type": "draw", "count": int(sec.get("count", 1))})
			"DEAL_DAMAGE":
				var dmg: int = int(sec.get("amount", 0))
				var sec_target := TemplateContext.resolve_targets(str(sec.get("target", "ENEMY_NEXUS")), state, caster, null)
				for st in sec_target:
					if st != null and _Utils.has_obj_method(st, "take_damage"):
						st.take_damage(dmg)
						effects.append({"type": "damage", "target_id": _Utils.get_id(st), "amount": dmg})

	return {"result": "success", "effects": effects}
