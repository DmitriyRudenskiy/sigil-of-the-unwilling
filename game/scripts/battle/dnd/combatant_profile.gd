class_name DnDCombatantProfile
extends RefCounted

## D&D 5e combatant profile — the per-character stat block a battle unit can carry.
## This is the "Combatant extends with D&D stats" seam: a BattleUnit may hold an
## optional DnDCombatantProfile (null = pure stack-model unit, backward compatible).
var id: String = ""
var name: String = ""
var abilities: DNDAbilityScores
var proficiency_bonus: int = 2
var armor: DNDArmorClass
var weapon: String = "longsword"
var is_ranged: bool = false
## dnd-live-battle-wiring: max HP of the character (hit-dice + CON in full D&D;
## explicit here). BattleUnit tracks the current pool from this value.
var max_hp: int = 10
## dnd-class-race-tactical-bonuses: optional class/race ids (default "" = no bonus).
## Tactical bonuses are derived from these via DnDTacticalBonuses.
var class_id: String = ""
var race_id: String = ""


func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	name = p_name
	abilities = DNDAbilityScores.new()
	armor = DNDArmorClass.new()


## Armor Class (10 + DEX when unarmored, armor-capped otherwise).
## Syncs the armor DEX modifier from the ability block so AC tracks DEX.
func get_ac() -> int:
	armor.dex_modifier = abilities.get_dex_mod()
	return armor.calculate_ac()


## Attack ability modifier: STR for melee, DEX for ranged.
func get_attack_ability_mod() -> int:
	return abilities.get_dex_mod() if is_ranged else abilities.get_str_mod()


## dnd-class-race-tactical-bonuses: tactical bonuses from class_id/race_id.
## All default to 0 when class_id/race_id are empty (backward compatible).


## Flat bonus added to the d20 attack roll.
func get_attack_bonus() -> int:
	return DnDTacticalBonuses.get_attack_bonus(class_id, race_id)


## Flat bonus added to the effective AC.
func get_defense_bonus() -> int:
	return DnDTacticalBonuses.get_defense_bonus(class_id, race_id)


## Extended crit range (0 = critical only on a natural 20).
func get_crit_bonus() -> int:
	return DnDTacticalBonuses.get_crit_bonus(class_id, race_id)


## Flat damage added to the weapon dice result.
func get_damage_bonus() -> int:
	return DnDTacticalBonuses.get_damage_bonus(class_id, race_id)


## Effective AC including the class/race defense bonus.
func get_total_ac() -> int:
	return get_ac() + get_defense_bonus()


## Is a given natural d20 roll a critical hit? Crit range is extended by
## crit_bonus (0 = critical only on a natural 20). Testable seam for the bridge.
func crits_on(natural: int) -> bool:
	return natural >= (20 - get_crit_bonus())


## Saving throw modifier for an ability (no proficiency added here).
func get_save_mod(ability: DNDAbilityScores.Ability) -> int:
	return DNDAbilityScores.get_ability_modifier(abilities.get_score(ability))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"abilities": abilities.to_dict(),
		"proficiency_bonus": proficiency_bonus,
		"armor": armor.to_dict(),
		"weapon": weapon,
		"is_ranged": is_ranged,
		"max_hp": max_hp,
		"class_id": class_id,
		"race_id": race_id,
	}


static func from_dict(data: Dictionary) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(str(data.get("id", "")), str(data.get("name", "")))
	p.abilities = DNDAbilityScores.from_dict(data.get("abilities", {}))
	p.proficiency_bonus = int(data.get("proficiency_bonus", 2))
	p.armor = DNDArmorClass.from_dict(data.get("armor", {}))
	p.weapon = str(data.get("weapon", "longsword"))
	p.is_ranged = bool(data.get("is_ranged", false))
	p.max_hp = int(data.get("max_hp", 10))
	p.class_id = str(data.get("class_id", ""))
	p.race_id = str(data.get("race_id", ""))
	return p
