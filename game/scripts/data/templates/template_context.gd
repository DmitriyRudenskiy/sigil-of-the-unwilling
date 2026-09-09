class_name TemplateContext
extends RefCounted

const _Utils = preload("res://scripts/data/SpellUtils.gd")

static func check_condition(
	cond: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> bool:
	if cond.is_empty():
		return true
	if cond.has("target_hp_max") and target != null:
		if _Utils.has_obj_method(target, "get_hp") and target.get_hp() > int(cond["target_hp_max"]):
			return false
	if cond.has("target_cost_max") and target != null:
		if _Utils.has_obj_method(target, "get_cost") and target.get_cost() > int(cond["target_cost_max"]):
			return false
	if cond.has("target_is_damaged") and target != null:
		if _Utils.has_obj_method(target, "is_damaged") and not target.is_damaged():
			return false
	if cond.has("target_is_flying") and target != null:
		if _Utils.has_obj_method(target, "is_flying") and not target.is_flying():
			return false
	if cond.has("hand_size_max"):
		if hand_size(caster) > int(cond["hand_size_max"]):
			return false
	if cond.has("spell_cost_max") and target != null:
		if _Utils.has_obj_method(target, "get_cost") and target.get_cost() > int(cond["spell_cost_max"]):
			return false
	if cond.has("attacker_unblocked"):
		if not _Utils.has_obj_method(state, "is_attacker_unblocked") or not state.is_attacker_unblocked():
			return false
	if cond.has("discard_cost"):
		if hand_size(caster) < int(cond["discard_cost"]):
			return false
	if cond.has("min_ally_count"):
		if board_count(caster) < int(cond["min_ally_count"]):
			return false
	return true

static func resolve_targets(
	target_type: String, state: Variant,
	caster: Variant, selected: Variant
) -> Array:
	match target_type:
		"ALL_ENEMY_UNITS":
			var opp: Variant = get_opponent(state, caster)
			if _Utils.has_obj_method(opp, "get_all_units"):
				return opp.get_all_units()
			return []
		"ALL_ALLY_UNITS":
			if _Utils.has_obj_method(caster, "get_all_units"):
				return caster.get_all_units()
			return []
		"ENEMY_NEXUS":
			var opp: Variant = get_opponent(state, caster)
			if opp != null:
				if _Utils.has_attr(opp, "nexus"):
					return [opp.nexus]
				return [opp]
			return []
		"ALLY_NEXUS":
			if caster != null and _Utils.has_attr(caster, "nexus"):
				return [caster.nexus]
			return [caster]
		"SELF":
			return [caster] if caster != null else []
		_:
			if selected != null:
				return [selected]
			return []

static func board_count(caster: Variant) -> int:
	if caster == null:
		return 0
	if _Utils.has_obj_method(caster, "board_count"):
		return caster.board_count()
	if _Utils.has_attr(caster, "board"):
		return caster.board.size()
	return 0

static func hand_size(caster: Variant) -> int:
	if caster == null:
		return 0
	if _Utils.has_attr(caster, "hand"):
		var hand = caster.hand
		if hand is Array:
			return hand.size()
	return 0

static func get_opponent(state: Variant, caster: Variant) -> Variant:
	if state != null and _Utils.has_obj_method(state, "get_opponent"):
		return state.get_opponent(caster)
	return null
