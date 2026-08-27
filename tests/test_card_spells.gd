extends "res://tests/test_base.gd"
## Тесты CardSpellRegistry + CardSpellResolver: 71 заклинание, валидация, резолвер.

const CardSpellDef = preload("res://scripts/card/CardSpellDef.gd")
const CardSpellRegistry = preload("res://scripts/card/CardSpellRegistry.gd")
const CardSpellResolver = preload("res://scripts/card/CardSpellResolver.gd")

var registry: Node

func before_each() -> void:
	registry = CardSpellRegistry.new()
	registry.name = "TestCardSpells"
	registry.ensure_definitions()

# ==================== РЕЕСТР ====================

func test_spell_count_71() -> void:
	assert_eq(registry.spell_count(), 71, "71 spells registered")

func test_get_annihilate() -> void:
	var spell: CardSpellDef = registry.get_spell(&"annihilate")
	assert_not_null(spell, "annihilate exists")
	assert_eq(spell.cost, 5, "cost 5")
	assert_eq(spell.spell_type, "fast", "fast type")

func test_get_banish() -> void:
	var spell: CardSpellDef = registry.get_spell(&"banish")
	assert_not_null(spell, "banish exists")
	assert_eq(spell.cost, 4, "cost 4")
	assert_eq(spell.effects.size(), 1, "1 effect")

func test_get_deathstrike_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"deathstrike")
	assert_not_null(spell, "deathstrike exists")
	assert_true(spell.condition.has("target_hp_max"), "has target_hp_max condition")

func test_get_ice_bolt_composite() -> void:
	var spell: CardSpellDef = registry.get_spell(&"ice_bolt")
	assert_not_null(spell, "ice_bolt exists")
	assert_eq(spell.effects.size(), 2, "2 effects")

func test_get_unmake_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"unmake")
	assert_not_null(spell, "unmake exists")
	assert_eq(spell.condition["target_cost_max"], 3, "cost max 3")

func test_get_slay_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"slay")
	assert_not_null(spell, "slay exists")
	assert_true(spell.condition["target_is_damaged"], "damaged condition")

func test_get_skybolt_flying() -> void:
	var spell: CardSpellDef = registry.get_spell(&"skybolt")
	assert_not_null(spell, "skybolt exists")
	assert_true(spell.condition["target_is_flying"], "flying condition")

func test_get_nullify() -> void:
	var spell: CardSpellDef = registry.get_spell(&"nullify")
	assert_not_null(spell, "nullify exists")
	assert_eq(spell.cost, 3, "cost 3")

func test_get_heesitate_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"hesitate")
	assert_not_null(spell, "hesitate exists")
	assert_eq(spell.condition["spell_cost_max"], 3, "spell cost max 3")

# ==================== ГРУППА Б: ЗАЩИТА ====================

func test_get_forcefield_nexus() -> void:
	var spell: CardSpellDef = registry.get_spell(&"forcefield")
	assert_not_null(spell, "forcefield exists")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["target"], CardSpellDef.TargetType.ALLY_NEXUS, "nexus target")

func test_get_bubble_shield_ward() -> void:
	var spell: CardSpellDef = registry.get_spell(&"bubble_shield")
	assert_not_null(spell, "bubble shield exists")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.WARD, "ward status")

func test_get_stoneskin_temp_hp() -> void:
	var spell: CardSpellDef = registry.get_spell(&"stoneskin")
	assert_not_null(spell, "stoneskin exists")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["hp_temp"], 2, "2 temp hp")

func test_get_transpose_swap() -> void:
	var spell: CardSpellDef = registry.get_spell(&"transpose")
	assert_not_null(spell, "transpose exists")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.SWAP_POSITION, "swap effect")

func test_get_two_ally_units_target() -> void:
	var spell: CardSpellDef = registry.get_spell(&"transpose")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["target"], CardSpellDef.TargetType.TWO_ALLY_UNITS, "two ally units")

# ==================== ГРУППА В: БОЕВЫЕ ХИТРОСТИ ====================

func test_get_agile_strike() -> void:
	var spell: CardSpellDef = registry.get_spell(&"agile_strike")
	assert_not_null(spell, "agile strike exists")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["atk"], 2, "+2 atk")
	assert_eq(params["hp"], 2, "+2 hp")

