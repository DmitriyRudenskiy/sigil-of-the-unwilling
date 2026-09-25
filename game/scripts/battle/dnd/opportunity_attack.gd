class_name DNDOpportunityAttack

## D&D 5e Opportunity Attacks
# A hostile creature that leaves a weapon's reach without Disengage
# provokes one opportunity attack from the defender, using its reaction.
#
# Triggers when:
#   - the mover is a creature (not an object/forced movement)
#   - the mover leaves the defender's reach
#   - the mover did NOT take the Disengage action
#   - the defender can see the mover and has a reaction available
#
# Does NOT trigger from:
#   - teleportation / any movement that doesn't pass through reach
#   - forced movement (shoved, pushed, grappled-dragged)
#   - flying out of reach vertically (no horizontal reach exit)

## Result of an opportunity attack resolution.
class OATResult:
	var triggered: bool = false
	var reason: String = ""


## Decide whether the defender may make an opportunity attack.
## p_mover_left_reach: mover started in reach and ends out of reach.
## p_disengaged: mover took the Disengage action this turn.
## p_is_forced: movement was forced (shove/push/grapple drag).
## p_is_teleport: movement did not pass through the reach (teleport, fly out).
## p_defender_can_see: line of sight to the mover.
## p_defender_has_reaction: defender still has its reaction this round.
static func should_trigger(
	p_mover_left_reach: bool,
	p_disengaged: bool,
	p_is_forced: bool,
	p_is_teleport: bool,
	p_defender_can_see: bool,
	p_defender_has_reaction: bool
) -> OATResult:
	var r := OATResult.new()
	if not p_mover_left_reach:
		r.reason = "mover did not leave reach"
		return r
	if p_is_forced:
		r.reason = "forced movement does not provoke"
		return r
	if p_is_teleport:
		r.reason = "teleportation does not provoke"
		return r
	if p_disengaged:
		r.reason = "Disengage prevents opportunity attacks"
		return r
	if not p_defender_can_see:
		r.reason = "defender cannot see the mover"
		return r
	if not p_defender_has_reaction:
		r.reason = "defender has no reaction left"
		return r
	r.triggered = true
	r.reason = "opportunity attack"
	return r


## Convenience: the opportunity attack is a single attack roll, not the
## full Attack action (no Extra Attack).
const IS_SINGLE_ATTACK := true
