class_name DNDAttackRoll

## D&D 5e Attack Roll System
# Handles d20 attack rolls with advantage/disadvantage and critical hits

const NATURAL_20 = 20
const NATURAL_1 = 1

enum RollResult {
	NORMAL,
	CRITICAL_HIT,
	CRITICAL_MISS
}

# Roll result data
var d20_result: int = 0
var second_d20: int = 0  # For advantage/disadvantage
var total: int = 0
var ability_modifier: int = 0
var proficiency_bonus: int = 0
var other_modifiers: int = 0
var is_critical_hit: bool = false
var is_critical_miss: bool = false
var has_advantage: bool = false
var has_disadvantage: bool = false


func _init():
	pass


## Make an attack roll
## Returns the total and sets internal state
func roll(rng: RandomNumberGenerator, p_ability_mod: int, p_proficiency: int = 0, 
		  p_other_mods: int = 0, p_advantage: bool = false, p_disadvantage: bool = false) -> int:
	
	ability_modifier = p_ability_mod
	proficiency_bonus = p_proficiency
	other_modifiers = p_other_mods
	
	has_advantage = p_advantage and not p_disadvantage
	has_disadvantage = p_disadvantage and not p_advantage
	
	# Roll d20(s)
	d20_result = rng.randi_range(1, 20)
	
	if has_advantage:
		second_d20 = rng.randi_range(1, 20)
		d20_result = max(d20_result, second_d20)
	elif has_disadvantage:
		second_d20 = rng.randi_range(1, 20)
		d20_result = min(d20_result, second_d20)
	else:
		second_d20 = 0
	
	# Check for critical hit/miss
	is_critical_hit = (d20_result == NATURAL_20)
	is_critical_miss = (d20_result == NATURAL_1)
	
	# Calculate total
	total = d20_result + ability_modifier + proficiency_bonus + other_modifiers
	
	return total


## Get the natural roll (before modifiers)
func get_natural_roll() -> int:
	return d20_result


## Check if this was a critical hit
func is_crit_hit() -> bool:
	return is_critical_hit


## Check if this was a critical miss
func is_crit_miss() -> bool:
	return is_critical_miss


## Get breakdown of the roll as string
func get_breakdown() -> String:
	var parts: Array[String] = []
	
	if second_d20 > 0:
		if has_advantage:
			parts.append("Advantage: [%d, %d] → %d" % [d20_result, second_d20, max(d20_result, second_d20)])
		else:
			parts.append("Disadvantage: [%d, %d] → %d" % [d20_result, second_d20, min(d20_result, second_d20)])
	else:
		parts.append("d20: %d" % d20_result)
	
	if ability_modifier != 0:
		parts.append("Ability: %+d" % ability_modifier)
	
	if proficiency_bonus != 0:
		parts.append("Proficiency: +%d" % proficiency_bonus)
	
	if other_modifiers != 0:
		parts.append("Other: %+d" % other_modifiers)
	
	parts.append("Total: %d" % total)
	
	if is_critical_hit:
		parts.append("CRITICAL HIT!")
	elif is_critical_miss:
		parts.append("CRITICAL MISS!")
	
	return ", ".join(parts)


## Reset roll state
func reset():
	d20_result = 0
	second_d20 = 0
	total = 0
	ability_modifier = 0
	proficiency_bonus = 0
	other_modifiers = 0
	is_critical_hit = false
	is_critical_miss = false
	has_advantage = false
	has_disadvantage = false


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"d20_result": d20_result,
		"second_d20": second_d20,
		"total": total,
		"ability_modifier": ability_modifier,
		"proficiency_bonus": proficiency_bonus,
		"other_modifiers": other_modifiers,
		"is_critical_hit": is_critical_hit,
		"is_critical_miss": is_critical_miss,
		"has_advantage": has_advantage,
		"has_disadvantage": has_disadvantage
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> DNDAttackRoll:
	var roll = DNDAttackRoll.new()
	roll.d20_result = data.get("d20_result", 0)
	roll.second_d20 = data.get("second_d20", 0)
	roll.total = data.get("total", 0)
	roll.ability_modifier = data.get("ability_modifier", 0)
	roll.proficiency_bonus = data.get("proficiency_bonus", 0)
	roll.other_modifiers = data.get("other_modifiers", 0)
	roll.is_critical_hit = data.get("is_critical_hit", false)
	roll.is_critical_miss = data.get("is_critical_miss", false)
	roll.has_advantage = data.get("has_advantage", false)
	roll.has_disadvantage = data.get("has_disadvantage", false)
	return roll


## Static helper: roll with advantage
static func roll_with_advantage(rng: RandomNumberGenerator) -> int:
	var r1 = rng.randi_range(1, 20)
	var r2 = rng.randi_range(1, 20)
	return max(r1, r2)


## Static helper: roll with disadvantage
static func roll_with_disadvantage(rng: RandomNumberGenerator) -> int:
	var r1 = rng.randi_range(1, 20)
	var r2 = rng.randi_range(1, 20)
	return min(r1, r2)
