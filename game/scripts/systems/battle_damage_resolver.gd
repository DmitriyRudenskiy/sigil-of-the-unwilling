class_name BattleDamageResolver
extends RefCounted

const _StatusEffects = preload("res://scripts/data/status_effects.gd")
const _BattleTerrain = preload("res://scripts/systems/BattleTerrain.gd")

static func resolve(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, ctx: Dictionary) -> Dictionary:
	var is_melee: bool = ctx.get("is_melee", true)
	var rng: RandomNumberGenerator = ctx.get("rng")
	var atk_bonus: int = ctx.get("atk_bonus", 0)
	var def_bonus: int = ctx.get("def_bonus", 0)
	var range: int = int(ctx.get("range", 1))

	if atk == null or def == null or not atk.is_alive() or not def.is_alive():
		return {}

	# LOCAL (tactical-combat): String-terrain → bonus adjustments.
	# (forest/hill/fort defense bonus, hill attack bonus when target not on hill).
	var def_terr: String = state.get_terrain_at(def.cell)
	def_bonus += int(round(float(def.get_defense()) * BattleTerrain.defense_bonus(def_terr)))
	var atk_terr: String = state.get_terrain_at(atk.cell)
	if BattleTerrain.attack_bonus(atk_terr) > 0.0 and BattleTerrain.attack_bonus(def_terr) <= 0.0:
		atk_bonus += int(round(float(atk.get_attack()) * BattleTerrain.attack_bonus(atk_terr)))

	# REMOTE (tactical-battle-system Phase 5/6/9): int-terrain multipliers,
	# elevation, flanking aspect, hero class/race tactics.
	var terrain_atk_mult: float = 1.0
	var terrain_def_mult: float = _BattleTerrain.defense_multiplier(state.get_hex_terrain(def.cell))
	if _BattleTerrain.elevation(state.get_hex_terrain(atk.cell)) > _BattleTerrain.elevation(state.get_hex_terrain(def.cell)):
		terrain_atk_mult = _BattleTerrain.DOWNHILL_ATTACK_MULT
	var flank_aspect: int = state.attack_aspect(atk.cell, def)
	terrain_def_mult *= HeroTactics.hill_defense_mult(def, state.get_hex_terrain(def.cell))
	atk_bonus += HeroTactics.front_attack_bonus(atk, flank_aspect)
	var extra_crit: float = HeroTactics.forest_crit_bonus(atk, state.get_hex_terrain(atk.cell))

	# LOCAL (tactical-combat Phase 5): flanking luck bonus + rear defense ignore.
	var flank_pos: int = BattleFlanking.classify(state, atk, def)
	var luck_bonus: float = BattleFlanking.luck_bonus(flank_pos)
	var def_ignore: float = BattleFlanking.defense_ignore(flank_pos)
	if def_ignore > 0.0:
		def_bonus = int(round(float(def_bonus) * (1.0 - def_ignore))) \
			- int(round(float(def.get_defense()) * def_ignore))

	var result: Dictionary = BattleRules.calculate_attack(
		atk, def, is_melee, rng, atk_bonus, def_bonus, terrain_atk_mult, terrain_def_mult,
		flank_aspect, extra_crit, luck_bonus
	)
	if result.is_empty():
		return result

	# Штраф дистанции (tactical-combat фаза 4): урон снижается на каждый
	# гекс за первый (10%/гекс, пол от минимального множителя 0.5).
	if not is_melee and range > 1:
		var factor: float = maxf(
			GameNumbersBattle.RANGED_MIN_RANGE_FACTOR,
			1.0 - GameNumbersBattle.RANGED_PENALTY_PER_HEX * float(range - 1)
		)
		result["damage"] = maxi(1, int(round(float(result.get("damage", 0)) * factor)))
	result["flank"] = flank_pos
	if luck_bonus > 0.0:
		result["luck_bonus"] = luck_bonus

	_apply_status_procs(atk, def, rng, result)
	_apply_hero_class_procs(atk, def, rng, result)
	_apply_vampiric(atk, result)
	_apply_breath(state, atk, def, result, rng, state.hex_shift_right)
	_apply_saltpeter(state, atk, def, rng, result, state.hex_shift_right)

	return result

static func _apply_status_procs(atk: BattleState.BattleUnit, def: BattleState.BattleUnit, rng: RandomNumberGenerator, result: Dictionary) -> void:
	if atk.has_tag("petrify") and rng.randf() < GameNumbers.STATUS_PROC_CHANCE:
		def.add_status(_StatusEffects.Effect.PETRIFIED, 1)
		result["petrify"] = true
	if atk.has_tag("blind") and rng.randf() < GameNumbers.STATUS_PROC_CHANCE:
		def.add_status(_StatusEffects.Effect.BLIND, 1)
		result["blind"] = true

## Классовые эффекты бойца-героя (early-game-foundation): тег = ключ класса.
static func _apply_hero_class_procs(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	rng: RandomNumberGenerator,
	result: Dictionary
) -> void:
	if atk == null or def == null or result.is_empty():
		return
	if atk.has_tag("ranger") and GameNumbersHero.WILD_ANIMAL_KEYS.has(def.get_key()):
		result["kills"] = int(result.get("kills", 0)) + GameNumbersHero.RANGER_ANIMAL_DAMAGE_BONUS
		result["ranger_bonus"] = true
	if atk.has_tag("rogue") and rng.randf() < GameNumbersHero.ROGUE_CRIT_CHANCE:
		result["kills"] = int(result.get("kills", 0)) * GameNumbersHero.ROGUE_CRIT_MULTIPLIER
		result["crit"] = true


static func _apply_vampiric(atk: BattleState.BattleUnit, result: Dictionary) -> void:
	if not atk.has_tag("vampiric") or int(result.get("kills", 0)) <= 0:
		return
	var healed: int = min(int(result.get("kills", 0)), atk.max_count - atk.get_count())
	if healed > 0:
		atk.set_count(atk.get_count() + healed)
		result["vampiric"] = healed

static func _apply_breath(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, result: Dictionary, _rng: RandomNumberGenerator, shift_right: bool) -> void:
	if atk.has_tag("breath"):
		result["breath_kills"] = _apply_area_damage(
			state, atk, def.cell,
			int(result.get("damage", 0) * GameNumbers.BREATH_DMG_RATIO),
			result, &"breath_kills", shift_right
		)

const _SIDES := [BattleState.Side.ATTACKER, BattleState.Side.DEFENDER]

static func _apply_area_damage(
	state: BattleState, atk: BattleState.BattleUnit,
	origin: Vector2i, dmg: int, result: Dictionary, key: StringName, shift_right: bool
) -> int:
	var total: int = 0
	for nb in HexUtils.get_all_neighbors(origin, shift_right):
		for side in _SIDES:
			var v: BattleState.BattleUnit = state.get_unit_at(nb, side)
			if v == null or not v.is_alive() or v == atk:
				continue
			var hp: int = max(1, v.get_hp())
			var kills: int = min(v.get_count(), max(1, int(dmg / float(hp))))
			v.set_count(v.get_count() - kills)
			total += kills
			if v.get_count() <= 0:
				BattleActionResolver.kill_unit(state, v)
	result[key] = total
	return total

static func _apply_saltpeter(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, _rng: RandomNumberGenerator, result: Dictionary, shift_right: bool) -> void:
	if atk.has_tag("saltpeter"):
		var explosion_dmg: int = int(atk.get_base_damage() * GameNumbers.SALTPETER_EXPLOSION_MULT)
		_apply_area_damage(
			state, atk, def.cell, explosion_dmg,
			result, &"saltpeter_kills", shift_right
		)
