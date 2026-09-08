class_name BattleRules
extends RefCounted




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
        effective_def = int(float(effective_def) * GameNumbers.DEFEND_DEFENSE_BONUS)

    var diff: int = effective_atk - effective_def

    if diff > 0:
        return clampf(
            1.0 + GameNumbers.ATK_ADVANTAGE_PER_POINT * float(diff),
            1.0,
            GameNumbers.MAX_DAMAGE_MULTIPLIER
        )

    if diff < 0:
        return clampf(
            1.0 - GameNumbers.DEF_ADVANTAGE_PER_POINT * float(absi(diff)),
            GameNumbers.MIN_DAMAGE_MULTIPLIER,
            1.0
        )

    return 1.0


## TASK_06: общая оценка базового урона атакующего (min, max) на весь стек.
## Используется и в расчёте, и в превью — один и тот же диапазон.
static func _damage_range(attacker) -> Vector2i:
    var stats: UnitStats = attacker.stack.stats
    var count: int = attacker.get_count()
    var min_base: int = stats.base_damage * count
    var max_base: int = int(ceil(float(stats.base_damage) * 1.25)) * count
    max_base = max(max_base, min_base)
    return Vector2i(min_base, max_base)


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

    var range := _damage_range(attacker)
    var base_total: int = rng.randi_range(range.x, range.y)

    var multiplier: float = damage_multiplier(
        attacker,
        defender,
        attacker_bonus,
        defender_bonus
    )

    var damage: int = int(float(base_total) * multiplier)

    if is_melee_attack and attacker.is_ranged():
        damage = int(float(damage) * GameNumbers.RANGED_MELEE_PENALTY)

    damage = max(1, damage)

    var luck: bool = false
    if can_luck(attacker) and rng.randf() < GameNumbers.LUCK_CHANCE:
        damage *= 2
        luck = true

    var hp: int = max(1, defender.get_hp())
    var kills: int = max(1, damage / hp)
    kills = min(kills, defender.get_count())

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

    var range := _damage_range(attacker)

    var multiplier: float = damage_multiplier(
        attacker,
        defender,
        attacker_bonus,
        defender_bonus
    )

    var min_damage: int = int(float(range.x) * multiplier)
    var max_damage: int = int(float(range.y) * multiplier)

    var distance: int = HexUtils.hex_distance(attacker.cell, defender.cell)
    if attacker.is_ranged() and distance == 1:
        min_damage = int(float(min_damage) * GameNumbers.RANGED_MELEE_PENALTY)
        max_damage = int(float(max_damage) * GameNumbers.RANGED_MELEE_PENALTY)

    min_damage = max(1, min_damage)
    max_damage = max(1, max_damage)

    var hp: int = max(1, defender.get_hp())
    var min_kills: int = max(1, min_damage / hp)
    var max_kills: int = max(1, max_damage / hp)

    min_kills = min(min_kills, defender.get_count())
    max_kills = min(max_kills, defender.get_count())

    return GameText.battle_damage_preview(min_damage, max_damage, min_kills, max_kills)
