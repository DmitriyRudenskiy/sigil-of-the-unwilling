class_name DNDActionEconomy

## D&D 5e Action Economy
# Tracks actions, bonus actions, and reactions per turn.
#
# Rules:
#   - one Action per turn
#   - one Bonus Action per turn (only if a class feature/spell allows one)
#   - one Reaction per round (resets at the start of your turn)
#   - the same standard action cannot be taken twice in one turn
#
# Actual action effects (Dash doubles movement, Dodge adds disadvantage, ...)
# are resolved by the battle integration (Phase 6, TASK_21).

enum ActionKind {
	ACTION,
	BONUS_ACTION,
	REACTION
}

## The 10 standard actions (PHB "Actions in Combat").
enum StandardAction {
	ATTACK,
	CAST_A_SPELL,
	DASH,
	DISENGAGE,
	DODGE,
	HELP,
	HIDE,
	READY,
	SEARCH,
	USE_AN_OBJECT
}

const ACTION_NAMES := {
	StandardAction.ATTACK: "Attack",
	StandardAction.CAST_A_SPELL: "Cast a Spell",
	StandardAction.DASH: "Dash",
	StandardAction.DISENGAGE: "Disengage",
	StandardAction.DODGE: "Dodge",
	StandardAction.HELP: "Help",
	StandardAction.HIDE: "Hide",
	StandardAction.READY: "Ready",
	StandardAction.SEARCH: "Search",
	StandardAction.USE_AN_OBJECT: "Use an Object"
}

# What was spent this turn
var action_used: bool = false
var action_taken: int = StandardAction.ATTACK
var bonus_action_used: bool = false
var reaction_available: bool = true
# Ready action: stored for trigger resolution (Phase 6)
var ready_action: int = -1


## Reset per-turn state. Called at the start of the combatant's turn;
## also restores the reaction (once per round).
func reset_turn() -> void:
	action_used = false
	bonus_action_used = false
	reaction_available = true
	ready_action = -1


## Can the combatant take a standard Action now?
func can_take_action() -> bool:
	return not action_used


## Can the combatant take a Bonus Action? p_has_bonus_source is true when a
## class feature or spell this turn provides one (e.g. Extra Attack does not).
func can_take_bonus_action(p_has_bonus_source: bool) -> bool:
	return p_has_bonus_source and not bonus_action_used


## Can the combatant use its Reaction?
func can_use_reaction() -> bool:
	return reaction_available


## Spend the Action on a standard action. Returns false if already spent.
## The same standard action cannot be taken twice in one turn.
func take_action(p_action: int) -> bool:
	if action_used:
		return false
	action_used = true
	action_taken = p_action
	return true


## Spend the Bonus Action.
func take_bonus_action() -> bool:
	if bonus_action_used:
		return false
	bonus_action_used = true
	return true


## Spend the Reaction (opportunity attack, counterspell, ...).
func use_reaction() -> bool:
	if not reaction_available:
		return false
	reaction_available = false
	return true


## True if the given standard action was already taken this turn.
func has_taken(p_action: int) -> bool:
	return action_used and action_taken == p_action


## Human-readable list of available actions for UI.
func available_actions() -> Array[String]:
	var out: Array[String] = []
	if can_take_action():
		for a in StandardAction.values():
			out.append(ACTION_NAMES[a])
	if can_take_bonus_action(true):
		out.append("Bonus Action")
	if can_use_reaction():
		out.append("Reaction")
	return out


## Serialize for save games.
func to_dict() -> Dictionary:
	return {
		"action_used": action_used,
		"action_taken": action_taken,
		"bonus_action_used": bonus_action_used,
		"reaction_available": reaction_available,
		"ready_action": ready_action
	}


## Deserialize from save data.
static func from_dict(data: Dictionary) -> DNDActionEconomy:
	var e = DNDActionEconomy.new()
	e.action_used = bool(data.get("action_used", false))
	e.action_taken = int(data.get("action_taken", 0))
	e.bonus_action_used = bool(data.get("bonus_action_used", false))
	e.reaction_available = bool(data.get("reaction_available", true))
	e.ready_action = int(data.get("ready_action", -1))
	return e
