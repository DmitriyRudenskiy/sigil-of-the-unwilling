class_name BattleDamageResolver
extends RefCounted

const _StatusEffects = preload("res://scripts/data/StatusEffects.gd")

static func resolve(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, ctx: Dictionary) -> Dictionary:
	var is_melee: bool = ctx.get("is_melee", true)
	var rng: RandomNumberGenerator = ctx.get("rng")
	var atk_bonus: int = ctx.get("atk_bonus", 0)
	var def_bonus: int = ctx.get("def_bonus", 0)

	if atk == null or def == null or not atk.is_alive() or not def.is_alive():
		return {}

	var result: Dictionary = BattleRules.calculate_attack(atk, def, is_melee, rng, atk_bonus, def_bonus)
	if result.is_empty():
		return result

	_apply_status_procs(atk, def, rng, result)
	_apply_vampiric(atk, result)
	_apply_breath(state, atk, def, result, rng)
	_apply_saltpeter(state, atk, def, rng, result)

	return result

static func _apply_status_procs(atk: BattleState.BattleUnit, def: BattleState.BattleUnit, rng: RandomNumberGenerator, result: Dictionary) -> void:
	if atk.has_tag("petrify") and rng.randf() < GameNumbers.STATUS_PROC_CHANCE:
		def.add_status(_StatusEffects.Effect.PETRIFIED, 1)
		result["petrify"] = true
	if atk.has_tag("blind") and rng.randf() < GameNumbers.STATUS_PROC_CHANCE:
		def.add_status(_StatusEffects.Effect.BLIND, 1)
		result["blind"] = true

static func _apply_vampiric(atk: BattleState.BattleUnit, result: Dictionary) -> void:
	if not atk.has_tag("vampiric") or int(result.get("kills", 0)) <= 0:
		return
	var healed: int = min(int(result.get("kills", 0)), atk.max_count - atk.get_count())
	if healed > 0:
		atk.set_count(atk.get_count() + healed)
		result["vampiric"] = healed

static func _apply_breath(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, result: Dictionary, _rng: RandomNumberGenerator) -> void:
	if atk.has_tag("breath"):
		result["breath_kills"] = _apply_area_damage(
			state, atk, def.cell,
			int(result.get("damage", 0) * GameNumbers.BREATH_DMG_RATIO),
			result, &"breath_kills"
		)

const _SIDES := [BattleState.Side.ATTACKER, BattleState.Side.DEFENDER]

static func _apply_area_damage(
	state: BattleState, atk: BattleState.BattleUnit,
	origin: Vector2i, dmg: int, result: Dictionary, key: StringName
) -> int:
	var total: int = 0
	for nb in HexUtils.get_all_neighbors(origin):
		for side in _SIDES:
			var v: BattleState.BattleUnit = state.get_unit_at(nb, side)
			if v == null or not v.is_alive() or v == atk:
				continue
			var hp: int = max(1, v.get_hp())
			var kills: int = min(v.get_count(), max(1, dmg / hp))
			v.set_count(v.get_count() - kills)
			total += kills
			if v.get_count() <= 0:
				BattleActionResolver.kill_unit(state, v)
	result[key] = total
	return total

static func _apply_saltpeter(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, _rng: RandomNumberGenerator, result: Dictionary) -> void:
	if atk.has_tag("saltpeter"):
		var explosion_dmg: int = int(atk.get_base_damage() * GameNumbers.SALTPETER_EXPLOSION_MULT)
		_apply_area_damage(
			state, atk, def.cell, explosion_dmg,
			result, &"saltpeter_kills"
		)
