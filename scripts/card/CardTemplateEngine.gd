## scripts/card/CardTemplateEngine.gd
class_name CardTemplateEngine
extends RefCounted
## 16 шаблонных обработчиков. Каждый шаблон — один метод.
## Все методы принимают одинаковую сигнатуру и возвращают Array[Dictionary] результатов.

const _Enums = preload("res://scripts/card/CardEnums.gd")
const _E := _Enums.EffectType
const _T := _Enums.TargetType
const _S := _Enums.StatusType

## Диспетчер: template_id → метод.
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
	if not _check_condition(condition, state, caster, target):
		return {"result": "condition_not_met", "effects": []}

	match template:
		&"DIRECT_DAMAGE":       return _t01_direct_damage(params, state, caster, target)
		&"HARD_REMOVAL":        return _t02_hard_removal(params, state, caster, target)
		&"BOUNCE":              return _t03_bounce(params, state, caster, target)
		&"COUNTERMAGIC":        return _t04_countermagic(params, state, caster, target)
		&"COMBAT_TRICK":        return _t05_combat_trick(params, secondary, state, caster, target)
		&"DEBUFF_CONTROL":      return _t06_debuff_control(params, state, caster, target)
		&"CARD_DRAW":           return _t07_card_draw(params, state, caster, target)
		&"MANA_RAMP":           return _t08_mana_ramp(params, state, caster, target)
		&"TOKEN_GENERATION":    return _t09_token_generation(params, state, caster, target)
		&"RELIC_INTERACTION":   return _t10_relic_interaction(params, state, caster, target)
		&"KEYWORD_BUFF":        return _t11_keyword_buff(params, state, caster, target)
		&"CHOICE_CYCLE":        return _t12_choice_cycle(params, state, caster, target)
		&"TOUCH_CYCLE":         return _t13_touch_cycle(params, state, caster, target)
		&"DISPLAY_CYCLE":       return _t14_display_cycle(params, state, caster, target)
		&"DISCARD_DRAW":        return _t15_discard_draw(params, state, caster, target)
		&"MARKET_NICHE":        return _t16_market_niche(params, state, caster, target)
		_:
			push_warning("Unknown template: %s" % template)
			return {"result": "unknown_template", "effects": []}


# ==================== ШАБЛОН 1: DIRECT DAMAGE ====================

