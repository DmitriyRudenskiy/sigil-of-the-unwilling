
extends RefCounted
class_name SpellCaster

const _UNDEAD_IMMUNE_SPELLS := {
	&"bless": true, &"cure": true, &"curse": true, &"weakness": true, &"slow": true
}
const _MIND_IMMUNE_SPELLS := {
	&"curse": true, &"misfortune": true, &"weakness": true, &"slow": true
}

static func cast(
	spell_id: StringName,
	target_unit: BattleState.BattleUnit,
	caster_hero_bonus: Dictionary,
	target_hero_bonus: Dictionary,
	rng: RandomNumberGenerator,
	registry: Node = null
) -> Dictionary:
	var is_res := spell_id == &"resurrection"

	var reg: Node = registry if registry != null else Services.resolve(&"spells")
	var spell: SpellRegistry.SpellDef = reg.get_spell(spell_id)
	if spell == null:
		return {"result": "not_found"}

	if target_unit == null:
		return {"result": "invalid_target"}
	if not is_res and not target_unit.is_alive():
		return {"result": "invalid_target"}

	if _check_immunity(target_unit, spell):
		return {"result": "immune", "spell_id": spell_id}

	var resist_chance := _calc_resistance(target_unit, target_hero_bonus)
	var resisted: bool = rng.randf() < resist_chance

	var sp: int = caster_hero_bonus.get("spell_power", 0)
	var result := {"result": "success", "damage": 0, "status": -1, "resisted": resisted, "spell_id": spell_id}

	if spell.custom_handler.is_valid():
		result = spell.custom_handler.call(target_unit, sp, rng, result)
	elif spell.damage_multiplier > 0:
		var base_dmg: int = sp * spell.damage_multiplier
		if resisted: base_dmg = int(base_dmg * 0.5)
		result = _apply_damage(target_unit, base_dmg, rng, result)
	elif spell.buff_effect >= 0:
		target_unit.add_status(spell.buff_effect, 3)
		result.status = spell.buff_effect

	return result

static func _apply_damage(unit: BattleState.BattleUnit, dmg: int, rng: RandomNumberGenerator, result: Dictionary) -> Dictionary:
	var hp: int = max(1, unit.get_hp())
	var kills: int = max(1, dmg / hp)
	kills = min(kills, unit.get_count())
	result.damage = dmg
	result.kills = kills
	return result

static func _check_immunity(unit: BattleState.BattleUnit, spell: Variant) -> bool:
	if spell == null: return false
	var s := spell as SpellRegistry.SpellDef
	if s == null: return false
	var spell_id: StringName = s.id
	var spell_level: int = s.level

	if unit.has_tag("undead") and _UNDEAD_IMMUNE_SPELLS.has(spell_id):
		return true
	if unit.has_tag("dragon") and spell_level < 4:
		return true
	if unit.has_tag("immune_mind") or unit.has_tag("mind_immune"):
		if _MIND_IMMUNE_SPELLS.has(spell_id):
			return true
	return false

static func _calc_resistance(unit: BattleState.BattleUnit, hero_bonus: Dictionary) -> float:
	var base: float = 0.05 * hero_bonus.get("knowledge", 0)
	if unit.has_tag("magic_resistant"):
		base += 0.40
	return clampf(base, 0.0, 0.9)
