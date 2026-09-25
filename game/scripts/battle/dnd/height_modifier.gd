class_name DNDHeightModifier

## D&D 5e High Ground / Elevation Attack Modifiers
# Pure function of elevation levels (5-foot increments).
#
# Downhill (attacker higher):
#   ranged: +1/+2/+3 for 2/3/4+ levels higher
#   melee:  +1/+2 for 2/3+ levels higher
# Uphill (attacker lower):
#   ranged: -1/-2 for 1/2+ levels lower
#   melee:  0 for 1 level lower (per spec), -1/-2/-3 for 2/3/4+
# Same level: 0.

const MELEE_DOWNHILL := {2: 1, 3: 2}
const RANGED_DOWNHILL := {2: 1, 3: 2, 4: 3}
const RANGED_UPHILL := {1: 1, 2: 2}
const MELEE_UPHILL := {2: 1, 3: 2, 4: 3}


## Attack roll modifier from elevation difference.
## p_attacker_level / p_target_level are 5-foot increments (0 = ground).
## p_is_ranged selects the ranged vs melee table.
static func attack_bonus(p_attacker_level: int, p_target_level: int, p_is_ranged: bool) -> int:
	var diff := p_attacker_level - p_target_level
	if diff == 0:
		return 0
	if diff > 0:
		# Attacker is higher (downhill shot).
		if p_is_ranged:
			if diff >= 4:
				return RANGED_DOWNHILL[4]
			return int(RANGED_DOWNHILL.get(diff, 0))
		# Melee downhill: 2 levels -> +1, 3+ -> +2.
		if diff >= 3:
			return MELEE_DOWNHILL[3]
		return int(MELEE_DOWNHILL.get(diff, 0))
	# Attacker is lower (uphill shot).
	var up := -diff
	if p_is_ranged:
		return -mini(up, RANGED_UPHILL.size())
	# Melee: 1 level up gives no penalty (spec), 2+ levels does.
	if up == 1:
		return 0
	if up >= 4:
		return -MELEE_UPHILL[4]
	return -MELEE_UPHILL[up]


## Ranged range bonus (in levels of range) when shooting downhill.
## +1 range step per 2+ levels of height advantage.
static func range_bonus(p_attacker_level: int, p_target_level: int) -> int:
	var diff := p_attacker_level - p_target_level
	if diff >= 4:
		return 2
	if diff >= 2:
		return 1
	return 0


## Human-readable description for UI tooltips.
static func describe(p_attacker_level: int, p_target_level: int, p_is_ranged: bool) -> String:
	var b := attack_bonus(p_attacker_level, p_target_level, p_is_ranged)
	if b > 0:
		return "high ground %+d" % b
	if b < 0:
		return "uphill %+d" % b
	return "same level"
