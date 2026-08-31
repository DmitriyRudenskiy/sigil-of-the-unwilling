extends RefCounted
class_name SpellCaster
## Core spell-casting logic: damage, status application, resistance checks.

const _SE = preload("res://scripts/data/StatusEffects.gd")


static func cast(
	spell_id: StringName,
	target_unit: BattleState.BattleUnit,
	caster_hero_bonus: Dictionary,
	target_hero_bonus: Dictionary,
	rng: RandomNumberGenerator,
	registry: Node = null  # SpellRegistry; null → autoload Spells
) -> Dictionary:
	var is_res := spell_id == &"resurrection"

	var reg: Node = ServiceLocator.resolve(registry, &"spells")
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

	if spell.damage_multiplier > 0:
		var base_dmg: int = sp * spell.damage_multiplier
		if resisted: base_dmg = int(base_dmg * 0.5)
		result = _apply_damage(target_unit, base_dmg, rng, result)
	elif spell.buff_effect >= 0:
		target_unit.add_status(spell.buff_effect, 3)
		result.status = spell.buff_effect
	elif spell_id == &"cure":
		target_unit.clear_debuffs()
		result.heal = sp * 10
	elif spell_id == &"slow_mass":
		target_unit.add_status(_SE.Effect.SLOW, 4)
		result.status = _SE.Effect.SLOW
	elif spell_id == &"resurrection":
		if target_unit.get_count() <= 0:
			var sp_res: int = int(caster_hero_bonus.get("spell_power", 0))
			var hp: int = max(1, target_unit.get_hp())

			var revived_count := int(sp_res * 20 / hp)
			revived_count = max(1, revived_count)
			revived_count = min(revived_count, target_unit.max_count)

			result["revive_count"] = revived_count

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
	# Undead immune to water healing/curses
	if unit.has_tag("undead") and spell_id in [&"bless", &"cure", &"curse", &"weakness", &"slow"]:
		return true
	# Dragons immune to spells below level 4
	if unit.has_tag("dragon") and spell_level < 4:
		return true
	# Golems immune to mind debuffs
	if unit.has_tag("immune_mind") or unit.has_tag("mind_immune"):
		if spell_id in [&"curse", &"misfortune", &"weakness", &"slow"]:
			return true
	return false


static func _calc_resistance(unit: BattleState.BattleUnit, hero_bonus: Dictionary) -> float:
	var base: float = 0.05 * hero_bonus.get("knowledge", 0)
	if unit.has_tag("magic_resistant"):
		base += 0.40
	return clampf(base, 0.0, 0.9)
