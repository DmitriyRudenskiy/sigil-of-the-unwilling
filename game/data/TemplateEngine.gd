## scripts/data/TemplateEngine.gd
class_name TemplateEngine
extends RefCounted
## Strategy pattern: template_id → Callable handler.
## Handlers are registered at boot; new templates add to _handlers without touching this file.

const _Enums = preload("res://data/SpellEnums.gd")
const _Utils = preload("res://data/SpellUtils.gd")
const _E := _Enums.EffectType
const _T := _Enums.TargetType
const _S := _Enums.StatusType

static var _handlers: Dictionary = {}


## Register a handler for a template. Call from autoload or init.
static func register_handler(template: StringName, handler: Callable) -> void:
	_handlers[template] = handler

## Clear all handlers. Use in tests to avoid state leaking between runs.
static func reset() -> void:
	_handlers.clear()


## Main dispatcher: template_id → handler.
static func execute(
	template: StringName,
	params: Dictionary,
	condition: Dictionary,
	secondary: Array[Dictionary],
	state: Variant,
	caster: Variant,
	target: Variant
) -> Dictionary:
	# Проверка глобального условия
	if not TemplateHandlers._check_condition(condition, state, caster, target):
		return {"result": "condition_not_met", "effects": []}

	if not _handlers.has(template):
		push_warning("Unknown template: %s" % template)
		return {"result": "unknown_template", "effects": []}

	# COMBAT_TRICK is the only template needing `secondary` array
	if template == &"COMBAT_TRICK":
		return _handlers[template].call(params, secondary, state, caster, target)
	return _handlers[template].call(params, state, caster, target)


