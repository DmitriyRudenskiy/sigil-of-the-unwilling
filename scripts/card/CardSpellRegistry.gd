## scripts/card/CardSpellRegistry.gd
## Autoload: CardSpells
## Реестр 71 карточного заклинания (LoR/MTG-стиль).

extends Node

const CardSpellDef = preload("res://scripts/card/CardSpellDef.gd")

var _spells: Dictionary = {}

func _ready() -> void:
	ensure_definitions()

func ensure_definitions() -> void:
	if not _spells.is_empty():
		return
	# === Группа А: Уничтожение и урон (14) ===
	_reg(&"annihilate", "Annihilate", "fast", 5, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_UNIT, {"ignore_ward": true, "cost_check": true}),
	])
	_reg(&"banish", "Banish", "fast", 4, [
		_eff(CardSpellDef.EffectType.EXILE, CardSpellDef.TargetType.ENEMY_UNIT, {"ignore_ward": true}),
	])
	_reg(&"deathstrike", "Deathstrike", "fast", 3, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_UNIT, {}),
	], {"target_hp_max": 4})
	_reg(&"incineration", "Incineration", "fast", 3, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ENEMY_UNIT, {"amount": 4}),
	])
	_reg(&"ruin", "Ruin", "fast", 4, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_RELIC, {}),
	])
	_reg(&"slay", "Slay", "fast", 3, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_UNIT, {}),
	], {"target_is_damaged": true})
	_reg(&"unmake", "Unmake", "fast", 2, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_UNIT, {}),
	], {"target_cost_max": 3})
	_reg(&"ice_bolt", "Ice Bolt", "fast", 1, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ANY_NEXUS, {"amount": 2}),
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.SAME_AS_PREVIOUS, {"status": CardSpellDef.StatusEffect.FROZEN, "duration": 1}),
	])
	_reg(&"lightning_strike", "Lightning Strike", "fast", 2, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ANY_UNIT, {"amount": 2}),
	])
	_reg(&"skybolt", "Skybolt", "fast", 3, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ENEMY_UNIT, {"amount": 3}),
	], {"target_is_flying": true})
	_reg(&"burn_them_all", "Burn Them All", "slow", 5, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ALL_ENEMY_UNITS, {"amount": 2}),
	])
	_reg(&"crack_the_earth", "Crack the Earth", "slow", 5, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ALL_ENEMY_UNITS, {"amount": 2}),
	])
	_reg(&"shatter", "Shatter", "fast", 3, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_RELIC, {}),
	])
	_reg(&"dismantle", "Dismantle", "fast", 3, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_RELIC, {}),
		_eff(CardSpellDef.EffectType.DRAW, CardSpellDef.TargetType.SELF, {"count": 1}),
	])

	# === Группа Б: Защита и уклонение (12) ===
	_reg(&"blink", "Blink", "fast", 2, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ALLY_UNIT, {}),
	])
	_reg(&"disappear", "Disappear", "fast", 2, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ALLY_UNIT, {}),
	])
	_reg(&"levitate", "Levitate", "fast", 2, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ANY_UNIT, {}),
	])
	_reg(&"teleport", "Teleport", "fast", 3, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ALLY_UNIT, {}),
	])
	_reg(&"transpose", "Transpose", "fast", 2, [
		_eff(CardSpellDef.EffectType.SWAP_POSITION, CardSpellDef.TargetType.TWO_ALLY_UNITS, {}),
	])
	_reg(&"nullify", "Nullify", "fast", 3, [
		_eff(CardSpellDef.EffectType.CANCEL, CardSpellDef.TargetType.ENEMY_SPELL, {}),
	])
	_reg(&"hesitate", "Hesitate", "fast", 2, [
		_eff(CardSpellDef.EffectType.CANCEL, CardSpellDef.TargetType.ENEMY_SPELL, {}),
	], {"spell_cost_max": 3})
	_reg(&"swift_refusal", "Swift Refusal", "fast", 2, [
		_eff(CardSpellDef.EffectType.CANCEL, CardSpellDef.TargetType.ENEMY_SPELL, {}),
	], {"spell_targets_ally": true})
	_reg(&"bubble_shield", "Bubble Shield", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ALLY_UNIT, {"status": CardSpellDef.StatusEffect.WARD, "duration": 1}),
	])
	_reg(&"forcefield", "Forcefield", "fast", 3, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_NEXUS, {"hp_temp": 4}),
	])
	_reg(&"stoneskin", "Stoneskin", "fast", 2, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_UNIT, {"hp_temp": 2}),
	])
	_reg(&"withstand", "Withstand", "fast", 2, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_UNIT, {"hp_temp": 2}),
	])

	# === Группа В: Боевые хитрости (12) ===
	_reg(&"agile_strike", "Agile Strike", "fast", 3, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_UNIT, {"atk": 2, "hp": 2}),
	])
	_reg(&"inner_might", "Inner Might", "fast", 3, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_UNIT, {"atk": 3, "hp": 3}),
	])
	_reg(&"mighty_strikes", "Mighty Strikes", "slow", 4, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALL_ALLY_UNITS, {"atk": 1, "hp": 1}),
	])
	_reg(&"overthrow", "Overthrow", "fast", 4, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_UNIT, {"atk_dynamic": "ally_count", "hp_dynamic": "ally_count"}),
	])
	_reg(&"reinvigorate", "Reinvigorate", "fast", 3, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALLY_UNIT, {"atk": 2, "hp": 2}),
		_eff(CardSpellDef.EffectType.HEAL, CardSpellDef.TargetType.SAME_AS_PREVIOUS, {"amount": 2}),
	])
	_reg(&"sharpened_reflex", "Sharpened Reflex", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ALLY_UNIT, {"status": CardSpellDef.StatusEffect.QUICKDRAW}),
	])
	_reg(&"steely_resolve", "Steely Resolve", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ALLY_UNIT, {"status": CardSpellDef.StatusEffect.UNBLOCKABLE}),
	])
	_reg(&"augmented_form", "Augmented Form", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ALLY_UNIT, {"status": CardSpellDef.StatusEffect.OVERWHELM}),
	])
	_reg(&"scalehide", "Scalehide", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ALLY_UNIT, {"status": CardSpellDef.StatusEffect.ARMORED}),
	])
	_reg(&"barrel_through", "Barrel Through", "fast", 2, [
		_eff(CardSpellDef.EffectType.DEAL_DAMAGE, CardSpellDef.TargetType.ENEMY_NEXUS, {"amount": 2}),
	], {"attacker_unblocked": true})
	_reg(&"daring_maneuver", "Daring Maneuver", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ALLY_UNIT, {"status": CardSpellDef.StatusEffect.CHALLENGE}),
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.SAME_AS_PREVIOUS, {"atk": 2}),
	])
	_reg(&"turn_the_tides", "Turn the Tides", "slow", 5, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ALL_ALLY_UNITS, {"atk": 2, "hp": 2}),
	])

	# === Группа Г: Ослабление и контроль (12) ===
	_reg(&"disarm", "Disarm", "fast", 3, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.SILENCE}),
	])
	_reg(&"mute", "Mute", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.SILENCE}),
	])
	_reg(&"sickness", "Sickness", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.SILENCE}),
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.SAME_AS_PREVIOUS, {"atk": -1, "hp": -1}),
	])
	_reg(&"chill", "Chill", "fast", 2, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ENEMY_UNIT, {"atk": -2, "hp": -2}),
	])
	_reg(&"icy_hold", "Icy Hold", "fast", 3, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.FROZEN}),
	])
	_reg(&"shrivel", "Shrivel", "slow", 3, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_PERM, CardSpellDef.TargetType.ENEMY_UNIT, {"atk": -2, "hp": -2}),
	])
	_reg(&"subdue", "Subdue", "fast", 3, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_TEMP, CardSpellDef.TargetType.ENEMY_UNIT, {"atk": -3, "hp": -3}),
	])
	_reg(&"withering_touch", "Withering Touch", "slow", 2, [
		_eff(CardSpellDef.EffectType.MODIFY_STAT_PERM, CardSpellDef.TargetType.ENEMY_UNIT, {"atk": -1, "hp": -1}),
	])
	_reg(&"arrest", "Arrest", "fast", 3, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.STUN}),
	])
	_reg(&"ensnare", "Ensnare", "fast", 3, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.STUN}),
	])
	_reg(&"hold_at_bay", "Hold At Bay", "fast", 2, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.CANNOT_BLOCK}),
	])
	_reg(&"telekinetic_shackles", "Telekinetic Shackles", "fast", 3, [
		_eff(CardSpellDef.EffectType.APPLY_STATUS, CardSpellDef.TargetType.ENEMY_UNIT, {"status": CardSpellDef.StatusEffect.CANNOT_ATTACK}),
	])

	# === Группа Д: Манипуляция картами (12) ===
	_reg(&"boundless_knowledge", "Boundless Knowledge", "slow", 3, [
		_eff(CardSpellDef.EffectType.DRAW, CardSpellDef.TargetType.SELF, {"count": 2}),
	], {"hand_size_max": 4})
	_reg(&"bottled_insight", "Bottled Insight", "fast", 2, [
		_eff(CardSpellDef.EffectType.DRAW, CardSpellDef.TargetType.SELF, {"count": 1}),
	])
	_reg(&"find_the_moment", "Find The Moment", "fast", 1, [
		_eff(CardSpellDef.EffectType.DRAW, CardSpellDef.TargetType.SELF, {"count": 1}),
	])
	_reg(&"wisdom_of_the_elders", "Wisdom of the Elders", "slow", 3, [
		_eff(CardSpellDef.EffectType.DRAW, CardSpellDef.TargetType.SELF, {"count": 1}),
	])
	_reg(&"recycle", "Recycle", "fast", 2, [
		_eff(CardSpellDef.EffectType.RETURN_TO_DECK, CardSpellDef.TargetType.ALLY_UNIT_IN_HAND, {"shuffle": true}),
		_eff(CardSpellDef.EffectType.DRAW, CardSpellDef.TargetType.SELF, {"count": 1}),
	])
	_reg(&"recovery", "Recovery", "fast", 2, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ALLY_UNIT_IN_GRAVE, {}),
	], {"target_cost_max": 2})
	_reg(&"express_route", "Express Route", "fast", 1, [
		_eff(CardSpellDef.EffectType.MODIFY_POWER, CardSpellDef.TargetType.SELF, {"power": 1}),
	])
	_reg(&"furnish", "Furnish", "fast", 1, [
		_eff(CardSpellDef.EffectType.MODIFY_POWER, CardSpellDef.TargetType.SELF, {"power": 1}),
	])
	_reg(&"earth_conjuring", "Earth Conjuring", "fast", 1, [
		_eff(CardSpellDef.EffectType.MODIFY_POWER, CardSpellDef.TargetType.SELF, {"power": 1, "influence": &"earth"}),
	])
	_reg(&"fire_conjuring", "Fire Conjuring", "fast", 1, [
		_eff(CardSpellDef.EffectType.MODIFY_POWER, CardSpellDef.TargetType.SELF, {"power": 1, "influence": &"fire"}),
	])
	_reg(&"water_conjuring", "Water Conjuring", "fast", 1, [
		_eff(CardSpellDef.EffectType.MODIFY_POWER, CardSpellDef.TargetType.SELF, {"power": 1, "influence": &"water"}),
	])
	_reg(&"wind_conjuring", "Wind Conjuring", "fast", 1, [
		_eff(CardSpellDef.EffectType.MODIFY_POWER, CardSpellDef.TargetType.SELF, {"power": 1, "influence": &"wind"}),
	])

	# === Группа Е: Специфические механики (9) ===
	_reg(&"send_an_agent", "Send an Agent", "fast", 1, [
		_eff(CardSpellDef.EffectType.MARKET_ACTION, CardSpellDef.TargetType.SELF, {"action": "draw_from_market", "cost": 1}),
	])
	_reg(&"skullmarket_delivery", "Skullmarket Delivery", "fast", 2, [
		_eff(CardSpellDef.EffectType.CREATE_TOKEN, CardSpellDef.TargetType.SELF, {"token": "random_cheap"}),
	], {"discard_cost": 1})
	_reg(&"warren_delivery", "Warren Delivery", "fast", 2, [
		_eff(CardSpellDef.EffectType.CREATE_TOKEN, CardSpellDef.TargetType.SELF, {"token": "rat", "atk": 1, "hp": 1}),
	])
	_reg(&"trick_shot", "Trick Shot", "fast", 2, [
		_eff(CardSpellDef.EffectType.DESTROY, CardSpellDef.TargetType.ENEMY_UNIT, {}),
	], {"target_hp_max": 2})
	_reg(&"trigger_happy", "Trigger-Happy", "fast", 3, [
		_eff(CardSpellDef.EffectType.ACTION_REPEAT, CardSpellDef.TargetType.ALLY_UNIT, {"action": "ranged_attack", "count": 1}),
	])
	_reg(&"stutterstep", "Stutterstep", "fast", 4, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ALLY_UNIT, {}),
		_eff(CardSpellDef.EffectType.CREATE_TOKEN, CardSpellDef.TargetType.SELF, {"replay_target": true, "free": true}),
	])
	_reg(&"reality_snap", "Reality Snap", "fast", 2, [
		_eff(CardSpellDef.EffectType.RETURN_TO_HAND, CardSpellDef.TargetType.ANY_UNIT, {}),
	], {"target_cost_max": 2})
	_reg(&"turnabout", "Turnabout", "fast", 5, [
		_eff(CardSpellDef.EffectType.CHANGE_CONTROL, CardSpellDef.TargetType.ENEMY_UNIT, {"duration": 1}),
	])
	_reg(&"well_laid_trap", "Well-Laid Trap", "fast", 2, [
		_eff(CardSpellDef.EffectType.TRIGGER_ON_DISCARD, CardSpellDef.TargetType.SELF, {"effect": "deal_damage", "amount": 2, "target": "enemy_nexus"}),
	])