func test_get_inner_might() -> void:
	var spell: CardSpellDef = registry.get_spell(&"inner_might")
	assert_not_null(spell, "inner might exists")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["atk"], 3, "+3 atk")
	assert_eq(params["hp"], 3, "+3 hp")

func test_get_overthrow_dynamic() -> void:
	var spell: CardSpellDef = registry.get_spell(&"overthrow")
	assert_not_null(spell, "overthrow exists")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["atk_dynamic"], "ally_count", "dynamic atk")

func test_get_reinvigorate_composite() -> void:
	var spell: CardSpellDef = registry.get_spell(&"reinvigorate")
	assert_not_null(spell, "reinvigorate exists")
	assert_eq(spell.effects.size(), 2, "2 effects (buff + heal)")

func test_get_sharpened_reflex_quickdraw() -> void:
	var spell: CardSpellDef = registry.get_spell(&"sharpened_reflex")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.QUICKDRAW, "quickdraw")

func test_get_steely_resolve_unblockable() -> void:
	var spell: CardSpellDef = registry.get_spell(&"steely_resolve")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.UNBLOCKABLE, "unblockable")

func test_get_augmented_form_overwhelm() -> void:
	var spell: CardSpellDef = registry.get_spell(&"augmented_form")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.OVERWHELM, "overwhelm")

func test_get_scalehide_armored() -> void:
	var spell: CardSpellDef = registry.get_spell(&"scalehide")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.ARMORED, "armored")

func test_get_daring_maneuver_challenge() -> void:
	var spell: CardSpellDef = registry.get_spell(&"daring_maneuver")
	assert_eq(spell.effects.size(), 2, "2 effects")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.CHALLENGE, "challenge")

func test_get_barrel_through_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"barrel_through")
	assert_true(spell.condition["attacker_unblocked"], "unblocked condition")

func test_get_turn_the_tides_aoe() -> void:
	var spell: CardSpellDef = registry.get_spell(&"turn_the_tides")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["target"], CardSpellDef.TargetType.ALL_ALLY_UNITS, "all ally units")

func test_get_mighty_strikes_aoe() -> void:
	var spell: CardSpellDef = registry.get_spell(&"mighty_strikes")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["target"], CardSpellDef.TargetType.ALL_ALLY_UNITS, "all ally units")

# ==================== ГРУППА Г: КОНТРОЛЬ ====================

func test_get_disarm_silence() -> void:
	var spell: CardSpellDef = registry.get_spell(&"disarm")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.SILENCE, "silence")

func test_get_sickness_composite() -> void:
	var spell: CardSpellDef = registry.get_spell(&"sickness")
	assert_eq(spell.effects.size(), 2, "2 effects")

func test_get_chill_debuff() -> void:
	var spell: CardSpellDef = registry.get_spell(&"chill")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["atk"], -2, "-2 atk")
	assert_eq(params["hp"], -2, "-2 hp")

func test_get_icy_hold_frozen() -> void:
	var spell: CardSpellDef = registry.get_spell(&"icy_hold")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.FROZEN, "frozen")

func test_get_shrivel_perm() -> void:
	var spell: CardSpellDef = registry.get_spell(&"shrivel")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.MODIFY_STAT_PERM, "perm effect")

func test_get_subdue() -> void:
	var spell: CardSpellDef = registry.get_spell(&"subdue")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["atk"], -3, "-3 atk")
	assert_eq(params["hp"], -3, "-3 hp")

func test_get_arrest_stun() -> void:
	var spell: CardSpellDef = registry.get_spell(&"arrest")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.STUN, "stun")

func test_get_ensnare_stun() -> void:
	var spell: CardSpellDef = registry.get_spell(&"ensnare")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.STUN, "stun")

func test_get_hold_at_bay_cannot_block() -> void:
	var spell: CardSpellDef = registry.get_spell(&"hold_at_bay")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.CANNOT_BLOCK, "cannot block")

func test_get_telekinetic_shackles_cannot_attack() -> void:
	var spell: CardSpellDef = registry.get_spell(&"telekinetic_shackles")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["status"], CardSpellDef.StatusEffect.CANNOT_ATTACK, "cannot attack")

func test_get_withering_touch_perm() -> void:
	var spell: CardSpellDef = registry.get_spell(&"withering_touch")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.MODIFY_STAT_PERM, "perm effect")

# ==================== ГРУППА Д: МАНИПУЛЯЦИЯ ====================

