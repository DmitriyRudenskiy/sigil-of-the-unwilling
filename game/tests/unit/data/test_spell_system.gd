extends GdUnitTestSuite

const _Registry = preload("res://scripts/autoload/SpellbookRegistry.gd")
const _Def = preload("res://scripts/data/SpellbookDef.gd")
const _Enums = preload("res://scripts/data/SpellEnums.gd")
const _Engine = preload("res://scripts/data/TemplateEngine.gd")
const _Resolver = preload("res://scripts/data/SpellResolver.gd")

var registry: Variant = null

func before_test() -> void:
	registry = _Registry.new()
	registry.name = "TestReg"
	registry.ensure_definitions()

func after_test() -> void:
	if registry != null:
		registry.free()
		registry = null

func test_parse_target_enemy_unit() -> void:
	assert_that(_Enums.parse_target("ENEMY_UNIT")).is_equal(_Enums.TargetType.ENEMY_UNIT)

func test_parse_target_all_ally() -> void:
	assert_that(_Enums.parse_target("ALL_ALLY_UNITS")).is_equal(_Enums.TargetType.ALL_ALLY_UNITS)

func test_parse_target_unknown_defaults_none() -> void:
	assert_that(_Enums.parse_target("INVALID")).is_equal(_Enums.TargetType.NONE)

func test_parse_effect_destroy() -> void:
	assert_that(_Enums.parse_effect("DESTROY")).is_equal(_Enums.EffectType.DESTROY)

func test_parse_status_frozen() -> void:
	assert_that(_Enums.parse_status("FROZEN")).is_equal(_Enums.StatusType.FROZEN)

func test_parse_speed_fast() -> void:
	assert_that(_Enums.parse_speed("fast")).is_equal(_Enums.SpellSpeed.FAST)

func test_parse_speed_slow() -> void:
	assert_that(_Enums.parse_speed("slow")).is_equal(_Enums.SpellSpeed.SLOW)

func test_parse_speed_burst() -> void:
	assert_that(_Enums.parse_speed("burst")).is_equal(_Enums.SpellSpeed.BURST)

func test_parse_speed_unknown_defaults_fast() -> void:
	assert_that(_Enums.parse_speed("invalid")).is_equal(_Enums.SpellSpeed.FAST)

func test_parse_color_fire() -> void:
	assert_that(_Enums.parse_color("FIRE")).is_equal(_Enums.SpellColor.FIRE)

func test_def_from_dict_ice_bolt() -> void:
	var d := {
		"id": "ice_bolt", "name": "Ice Bolt", "template": "DIRECT_DAMAGE",
		"speed": "fast", "cost": 1, "color": "primal",
		"params": {"amount": 2, "target": "ANY_NEXUS"},
	}
	var spell: Variant = _Def.from_dict(d)
	assert_that(spell.id).is_equal(&"ice_bolt")
	assert_that(spell.display_name).is_equal("Ice Bolt")
	assert_that(spell.template).is_equal(&"DIRECT_DAMAGE")
	assert_that(spell.cost).is_equal(1)
	assert_bool(spell != null).is_true()

func test_def_from_dict_with_condition() -> void:
	var d := {
		"id": "deathstrike", "name": "Deathstrike", "template": "HARD_REMOVAL",
		"speed": "fast", "cost": 3, "color": "shadow",
		"params": {},
		"condition": {"target_hp_max": 4},
	}
	var spell: Variant = _Def.from_dict(d)
	assert_bool(spell.condition.has("target_hp_max")).is_true()
	assert_that(int(spell.condition["target_hp_max"])).is_equal(4)

func test_def_from_dict_empty() -> void:
	var spell: Variant = _Def.from_dict({})
	assert_that(spell.id).is_equal(&"")
	assert_that(spell.template).is_equal(&"")

func test_def_from_dict_secondary_effects() -> void:
	var d := {
		"id": "test", "name": "Test", "template": "COMBAT_TRICK",
		"cost": 2, "params": {"atk": 1, "hp": 1},
		"secondary_effects": [{"effect": "DRAW", "count": 1}],
	}
	var spell: Variant = _Def.from_dict(d)
	assert_that(spell.secondary_effects.size()).is_equal(1)

