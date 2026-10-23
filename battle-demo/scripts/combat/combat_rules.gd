class_name CombatRules extends RefCounted

## Формула урона (design-brief.md): damage = max(1, round(attack·mult·variance −
## defense·0.5·(1 − ignores))). rng — генератор боя, поэтому при одном seed
## урон воспроизводим.

const VARIANCE_MIN := 0.9
const VARIANCE_MAX := 1.1
const DEFENSE_FACTOR := 0.5


static func damage(
	actor: BattleUnit, target: BattleUnit, ability: Ability, rng: RandomNumberGenerator
) -> int:
	var multiplier := 1.0
	var ignores := 0.0
	if ability != null:
		multiplier = ability.multiplier
		ignores = clampf(ability.defense_ignores, 0.0, 1.0)
	var variance := rng.randf_range(VARIANCE_MIN, VARIANCE_MAX)
	var raw := float(actor.effective_attack()) * multiplier * variance
	var defense := float(target.stats.defense) * (1.0 - ignores)
	return maxi(1, int(round(raw - defense * DEFENSE_FACTOR)))
