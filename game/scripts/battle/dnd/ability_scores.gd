class_name DNDAbilityScores

## D&D 5e Ability Score System
# Stores six ability scores and calculates modifiers

const MODIFIER_TABLE = {
	0: -5, 1: -5, 2: -4, 3: -4, 4: -3, 5: -3,
	6: -2, 7: -2, 8: -1, 9: -1, 10: 0, 11: 0,
	12: 1, 13: 1, 14: 2, 15: 2, 16: 3, 17: 3,
	18: 4, 19: 4, 20: 5, 21: 5, 22: 6, 23: 6,
	24: 7, 25: 7, 26: 8, 27: 8, 28: 9, 29: 9,
	30: 10
}

enum Ability {
	STR,  # Strength
	DEX,  # Dexterity
	CON,  # Constitution
	INT,  # Intelligence
	WIS,  # Wisdom
	CHA   # Charisma
}

# Ability scores (8-20 typical range, can exceed with magic)
var strength: int = 10
var dexterity: int = 10
var constitution: int = 10
var intelligence: int = 10
var wisdom: int = 10
var charisma: int = 10


func _init(p_strength: int = 10, p_dexterity: int = 10, p_constitution: int = 10,
		   p_intelligence: int = 10, p_wisdom: int = 10, p_charisma: int = 10):
	strength = clamp(p_strength, 1, 30)
	dexterity = clamp(p_dexterity, 1, 30)
	constitution = clamp(p_constitution, 1, 30)
	intelligence = clamp(p_intelligence, 1, 30)
	wisdom = clamp(p_wisdom, 1, 30)
	charisma = clamp(p_charisma, 1, 30)


## Get ability score by enum
func get_score(ability: Ability) -> int:
	match ability:
		Ability.STR: return strength
		Ability.DEX: return dexterity
		Ability.CON: return constitution
		Ability.INT: return intelligence
		Ability.WIS: return wisdom
		Ability.CHA: return charisma
	return 10


## Set ability score by enum
func set_score(ability: Ability, value: int):
	value = clamp(value, 1, 30)
	match ability:
		Ability.STR: strength = value
		Ability.DEX: dexterity = value
		Ability.CON: constitution = value
		Ability.INT: intelligence = value
		Ability.WIS: wisdom = value
		Ability.CHA: charisma = value


## Calculate ability modifier from score
## Formula: floor((score - 10) / 2)
static func get_ability_modifier(score: int) -> int:
	score = clamp(score, 1, 30)
	if score in MODIFIER_TABLE:
		return MODIFIER_TABLE[score]
	# Fallback calculation
	return floor((score - 10) / 2.0)


## Get modifier for specific ability
func get_str_mod() -> int:
	return get_ability_modifier(strength)


func get_dex_mod() -> int:
	return get_ability_modifier(dexterity)


func get_con_mod() -> int:
	return get_ability_modifier(constitution)


func get_int_mod() -> int:
	return get_ability_modifier(intelligence)


func get_wis_mod() -> int:
	return get_ability_modifier(wisdom)


func get_cha_mod() -> int:
	return get_ability_modifier(charisma)


## Get all modifiers as dictionary
func get_all_modifiers() -> Dictionary:
	return {
		"strength": get_str_mod(),
		"dexterity": get_dex_mod(),
		"constitution": get_con_mod(),
		"intelligence": get_int_mod(),
		"wisdom": get_wis_mod(),
		"charisma": get_cha_mod()
	}


## Serialize to dictionary for save games
func to_dict() -> Dictionary:
	return {
		"str": strength,
		"dex": dexterity,
		"con": constitution,
		"int": intelligence,
		"wis": wisdom,
		"cha": charisma
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> DNDAbilityScores:
	var scores = DNDAbilityScores.new()
	scores.strength = data.get("str", 10)
	scores.dexterity = data.get("dex", 10)
	scores.constitution = data.get("con", 10)
	scores.intelligence = data.get("int", 10)
	scores.wisdom = data.get("wis", 10)
	scores.charisma = data.get("cha", 10)
	return scores


## Generate standard array (15, 14, 13, 12, 11, 10)
static func generate_standard_array() -> DNDAbilityScores:
	var scores = DNDAbilityScores.new()
	# Player should assign these, but we'll distribute evenly for now
	scores.strength = 15
	scores.dexterity = 14
	scores.constitution = 13
	scores.intelligence = 12
	scores.wisdom = 11
	scores.charisma = 10
	return scores


## Roll 4d6 drop lowest for each stat
static func roll_stats(rng: RandomNumberGenerator = null) -> DNDAbilityScores:
	if rng == null:
		rng = RandomNumberGenerator.new()
	
	var scores = DNDAbilityScores.new()
	scores.strength = _roll_4d6_drop_lowest(rng)
	scores.dexterity = _roll_4d6_drop_lowest(rng)
	scores.constitution = _roll_4d6_drop_lowest(rng)
	scores.intelligence = _roll_4d6_drop_lowest(rng)
	scores.wisdom = _roll_4d6_drop_lowest(rng)
	scores.charisma = _roll_4d6_drop_lowest(rng)
	return scores


static func _roll_4d6_drop_lowest(rng: RandomNumberGenerator) -> int:
	var rolls: Array[int] = []
	for i in range(4):
		rolls.append(rng.randi_range(1, 6))
	rolls.sort()
	# Drop lowest (first element after sort)
	rolls.pop_front()
	return rolls[0] + rolls[1] + rolls[2]