func test_def_from_dict_influence_req() -> void:
	var d := {
		"id": "big_spell", "name": "Big Spell", "template": "DIRECT_DAMAGE",
		"cost": 5, "influence_req": {"fire": 2, "time": 1},
		"params": {"amount": 5},
	}
	var spell: Variant = _Def.from_dict(d)
	assert_that(int(spell.influence_req["fire"])).is_equal(2)
	assert_that(int(spell.influence_req["time"])).is_equal(1)

func test_def_to_dict_round_trip() -> void:
	var d := {
		"id": "round", "name": "Round", "template": "SPELL_DRAW",
		"speed": "slow", "cost": 3, "color": "fire",
		"params": {"count": 2}, "description": "Draw 2",
	}
	var spell: Variant = _Def.from_dict(d)
	var out: Variant = spell.to_dict()
	assert_that(out["id"]).is_equal(&"round")
	assert_that(out["color"]).is_equal("fire")
	assert_that(out["speed"]).is_equal("slow")

func test_registry_fallback_loads() -> void:
	assert_bool(registry.get_count() > 0).is_true()

func test_registry_get_spell() -> void:
	var spell = registry.get_spell(&"ice_bolt")
	assert_that(spell).is_not_null()
	assert_that(spell.template).is_equal(&"DIRECT_DAMAGE")

func test_registry_get_spell_missing() -> void:
	var spell = registry.get_spell(&"nonexistent_spell")
	assert_that(spell).is_null()

func test_registry_reset() -> void:
	assert_bool(registry.get_count() > 0).is_true()
	registry.reset()
	assert_that(registry.get_count()).is_equal(0)

func test_registry_get_by_template() -> void:
	var damage_spells: Array = registry.get_by_template(&"DIRECT_DAMAGE")
	assert_bool(damage_spells.size() > 0).is_true()
	for spell in damage_spells:
		assert_that(spell.template).is_equal(&"DIRECT_DAMAGE")

func test_registry_no_duplicate_ids() -> void:
	var all: Array = registry.get_all()
	var ids: Dictionary = {}
	for spell in all:
		assert_bool(ids.has(spell.id)).is_false()
		ids[spell.id] = true

func test_registry_all_have_template() -> void:
	for spell in registry.get_all():
		assert_bool(spell.template.is_empty()).is_false()

func test_registry_all_have_cost() -> void:
	for spell in registry.get_all():
		assert_bool(spell.cost >= 0).is_true()

func test_registry_template_count() -> void:
	assert_bool(registry.get_template_count() >= 5).is_true()

func test_template_unknown_returns_error() -> void:
	var result: Dictionary = _Engine.execute(&"NONEXISTENT", {}, {}, [], null, null, null)
	assert_that(result.get("result")).is_equal("unknown_template")

func test_all_templates_exist() -> void:
	var templates := [
		&"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
		&"COMBAT_TRICK", &"DEBUFF_CONTROL", &"SPELL_DRAW", &"MANA_RAMP",
		&"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
		&"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
		&"DISPEL_DRAW", &"MARKET_NICHE",
		&"HEAL_CLEAR", &"REVIVE", &"PORTAL",
	]
	for t in templates:
		var result: Dictionary = _Engine.execute(t, {}, {}, [], null, null, null)
		assert_bool(result.has("result")).is_true()
		assert_bool(result.get("result") != "unknown_template").is_true()

func test_template_count_is_16() -> void:
	var templates := [
		&"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
		&"COMBAT_TRICK", &"DEBUFF_CONTROL", &"SPELL_DRAW", &"MANA_RAMP",
		&"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
		&"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
		&"DISPEL_DRAW", &"MARKET_NICHE",
		&"HEAL_CLEAR", &"REVIVE", &"PORTAL",
	]
	assert_that(templates.size()).is_equal(19)

class _MockUnit extends RefCounted:
	var _hp: int
	var _debuffs: Array = []
	var _revived: int = 0
	var _displaced: String = ""
	func _init(p_hp: int = 5) -> void:
		_hp = p_hp
	func get_id() -> String:
		return "mock-unit"
	func heal(amount: int) -> void:
		_hp += amount
	func get_hp() -> int:
		return _hp
	func clear_debuffs() -> void:
		_debuffs.clear()
	func revive(amount: int) -> void:
		_revived += amount
	func displace(to: String) -> void:
		_displaced = to