static func _t01_direct_damage(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var amount: int = int(params.get("amount", 0))
	var target_type: String = str(params.get("target", "ENEMY_UNIT"))
	var effects: Array[Dictionary] = []

	# Динамический урон
	if params.has("amount_dynamic"):
		match str(params["amount_dynamic"]):
			"ally_count": amount = _board_count(caster)
			"enemy_count": amount = _board_count(_get_opponent(state, caster))
			"hand_size": amount = _hand_size(caster)

	# Целевой тип определяет множество целей
	var targets := _resolve_targets(target_type, state, caster, target)
	for t in targets:
		if t != null and _has_method(t, "take_damage"):
			var actual: Variant = t.take_damage(amount)
			effects.append({"type": "damage", "target_id": _get_id(t), "amount": actual})

	# Дополнительный статус (Ice Bolt → FROZEN)
	if params.has("apply_status"):
		var status: int = _Enums.parse_status(str(params["apply_status"]))
		var duration: int = int(params.get("status_duration", 1))
		for t in targets:
			if t != null and _has_method(t, "add_status"):
				t.add_status(status, duration)
				effects.append({"type": "status", "target_id": _get_id(t), "status": status})

	# Доп. эффект: self-damage (At Any Cost, Burn Out)
	if params.has("self_damage"):
		var self_dmg: int = int(params["self_damage"])
		if caster != null and _has_method(caster, "take_damage"):
			caster.take_damage(self_dmg)
			effects.append({"type": "self_damage", "amount": self_dmg})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 2: HARD REMOVAL ====================

static func _t02_hard_removal(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var ignore_ward: bool = bool(params.get("ignore_ward", false))
	var exile: bool = bool(params.get("exile", false))

	# Ward check
	if not ignore_ward and _has_method(target, "has_ward") and target.has_ward():
		if _has_method(target, "remove_ward"):
			target.remove_ward()
		effects.append({"type": "blocked_by_ward", "target_id": _get_id(target)})
		return {"result": "ward_blocked", "effects": effects}

	if exile:
		if _has_method(target, "exile"):
			target.exile()
			effects.append({"type": "exile", "target_id": _get_id(target)})
	else:
		if _has_method(target, "destroy"):
			target.destroy()
			effects.append({"type": "destroy", "target_id": _get_id(target)})

	# Дополнительные эффекты после уничтожения
	if params.has("draw_on_kill"):
		if _has_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_on_kill"]))
		effects.append({"type": "draw", "count": int(params["draw_on_kill"])})

	if params.has("create_token_on_kill"):
		if _has_method(caster, "create_token"):
			var token_id: String = str(params["create_token_on_kill"])
			caster.create_token(token_id, 1, 1)
		effects.append({"type": "token", "token_id": str(params["create_token_on_kill"])})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 3: BOUNCE ====================

static func _t03_bounce(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var target_type: String = str(params.get("target", "ALLY_UNIT"))

	# Проверяем принадлежность цели
	if target_type == "ALLY_UNIT":
		if caster != null and _has_method(caster, "owns_unit") and not caster.owns_unit(target):
			return {"result": "invalid_target", "effects": effects}

	if _has_method(target, "return_to_hand"):
		target.return_to_hand()
		effects.append({"type": "bounce", "target_id": _get_id(target)})

	# Replay target free (Stutterstep)
	if params.has("replay_free") and bool(params["replay_free"]):
		effects.append({"type": "replay_free", "target_id": _get_id(target)})

	# Draw after bounce
	if params.has("draw_after"):
		if _has_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_after"]))
		effects.append({"type": "draw", "count": int(params["draw_after"])})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 4: COUNTERMAGIC ====================

static func _t04_countermagic(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null or not _has_method(target, "cancel"):
		return {"result": "no_target", "effects": effects}

	# Условие по стоимости цели (Hesitate: cost <= 3)
	if params.has("cost_max"):
		if _has_method(target, "get_cost") and target.get_cost() > int(params["cost_max"]):
			return {"result": "cost_too_high", "effects": effects}

	# Условие: только если целит союзника (Swift Refusal)
	if params.has("targets_ally_only") and bool(params["targets_ally_only"]):
		if not _has_method(target, "targets_ally") or not target.targets_ally():
			return {"result": "not_targeting_ally", "effects": effects}

	target.cancel()
	effects.append({"type": "counter", "target_id": _get_id(target)})

	# Дополнительный эффект после отмены
	if params.has("draw_on_counter"):
		if _has_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_on_counter"]))
		effects.append({"type": "draw", "count": int(params["draw_on_counter"])})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 5: COMBAT TRICK ====================

static func _t05_combat_trick(
	params: Dictionary, secondary: Array[Dictionary],
	state: Variant, caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []

	# Определяем целевую группу
	var target_type: String = str(params.get("target", "ALLY_UNIT"))
	var targets := _resolve_targets(target_type, state, caster, target)

	var atk: int = int(params.get("atk", 0))
	var hp: int = int(params.get("hp", 0))

	# Динамические значения (Overthrow: X = ally_count)
	if params.has("atk_dynamic"):
		match str(params["atk_dynamic"]):
			"ally_count": atk = _board_count(caster)
			"enemy_count": atk = _board_count(_get_opponent(state, caster))
	if params.has("hp_dynamic"):
		match str(params["hp_dynamic"]):
			"ally_count": hp = _board_count(caster)
			"enemy_count": hp = _board_count(_get_opponent(state, caster))

	for t in targets:
		if t != null and _has_method(t, "modify_temp_stats"):
			t.modify_temp_stats(atk, hp)
			effects.append({"type": "buff", "target_id": _get_id(t), "atk": atk, "hp": hp})

	# Heal component (Reinvigorate)
	if params.has("heal"):
		for t in targets:
			if t != null and _has_method(t, "heal"):
				t.heal(int(params["heal"]))
				effects.append({"type": "heal", "target_id": _get_id(t), "amount": int(params["heal"])})

	# Secondary effects (из JSON-массива)
	for sec in secondary:
		var sec_type: String = str(sec.get("effect", ""))
		match sec_type:
			"DRAW":
				if _has_method(caster, "draw_cards"):
					caster.draw_cards(int(sec.get("count", 1)))
				effects.append({"type": "draw", "count": int(sec.get("count", 1))})
			"DEAL_DAMAGE":
				var dmg: int = int(sec.get("amount", 0))
				var sec_target := _resolve_targets(str(sec.get("target", "ENEMY_NEXUS")), state, caster, null)
				for st in sec_target:
					if st != null and _has_method(st, "take_damage"):
						st.take_damage(dmg)
						effects.append({"type": "damage", "target_id": _get_id(st), "amount": dmg})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 6: DEBUFF / CONTROL ====================

static func _t06_debuff_control(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	# Статус
	if params.has("status"):
		var status: int = _Enums.parse_status(str(params["status"]))
		var duration: int = int(params.get("duration", -1))
		if _has_method(target, "add_status"):
			target.add_status(status, duration)
			effects.append({"type": "status", "target_id": _get_id(target), "status": status})

	# Stat debuff
	var atk: int = int(params.get("atk", 0))
	var hp: int = int(params.get("hp", 0))
	if atk != 0 or hp != 0:
		var permanent: bool = bool(params.get("permanent", false))
		if permanent and _has_method(target, "modify_perm_stats"):
			target.modify_perm_stats(atk, hp)
			effects.append({"type": "perm_debuff", "target_id": _get_id(target), "atk": atk, "hp": hp})
		elif _has_method(target, "modify_temp_stats"):
			target.modify_temp_stats(atk, hp)
			effects.append({"type": "temp_debuff", "target_id": _get_id(target), "atk": atk, "hp": hp})

	# Change control (Turnabout)
	if params.has("change_control") and bool(params["change_control"]):
		var duration: int = int(params.get("control_duration", 1))
		if _has_method(target, "change_control"):
			target.change_control(caster, duration)
			effects.append({"type": "steal", "target_id": _get_id(target), "duration": duration})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 7: CARD DRAW ====================

static func _t07_card_draw(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var count: int = int(params.get("count", 1))

	# Condition: hand size
	if params.has("hand_max"):
		if _hand_size(caster) > int(params["hand_max"]):
			return {"result": "hand_too_large", "effects": effects}

	# Search (от школы / по типу)
	if params.has("search_filter"):
		var filter: String = str(params["search_filter"])
		effects.append({"type": "search", "filter": filter, "count": count})
	else:
		if _has_method(caster, "draw_cards"):
			caster.draw_cards(count)
		effects.append({"type": "draw", "count": count})

	# Opponent draw (Generosity, Fair Exchange)
	if params.has("opponent_draw"):
		var opp: Variant = _get_opponent(state, caster)
		if _has_method(opp, "draw_cards"):
			opp.draw_cards(int(params["opponent_draw"]))
		effects.append({"type": "opponent_draw", "count": int(params["opponent_draw"])})

	# Scout (смотреть верх колоды)
	if params.has("scout"):
		effects.append({"type": "scout", "count": int(params["scout"])})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 8: MANA RAMP ====================

static func _t08_mana_ramp(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var power: int = int(params.get("power", 1))

	if _has_method(caster, "add_max_power"):
		caster.add_max_power(power)
	effects.append({"type": "ramp", "amount": power})

	# Influence (Earth Conjuring → +1 Earth)
	if params.has("influence"):
		var inf: String = str(params["influence"])
		if _has_method(caster, "add_influence"):
			caster.add_influence(inf)
		effects.append({"type": "influence", "color": inf})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 9: TOKEN GENERATION ====================

static func _t09_token_generation(
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
		if _has_method(caster, "create_token"):
			var unit = caster.create_token(token_id, atk, hp)
			if unit != null:
				for kw in keywords:
					if _has_method(unit, "add_status"):
						unit.add_status(_Enums.parse_status(str(kw)), -1)

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 10: RELIC INTERACTION ====================

static func _t10_relic_interaction(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var action: String = str(params.get("action", "destroy"))

	match action:
		"destroy":
			if _has_method(target, "destroy"):
				target.destroy()
				effects.append({"type": "destroy_relic", "target_id": _get_id(target)})
		"steal":
			if _has_method(target, "steal"):
				target.steal(caster)
				effects.append({"type": "steal_relic", "target_id": _get_id(target)})

	if params.has("draw_on_destroy"):
		if _has_method(caster, "draw_cards"):
			caster.draw_cards(int(params["draw_on_destroy"]))
		effects.append({"type": "draw", "count": int(params["draw_on_destroy"])})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 11: KEYWORD BUFF ====================

static func _t11_keyword_buff(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var keyword: String = str(params.get("keyword", ""))
	var duration: int = int(params.get("duration", -1))  # -1 = permanent
	var status: int = _Enums.parse_status(keyword)

	if _has_method(target, "add_status"):
		target.add_status(status, duration)
		effects.append({"type": "keyword", "target_id": _get_id(target), "keyword": keyword})

	# Stat bonus alongside keyword
	if params.has("atk") or params.has("hp"):
		var atk: int = int(params.get("atk", 0))
		var hp: int = int(params.get("hp", 0))
		if _has_method(target, "modify_temp_stats"):
			target.modify_temp_stats(atk, hp)
			effects.append({"type": "buff", "target_id": _get_id(target), "atk": atk, "hp": hp})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 12: CHOICE CYCLE ====================

static func _t12_choice_cycle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []

	# Всегда draw 1
	var draw_count: int = int(params.get("draw", 1))
	if _has_method(caster, "draw_cards"):
		caster.draw_cards(draw_count)
	effects.append({"type": "draw", "count": draw_count})

	# Вторичный эффект (зависит от карты)
	if params.has("secondary"):
		var sec: String = str(params["secondary"])
		match sec:
			"DEAL_1_DAMAGE":
				if target != null and _has_method(target, "take_damage"):
					target.take_damage(1)
					effects.append({"type": "damage", "target_id": _get_id(target), "amount": 1})
			"BUFF_1_1":
				if target != null and _has_method(target, "modify_temp_stats"):
					target.modify_temp_stats(1, 1)
					effects.append({"type": "buff", "target_id": _get_id(target), "atk": 1, "hp": 1})
			"HEAL_2":
				if target != null and _has_method(target, "heal"):
					target.heal(2)
					effects.append({"type": "heal", "target_id": _get_id(target), "amount": 2})
			"GAIN_1_ARMOR":
				if target != null and _has_method(target, "add_status"):
					target.add_status(_S.ARMORED, 1)
					effects.append({"type": "keyword", "target_id": _get_id(target), "keyword": "ARMORED"})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 13: TOUCH CYCLE ====================

static func _t13_touch_cycle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	if target == null:
		return {"result": "no_target", "effects": effects}

	var atk: int = int(params.get("atk", 1))
	var hp: int = int(params.get("hp", 1))

	if _has_method(target, "modify_perm_stats"):
		target.modify_perm_stats(atk, hp)
		effects.append({"type": "perm_buff", "target_id": _get_id(target), "atk": atk, "hp": hp})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 14: DISPLAY CYCLE ====================

static func _t14_display_cycle(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []

	# Reduce cost of next spell
	if params.has("cost_reduction"):
		var amount: int = int(params["cost_reduction"])
		effects.append({"type": "cost_reduce", "amount": amount})
		if _has_method(caster, "set_next_spell_discount"):
			caster.set_next_spell_discount(amount)

	# Gain influence
	if params.has("influence"):
		var inf: String = str(params["influence"])
		effects.append({"type": "influence", "color": inf})
		if _has_method(caster, "add_influence"):
			caster.add_influence(inf)

	# Trigger ability
	if params.has("trigger"):
		var trigger_type: String = str(params["trigger"])
		effects.append({"type": "trigger", "trigger_type": trigger_type})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 15: DISCARD & DRAW ====================

static func _t15_discard_draw(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var discard_count: int = int(params.get("discard", 1))
	var draw_count: int = int(params.get("draw", 1))

	if _hand_size(caster) < discard_count:
		return {"result": "not_enough_cards", "effects": effects}

	# Сброс
	if params.has("discard_target") and target != null:
		if _has_method(caster, "discard_card"):
			caster.discard_card(target)
		effects.append({"type": "discard", "card_id": _get_id(target)})
	else:
		for i in range(discard_count):
			effects.append({"type": "discard", "auto": true})
			if _has_method(caster, "discard_random"):
				caster.discard_random()

	# Добор
	if _has_method(caster, "draw_cards"):
		caster.draw_cards(draw_count)
	effects.append({"type": "draw", "count": draw_count})

	# Shuffle into deck (Recycle)
	if params.has("shuffle_back") and bool(params["shuffle_back"]):
		effects.append({"type": "shuffle"})

	return {"result": "success", "effects": effects}


# ==================== ШАБЛОН 16: MARKET / NICHE ====================

static func _t16_market_niche(
	params: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> Dictionary:
	var effects: Array[Dictionary] = []
	var action: String = str(params.get("action", ""))

	match action:
		"draw_from_market":
			var cost: int = int(params.get("market_cost", 0))
			if caster != null and _has_attr(caster, "current_power") and caster.current_power >= cost:
				caster.current_power -= cost
				effects.append({"type": "market_draw", "cost": cost})
		"trigger_on_discard":
			var effect: String = str(params.get("trigger_effect", ""))
			var amount: int = int(params.get("trigger_amount", 0))
			effects.append({"type": "discard_trigger", "effect": effect, "amount": amount})

	return {"result": "success", "effects": effects}


# ==================== УТИЛИТЫ ====================

static func _check_condition(
	cond: Dictionary, state: Variant,
	caster: Variant, target: Variant
) -> bool:
	if cond.is_empty():
		return true
	if cond.has("target_hp_max") and target != null:
		if _has_method(target, "get_hp") and target.get_hp() > int(cond["target_hp_max"]):
			return false
	if cond.has("target_cost_max") and target != null:
		if _has_method(target, "get_cost") and target.get_cost() > int(cond["target_cost_max"]):
			return false
	if cond.has("target_is_damaged") and target != null:
		if _has_method(target, "is_damaged") and not target.is_damaged():
			return false
	if cond.has("target_is_flying") and target != null:
		if _has_method(target, "is_flying") and not target.is_flying():
			return false
	if cond.has("hand_size_max"):
		if _hand_size(caster) > int(cond["hand_size_max"]):
			return false
	if cond.has("spell_cost_max") and target != null:
		if _has_method(target, "get_cost") and target.get_cost() > int(cond["spell_cost_max"]):
			return false
	if cond.has("attacker_unblocked"):
		if not _has_method(state, "is_attacker_unblocked") or not state.is_attacker_unblocked():
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
			if _has_method(opp, "get_all_units"):
				return opp.get_all_units()
			return []
		"ALL_ALLY_UNITS":
			if _has_method(caster, "get_all_units"):
				return caster.get_all_units()
			return []
		"ENEMY_NEXUS":
			var opp: Variant = _get_opponent(state, caster)
			if opp != null:
				if _has_attr(opp, "nexus"):
					return [opp.nexus]
				return [opp]
			return []
		"ALLY_NEXUS":
			if caster != null and _has_attr(caster, "nexus"):
				return [caster.nexus]
			return [caster]
		"SELF":
			return [caster] if caster != null else []
		_:
			if selected != null:
				return [selected]
			return []

static func _has_method(obj: Variant, method: String) -> bool:
	if obj == null:
		return false
	if obj is Object:
		return obj.has_method(method)
	return false

static func _has_attr(obj: Variant, attr: String) -> bool:
	if obj == null:
		return false
	if obj is Dictionary:
		return obj.has(attr)
	return false

static func _get_id(obj: Variant) -> String:
	if obj == null:
		return ""
	if _has_method(obj, "get_id"):
		return obj.get_id()
	return str(obj)

static func _board_count(caster: Variant) -> int:
	if caster == null:
		return 0
	if _has_method(caster, "board_count"):
		return caster.board_count()
	if _has_attr(caster, "board"):
		return caster.board.size()
	return 0

static func _hand_size(caster: Variant) -> int:
	if caster == null:
		return 0
	if _has_attr(caster, "hand"):
		var hand = caster.hand
		if hand is Array:
			return hand.size()
	return 0

static func _get_opponent(state: Variant, caster: Variant) -> Variant:
	if state != null and _has_method(state, "get_opponent"):
		return state.get_opponent(caster)
	return null
