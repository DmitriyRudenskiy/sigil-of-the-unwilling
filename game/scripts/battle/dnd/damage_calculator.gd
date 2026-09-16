class_name DNDDamageCalculator

## D&D 5e Damage Calculation System
# Handles weapon damage dice, modifiers, critical hits, and damage types

enum DamageType {
	BLUDGEONING,
	PIERCING,
	SLASHING,
	FIRE,
	COLD,
	LIGHTNING,
	THUNDER,
	ACID,
	POISON,
	RADIANT,
	NECROTIC,
	PYCHIC,
	FORCE
}

const DAMAGE_TYPE_NAMES = [
	"Bludgeoning", "Piercing", "Slashing", "Fire", "Cold", 
	"Lightning", "Thunder", "Acid", "Poison", "Radiant", 
	"Necrotic", "Psychic", "Force"
]

# Weapon damage dice (PHB weapons)
const WEAPON_DAMAGE = {
	# Simple Melee
	"club": { "dice": "1d4", "type": DamageType.BLUDGEONING },
	"dagger": { "dice": "1d4", "type": DamageType.PIERCING },
	"greatclub": { "dice": "1d8", "type": DamageType.BLUDGEONING },
	"handaxe": { "dice": "1d6", "type": DamageType.SLASHING },
	"javelin": { "dice": "1d6", "type": DamageType.PIERCING },
	"light_hammer": { "dice": "1d4", "type": DamageType.BLUDGEONING },
	"mace": { "dice": "1d6", "type": DamageType.BLUDGEONING },
	"quarterstaff": { "dice": "1d6", "type": DamageType.BLUDGEONING },
	"sickle": { "dice": "1d4", "type": DamageType.SLASHING },
	"spear": { "dice": "1d6", "type": DamageType.PIERCING },
	
	# Simple Ranged
	"crossbow_light": { "dice": "1d8", "type": DamageType.PIERCING },
	"dart": { "dice": "1d4", "type": DamageType.PIERCING },
	"shortbow": { "dice": "1d6", "type": DamageType.PIERCING },
	"sling": { "dice": "1d4", "type": DamageType.BLUDGEONING },
	
	# Martial Melee
	"battleaxe": { "dice": "1d8", "type": DamageType.SLASHING },
	"flail": { "dice": "1d8", "type": DamageType.BLUDGEONING },
	"glaive": { "dice": "1d10", "type": DamageType.SLASHING },
	"greataxe": { "dice": "1d12", "type": DamageType.SLASHING },
	"greatsword": { "dice": "2d6", "type": DamageType.SLASHING },
	"halberd": { "dice": "1d10", "type": DamageType.SLASHING },
	"lance": { "dice": "1d12", "type": DamageType.PIERCING },
	"longsword": { "dice": "1d8", "type": DamageType.SLASHING },
	"maul": { "dice": "2d6", "type": DamageType.BLUDGEONING },
	"morningstar": { "dice": "1d8", "type": DamageType.PIERCING },
	"pike": { "dice": "1d10", "type": DamageType.PIERCING },
	"rapier": { "dice": "1d8", "type": DamageType.PIERCING },
	"scimitar": { "dice": "1d6", "type": DamageType.SLASHING },
	"shortsword": { "dice": "1d6", "type": DamageType.PIERCING },
	"trident": { "dice": "1d6", "type": DamageType.PIERCING },
	"war_pick": { "dice": "1d8", "type": DamageType.PIERCING },
	"warhammer": { "dice": "1d8", "type": DamageType.BLUDGEONING },
	"whip": { "dice": "1d4", "type": DamageType.SLASHING },
	
	# Martial Ranged
	"blowgun": { "dice": "1d1", "type": DamageType.PIERCING },
	"crossbow_hand": { "dice": "1d6", "type": DamageType.PIERCING },
	"crossbow_heavy": { "dice": "1d10", "type": DamageType.PIERCING },
	"longbow": { "dice": "1d8", "type": DamageType.PIERCING },
	"net": { "dice": "0d0", "type": DamageType.NONE }  # Special
}

# Resistance/vulnerability multipliers
const RESISTANCE_MULTIPLIER = 0.5
const VULNERABILITY_MULTIPLIER = 2.0
const IMMUNITY_MULTIPLIER = 0.0


