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
	}


static func from_dict(data: Dictionary) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(str(data.get("id", "")), str(data.get("name", "")))
	p.abilities = DNDAbilityScores.from_dict(data.get("abilities", {}))
	p.proficiency_bonus = int(data.get("proficiency_bonus", 2))
	p.armor = DNDArmorClass.from_dict(data.get("armor", {}))
	p.weapon = str(data.get("weapon", "longsword"))
	p.is_ranged = bool(data.get("is_ranged", false))
	return p
