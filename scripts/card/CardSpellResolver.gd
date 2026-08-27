## scripts/card/CardSpellResolver.gd
class_name CardSpellResolver
extends RefCounted
## Резолвер эффектов карточных заклинаний.
## Обрабатывает составные эффекты, условия каста, валидацию параметров.

const CardSpellDef = preload("res://scripts/card/CardSpellDef.gd")


## @param spell  определение заклинания
## @param game_state  состояние карточной партии
## @param caster_player  игрок-кастер
## @param target  выбранная цель (Variant)
## @return Dictionary {"result": String, "effects": Array[Dictionary], ...}
static func resolve(
	spell: CardSpellDef,
	game_state: Variant,
	caster_player: Variant,
	target: Variant = null
) -> Dictionary:
	if spell == null:
		return {"result": "invalid_spell"}

	# 1. Проверка глобального условия
	if not _check_global_condition(spell.condition, game_state, caster_player, target):
		return {"result": "condition_not_met"}

	# 2. Проверка стоимости
	if caster_player != null and caster_player.has("current_power"):
		if caster_player.current_power < spell.cost:
			return {"result": "insufficient_power"}
		caster_player.current_power -= spell.cost

	# 3. Последовательное применение эффектов
	var last_target: Variant = target
	var results: Array[Dictionary] = []

	for effect in spell.effects:
		var action: int = int(effect.get("action", -1))
		var target_type: int = int(effect.get("target", CardSpellDef.TargetType.NONE))
		var params: Dictionary = effect.get("params", {})

		# Резолвим цель
		var resolved_target: Variant = _resolve_target(
			target_type, game_state, caster_player, target, last_target
		)

		# Применяем эффект
		var r := _apply_effect(action, resolved_target, params, game_state, caster_player)
		results.append(r)
		last_target = resolved_target

	return {"result": "success", "effects": results}


# ==================== УСЛОВИЯ КАСТА ====================

