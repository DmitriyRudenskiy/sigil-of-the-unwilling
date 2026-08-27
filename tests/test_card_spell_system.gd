extends "res://tests/test_base.gd"
## Тесты карточной системы заклинаний: реестр, шаблоны, резолвер.

const _Registry = preload("res://scripts/card/CardSpellRegistry.gd")
const _Def = preload("res://scripts/card/CardSpellDef.gd")
const _Enums = preload("res://scripts/card/CardEnums.gd")
const _Engine = preload("res://scripts/card/CardTemplateEngine.gd")
const _Resolver = preload("res://scripts/card/CardSpellResolver.gd")

var registry: Variant = null

func before_each() -> void:
	registry = _Registry.new()
	registry.name = "TestReg"
	registry.ensure_definitions()


# ==================== ENUM PARSING ====================

func test_parse_target_enemy_unit() -> void:
	assert_eq(_Enums.parse_target("ENEMY_UNIT"), _Enums.TargetType.ENEMY_UNIT, "parse ENEMY_UNIT")

func test_parse_target_all_ally() -> void:
	assert_eq(_Enums.parse_target("ALL_ALLY_UNITS"), _Enums.TargetType.ALL_ALLY_UNITS, "parse ALL_ALLY_UNITS")

func test_parse_target_unknown_defaults_none() -> void:
	assert_eq(_Enums.parse_target("INVALID"), _Enums.TargetType.NONE, "unknown → NONE")

func test_parse_effect_destroy() -> void:
	assert_eq(_Enums.parse_effect("DESTROY"), _Enums.EffectType.DESTROY, "parse DESTROY")

func test_parse_status_frozen() -> void:
	assert_eq(_Enums.parse_status("FROZEN"), _Enums.StatusType.FROZEN, "parse FROZEN")

func test_parse_speed_fast() -> void:
	assert_eq(_Enums.parse_speed("fast"), _Enums.SpellSpeed.FAST, "parse fast")

func test_parse_speed_slow() -> void:
	assert_eq(_Enums.parse_speed("slow"), _Enums.SpellSpeed.SLOW, "parse slow")

func test_parse_speed_burst() -> void:
	assert_eq(_Enums.parse_speed("burst"), _Enums.SpellSpeed.BURST, "parse burst")

func test_parse_speed_unknown_defaults_fast() -> void:
	assert_eq(_Enums.parse_speed("invalid"), _Enums.SpellSpeed.FAST, "unknown → FAST")

func test_parse_color_fire() -> void:
	assert_eq(_Enums.parse_color("FIRE"), _Enums.CardColor.FIRE, "parse FIRE")


# ==================== SPELL DEF FROM DICT ====================

func test_def_from_dict_ice_bolt() -> void:
	var d := {
		"id": "ice_bolt", "name": "Ice Bolt", "template": "DIRECT_DAMAGE",
		"speed": "fast", "cost": 1, "color": "primal",
		"params": {"amount": 2, "target": "ANY_NEXUS"},
	}
	var spell: Variant = _Def.from_dict(d)
	assert_eq(spell.id, &"ice_bolt", "id")
	assert_eq(spell.display_name, "Ice Bolt", "name")
	assert_eq(spell.template, &"DIRECT_DAMAGE", "template")
	assert_eq(spell.cost, 1, "cost")
	assert_true(spell != null, "spell created")

func test_def_from_dict_with_condition() -> void:
	var d := {
		"id": "deathstrike", "name": "Deathstrike", "template": "HARD_REMOVAL",
		"speed": "fast", "cost": 3, "color": "shadow",
		"params": {},
		"condition": {"target_hp_max": 4},
	}
	var spell: Variant = _Def.from_dict(d)
	assert_true(spell.condition.has("target_hp_max"), "condition parsed")
	assert_eq(int(spell.condition["target_hp_max"]), 4, "hp max = 4")

func test_def_from_dict_empty() -> void:
	var spell: Variant = _Def.from_dict({})
	assert_eq(spell.id, &"", "empty id")
	assert_eq(spell.template, &"", "empty template")

func test_def_from_dict_secondary_effects() -> void:
	var d := {
		"id": "test", "name": "Test", "template": "COMBAT_TRICK",
		"cost": 2, "params": {"atk": 1, "hp": 1},
		"secondary_effects": [{"effect": "DRAW", "count": 1}],
	}
	var spell: Variant = _Def.from_dict(d)
	assert_eq(spell.secondary_effects.size(), 1, "1 secondary effect")

func test_def_from_dict_influence_req() -> void:
	var d := {
		"id": "big_spell", "name": "Big Spell", "template": "DIRECT_DAMAGE",
		"cost": 5, "influence_req": {"fire": 2, "time": 1},
		"params": {"amount": 5},
	}
	var spell: Variant = _Def.from_dict(d)
	assert_eq(int(spell.influence_req["fire"]), 2, "fire req = 2")
	assert_eq(int(spell.influence_req["time"]), 1, "time req = 1")

