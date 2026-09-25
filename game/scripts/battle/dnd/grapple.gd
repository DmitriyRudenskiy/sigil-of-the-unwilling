class_name DNDGrapple

## D&D 5e Grapple System
# Grappling is a special melee attack using a contested Strength (Athletics)
# check. A grappled creature's speed becomes 0 and the condition ends when
# the grappler is incapacitated or moves more than 5 ft away.

## Outcome of a grapple attempt.
class GrappleResult:
	var success: bool = false
	var grappler_total: int = 0
	var target_total: int = 0
	var reason: String = ""


## Resolve a contested grapple check.
## p_grappler_mod: grappler's Athletics modifier.
## p_target_mod: target's Athletics or Acrobatics modifier (target's choice).
## Advantage/disadvantage applied to the grappler's roll.
static func attempt(
	rng: RandomNumberGenerator,
	p_grappler_mod: int,
	p_target_mod: int,
	p_grappler_advantage: bool = false,
	p_grappler_disadvantage: bool = false
) -> GrappleResult:
	var r := GrappleResult.new()
	var g := DNDAbilityCheck.new()
	var t := DNDAbilityCheck.new()
	r.grappler_total = g.roll(rng, p_grappler_mod, p_grappler_advantage, p_grappler_disadvantage)
	r.target_total = t.roll(rng, p_target_mod)
	# Tie goes to the grappler (the attacker).
	r.success = r.grappler_total >= r.target_total
	r.reason = "grapple " + ("succeeded" if r.success else "failed")
	return r


## A grappled creature's speed is 0.
static func grappled_speed(_base_speed: int) -> int:
	return 0


## A grappled creature can still move the grapple, but at half speed.
static func grappler_move_speed(base_speed: int) -> int:
	return base_speed / 2


## The grapple ends when the grappler is incapacitated.
static func ends_when_grappler_incapacitated() -> bool:
	return true


## A grappled creature can use its action to escape via a contested check.
## Returns true if it breaks free.
static func escape(
	rng: RandomNumberGenerator,
	p_athlete_mod: int,
	p_grappler_mod: int
) -> bool:
	var e := DNDAbilityCheck.new()
	var g := DNDAbilityCheck.new()
	e.roll(rng, p_athlete_mod)
	g.roll(rng, p_grappler_mod)
	# Tie goes to the grappler (stays grappled).
	return e.total > g.total