static func _check_global_condition(
	cond: Dictionary,
	_state: Variant,
	player: Variant,
	target: Variant
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

	if cond.has("hand_size_max") and player != null:
		if player.has("hand") and player.hand.size() > int(cond["hand_size_max"]):
			return false

	if cond.has("spell_cost_max") and target != null:
		if _has_method(target, "get_cost") and target.get_cost() > int(cond["spell_cost_max"]):
			return false

	if cond.has("attacker_unblocked") and _state != null:
		if _has_method(_state, "is_attacker_unblocked") and not _state.is_attacker_unblocked():
			return false

	if cond.has("spell_targets_ally") and target != null:
		# Spell targets ally — проверяется на уровне цели
		pass

	if cond.has("discard_cost") and player != null:
		if player.has("hand") and player.hand.size() < int(cond["discard_cost"]):
			return false

	return true


# ==================== РЕЗОЛВ ЦЕЛИ ====================

static func _resolve_target(
	target_type: int,
	_state: Variant,
	caster: Variant,
	selected: Variant,
	last: Variant
) -> Variant:
	match target_type:
		CardSpellDef.TargetType.SAME_AS_PREVIOUS:
			return last
		CardSpellDef.TargetType.SELF:
			return caster
		CardSpellDef.TargetType.ALL_ALLY_UNITS:
			# Возвращаем кастера как маркер "все свои"
			return caster
		CardSpellDef.TargetType.ALL_ENEMY_UNITS:
			# Возвращаем null как маркер "все враги"
			return null
		_:
			return selected


# ==================== ПРИМЕНЕНИЕ ЭФФЕКТА ====================

static func _apply_effect(
	action: int,
	target: Variant,
	params: Dictionary,
	state: Variant,
	caster: Variant
) -> Dictionary:
	match action:
		CardSpellDef.EffectType.DEAL_DAMAGE:
			var amount: int = int(params.get("amount", 0))
			if target != null and _has_method(target, "take_damage"):
				target.take_damage(amount)
			return {"type": "damage", "amount": amount}

		CardSpellDef.EffectType.APPLY_STATUS:
			var status: int = int(params.get("status", -1))
			var duration: int = int(params.get("duration", -1))
			if target != null and _has_method(target, "add_status"):
				target.add_status(status, duration)
			return {"type": "status", "status": status}

		CardSpellDef.EffectType.DESTROY:
			var ignore_ward: bool = bool(params.get("ignore_ward", false))
			if target != null:
				if not ignore_ward and _has_method(target, "has_ward") and target.has_ward():
					target.remove_ward()
					return {"type": "blocked_by_ward"}
				if _has_method(target, "destroy"):
					target.destroy()
			return {"type": "destroy"}

		CardSpellDef.EffectType.EXILE:
			if target != null and _has_method(target, "exile"):
				target.exile()
			return {"type": "exile"}

		CardSpellDef.EffectType.RETURN_TO_HAND:
			if target != null and _has_method(target, "return_to_hand"):
				target.return_to_hand()
			return {"type": "bounce"}

		CardSpellDef.EffectType.RETURN_TO_DECK:
			var shuffle: bool = bool(params.get("shuffle", true))
			if target != null and _has_method(target, "return_to_deck"):
				target.return_to_deck(shuffle)
			return {"type": "return_to_deck"}

		CardSpellDef.EffectType.MODIFY_STAT_TEMP:
			if target != null and _has_method(target, "modify_temp_stats"):
				var atk: int = int(params.get("atk", 0))
				var hp: int = int(params.get("hp", 0))
				var hp_temp: int = int(params.get("hp_temp", 0))
				if params.has("atk_dynamic") and params["atk_dynamic"] == "ally_count":
					atk = _board_count(caster)
				if params.has("hp_dynamic") and params["hp_dynamic"] == "ally_count":
					hp = _board_count(caster)
				target.modify_temp_stats(atk, hp + hp_temp)
			return {"type": "buff"}

		CardSpellDef.EffectType.MODIFY_STAT_PERM:
			if target != null and _has_method(target, "modify_perm_stats"):
				var atk: int = int(params.get("atk", 0))
				var hp: int = int(params.get("hp", 0))
				target.modify_perm_stats(atk, hp)
			return {"type": "perm_debuff"}

		CardSpellDef.EffectType.DRAW:
			var count: int = int(params.get("count", 1))
			if caster != null and _has_method(caster, "draw_cards"):
				caster.draw_cards(count)
			return {"type": "draw", "count": count}

		CardSpellDef.EffectType.HEAL:
			var amount: int = int(params.get("amount", 0))
			if target != null and _has_method(target, "heal"):
				target.heal(amount)
			return {"type": "heal", "amount": amount}

		CardSpellDef.EffectType.CANCEL:
			if target != null and _has_method(target, "cancel"):
				target.cancel()
			return {"type": "counter"}

		CardSpellDef.EffectType.MODIFY_POWER:
			var power: int = int(params.get("power", 0))
			if caster != null and caster.has("current_power"):
				caster.current_power += power
			return {"type": "ramp", "amount": power}

		CardSpellDef.EffectType.CREATE_TOKEN:
			var token_id: String = str(params.get("token", ""))
			if caster != null and _has_method(caster, "create_token"):
				if token_id == "rat":
					caster.create_token("rat", int(params.get("atk", 1)), int(params.get("hp", 1)))
				elif token_id == "random_cheap" and _has_method(caster, "create_random_cheap_token"):
					caster.create_random_cheap_token()
			return {"type": "token"}

		CardSpellDef.EffectType.SWAP_POSITION:
			# Требует две цели — обработка на уровне game_state
			if state != null and _has_method(state, "swap_units"):
				state.swap_units(target, null)
			return {"type": "swap"}

		CardSpellDef.EffectType.DISCARD:
			var count: int = int(params.get("count", 1))
			if caster != null and _has_method(caster, "discard_cards"):
				caster.discard_cards(count)
			return {"type": "discard", "count": count}

		CardSpellDef.EffectType.MARKET_ACTION:
			# Специфическое действие рынка
			return {"type": "market"}

		CardSpellDef.EffectType.ACTION_REPEAT:
			# Повтор действия юнита
			return {"type": "action_repeat"}

		CardSpellDef.EffectType.CHANGE_CONTROL:
			var duration: int = int(params.get("duration", 1))
			if target != null and _has_method(target, "change_control"):
				target.change_control(caster, duration)
			return {"type": "change_control", "duration": duration}

		CardSpellDef.EffectType.TRIGGER_ON_DISCARD:
			# Триггер при сбросе — устанавливается как обработчик
			return {"type": "trigger_on_discard"}

		_:
			push_warning("Unhandled effect type: %d" % action)
			return {"type": "unknown"}


static func _board_count(player: Variant) -> int:
	if player != null and _has_method(player, "board_count"):
		return player.board_count()
	if player != null and player.has("board"):
		return player.board.size()
	return 0

static func _has_method(obj: Variant, method: String) -> bool:
	if obj == null:
		return false
	if obj is Object:
		return obj.has_method(method)
	return false