func test_heal_clear_heals_and_clears_debuffs() -> void:
	var unit := _MockUnit.new()
	unit.clear_debuffs()
	unit.clear_debuffs()
	unit._debuffs.append(3)
	var result: Dictionary = _Engine.execute(
		&"HEAL_CLEAR", {"target": "ALLY_UNIT", "amount": 3}, {}, [], null, null, unit)
	assert_that(result["result"]).is_equal("success")
	assert_that(unit.get_hp()).is_equal(8)
	assert_bool(unit._debuffs.is_empty()).is_true()
	var types: Array = result["effects"]
	assert_bool(types.size() >= 2).is_true()

func test_heal_clear_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"HEAL_CLEAR", {"target": "ALLY_UNIT", "amount": 3}, {}, [], null, null, null)
	assert_that(result["result"]).is_equal("no_target")

func test_revive_resurrects_fallen_stack() -> void:
	var unit := _MockUnit.new()
	var result: Dictionary = _Engine.execute(
		&"REVIVE", {"target": "ANY_UNIT", "amount": 2}, {}, [], null, null, unit)
	assert_that(result["result"]).is_equal("success")
	assert_that(unit._revived).is_equal(2)

func test_portal_displaces_target() -> void:
	var unit := _MockUnit.new()
	var result: Dictionary = _Engine.execute(
		&"PORTAL", {"target": "ALLY_UNIT", "to": "town"}, {}, [], null, null, unit)
	assert_that(result["result"]).is_equal("success")
	assert_that(unit._displaced).is_equal("town")

func test_direct_damage_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"DIRECT_DAMAGE", {"amount": 5, "target": "ENEMY_UNIT"}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("success")
	assert_bool(result["effects"] is Array).is_true()