# ==================== PRIVATE HELPERS ====================

func _reg(id: StringName, name: String, type: String, cost: int, effects: Array[Dictionary], condition: Dictionary = {}) -> void:
	var s := CardSpellDef.new()
	s.id = id
	s.display_name = name
	s.spell_type = type
	s.cost = cost
	s.effects = effects
	s.condition = condition
	_spells[id] = s

func _eff(action: int, target: int, params: Dictionary) -> Dictionary:
	return {"action": action, "target": target, "params": params}


# ==================== PUBLIC API ====================

func reset() -> void:
	_spells.clear()

func get_spell(id: StringName) -> CardSpellDef:
	ensure_definitions()
	return _spells.get(id, null)

func get_all() -> Array[CardSpellDef]:
	ensure_definitions()
	var result: Array[CardSpellDef] = []
	for id in _spells:
		result.append(_spells[id])
	return result

func get_by_type(type: String) -> Array[CardSpellDef]:
	ensure_definitions()
	var result: Array[CardSpellDef] = []
	for id in _spells:
		if _spells[id].spell_type == type:
			result.append(_spells[id])
	return result

func get_by_cost(cost: int) -> Array[CardSpellDef]:
	ensure_definitions()
	var result: Array[CardSpellDef] = []
	for id in _spells:
		if _spells[id].cost == cost:
			result.append(_spells[id])
	return result

func get_multi_effect() -> Array[CardSpellDef]:
	ensure_definitions()
	var result: Array[CardSpellDef] = []
	for id in _spells:
		if _spells[id].effects.size() > 1:
			result.append(_spells[id])
	return result

func get_conditional() -> Array[CardSpellDef]:
	ensure_definitions()
	var result: Array[CardSpellDef] = []
	for id in _spells:
		if not _spells[id].condition.is_empty():
			result.append(_spells[id])
	return result

func spell_count() -> int:
	return _spells.size()