## Parse dice notation (e.g., "2d6", "1d8") and roll
static func roll_dice(dice_notation: String, rng: RandomNumberGenerator) -> int:
	if dice_notation == "0d0":
		return 0
	
	var parts = dice_notation.split("d")
	if parts.size() != 2:
		return 0
	
	var num_dice = int(parts[0])
	var die_size = int(parts[1])
	
	var total = 0
	for i in range(num_dice):
		total += rng.randi_range(1, die_size)
	
	return total


## Calculate damage for an attack
## Returns: { base_damage, modifier, total, damage_type, is_critical }
func calculate_damage(rng: RandomNumberGenerator, weapon_id: String, 
					  ability_modifier: int, is_critical: bool = false,
					  other_modifiers: int = 0) -> Dictionary:
	
	var result = {
		"base_damage": 0,
		"modifier": 0,
		"other_modifiers": other_modifiers,
		"total": 0,
		"damage_type": DamageType.PIERCING,
		"is_critical": is_critical,
		"breakdown": ""
	}
	
	# Get weapon data
	if weapon_id not in WEAPON_DAMAGE:
		# Default to unarmed strike
		result["base_damage"] = 1
		result["damage_type"] = DamageType.BLUDGEONING
		result["modifier"] = ability_modifier
		result["total"] = max(1, result["base_damage"] + result["modifier"] + other_modifiers)
		result["breakdown"] = "Unarmed: 1 + %d = %d" % [result["modifier"], result["total"]]
		return result
	
	var weapon_data = WEAPON_DAMAGE[weapon_id]
	var dice_notation = weapon_data["dice"]
	result["damage_type"] = weapon_data["type"]
	
	# Roll weapon damage dice
	var base_damage = roll_dice(dice_notation, rng)
	result["base_damage"] = base_damage
	
	# Critical hit: roll double dice
	if is_critical:
		var extra_damage = roll_dice(dice_notation, rng)
		base_damage += extra_damage
		result["base_damage"] = base_damage
	
	# Add ability modifier
	result["modifier"] = ability_modifier
	
	# Calculate total (minimum 1 for non-magical attacks)
	result["total"] = max(1, base_damage + ability_modifier + other_modifiers)
	
	# Build breakdown string
	result["breakdown"] = "%s: %d" % [weapon_id.capitalize().replace("_", " "), base_damage]
	if ability_modifier != 0:
		result["breakdown"] += " %+d" % ability_modifier
	if other_modifiers != 0:
		result["breakdown"] += " %+d" % other_modifiers
	if is_critical:
		result["breakdown"] += " (CRITICAL!)"
	result["breakdown"] += " = %d" % result["total"]
	
	return result


## Apply resistance/vulnerability to damage
func apply_resistance(damage: int, damage_type: DamageType,
					  resistances: Array[DamageType] = [],
					  vulnerabilities: Array[DamageType] = [],
					  immunities: Array[DamageType] = []) -> int:
	
	if damage_type in immunities:
		return 0
	
	var multiplier = 1.0
	
	if damage_type in resistances:
		multiplier *= RESISTANCE_MULTIPLIER
	
	if damage_type in vulnerabilities:
		multiplier *= VULNERABILITY_MULTIPLIER
	
	return max(1, floor(damage * multiplier))


## Get damage type name
static func get_damage_type_name(type: DamageType) -> String:
	if type >= 0 and type < DAMAGE_TYPE_NAMES.size():
		return DAMAGE_TYPE_NAMES[type]
	return "Unknown"


## Roll sneak attack damage (rogue feature)
static func roll_sneak_attack(level: int, rng: RandomNumberGenerator) -> int:
	# Sneak attack: 1d6 at level 1, +1d6 every 2 levels
	var num_dice = (level + 1) / 2
	num_dice = min(num_dice, 10)  # Max 10d6 at level 19+
	
	var total = 0
	for i in range(num_dice):
		total += rng.randi_range(1, 6)
	
	return total


## Roll spell damage
static func roll_spell_damage(dice_notation: String, rng: RandomNumberGenerator) -> int:
	return roll_dice(dice_notation, rng)