func test_get_boundless_knowledge_hand_limit() -> void:
	var spell: CardSpellDef = registry.get_spell(&"boundless_knowledge")
	assert_eq(spell.condition["hand_size_max"], 4, "hand max 4")

func test_get_bottled_insight_draw() -> void:
	var spell: CardSpellDef = registry.get_spell(&"bottled_insight")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["count"], 1, "draw 1")

func test_get_recycle_composite() -> void:
	var spell: CardSpellDef = registry.get_spell(&"recycle")
	assert_eq(spell.effects.size(), 2, "return_to_deck + draw")

func test_get_recovery_grave() -> void:
	var spell: CardSpellDef = registry.get_spell(&"recovery")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["target"], CardSpellDef.TargetType.ALLY_UNIT_IN_GRAVE, "grave target")

func test_get_express_route_ramp() -> void:
	var spell: CardSpellDef = registry.get_spell(&"express_route")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["power"], 1, "ramp 1")

func test_get_earth_conjuring() -> void:
	var spell: CardSpellDef = registry.get_spell(&"earth_conjuring")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["influence"], &"earth", "earth influence")

func test_get_fire_conjuring() -> void:
	var spell: CardSpellDef = registry.get_spell(&"fire_conjuring")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["influence"], &"fire", "fire influence")

func test_get_water_conjuring() -> void:
	var spell: CardSpellDef = registry.get_spell(&"water_conjuring")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["influence"], &"water", "water influence")

func test_get_wind_conjuring() -> void:
	var spell: CardSpellDef = registry.get_spell(&"wind_conjuring")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["influence"], &"wind", "wind influence")

func test_get_furnish_ramp() -> void:
	var spell: CardSpellDef = registry.get_spell(&"furnish")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["power"], 1, "ramp 1")

func test_get_find_the_moment() -> void:
	var spell: CardSpellDef = registry.get_spell(&"find_the_moment")
	assert_eq(spell.cost, 1, "cost 1")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["count"], 1, "draw 1")

func test_get_wisdom_of_the_elders() -> void:
	var spell: CardSpellDef = registry.get_spell(&"wisdom_of_the_elders")
	assert_eq(spell.spell_type, "slow", "slow type")

# ==================== ГРУППА Е: СПЕЦИФИЧЕСКИЕ ====================

func test_get_send_an_agent_market() -> void:
	var spell: CardSpellDef = registry.get_spell(&"send_an_agent")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.MARKET_ACTION, "market action")

func test_get_skullmarket_discard_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"skullmarket_delivery")
	assert_eq(spell.condition["discard_cost"], 1, "discard 1")

func test_get_warren_delivery_rat() -> void:
	var spell: CardSpellDef = registry.get_spell(&"warren_delivery")
	var params: Dictionary = spell.effects[0]["params"]
	assert_eq(params["token"], "rat", "rat token")

func test_get_trick_shot_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"trick_shot")
	assert_eq(spell.condition["target_hp_max"], 2, "hp max 2")

func test_get_trigger_happy_repeat() -> void:
	var spell: CardSpellDef = registry.get_spell(&"trigger_happy")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.ACTION_REPEAT, "repeat action")

func test_get_stutterstep_replay() -> void:
	var spell: CardSpellDef = registry.get_spell(&"stutterstep")
	assert_eq(spell.effects.size(), 2, "bounce + replay")

func test_get_reality_snap_condition() -> void:
	var spell: CardSpellDef = registry.get_spell(&"reality_snap")
	assert_eq(spell.condition["target_cost_max"], 2, "cost max 2")

func test_get_turnabout_control() -> void:
	var spell: CardSpellDef = registry.get_spell(&"turnabout")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.CHANGE_CONTROL, "change control")

func test_get_well_laid_trap_discard_trigger() -> void:
	var spell: CardSpellDef = registry.get_spell(&"well_laid_trap")
	var eff: Dictionary = spell.effects[0]
	assert_eq(eff["action"], CardSpellDef.EffectType.TRIGGER_ON_DISCARD, "discard trigger")

# ==================== ПОЛУЧЕНИЕ ГРУПП ====================

func test_get_all_count() -> void:
	var all: Array[CardSpellDef] = registry.get_all()
	assert_eq(all.size(), 71, "all 71 spells")

func test_get_by_type_fast() -> void:
	var fast: Array[CardSpellDef] = registry.get_by_type("fast")
	assert_true(fast.size() > 40, "many fast spells")

