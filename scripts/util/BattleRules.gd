class_name BattleRules
extends RefCounted
## Правила боя: ATK/DEF multiplier, luck, morale, retaliation, retreat.

const ATK_ADVANTAGE_PER_POINT := 0.05
const DEF_ADVANTAGE_PER_POINT := 0.025
const MAX_DAMAGE_MULTIPLIER := 5.0
const MIN_DAMAGE_MULTIPLIER := 0.3

const LUCK_CHANCE := 0.10
const MORALE_CHANCE := 0.08
const RETREAT_SURVIVAL_RATIO := 0.5
const DEFEND_DEFENSE_BONUS := 1.2
const RANGED_MELEE_PENALTY := 0.5


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


static func damage_multiplier(
    attacker,
    defender,
    attacker_bonus: int,
    defender_bonus: int
) -> float:
    if attacker == null or defender == null:
        return 1.0

    var effective_atk: int = attacker.get_attack() + attacker_bonus

    var effective_def: int = defender.get_defense() + defender_bonus
    if defender.defending:
        effective_def = int(float(effective_def) * DEFEND_DEFENSE_BONUS)

    var diff: int = effective_atk - effective_def

    if diff > 0:
        return clampf(
            1.0 + ATK_ADVANTAGE_PER_POINT * float(diff),
            1.0,
            MAX_DAMAGE_MULTIPLIER
        )

    if diff < 0:
        return clampf(
            1.0 - DEF_ADVANTAGE_PER_POINT * float(absi(diff)),
            MIN_DAMAGE_MULTIPLIER,
            1.0
        )

    return 1.0


static func calculate_attack(
    attacker,
    defender,
    is_melee_attack: bool,
    rng: RandomNumberGenerator,
    attacker_bonus: int,
    defender_bonus: int
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

    var min_base: int = stats.base_damage
    var max_base: int = int(ceil(float(stats.base_damage) * 1.25))
    max_base = maxi(max_base, min_base)

    var base_total: int = rng.randi_range(min_base, max_base) * count

    var multiplier: float = damage_multiplier(
        attacker,
        defender,
        attacker_bonus,
        defender_bonus
    )

    var damage: int = int(float(base_total) * multiplier)

    # Ranged unit forced into melee loses half damage.
    if is_melee_attack and attacker.is_ranged():
        damage = int(float(damage) * RANGED_MELEE_PENALTY)

    damage = maxi(1, damage)

    var luck: bool = false
    if can_luck(attacker) and rng.randf() < LUCK_CHANCE:
        damage *= 2
        luck = true

    var hp: int = maxi(1, defender.get_hp())
    var kills: int = maxi(1, damage / hp)
    kills = mini(kills, defender.get_count())

    return {
        "damage": damage,
        "kills": kills,
        "luck": luck,
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

    var count: int = attacker.get_count()
    var min_base: int = stats.base_damage * count
    var max_base: int = int(ceil(float(stats.base_damage) * 1.25)) * count

    var multiplier: float = damage_multiplier(
        attacker,
        defender,
        attacker_bonus,
        defender_bonus
    )

    var min_damage: int = int(float(min_base) * multiplier)
    var max_damage: int = int(float(max_base) * multiplier)

    var distance: int = HexUtils.hex_distance(attacker.cell, defender.cell)
    if attacker.is_ranged() and distance == 1:
        min_damage = int(float(min_damage) * RANGED_MELEE_PENALTY)
        max_damage = int(float(max_damage) * RANGED_MELEE_PENALTY)

    min_damage = maxi(1, min_damage)
    max_damage = maxi(1, max_damage)

    var hp: int = maxi(1, defender.get_hp())
    var min_kills: int = maxi(1, min_damage / hp)
    var max_kills: int = maxi(1, max_damage / hp)

    min_kills = mini(min_kills, defender.get_count())
    max_kills = mini(max_kills, defender.get_count())

    return "Damage: ~%d-%d (kills ~%d-%d)" % [
        min_damage,
        max_damage,
        min_kills,
        max_kills
    ]
