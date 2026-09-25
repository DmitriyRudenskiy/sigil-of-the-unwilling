class_name DNDShove

## D&D 5e Shove / Prone System
# Shove is an attack action using a contested Strength (Athletics) check.
# On success the target is knocked prone OR pushed 5 feet (attacker's choice).
# Requires a free hand and the target within reach.

enum ShoveOutcome {
	PREVENTED,
	PRONE,
	PUSHED
}

class ShoveResult:
	var outcome: ShoveOutcome = ShoveOutcome.PREVENTED
	var grappler_total: int = 0
	var target_total: int = 0
	var reason: String = ""


## Pre-flight checks: free hand and target in reach.
## Returns empty string if the shove is allowed, else a denial reason.
static func can_shove(p_has_hand_free: bool, p_target_in_reach: bool) -> String:
	if not p_has_hand_free:
		return "no free hand"
	if not p_target_in_reach:
		return "target out of reach"
	return ""


## Resolve a contested shove check.
## p_attacker_mod: attacker's Athletics modifier.
## p_target_mod: target's Athletics or Acrobatics modifier.
## p_outcome: what the attacker wants on success (PRONE or PUSHED).
static func attempt(
	rng: RandomNumberGenerator,
	p_attacker_mod: int,
	p_target_mod: int,
	p_outcome: ShoveOutcome,
	p_has_hand_free: bool = true,
	p_target_in_reach: bool = true
) -> ShoveResult:
	var r := ShoveResult.new()
	var denial := can_shove(p_has_hand_free, p_target_in_reach)
	if denial != "":
		r.reason = denial
		return r
	var a := DNDAbilityCheck.new()
	var t := DNDAbilityCheck.new()
	r.grappler_total = a.roll(rng, p_attacker_mod)
	r.target_total = t.roll(rng, p_target_mod)
	# Tie goes to the target (no shove).
	if r.grappler_total > r.target_total:
		r.outcome = p_outcome
		r.reason = "shove " + ("succeeded" if p_outcome == ShoveOutcome.PRONE else "pushed")
	else:
		r.outcome = ShoveOutcome.PREVENTED
		r.reason = "shove failed"
	return r


## A pushed creature that leaves a ledge takes falling damage
## (resolved by the height system, Phase 2).
const PUSH_DISTANCE_FEET := 5
