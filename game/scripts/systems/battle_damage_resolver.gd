class_name BattleDamageResolver
extends RefCounted

const _StatusEffects = preload("res://scripts/data/status_effects.gd")
const _BattleTerrain = preload("res://scripts/systems/BattleTerrain.gd")

## Разрешение урона по лестнице (T17/D2, 02d v1.2). Без ГСЧ:
## все проки (petrify/blind/крит rogue) срабатывают на Триумфе.
static func resolve(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, ctx: Dictionary) -> Dictionary:
	var is_melee: bool = ctx.get("is_melee", true)
	var atk_bonus: int = ctx.get("atk_bonus", 0)
	var def_bonus: int = ctx.get("def_bonus", 0)
	var range: int = int(ctx.get("range", 1))

	if atk == null or def == null or not atk.is_alive() or not def.is_alive():
		return {}

	# T12: D&D-персонажи (count=1, профиль) идут по d20-мосту, не по лестнице:
	# бросок атаки по AC, кубы урона, крит. Смерть по-прежнему count-based
	# (старое поведение main: любой урон = 1 килл, пул HP не списывается).
	# ponytail: д20-ветка отдельная, т.к. шкала AC/бонусов не совпадает со
	# шкалой перевеса лестницы; объединять — только при редизайне dnd-боёв.
	if atk.is_dnd_character() and def.is_dnd_character():
		var dnd_rng: RandomNumberGenerator = ctx.get("rng")
		if dnd_rng == null:
			dnd_rng = state.dnd_rng
		var d: Dictionary = DnDBattleBridge.resolve_attack(
			atk.dnd_profile, def.dnd_profile, dnd_rng, false, false)
		var dnd_dmg: int = int(d.get("damage", 0)) if d.get("hit", false) else 0
		return {
			"damage": dnd_dmg,
			"kills": 1 if dnd_dmg > 0 else 0,
			"zone": "dnd",
			"margin": 0,
			"is_retaliation": false,
		}

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
	# Единая классификация позиции (facade-based) — и для перевеса, и для
	# флага flank в результате (T17/D2).
	var flank_aspect: int = BattleFlanking.classify(state, atk, def)
	terrain_def_mult *= HeroTactics.hill_defense_mult(def, state.get_hex_terrain(def.cell))
	atk_bonus += HeroTactics.front_attack_bonus(atk, flank_aspect)

	# Лестница (02d v1.2): эльф в лесу = +1 к перевесу (детерминированный
	# аналог старого crit-бонуса).
	var extra_margin: int = 0
	if HeroTactics.forest_crit_bonus(atk, state.get_hex_terrain(atk.cell)) > 0.0:
		extra_margin += 1

	# Фланг/тыл: классификация позиции (тыл дополнительно в margin_of:
	# def ×0.5 + преимущество).
	var flank_pos: int = BattleFlanking.classify(state, atk, def)

	var result: Dictionary = BattleRules.calculate_attack(
		atk, def, is_melee, atk_bonus, def_bonus, terrain_atk_mult, terrain_def_mult,
		flank_aspect, extra_margin
	)
	if result.is_empty():
		return result

	# Штраф дистанции (tactical-combat фаза 4): урон снижается на каждый
	# гекс за первый (10%/гекс, пол от минимального множителя 0.5).
	# Провал остаётся промахом (0 урона).
	if not is_melee and range > 1 and int(result.get("damage", 0)) > 0:
		var factor: float = maxf(
			GameNumbersBattle.RANGED_MIN_RANGE_FACTOR,
			1.0 - GameNumbersBattle.RANGED_PENALTY_PER_HEX * float(range - 1)
		)
		result["damage"] = maxi(1, int(round(float(result.get("damage", 0)) * factor)))
		var hp: int = max(1, def.get_hp())
		result["kills"] = mini(def.get_count(), maxi(1, int(result["damage"] / float(hp))))
	result["flank"] = flank_pos

	_apply_status_procs(atk, def, result)
	_apply_hero_class_procs(atk, def, result)
	_apply_vampiric(atk, result)
	_apply_breath(state, atk, def, result, state.hex_shift_right)
	_apply_saltpeter(state, atk, def, result, state.hex_shift_right)

	return result

## Статусные проки: на Триумфе (критический эффект лестницы, 02d v1.2).
static func _apply_status_procs(atk: BattleState.BattleUnit, def: BattleState.BattleUnit, result: Dictionary) -> void:
	if result.get("zone") != BattleRules.ZONE_TRIUMPH:
		return
	if atk.has_tag("petrify"):
		def.add_status(_StatusEffects.Effect.PETRIFIED, 1)
		result["petrify"] = true
	if atk.has_tag("blind"):
		def.add_status(_StatusEffects.Effect.BLIND, 1)
		result["blind"] = true

## Классовые эффекты бойца-героя (early-game-foundation): тег = ключ класса.
static func _apply_hero_class_procs(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary
) -> void:
	if atk == null or def == null or result.is_empty():
		return
	if atk.has_tag("ranger") and GameNumbersHero.WILD_ANIMAL_KEYS.has(def.get_key()):
		result["kills"] = int(result.get("kills", 0)) + GameNumbersHero.RANGER_ANIMAL_DAMAGE_BONUS
		result["ranger_bonus"] = true
	# Крит rogue = Триумф (детерминированный аналог 10%-го прока).
	if atk.has_tag("rogue") and result.get("zone") == BattleRules.ZONE_TRIUMPH:
		result["kills"] = int(result.get("kills", 0)) * GameNumbersHero.ROGUE_CRIT_MULTIPLIER
		result["crit"] = true


static func _apply_vampiric(atk: BattleState.BattleUnit, result: Dictionary) -> void:
	if not atk.has_tag("vampiric") or int(result.get("kills", 0)) <= 0:
		return
	var healed: int = min(int(result.get("kills", 0)), atk.max_count - atk.get_count())
	if healed > 0:
		atk.set_count(atk.get_count() + healed)
		result["vampiric"] = healed

static func _apply_breath(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, result: Dictionary, shift_right: bool) -> void:
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

static func _apply_saltpeter(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, result: Dictionary, shift_right: bool) -> void:
	if atk.has_tag("saltpeter"):
		var explosion_dmg: int = int(atk.get_base_damage() * GameNumbers.SALTPETER_EXPLOSION_MULT)
		_apply_area_damage(
			state, atk, def.cell, explosion_dmg,
			result, &"saltpeter_kills", shift_right
		)
