class_name DNDProficiencySystem

## D&D 5e Proficiency Bonus System
# Handles proficiency bonus progression and proficiency checks

# Proficiency bonus by character level (PHB p.15)
const PROFICIENCY_BY_LEVEL = {
	1: 2, 2: 2, 3: 2, 4: 2,  # Levels 1-4
	5: 3, 6: 3, 7: 3, 8: 3,  # Levels 5-8
	9: 4, 10: 4, 11: 4, 12: 4,  # Levels 9-12
	13: 5, 14: 5, 15: 5, 16: 5,  # Levels 13-16
	17: 6, 18: 6, 19: 6, 20: 6   # Levels 17-20
}

enum ProficiencyType {
	WEAPON,
	ARMOR,
	SAVE,
	SKILL,
	TOOL,
	LANGUAGE
}

# Character level (1-20)
var level: int = 1

# Proficiency sets (arrays of IDs/names)
var weapon_proficiencies: Array[String] = []
var armor_proficiencies: Array[String] = []
var save_proficiencies: Array[String] = []  # "STR", "DEX", etc.
var skill_proficiencies: Array[String] = []  # "Acrobatics", "Stealth", etc.
var tool_proficiencies: Array[String] = []
var language_proficiencies: Array[String] = []

# Expertise skills (double proficiency bonus)
var expertise_skills: Array[String] = []


func _init(p_level: int = 1):
	level = clamp(p_level, 1, 20)


## Get proficiency bonus based on current level
func get_proficiency_bonus() -> int:
	if level in PROFICIENCY_BY_LEVEL:
		return PROFICIENCY_BY_LEVEL[level]
	# Fallback calculation: +2 at level 1, increases by 1 every 4 levels
	return 2 + ((level - 1) / 4)


## Check if proficient with a weapon
func is_weapon_proficient(weapon_id: String) -> bool:
	return weapon_id in weapon_proficiencies


## Check if proficient with an armor type
func is_armor_proficient(armor_type: String) -> bool:
	return armor_type in armor_proficiencies


## Check if proficient with a saving throw
func is_save_proficient(ability: String) -> bool:
	return ability in save_proficiencies


## Check if proficient with a skill
func is_skill_proficient(skill_name: String) -> bool:
	return skill_name in skill_proficiencies


## Check if has expertise in a skill (double proficiency)
func has_expertise(skill_name: String) -> bool:
	return skill_name in expertise_skills


## Add weapon proficiency
func add_weapon_proficiency(weapon_id: String):
	if weapon_id not in weapon_proficiencies:
		weapon_proficiencies.append(weapon_id)


## Remove weapon proficiency
func remove_weapon_proficiency(weapon_id: String):
	var idx = weapon_proficiencies.find(weapon_id)
	if idx >= 0:
		weapon_proficiencies.remove_at(idx)


## Add armor proficiency
func add_armor_proficiency(armor_type: String):
	if armor_type not in armor_proficiencies:
		armor_proficiencies.append(armor_type)


## Add saving throw proficiency
func add_save_proficiency(ability: String):
	if ability not in save_proficiencies:
		save_proficiencies.append(ability)


## Add skill proficiency
func add_skill_proficiency(skill_name: String):
	if skill_name not in skill_proficiencies:
		skill_proficiencies.append(skill_name)


## Add expertise to a skill (must already be proficient)
func add_expertise(skill_name: String):
	if skill_name in skill_proficiencies and skill_name not in expertise_skills:
		expertise_skills.append(skill_name)


## Calculate total proficiency bonus for a skill
func get_skill_bonus(skill_name: String) -> int:
	var bonus = get_proficiency_bonus()
	if has_expertise(skill_name):
		return bonus * 2
	elif is_skill_proficient(skill_name):
		return bonus
	return 0


## Level up character
func level_up():
	if level < 20:
		level += 1


## Set character level directly
func set_level(new_level: int):
	level = clamp(new_level, 1, 20)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"level": level,
		"weapon_proficiencies": weapon_proficiencies.duplicate(),
		"armor_proficiencies": armor_proficiencies.duplicate(),
		"save_proficiencies": save_proficiencies.duplicate(),
		"skill_proficiencies": skill_proficiencies.duplicate(),
		"tool_proficiencies": tool_proficiencies.duplicate(),
		"language_proficiencies": language_proficiencies.duplicate(),
		"expertise_skills": expertise_skills.duplicate()
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> DNDProficiencySystem:
	var prof = DNDProficiencySystem.new()
	prof.level = data.get("level", 1)
	prof.weapon_proficiencies = data.get("weapon_proficiencies", []).duplicate()
	prof.armor_proficiencies = data.get("armor_proficiencies", []).duplicate()
	prof.save_proficiencies = data.get("save_proficiencies", []).duplicate()
	prof.skill_proficiencies = data.get("skill_proficiencies", []).duplicate()
	prof.tool_proficiencies = data.get("tool_proficiencies", []).duplicate()
	prof.language_proficiencies = data.get("language_proficiencies", []).duplicate()
	prof.expertise_skills = data.get("expertise_skills", []).duplicate()
	return prof


## Get proficiency bonus multiplier (for expertise check)
func get_proficiency_multiplier(skill_name: String) -> float:
	if has_expertise(skill_name):
		return 2.0
	elif is_skill_proficient(skill_name):
		return 1.0
	return 0.0