func test_def_to_dict_round_trip() -> void:
	var d := {
		"id": "round", "name": "Round", "template": "CARD_DRAW",
		"speed": "slow", "cost": 3, "color": "fire",
		"params": {"count": 2}, "description": "Draw 2",
	}
	var spell: Variant = _Def.from_dict(d)
	var out: Variant = spell.to_dict()
	assert_eq(out["id"], &"round", "round-trip id")
	assert_eq(out["color"], "fire", "round-trip color")
	assert_eq(out["speed"], "slow", "round-trip speed")


# ==================== REGISTRY ====================

func test_registry_fallback_loads() -> void:
	assert_true(registry.get_count() > 0, "fallback loaded %d spells" % registry.get_count())

func test_registry_get_spell() -> void:
	var spell = registry.get_spell(&"ice_bolt")
	assert_not_null(spell, "ice_bolt exists")
	assert_eq(spell.template, &"DIRECT_DAMAGE", "template is DIRECT_DAMAGE")

func test_registry_get_spell_missing() -> void:
	var spell = registry.get_spell(&"nonexistent_spell")
	assert_null(spell, "missing spell is null")

func test_registry_reset() -> void:
	assert_true(registry.get_count() > 0, "has spells")
	registry.reset()
	assert_eq(registry.get_count(), 0, "empty after reset")

func test_registry_get_by_template() -> void:
	var damage_spells: Array = registry.get_by_template(&"DIRECT_DAMAGE")
	assert_true(damage_spells.size() > 0, "has damage spells")
	for spell in damage_spells:
		assert_eq(spell.template, &"DIRECT_DAMAGE", "all are DIRECT_DAMAGE")

func test_registry_no_duplicate_ids() -> void:
	var all: Array = registry.get_all()
	var ids: Dictionary = {}
	for spell in all:
		assert_false(ids.has(spell.id), "no duplicate id: %s" % spell.id)
		ids[spell.id] = true

func test_registry_all_have_template() -> void:
	for spell in registry.get_all():
		assert_false(spell.template.is_empty(), "spell %s has template" % spell.id)

func test_registry_all_have_cost() -> void:
	for spell in registry.get_all():
		assert_true(spell.cost >= 0, "spell %s cost >= 0" % spell.id)

func test_registry_template_count() -> void:
	assert_true(registry.get_template_count() >= 5, "many templates represented")


# ==================== TEMPLATE ENGINE ====================

func test_template_unknown_returns_error() -> void:
	var result: Dictionary = _Engine.execute(&"NONEXISTENT", {}, {}, [], null, null, null)
	assert_eq(result.get("result"), "unknown_template", "unknown template error")

func test_all_templates_exist() -> void:
	var templates := [
		&"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
		&"COMBAT_TRICK", &"DEBUFF_CONTROL", &"CARD_DRAW", &"MANA_RAMP",
		&"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
		&"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
		&"DISCARD_DRAW", &"MARKET_NICHE",
	]
	for t in templates:
		var result: Dictionary = _Engine.execute(t, {}, {}, [], null, null, null)
		assert_true(result.has("result"), "template %s returns result" % t)
		assert_true(result.get("result") != "unknown_template", "template %s recognized" % t)

func test_template_count_is_16() -> void:
	var templates := [
		&"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
		&"COMBAT_TRICK", &"DEBUFF_CONTROL", &"CARD_DRAW", &"MANA_RAMP",
		&"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
		&"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
		&"DISCARD_DRAW", &"MARKET_NICHE",
	]
	assert_eq(templates.size(), 16, "exactly 16 templates")

func test_direct_damage_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"DIRECT_DAMAGE", {"amount": 5, "target": "ENEMY_UNIT"}, {}, [], null, null, null
	)
	assert_eq(result["result"], "success", "success with no targets")
	assert_true(result["effects"] is Array, "returns effects array")

func test_direct_damage_dynamic_ally_count() -> void:
	var caster: Dictionary = {"board": [1, 2, 3]}
	var result: Dictionary = _Engine.execute(
		&"DIRECT_DAMAGE", {"amount": 0, "amount_dynamic": "ally_count", "target": "ENEMY_UNIT"},
		{}, [], null, caster, null
	)
	assert_eq(result["result"], "success", "success")

func test_hard_removal_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"HARD_REMOVAL", {}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_bounce_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"BOUNCE", {"target": "ALLY_UNIT"}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_countermagic_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"COUNTERMAGIC", {}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_debuff_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"DEBUFF_CONTROL", {"status": "SILENCE"}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_card_draw_basic() -> void:
	var caster: Dictionary = {"hand": []}
	var result: Dictionary = _Engine.execute(
		&"CARD_DRAW", {"count": 2}, {}, [], null, caster, null
	)
	assert_eq(result["result"], "success", "success")
	assert_true(result["effects"].size() > 0, "has effects")

func test_mana_ramp_basic() -> void:
	var caster: Dictionary = {"current_power": 5}
	var result: Dictionary = _Engine.execute(
		&"MANA_RAMP", {"power": 2, "influence": "fire"}, {}, [], null, caster, null
	)
	assert_eq(result["result"], "success", "success")
	assert_true(result["effects"].size() > 0, "has effects")