# ==================== HANDLER IMPLEMENTATIONS ====================
## Each handler is a standalone Callable so the registry can swap them.
class TemplateHandlers:
	## ——— T01: DIRECT DAMAGE ———
	static func t01_direct_damage(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var amount: int = int(params.get("amount", 0))
		var target_type: String = str(params.get("target", "ENEMY_UNIT"))
		var effects: Array[Dictionary] = []

		if params.has("amount_dynamic"):
			match str(params["amount_dynamic"]):
				"ally_count": amount = _board_count(caster)
				"enemy_count": amount = _board_count(_get_opponent(state, caster))
				"hand_size": amount = _hand_size(caster)

		var targets := _resolve_targets(target_type, state, caster, target)
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

	## ——— T02: HARD REMOVAL ———
	static func t02_hard_removal(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		if target == null:
			return {"result": "no_target", "effects": effects}

		var ignore_ward: bool = bool(params.get("ignore_ward", false))
		var exile: bool = bool(params.get("exile", false))

		if not ignore_ward and _Utils.has_obj_method(target, "has_ward") and target.has_ward():
			if _Utils.has_obj_method(target, "remove_ward"):
				target.remove_ward()
			effects.append({"type": "blocked_by_ward", "target_id": _Utils.get_id(target)})
			return {"result": "ward_blocked", "effects": effects}

		if exile:
			if _Utils.has_obj_method(target, "exile"):
				target.exile()
				effects.append({"type": "exile", "target_id": _Utils.get_id(target)})
		else:
			if _Utils.has_obj_method(target, "destroy"):
				target.destroy()
				effects.append({"type": "destroy", "target_id": _Utils.get_id(target)})

		if params.has("draw_on_kill"):
			if _Utils.has_obj_method(caster, "draw_cards"):
				caster.draw_cards(int(params["draw_on_kill"]))
			effects.append({"type": "draw", "count": int(params["draw_on_kill"])})

		if params.has("create_token_on_kill"):
			if _Utils.has_obj_method(caster, "create_token"):
				var token_id: String = str(params["create_token_on_kill"])
				caster.create_token(token_id, 1, 1)
			effects.append({"type": "token", "token_id": str(params["create_token_on_kill"])})

		return {"result": "success", "effects": effects}

	## ——— T03: BOUNCE ———
	static func t03_bounce(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		if target == null:
			return {"result": "no_target", "effects": effects}

		var target_type: String = str(params.get("target", "ALLY_UNIT"))
		if target_type == "ALLY_UNIT":
			if caster != null and _Utils.has_obj_method(caster, "owns_unit") and not caster.owns_unit(target):
				return {"result": "invalid_target", "effects": effects}

		if _Utils.has_obj_method(target, "return_to_hand"):
			target.return_to_hand()
			effects.append({"type": "bounce", "target_id": _Utils.get_id(target)})

		if params.has("replay_free") and bool(params["replay_free"]):
			effects.append({"type": "replay_free", "target_id": _Utils.get_id(target)})

		if params.has("draw_after"):
			if _Utils.has_obj_method(caster, "draw_cards"):
				caster.draw_cards(int(params["draw_after"]))
			effects.append({"type": "draw", "count": int(params["draw_after"])})

		return {"result": "success", "effects": effects}

	## ——— T04: COUNTERMAGIC ———
	static func t04_countermagic(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		if target == null or not _Utils.has_obj_method(target, "cancel"):
			return {"result": "no_target", "effects": effects}

		if params.has("cost_max"):
			if _Utils.has_obj_method(target, "get_cost") and target.get_cost() > int(params["cost_max"]):
				return {"result": "cost_too_high", "effects": effects}

		if params.has("targets_ally_only") and bool(params["targets_ally_only"]):
			if not _Utils.has_obj_method(target, "targets_ally") or not target.targets_ally():
				return {"result": "not_targeting_ally", "effects": effects}

		target.cancel()
		effects.append({"type": "counter", "target_id": _Utils.get_id(target)})

		if params.has("draw_on_counter"):
			if _Utils.has_obj_method(caster, "draw_cards"):
				caster.draw_cards(int(params["draw_on_counter"]))
			effects.append({"type": "draw", "count": int(params["draw_on_counter"])})

		return {"result": "success", "effects": effects}

	## ——— T05: COMBAT TRICK ———
	static func t05_combat_trick(
		params: Dictionary, secondary: Array[Dictionary],
		state: Variant, caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		var target_type: String = str(params.get("target", "ALLY_UNIT"))
		var targets := _resolve_targets(target_type, state, caster, target)

		var atk: int = int(params.get("atk", 0))
		var hp: int = int(params.get("hp", 0))

		if params.has("atk_dynamic"):
			match str(params["atk_dynamic"]):
				"ally_count": atk = _board_count(caster)
				"enemy_count": atk = _board_count(_get_opponent(state, caster))
		if params.has("hp_dynamic"):
			match str(params["hp_dynamic"]):
				"ally_count": hp = _board_count(caster)
				"enemy_count": hp = _board_count(_get_opponent(state, caster))

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
					var sec_target := _resolve_targets(str(sec.get("target", "ENEMY_NEXUS")), state, caster, null)
					for st in sec_target:
						if st != null and _Utils.has_obj_method(st, "take_damage"):
							st.take_damage(dmg)
							effects.append({"type": "damage", "target_id": _Utils.get_id(st), "amount": dmg})

		return {"result": "success", "effects": effects}

	## ——— T06: DEBUFF / CONTROL ———
	static func t06_debuff_control(
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

	## ——— T07: SPELL DRAW ———
	static func t07_spell_draw(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		var count: int = int(params.get("count", 1))

		if params.has("hand_max"):
			if _hand_size(caster) > int(params["hand_max"]):
				return {"result": "hand_too_large", "effects": effects}

		if params.has("search_filter"):
			var filter: String = str(params["search_filter"])
			effects.append({"type": "search", "filter": filter, "count": count})
		else:
			if _Utils.has_obj_method(caster, "draw_cards"):
				caster.draw_cards(count)
			effects.append({"type": "draw", "count": count})

		if params.has("opponent_draw"):
			var opp: Variant = _get_opponent(state, caster)
			if _Utils.has_obj_method(opp, "draw_cards"):
				opp.draw_cards(int(params["opponent_draw"]))
			effects.append({"type": "opponent_draw", "count": int(params["opponent_draw"])})

		if params.has("scout"):
			effects.append({"type": "scout", "count": int(params["scout"])})

		return {"result": "success", "effects": effects}

	## ——— T08: MANA RAMP ———
	static func t08_mana_ramp(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
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

	## ——— T09: TOKEN GENERATION ———
	static func t09_token_generation(
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

	## ——— T10: RELIC INTERACTION ———
	static func t10_relic_interaction(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		if target == null:
			return {"result": "no_target", "effects": effects}

		var action: String = str(params.get("action", "destroy"))
		match action:
			"destroy":
				if _Utils.has_obj_method(target, "destroy"):
					target.destroy()
					effects.append({"type": "destroy_relic", "target_id": _Utils.get_id(target)})
			"steal":
				if _Utils.has_obj_method(target, "steal"):
					target.steal(caster)
					effects.append({"type": "steal_relic", "target_id": _Utils.get_id(target)})

		if params.has("draw_on_destroy"):
			if _Utils.has_obj_method(caster, "draw_cards"):
				caster.draw_cards(int(params["draw_on_destroy"]))
			effects.append({"type": "draw", "count": int(params["draw_on_destroy"])})

		return {"result": "success", "effects": effects}

	## ——— T11: KEYWORD BUFF ———
	static func t11_keyword_buff(
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

	## ——— T12: CHOICE CYCLE ———
	static func t12_choice_cycle(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
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

	## ——— T13: TOUCH CYCLE ———
	static func t13_touch_cycle(
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

	## ——— T14: DISPLAY CYCLE ———
	static func t14_display_cycle(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []

		if params.has("cost_reduction"):
			var amount: int = int(params["cost_reduction"])
			effects.append({"type": "cost_reduce", "amount": amount})
			if _Utils.has_obj_method(caster, "set_next_spell_discount"):
				caster.set_next_spell_discount(amount)

		if params.has("influence"):
			var inf: String = str(params["influence"])
			effects.append({"type": "influence", "color": inf})
			if _Utils.has_obj_method(caster, "add_influence"):
				caster.add_influence(inf)

		if params.has("trigger"):
			var trigger_type: String = str(params["trigger"])
			effects.append({"type": "trigger", "trigger_type": trigger_type})

		return {"result": "success", "effects": effects}

	## ——— T15: DISPEL & DRAW ———
	static func t15_dispel_draw(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		var discard_count: int = int(params.get("discard", 1))
		var draw_count: int = int(params.get("draw", 1))

		if _hand_size(caster) < discard_count:
			return {"result": "not_enough_cards", "effects": effects}

		if params.has("discard_target") and target != null:
			if _Utils.has_obj_method(caster, "discard_card"):
				caster.discard_card(target)
			effects.append({"type": "discard", "card_id": _Utils.get_id(target)})
		else:
			for i in range(discard_count):
				effects.append({"type": "discard", "auto": true})
				if _Utils.has_obj_method(caster, "discard_random"):
					caster.discard_random()

		if _Utils.has_obj_method(caster, "draw_cards"):
			caster.draw_cards(draw_count)
		effects.append({"type": "draw", "count": draw_count})

		if params.has("shuffle_back") and bool(params["shuffle_back"]):
			effects.append({"type": "shuffle"})

		return {"result": "success", "effects": effects}

	## ——— T16: MARKET / NICHE ———
	static func t16_market_niche(
		params: Dictionary, state: Variant,
		caster: Variant, target: Variant
	) -> Dictionary:
		var effects: Array[Dictionary] = []
		var action: String = str(params.get("action", ""))

		match action:
			"draw_from_market":
				var cost: int = int(params.get("market_cost", 0))
				if caster != null and _Utils.has_attr(caster, "current_power") and caster.current_power >= cost:
					caster.current_power -= cost
					effects.append({"type": "market_draw", "cost": cost})
			"trigger_on_discard":
				var effect: String = str(params.get("trigger_effect", ""))
				var amount: int = int(params.get("trigger_amount", 0))
				effects.append({"type": "discard_trigger", "effect": effect, "amount": amount})

		return {"result": "success", "effects": effects}

	## ——— UTILITIES (shared across all handlers) ———
	static func _check_condition(
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
			if _hand_size(caster) > int(cond["hand_size_max"]):
				return false
		if cond.has("spell_cost_max") and target != null:
			if _Utils.has_obj_method(target, "get_cost") and target.get_cost() > int(cond["spell_cost_max"]):
				return false
		if cond.has("attacker_unblocked"):
			if not _Utils.has_obj_method(state, "is_attacker_unblocked") or not state.is_attacker_unblocked():
				return false
		if cond.has("discard_cost"):
			if _hand_size(caster) < int(cond["discard_cost"]):
				return false
		if cond.has("min_ally_count"):
			if _board_count(caster) < int(cond["min_ally_count"]):
				return false
		return true

	static func _resolve_targets(
		target_type: String, state: Variant,
		caster: Variant, selected: Variant
	) -> Array:
		match target_type:
			"ALL_ENEMY_UNITS":
				var opp: Variant = _get_opponent(state, caster)
				if _Utils.has_obj_method(opp, "get_all_units"):
					return opp.get_all_units()
				return []
			"ALL_ALLY_UNITS":
				if _Utils.has_obj_method(caster, "get_all_units"):
					return caster.get_all_units()
				return []
			"ENEMY_NEXUS":
				var opp: Variant = _get_opponent(state, caster)
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

	static func _board_count(caster: Variant) -> int:
		if caster == null:
			return 0
		if _Utils.has_obj_method(caster, "board_count"):
			return caster.board_count()
		if _Utils.has_attr(caster, "board"):
			return caster.board.size()
		return 0

	static func _hand_size(caster: Variant) -> int:
		if caster == null:
			return 0
		if _Utils.has_attr(caster, "hand"):
			var hand = caster.hand
			if hand is Array:
				return hand.size()
		return 0

	static func _get_opponent(state: Variant, caster: Variant) -> Variant:
		if state != null and _Utils.has_obj_method(state, "get_opponent"):
			return state.get_opponent(caster)
		return null
