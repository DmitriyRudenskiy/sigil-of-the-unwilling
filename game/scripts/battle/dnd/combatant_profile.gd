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
## battle-unit-vitals: character level. Display-only — it never enters an
## attack/AC/damage formula (owner rule 2026-10-18). Travels with the profile
## so a saved battle keeps the level it showed.
var level: int = 1
## battle-unit-vitals: current mana pool. -1 = not drawn yet; the pool size
## depends on `abilities`, which the factory fills AFTER _init, so it is
## materialized lazily on first access (see get_mana()).
var mana_current: int = -1

## Mana step in points (a +1 INT step buys this much more mana).
const MANA_PER_INT_STEP := 5
## Mana in INT-steps at Intelligence 10 (modifier +0).
const MANA_BASE_INT_STEPS := 2


## battle-unit-vitals: mana pool of a character = 5 × (2 + INT modifier), never
## below one step, so any profile-bearing unit can afford at least the default
## 5-point spell. A plain stack (no profile) has no mana at all — see
## BattleState.BattleUnit.has_mana().
func get_mana_max() -> int:
	return maxi(MANA_PER_INT_STEP, MANA_PER_INT_STEP * (MANA_BASE_INT_STEPS + abilities.get_int_mod()))


## Current mana, drawing the pool from Intelligence on first access.
func get_mana() -> int:
	if mana_current < 0:
		mana_current = get_mana_max()
	return mana_current


## Spend mana from the personal pool. False when the pool cannot cover it.
func spend_mana(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_mana() < amount:
		return false
	mana_current = get_mana() - amount
	return true


## Return mana (failed cast), capped at the pool size.
func refund_mana(amount: int) -> void:
	mana_current = mini(get_mana_max(), get_mana() + amount)


## Highest mental ability modifier (INT/WIS/CHA) — the ability a Rescue check
## of this character is made with (battle-unit-vitals).
func get_rescue_mod() -> int:
	return maxi(abilities.get_int_mod(), maxi(abilities.get_wis_mod(), abilities.get_cha_mod()))


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
		"level": level,
		"mana_current": mana_current,
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
	p.level = int(data.get("level", 1))
	# Absent key = pool not drawn yet (lazy, follows the current INT).
	p.mana_current = int(data.get("mana_current", -1))
	return p
