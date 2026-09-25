class_name DNDConditionManager

## D&D 5e Conditions System
# Tracks the 14 combat conditions and their mechanical effects.
# Pure data + effect query; the battle system reads the merged effects
# during attack/ability/save resolution (Phase 6).

enum Condition {
	BLINDED,
	CHARMED,
	DEAFENED,
	FRIGHTENED,
	GRAPPLED,
	INCAPACITATED,
	INVISIBLE,
	PARALYZED,
	PETRIFIED,
	POISONED,
	PRONE,
	RESTRAINED,
	STUNNED,
	UNCONSCIOUS
}

const CONDITION_NAMES := {
	Condition.BLINDED: "Blinded",
	Condition.CHARMED: "Charmed",
	Condition.DEAFENED: "Deafened",
	Condition.FRIGHTENED: "Frightened",
	Condition.GRAPPLED: "Grappled",
	Condition.INCAPACITATED: "Incapacitated",
	Condition.INVISIBLE: "Invisible",
	Condition.PARALYZED: "Paralyzed",
	Condition.PETRIFIED: "Petrified",
	Condition.POISONED: "Poisoned",
	Condition.PRONE: "Prone",
	Condition.RESTRAINED: "Restrained",
	Condition.STUNNED: "Stunned",
	Condition.UNCONSCIOUS: "Unconscious"
}

## Merged mechanical effects of all active conditions.
class Effects:
	var attack_disadvantage: bool = false        # your attack rolls
	var attack_advantage: bool = false           # your attack rolls (invisibility)
	var attack_advantage_against: bool = false   # attacks against you
	var ability_check_disadvantage: bool = false
	var save_disadvantage: bool = false
	var auto_fail_str_dex_saves: bool = false
	var speed_zero: bool = false
	var incapacitated: bool = false
	var crit_on_19_20: bool = false
	var immune_to_damage: bool = false
	var cannot_move_closer: bool = false         # frightened
	var stand_up_costs_half_move: bool = false   # prone
	var cannot_attack_charmer: bool = false      # charmed


# Per-condition effect signature (data-driven).
const EFFECTS := {
	Condition.BLINDED:      { "atk_dis": true, "atk_adv_against": true },
	Condition.CHARMED:      { "no_attack_charmer": true },
	Condition.DEAFENED:     { "atk_adv_against": true },
	Condition.FRIGHTENED:   { "check_dis": true, "atk_dis": true, "no_move_closer": true },
	Condition.GRAPPLED:     { "speed_zero": true },
	Condition.INCAPACITATED:{ "incap": true },
	Condition.INVISIBLE:    { "atk_adv": true },
	Condition.PARALYZED:    { "incap": true, "atk_adv_against": true, "auto_fail": true, "crit19": true },
	Condition.PETRIFIED:    { "incap": true, "atk_adv_against": true, "auto_fail": true, "crit19": true, "immune": true },
	Condition.POISONED:     { "atk_dis": true, "check_dis": true },
	Condition.PRONE:        { "atk_dis": true, "atk_adv_against": true, "stand_up": true },
	Condition.RESTRAINED:   { "speed_zero": true, "atk_adv_against": true, "atk_dis": true, "save_dis": true },
	Condition.STUNNED:      { "incap": true, "atk_adv_against": true, "auto_fail": true, "crit19": true },
	Condition.UNCONSCIOUS:  { "incap": true, "atk_adv_against": true, "auto_fail": true, "crit19": true }
}

# condition -> turns remaining (-1 = until removed)
var active: Dictionary = {}


## Apply a condition. p_duration is turns remaining, or -1 for "until removed".
func apply(cond: int, p_duration: int = -1) -> void:
	active[cond] = p_duration


## Remove a condition.
func remove(cond: int) -> void:
	active.erase(cond)


## True if the condition is currently active.
func has(cond: int) -> bool:
	return active.has(cond)


## All active conditions.
func get_active() -> Array:
	return active.keys()


## Decrement timed conditions; expired ones are removed.
## Returns the list of conditions that expired this tick.
func tick() -> Array:
	var expired: Array = []
	for cond in active.keys():
		var d: int = active[cond]
		if d < 0:
			continue
		if d <= 1:
			expired.append(cond)
			active.erase(cond)
		else:
			active[cond] = d - 1
	return expired


## Merge all active conditions into a single Effects struct.
func get_effects() -> Effects:
	var e := Effects.new()
	for cond in active.keys():
		var sig: Dictionary = EFFECTS[cond]
		if sig.has("atk_dis"): e.attack_disadvantage = true
		if sig.has("atk_adv_against"): e.attack_advantage_against = true
		if sig.has("atk_adv"): e.attack_advantage = true
		if sig.has("check_dis"): e.ability_check_disadvantage = true
		if sig.has("save_dis"): e.save_disadvantage = true
		if sig.has("auto_fail"): e.auto_fail_str_dex_saves = true
		if sig.has("speed_zero"): e.speed_zero = true
		if sig.has("incap"): e.incapacitated = true
		if sig.has("crit19"): e.crit_on_19_20 = true
		if sig.has("immune"): e.immune_to_damage = true
		if sig.has("no_move_closer"): e.cannot_move_closer = true
		if sig.has("stand_up"): e.stand_up_costs_half_move = true
		if sig.has("no_attack_charmer"): e.cannot_attack_charmer = true
	return e


## Serialize for save games.
func to_dict() -> Dictionary:
	return active.duplicate()


## Deserialize from save data.
static func from_dict(data: Dictionary) -> DNDConditionManager:
	var m = DNDConditionManager.new()
	m.active = data.duplicate()
	return m
