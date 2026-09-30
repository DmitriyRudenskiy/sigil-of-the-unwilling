class_name DNDAbilityCheck

## D&D 5e Ability / Contested Check
# A d20 roll plus a modifier, with advantage/disadvantage.
# Reused for contested checks (grapple, shove), escape checks,
# Stealth/Perception/Investigation, and saving throws.

var d20_result: int = 0
var second_d20: int = 0
var total: int = 0
var modifier: int = 0
var has_advantage: bool = false
var has_disadvantage: bool = false


## Roll a check. Returns the total (d20 + modifier).
func roll(rng: RandomNumberGenerator, p_modifier: int, p_advantage: bool = false, p_disadvantage: bool = false) -> int:
	modifier = p_modifier
	has_advantage = p_advantage and not p_disadvantage
	has_disadvantage = p_disadvantage and not p_advantage

	d20_result = rng.randi_range(1, 20)
	if has_advantage:
		second_d20 = rng.randi_range(1, 20)
		d20_result = maxi(d20_result, second_d20)
	elif has_disadvantage:
		second_d20 = rng.randi_range(1, 20)
		d20_result = mini(d20_result, second_d20)
	else:
		second_d20 = 0

	total = d20_result + modifier
	return total


## True if the check met or beat the target DC.
func meets(dc: int) -> bool:
	return total >= dc