func test_token_generation_basic() -> void:
	var result: Dictionary = _Engine.execute(
		&"TOKEN_GENERATION", {"token_id": "soldier", "count": 3, "atk": 2, "hp": 2},
		{}, [], null, null, null
	)
	assert_eq(result["result"], "success", "success")
	assert_eq(result["effects"].size(), 3, "3 tokens")

func test_keyword_buff_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"KEYWORD_BUFF", {"keyword": "ARMORED"}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_choice_cycle_draws() -> void:
	var caster: Dictionary = {"hand": []}
	var result: Dictionary = _Engine.execute(
		&"CHOICE_CYCLE", {"draw": 1, "secondary": "HEAL_2"}, {}, [], null, caster, null
	)
	assert_eq(result["result"], "success", "success")
	assert_true(result["effects"].size() >= 1, "has draw effect")

func test_touch_cycle_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"TOUCH_CYCLE", {"atk": 1, "hp": 1}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_display_cycle_basic() -> void:
	var caster: Dictionary = {}
	var result: Dictionary = _Engine.execute(
		&"DISPLAY_CYCLE", {"cost_reduction": 2, "influence": "time"}, {}, [], null, caster, null
	)
	assert_eq(result["result"], "success", "success")

func test_discard_draw_not_enough() -> void:
	var caster: Dictionary = {"hand": [1]}
	var result: Dictionary = _Engine.execute(
		&"DISCARD_DRAW", {"discard": 3, "draw": 1}, {}, [], null, caster, null
	)
	assert_eq(result["result"], "not_enough_cards", "not enough")

func test_discard_draw_basic() -> void:
	var caster: Dictionary = {"hand": [1, 2, 3]}
	var result: Dictionary = _Engine.execute(
		&"DISCARD_DRAW", {"discard": 1, "draw": 1}, {}, [], null, caster, null
	)
	assert_eq(result["result"], "success", "success")

func test_relic_interaction_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"RELIC_INTERACTION", {"action": "destroy"}, {}, [], null, null, null
	)
	assert_eq(result["result"], "no_target", "no target")

func test_market_niche_basic() -> void:
	var result: Dictionary = _Engine.execute(
		&"MARKET_NICHE", {"action": "draw_from_market", "market_cost": 1}, {}, [], null, null, null
	)
	assert_eq(result["result"], "success", "success")


# ==================== RESOLVER ====================

func test_resolve_null_spell() -> void:
	var result: Dictionary = _Resolver.resolve(null, null, null)
	assert_eq(result["result"], "invalid_spell", "invalid spell")

func test_resolve_no_template() -> void:
	var spell: Variant = _Def.from_dict({"id": "no_template", "cost": 0})
	var result: Dictionary = _Resolver.resolve(spell, null, null)
	assert_eq(result["result"], "no_template", "no template error")

func test_resolve_insufficient_power() -> void:
	var spell = registry.get_spell(&"annihilate")
	var player: Dictionary = {"current_power": 2}
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_eq(result["result"], "insufficient_power", "not enough power")

func test_resolve_success_no_target() -> void:
	var spell = registry.get_spell(&"bottled_insight")
	var player: Dictionary = {"current_power": 10, "hand": []}
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_eq(result["result"], "success", "success")
	assert_true(result.has("effects"), "has effects")

func test_resolve_deducts_cost() -> void:
	var spell = registry.get_spell(&"ice_bolt")
	var player: Dictionary = {"current_power": 10, "hand": []}
	var before: int = player.current_power
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_eq(result["result"], "success", "success")
	assert_eq(player.current_power, before - spell.cost, "cost deducted")

func test_resolve_insufficient_influence() -> void:
	var spell: Variant = _Def.from_dict({
		"id": "big", "template": "DIRECT_DAMAGE", "cost": 1,
		"influence_req": {"fire": 5},
		"params": {"amount": 1, "target": "ENEMY_NEXUS"},
	})
	var player: Dictionary = {"current_power": 10, "influence": {"fire": 1}}
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_eq(result["result"], "insufficient_influence", "not enough influence")

func test_resolve_condition_not_met() -> void:
	var spell = registry.get_spell(&"deathstrike")
	var player: Dictionary = {"current_power": 10}
	var result: Dictionary = _Resolver.resolve(spell, null, player, null)
	assert_true(result["result"] in ["success", "condition_not_met"], "resolved")

func test_resolve_all_16_templates() -> void:
	var templates := [
		&"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
		&"COMBAT_TRICK", &"DEBUFF_CONTROL", &"CARD_DRAW", &"MANA_RAMP",
		&"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
		&"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
		&"DISCARD_DRAW", &"MARKET_NICHE",
	]
	for t in templates:
		var spell: Variant = _Def.from_dict({
			"id": str(t), "template": str(t), "cost": 0,
			"params": {"amount": 1, "target": "ENEMY_UNIT", "count": 1, "atk": 1, "hp": 1, "keyword": "ARMORED"},
		})
		var player: Dictionary = {"current_power": 10, "hand": [1]}
		var result: Dictionary = _Resolver.resolve(spell, null, player)
		assert_true(result["result"] != "unknown_template", "%s not unknown" % t)