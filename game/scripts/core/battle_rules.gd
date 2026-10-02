class_name BattleRules
extends RefCounted

## Разрешение боя по лестнице перевеса (02d v1.2 §3.2, K2).
## Кубиков нет: исход = перевес (эффективная атака − эффективная защита),
## Удача (модификатор 7-й характеристики) сдвигает пороги зон.
## Полностью детерминировано: те же входы → тот же результат, байт в байт.

const ZONE_TRIUMPH := &"triumph"
const ZONE_SUCCESS := &"success"
const ZONE_PARTIAL := &"partial"
const ZONE_FAILURE := &"failure"
const ZONE_FUMBLE := &"fumble"

## Зона исхода по перевесу. luck_mod = модификатор Удачи (02d v1.2 §3.2):
## триумф при перевесе ≥ max(1, 4 − luck), частичная до −(3 + luck),
## критпровал при ≤ −(8 + luck).
static func ladder_zone(margin: int, luck_mod: int = 0) -> StringName:
	if margin >= maxi(1, 4 - luck_mod):
		return ZONE_TRIUMPH
	if margin >= 0:
		return ZONE_SUCCESS
	if margin >= -(3 + luck_mod):
		return ZONE_PARTIAL
	if margin <= -(8 + luck_mod):
		return ZONE_FUMBLE
	return ZONE_FAILURE

## Перевес: эффективная атака − эффективная защита.
## Фланг/тыл = преимущество (+2 к перевесу, 02d v1.2 §3.3);
## тыл дополнительно режет защиту ×0.5; защита юнита ×1.2.
static func margin_of(
	attacker,
	defender,
	attacker_bonus: int,
	defender_bonus: int,
	terrain_atk_mult: float = 1.0,
	terrain_def_mult: float = 1.0,
	flank_aspect: int = -1
) -> int:
	if attacker == null or defender == null:
		return 0
	var effective_atk: float = float(attacker.get_attack() + attacker_bonus) * terrain_atk_mult
	var effective_def: float = float(defender.get_defense() + defender_bonus) * terrain_def_mult
	if defender.defending:
		effective_def = effective_def * GameNumbers.DEFEND_DEFENSE_BONUS
	if flank_aspect == 2:
		effective_def = effective_def * GameNumbers.REAR_DEFENSE_MULT
	if flank_aspect == 1 or flank_aspect == 2:
		effective_atk += GameNumbersBattle.ADVANTAGE_MARGIN
	return int(round(effective_atk - effective_def))

static func can_luck(unit) -> bool:
	if unit == null or not unit.has_method("has_tag"):
		return false

	if unit.has_tag("undead"):
		return false
	if unit.has_tag("elemental"):
		return false
	if unit.has_tag("mind_immune"):
		return false

	return true

static func can_morale(unit) -> bool:
	if unit == null or not unit.has_method("has_tag"):
		return false

	if unit.has_tag("undead"):
		return false
	if unit.has_tag("elemental"):
		return false
	if unit.has_tag("mind_immune"):
		return false
	if unit.has_tag("dragon"):
		return false

	return true

## Разрешение атаки по лестнице. Возвращает
## {damage, kills, zone, fumble, is_retaliation} — детерминированно.
## extra_margin — ситуативные поправки (например, эльф в лесу = +1).
static func calculate_attack(
	attacker,
	defender,
	is_melee_attack: bool,
	attacker_bonus: int,
	defender_bonus: int,
	terrain_atk_mult: float = 1.0,
	terrain_def_mult: float = 1.0,
	flank_aspect: int = -1,
	extra_margin: int = 0,
	luck_mod: int = 0
) -> Dictionary:
	if attacker == null or defender == null:
		return {}

	if not attacker.is_alive() or not defender.is_alive():
		return {}

	var stats: UnitStats = attacker.stack.stats
	if stats == null:
		return {}

	var count: int = attacker.get_count()
	if count <= 0:
		return {}

	var margin: int = margin_of(
		attacker, defender, attacker_bonus, defender_bonus,
		terrain_atk_mult, terrain_def_mult, flank_aspect
	) + extra_margin
	var zone: StringName = ladder_zone(margin, luck_mod)

	# Базовый урон детерминирован: base_damage × численность (без диапазона).
	var base: int = stats.base_damage * count
	var damage: int = 0
	match zone:
		ZONE_TRIUMPH:
			damage = int(float(base) * GameNumbersBattle.FLANK_CRIT_MULTIPLIER)
		ZONE_SUCCESS:
			damage = base
		ZONE_PARTIAL:
			damage = maxi(1, base / 2) if base > 0 else 0
		_:
			damage = 0

	if is_melee_attack and attacker.is_ranged():
		damage = int(float(damage) * GameNumbers.RANGED_MELEE_PENALTY)

	var kills: int = 0
	if damage > 0:
		var hp: int = max(1, defender.get_hp())
		kills = maxi(1, int(damage / float(hp)))
		kills = min(kills, defender.get_count())

	return {
		"damage": damage,
		"kills": kills,
		"zone": zone,
		"fumble": zone == ZONE_FUMBLE,
		"margin": margin,
		"is_retaliation": false,
	}

static func preview_text(
	attacker,
	defender,
	attacker_bonus: int,
	defender_bonus: int
) -> String:
	if attacker == null or defender == null:
		return ""

	var stats: UnitStats = attacker.stack.stats
	if stats == null:
		return ""

	var result := calculate_attack(attacker, defender, true, attacker_bonus, defender_bonus)
	var damage: int = int(result.get("damage", 0))
	var kills: int = int(result.get("kills", 0))

	return GameText.battle_damage_preview(damage, damage, kills, kills)
