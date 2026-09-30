class_name DnDTacticalBonuses
extends RefCounted

## dnd-class-race-tactical-bonuses: class/race -> tactical battle bonuses.
##
## D&D 5e classes and races grant concrete combat advantages (Fighting Style,
## Sneak Attack, Rage, Divine Grace, Stonecunning, Lucky, ...). This table maps a
## combatant's class_id / race_id to four tactical bonuses that
## DnDBattleBridge.resolve_attack applies:
##   attack  - flat bonus added to the d20 attack roll
##   defense - flat bonus added to the effective AC
##   crit    - extended crit range (crit on natural d20 >= 20 - crit; 0 = nat 20 only)
##   damage  - flat damage added to the weapon dice result
##
## Class and race bonuses ADD together (a character = class + race). Unknown ids
## yield 0 (the character fights without a bonus). Pure stack units and characters
## with no class/race (default "") get all-zero bonuses -> unchanged resolution.

## class_id -> {attack, defense, crit, damage}
const _CLASSES: Dictionary = {
	"fighter": {"attack": 0, "defense": 1, "crit": 0, "damage": 0},  # Fighting Style: Defense
	"rogue": {"attack": 0, "defense": 0, "crit": 1, "damage": 0},    # Sneak Attack (higher crit)
	"ranger": {"attack": 1, "defense": 0, "crit": 0, "damage": 0},   # Fighting Style: Archery
	"barbarian": {"attack": 0, "defense": 0, "crit": 0, "damage": 1}, # Rage
	"paladin": {"attack": 0, "defense": 1, "crit": 0, "damage": 1},   # Aura + Divine Smite
	"cleric": {"attack": 0, "defense": 1, "crit": 0, "damage": 0},    # Divine Grace
}

## race_id -> {attack, defense, crit, damage}
const _RACES: Dictionary = {
	"dwarf": {"attack": 0, "defense": 1, "crit": 0, "damage": 0},     # Dwarven Resilience
	"human": {"attack": 1, "defense": 0, "crit": 0, "damage": 0},     # Versatile / Martial Adept
	"dragonborn": {"attack": 0, "defense": 0, "crit": 0, "damage": 1}, # Draconic Ancestry
	"halfling": {"attack": 0, "defense": 0, "crit": 1, "damage": 0},   # Lucky
}


## Sum one bonus field across class + race. Unknown id / missing key -> 0.
static func _sum_field(class_id: String, race_id: String, field: String) -> int:
	var total: int = 0
	if _CLASSES.has(class_id):
		total += int((_CLASSES[class_id] as Dictionary).get(field, 0))
	if _RACES.has(race_id):
		total += int((_RACES[race_id] as Dictionary).get(field, 0))
	return total


## Flat bonus added to the d20 attack roll (class + race).
static func get_attack_bonus(class_id: String, race_id: String) -> int:
	return _sum_field(class_id, race_id, "attack")


## Flat bonus added to the effective AC (class + race).
static func get_defense_bonus(class_id: String, race_id: String) -> int:
	return _sum_field(class_id, race_id, "defense")


## Extended crit range (class + race). 0 = critical only on a natural 20.
static func get_crit_bonus(class_id: String, race_id: String) -> int:
	return _sum_field(class_id, race_id, "crit")


## Flat damage added to the weapon dice result (class + race).
static func get_damage_bonus(class_id: String, race_id: String) -> int:
	return _sum_field(class_id, race_id, "damage")
