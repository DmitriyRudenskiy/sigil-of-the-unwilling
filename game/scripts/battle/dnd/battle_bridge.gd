class_name DnDBattleBridge
extends RefCounted

## Thin adapter that lets the existing battle framework use the D&D mechanics.
## Stack-model units (BattleUnit) keep working unchanged; a unit that carries a
## DnDCombatantProfile can resolve per-character D&D attacks through this bridge.
## This is the "DamageCalculator delegates to the D&D system" + "TurnManager uses
## InitiativeTracker" seam. It does NOT rewrite the live battle loop (that needs
## playtest — see tasks.md Phase 6 notes).


## Resolve one D&D attack: attack roll vs target AC, natural-20 crit, damage dice.
## Returns a result dict: {hit, crit, miss, roll_total, natural_roll, ac, damage,
## damage_breakdown, breakdown}.
static func resolve_attack(
	atk: DnDCombatantProfile,
	def: DnDCombatantProfile,
	rng: RandomNumberGenerator,
	p_advantage: bool = false,
	p_disadvantage: bool = false
) -> Dictionary:
	# dnd-class-race-tactical-bonuses: AC includes the class/race defense bonus.
	var ac: int = def.get_total_ac()
	var roll := DNDAttackRoll.new()
	# attack_bonus is folded into the roll's other_modifiers.
	var total: int = roll.roll(
		rng, atk.get_attack_ability_mod(), atk.proficiency_bonus, atk.get_attack_bonus(), p_advantage, p_disadvantage
	)
	var hit: bool = total >= ac
	# Crit range extended by crit_bonus (0 = critical only on a natural 20).
	var crit: bool = atk.crits_on(roll.get_natural_roll())
	var result := {
		"hit": hit,
		"crit": crit,
		"miss": not hit,
		"roll_total": total,
		"natural_roll": roll.get_natural_roll(),
		"ac": ac,
		"damage": 0,
		"damage_breakdown": "",
		"breakdown": roll.get_breakdown(),
	}
	if hit:
		var dmg: Dictionary = DNDDamageCalculator.new().calculate_damage(
			rng, atk.weapon, atk.get_attack_ability_mod(), crit
		)
		# dnd-class-race-tactical-bonuses: flat class/race damage bonus on top of dice.
		result["damage"] = int(dmg.get("total", 0)) + atk.get_damage_bonus()
		result["damage_breakdown"] = str(dmg.get("breakdown", ""))
	return result


## Build a D&D initiative tracker (d20 + DEX) from combatant profiles.
static func build_initiative(profiles: Array, rng: RandomNumberGenerator) -> DNDInitiativeTracker:
	var tracker := DNDInitiativeTracker.new()
	for p in profiles:
		var prof: DnDCombatantProfile = p
		tracker.roll_initiative(prof.id, prof.name, prof.abilities.get_dex_mod(), rng)
	return tracker


## dnd-verticality-falling 3.2: single entry point for the battle framework
## to resolve a fall (movement step or push off a ledge).
## Resolution happens at the moment of the move/push — before the next turn —
## so initiative order is never disturbed.
## p_condition_mgr receives PRONE on a failed DEX save (optional).
static func resolve_fall(
	profile: DnDCombatantProfile,
	p_from_level: int,
	p_to_level: int,
	rng: RandomNumberGenerator,
	p_condition_mgr: DNDConditionManager = null,
	p_proficient: bool = false
) -> DNDFallingDamage.FallResult:
	return DNDFallingDamage.resolve(
		p_from_level, p_to_level, rng, profile.get_save_mod(DNDAbilityScores.Ability.DEX),
		p_condition_mgr, p_proficient
	)
