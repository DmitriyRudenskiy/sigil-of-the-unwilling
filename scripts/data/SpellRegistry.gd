extends Node
class_name SpellRegistry
## Autoload: Spells. 20 spells across 4 schools.

enum School { AIR, FIRE, WATER, EARTH }
enum TargetType { SINGLE_ENEMY, SINGLE_ALLY, ALL_ENEMIES, ALL_ALLIES, HEX_AOE, SELF }

class SpellDef extends RefCounted:
	var id: StringName
	var display_name: String
	var school: String = ""
	var school_int: int
	var level: int
	var base_mana: int
	var target_type: int
	var tags: Array[String] = []
	var desc: String
	var expert_desc: String


var _spells: Dictionary = {}

func _ready() -> void:
	ensure_definitions()

func reset() -> void:
	_spells.clear()

func ensure_definitions() -> void:
	if not _spells.is_empty():
		return

	# AIR
	_reg(&"magic_arrow", "Magic Arrow", School.AIR, 1, 5, TargetType.SINGLE_ENEMY, "10x SP dmg", "15x SP dmg", [])
	_reg(&"haste", "Haste", School.AIR, 1, 6, TargetType.SINGLE_ALLY, "+3 SPD", "All allies +3 SPD", [])
	_reg(&"lightning_bolt", "Lightning Bolt", School.AIR, 2, 10, TargetType.SINGLE_ENEMY, "25x SP dmg", "37x SP dmg", [])
	_reg(&"precision", "Precision", School.AIR, 2, 8, TargetType.ALL_ALLIES, "+3 ATK ranged", "All ranged +3 ATK", [])
	_reg(&"wind_wall", "Wind Wall", School.AIR, 3, 12, TargetType.ALL_ALLIES, "+50% DEF vs ranged", "All allies", [])

	# FIRE
	_reg(&"bloodlust", "Bloodlust", School.FIRE, 1, 5, TargetType.SINGLE_ALLY, "+3 ATK melee", "All melee +3 ATK", [])
	_reg(&"fireball", "Fireball", School.FIRE, 3, 15, TargetType.HEX_AOE, "20x SP dmg (7 hex)", "30x SP dmg", [])
	_reg(&"curse", "Curse", School.FIRE, 1, 6, TargetType.SINGLE_ENEMY, "-20% dmg", "All enemies -20% dmg", ["anti_magic"])
	_reg(&"misfortune", "Misfortune", School.FIRE, 2, 7, TargetType.SINGLE_ENEMY, "-2 Luck", "All enemies -2 Luck", [])
	_reg(&"armageddon", "Armageddon", School.FIRE, 4, 30, TargetType.ALL_ENEMIES, "40x SP dmg all", "Immune safe", [])

	# WATER
	_reg(&"bless", "Bless", School.WATER, 1, 5, TargetType.SINGLE_ALLY, "+20% max dmg", "All allies", [])
	_reg(&"cure", "Cure", School.WATER, 1, 6, TargetType.SINGLE_ALLY, "Heal 10x SP, clear debuffs", "All allies", [])
	_reg(&"slow", "Slow", School.WATER, 1, 6, TargetType.SINGLE_ENEMY, "-3 SPD", "All enemies", [])
	_reg(&"weakness", "Weakness", School.WATER, 2, 7, TargetType.SINGLE_ENEMY, "-3 ATK", "All enemies", [])
	_reg(&"town_portal", "Town Portal", School.WATER, 4, 20, TargetType.SELF, "Teleport to town", "Instant", [])

	# EARTH
	_reg(&"shield", "Shield", School.EARTH, 1, 5, TargetType.SINGLE_ALLY, "-15% melee dmg", "All allies", [])
	_reg(&"stoneskin", "Stoneskin", School.EARTH, 2, 8, TargetType.SINGLE_ALLY, "+3 DEF", "All allies", [])
	_reg(&"meteor_shower", "Meteor Shower", School.EARTH, 4, 25, TargetType.HEX_AOE, "30x SP dmg (7 hex)", "45x SP dmg", [])
	_reg(&"slow_mass", "Slow (Mass)", School.EARTH, 3, 12, TargetType.ALL_ENEMIES, "Slow all", "+Duration", [])
	_reg(&"resurrection", "Resurrection", School.EARTH, 4, 20, TargetType.SINGLE_ALLY, "Revive 20x SP HP", "Permanent", [])


func _reg(id: StringName, name: String, school: int, lvl: int, mana: int, target: int, desc: String, exp_desc: String, tags: Array[String]) -> void:
	var s := SpellDef.new()
	s.id = id
	s.display_name = name
	s.school = get_school_name(school)
	s.school_int = school
	s.level = lvl
	s.base_mana = mana
	s.target_type = target
	s.tags = tags
	s.desc = desc
	s.expert_desc = exp_desc
	_spells[id] = s


func get_spell(id: StringName) -> SpellDef:
	ensure_definitions()
	return _spells.get(id, null)


func get_all_spells() -> Array:
	ensure_definitions()
	var result: Array = []
	for id in _spells:
		result.append(_spells[id])
	result.sort_custom(func(a: SpellDef, b: SpellDef): return (a.school_int * 10 + a.level) < (b.school_int * 10 + b.level))
	return result


func get_spells_by_school(school: int) -> Array:
	ensure_definitions()
	var result: Array = []
	for id in _spells:
		var s: SpellDef = _spells[id]
		if s.school_int == school:
			result.append(s)
	return result


func get_school_name(school: int) -> String:
	match school:
		School.AIR: return "Air"
		School.FIRE: return "Fire"
		School.WATER: return "Water"
		School.EARTH: return "Earth"
	return "Unknown"