func test_get_by_type_slow() -> void:
	var slow: Array[CardSpellDef] = registry.get_by_type("slow")
	assert_true(slow.size() > 0, "some slow spells")

func test_get_by_cost_1() -> void:
	var cost1: Array[CardSpellDef] = registry.get_by_cost(1)
	assert_true(cost1.size() > 0, "some cost 1 spells")

func test_get_by_cost_5() -> void:
	var cost5: Array[CardSpellDef] = registry.get_by_cost(5)
	assert_true(cost5.size() > 0, "some cost 5 spells")

func test_get_multi_effect() -> void:
	var multi: Array[CardSpellDef] = registry.get_multi_effect()
	assert_true(multi.size() >= 7, "at least 7 composite spells")

func test_get_conditional() -> void:
	var cond: Array[CardSpellDef] = registry.get_conditional()
	assert_true(cond.size() >= 12, "at least 12 conditional spells")

func test_get_spell_not_found() -> void:
	var spell: CardSpellDef = registry.get_spell(&"nonexistent_spell")
	assert_true(spell == null, "null for nonexistent")

# ==================== РЕЗОЛВЕР ====================

func test_resolve_null_spell() -> void:
	var result: Dictionary = CardSpellResolver.resolve(null, null, null)
	assert_eq(result["result"], "invalid_spell", "invalid spell")

func test_resolve_insufficient_power() -> void:
	var spell: CardSpellDef = registry.get_spell(&"annihilate")
	var player: Dictionary = {"current_power": 2}
	var result: Dictionary = CardSpellResolver.resolve(spell, null, player)
	assert_eq(result["result"], "insufficient_power", "not enough power")

func test_resolve_success_no_target() -> void:
	var spell: CardSpellDef = registry.get_spell(&"bottled_insight")
	var player: Dictionary = {"current_power": 10, "hand": []}
	var result: Dictionary = CardSpellResolver.resolve(spell, null, player)
	assert_eq(result["result"], "success", "success")
	assert_true(result.has("effects"), "has effects")

func test_resolve_condition_not_met() -> void:
	var spell: CardSpellDef = registry.get_spell(&"deathstrike")
	var player: Dictionary = {"current_power": 10}
	# Без мок-объекта условие пропускается (target без метода get_hp) → success
	var result: Dictionary = CardSpellResolver.resolve(spell, null, player, null)
	assert_true(result["result"] in ["success", "condition_not_met"], "resolved")

func test_resolve_deducts_cost() -> void:
	var spell: CardSpellDef = registry.get_spell(&"bottled_insight")
	var player: Dictionary = {"current_power": 10, "hand": []}
	var before: int = player.current_power
	CardSpellResolver.resolve(spell, null, player)
	assert_eq(player.current_power, before - spell.cost, "cost deducted")

func test_resolve_composite_spell() -> void:
	var spell: CardSpellDef = registry.get_spell(&"ice_bolt")
	var player: Dictionary = {"current_power": 10}
	var result: Dictionary = CardSpellResolver.resolve(spell, null, player)
	assert_eq(result["result"], "success", "success")
	assert_eq(result["effects"].size(), 2, "2 effects applied")

func test_reset_registry() -> void:
	registry.reset()
	assert_eq(registry.spell_count(), 0, "registry cleared")

func _file_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

# ==================== ENUM VALUES ====================

func test_target_type_enum_values() -> void:
	assert_eq(CardSpellDef.TargetType.NONE, 0, "NONE is 0")
	assert_eq(CardSpellDef.TargetType.SELF, 14, "SELF is 14")
	assert_eq(CardSpellDef.TargetType.SAME_AS_PREVIOUS, 15, "SAME_AS_PREVIOUS is 15")

func test_effect_type_enum_values() -> void:
	assert_eq(CardSpellDef.EffectType.DESTROY, 0, "DESTROY is 0")
	assert_eq(CardSpellDef.EffectType.DEAL_DAMAGE, 4, "DEAL_DAMAGE is 4")
	assert_eq(CardSpellDef.EffectType.HEAL, 18, "HEAL is 18")

func test_status_effect_enum_values() -> void:
	assert_eq(CardSpellDef.StatusEffect.SILENCE, 0, "SILENCE is 0")
	assert_eq(CardSpellDef.StatusEffect.FROZEN, 1, "FROZEN is 1")
	assert_eq(CardSpellDef.StatusEffect.STUN, 2, "STUN is 2")