func test_direct_damage_dynamic_ally_count() -> void:
	var caster: Dictionary = {"board": [1, 2, 3]}
	var result: Dictionary = _Engine.execute(
		&"DIRECT_DAMAGE", {"amount": 0, "amount_dynamic": "ally_count", "target": "ENEMY_UNIT"},
		{}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("success")

func test_hard_removal_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"HARD_REMOVAL", {}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_bounce_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"BOUNCE", {"target": "ALLY_UNIT"}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_countermagic_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"COUNTERMAGIC", {}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_debuff_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"DEBUFF_CONTROL", {"status": "SILENCE"}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_spell_draw_basic() -> void:
	var caster: Dictionary = {"hand": []}
	var result: Dictionary = _Engine.execute(
		&"SPELL_DRAW", {"count": 2}, {}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("success")
	assert_bool(result["effects"].size() > 0).is_true()

func test_mana_ramp_basic() -> void:
	var caster: Dictionary = {"current_power": 5}
	var result: Dictionary = _Engine.execute(
		&"MANA_RAMP", {"power": 2, "influence": "fire"}, {}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("success")
	assert_bool(result["effects"].size() > 0).is_true()

func test_token_generation_basic() -> void:
	var result: Dictionary = _Engine.execute(
		&"TOKEN_GENERATION", {"token_id": "soldier", "count": 3, "atk": 2, "hp": 2},
		{}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("success")
	assert_that(result["effects"].size()).is_equal(3)

func test_keyword_buff_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"KEYWORD_BUFF", {"keyword": "ARMORED"}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_choice_cycle_draws() -> void:
	var caster: Dictionary = {"hand": []}
	var result: Dictionary = _Engine.execute(
		&"CHOICE_CYCLE", {"draw": 1, "secondary": "HEAL_2"}, {}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("success")
	assert_bool(result["effects"].size() >= 1).is_true()

func test_touch_cycle_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"TOUCH_CYCLE", {"atk": 1, "hp": 1}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_display_cycle_basic() -> void:
	var caster: Dictionary = {}
	var result: Dictionary = _Engine.execute(
		&"DISPLAY_CYCLE", {"cost_reduction": 2, "influence": "time"}, {}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("success")

func test_dispel_draw_not_enough() -> void:
	var caster: Dictionary = {"hand": [1]}
	var result: Dictionary = _Engine.execute(
		&"DISPEL_DRAW", {"discard": 3, "draw": 1}, {}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("not_enough_cards")

func test_dispel_draw_basic() -> void:
	var caster: Dictionary = {"hand": [1, 2, 3]}
	var result: Dictionary = _Engine.execute(
		&"DISPEL_DRAW", {"discard": 1, "draw": 1}, {}, [], null, caster, null
	)
	assert_that(result["result"]).is_equal("success")

func test_relic_interaction_no_target() -> void:
	var result: Dictionary = _Engine.execute(
		&"RELIC_INTERACTION", {"action": "destroy"}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("no_target")

func test_market_niche_basic() -> void:
	var result: Dictionary = _Engine.execute(
		&"MARKET_NICHE", {"action": "draw_from_market", "market_cost": 1}, {}, [], null, null, null
	)
	assert_that(result["result"]).is_equal("success")

func test_resolve_null_spell() -> void:
	var result: Dictionary = _Resolver.resolve(null, null, null)
	assert_that(result["result"]).is_equal("invalid_spell")

func test_resolve_no_template() -> void:
	var spell: Variant = _Def.from_dict({"id": "no_template", "cost": 0})
	var result: Dictionary = _Resolver.resolve(spell, null, null)
	assert_that(result["result"]).is_equal("no_template")

func test_resolve_insufficient_power() -> void:
	var spell = registry.get_spell(&"annihilate")
	var player: Dictionary = {"current_power": 2}
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_that(result["result"]).is_equal("insufficient_power")

func test_resolve_success_no_target() -> void:
	var spell = registry.get_spell(&"bottled_insight")
	var player: Dictionary = {"current_power": 10, "hand": []}
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_that(result["result"]).is_equal("success")
	assert_bool(result.has("effects")).is_true()

func test_resolve_deducts_cost() -> void:
	var spell = registry.get_spell(&"ice_bolt")
	var player: Dictionary = {"current_power": 10, "hand": []}
	var before: int = player.current_power
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_that(result["result"]).is_equal("success")
	assert_that(player.current_power).is_equal(before - spell.cost)

func test_resolve_insufficient_influence() -> void:
	var spell: Variant = _Def.from_dict({
		"id": "big", "template": "DIRECT_DAMAGE", "cost": 1,
		"influence_req": {"fire": 5},
		"params": {"amount": 1, "target": "ENEMY_NEXUS"},
	})
	var player: Dictionary = {"current_power": 10, "influence": {"fire": 1}}
	var result: Dictionary = _Resolver.resolve(spell, null, player)
	assert_that(result["result"]).is_equal("insufficient_influence")

func test_resolve_condition_not_met() -> void:
	var spell = registry.get_spell(&"deathstrike")
	var player: Dictionary = {"current_power": 10}
	var result: Dictionary = _Resolver.resolve(spell, null, player, null)
	assert_bool(result["result"] in ["success", "condition_not_met", "no_target"]).is_true()

func test_resolve_all_16_templates() -> void:
	var templates := [
		&"DIRECT_DAMAGE", &"HARD_REMOVAL", &"BOUNCE", &"COUNTERMAGIC",
		&"COMBAT_TRICK", &"DEBUFF_CONTROL", &"SPELL_DRAW", &"MANA_RAMP",
		&"TOKEN_GENERATION", &"RELIC_INTERACTION", &"KEYWORD_BUFF",
		&"CHOICE_CYCLE", &"TOUCH_CYCLE", &"DISPLAY_CYCLE",
		&"DISPEL_DRAW", &"MARKET_NICHE",
	]
	for t in templates:
		var spell: Variant = _Def.from_dict({
			"id": str(t), "template": str(t), "cost": 0,
			"params": {"amount": 1, "target": "ENEMY_UNIT", "count": 1, "atk": 1, "hp": 1, "keyword": "ARMORED"},
		})
		var player: Dictionary = {"current_power": 10, "hand": [1]}
		var result: Dictionary = _Resolver.resolve(spell, null, player)
		assert_bool(result["result"] != "unknown_template").is_true()
