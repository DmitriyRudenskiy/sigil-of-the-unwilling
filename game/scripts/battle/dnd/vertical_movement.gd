class_name DNDVerticalMovement
extends RefCounted

## D&D 5e Vertical Movement (dnd-verticality-falling, TASK_11)
# Climbing, flying, and jumping on the D&D battle board
# (DNDElevationSystem, 5-foot levels per cell).
#
# Rules (design.md):
#   - Climbing up costs x2 movement per level (difficult terrain).
#   - A climb of CLIMB_CHECK_THRESHOLD+ levels in one step is "difficult":
#     requires an Athletics check, DC = clamp(10 + 5*(levels-1), 10, 15).
#     Failure: the unit stays put, the movement cost is still spent.
#   - A jump replaces the Athletics check when the climb fits within
#     jump height (3 + STR mod feet).
#   - Flying ignores elevation entirely: any step costs 1, no checks,
#     no falling.
#   - A drop of more than DNDFallingDamage.CONTROLLED_DROP_LEVELS levels
#     is an uncontrolled fall (DNDFallingDamage.resolve).

const BASE_STEP_COST := 1
const CLIMB_COST_MULTIPLIER := 2
const CLIMB_CHECK_THRESHOLD := 2
const CLIMB_DC_MIN := 10
const CLIMB_DC_MAX := 15
const JUMP_BASE_FEET := 3
const JUMP_DISTANCE_BASE := 10
const FEET_PER_LEVEL := 5


class MoveResult:
	var allowed: bool = true
	var cost: int = BASE_STEP_COST
	var needs_check: bool = false
	var dc: int = 0
	var fell: bool = false
	var fall_feet: int = 0
	var reason: String = ""


## Athletics DC for climbing p_levels levels in one step (10..15).
static func climb_dc(p_levels: int) -> int:
	return clampi(CLIMB_DC_MIN + 5 * (p_levels - 1), CLIMB_DC_MIN, CLIMB_DC_MAX)


## Vertical jump height in feet (5e: 3 + STR modifier).
static func jump_height_feet(p_str_mod: int) -> int:
	return JUMP_BASE_FEET + p_str_mod


## Horizontal jump distance in feet (5e: 10 + STR modifier).
static func jump_distance_feet(p_str_mod: int) -> int:
	return JUMP_DISTANCE_BASE + p_str_mod


## True if a jump of p_str_mod reaches p_levels levels without a check.
static func can_jump_up(p_levels: int, p_str_mod: int) -> bool:
	return p_levels * FEET_PER_LEVEL <= jump_height_feet(p_str_mod)


## Movement cost (points, 1 = 5 feet) of stepping from p_from_level to
## p_to_level. Flying always costs 1; a fall costs 1 (the fall itself is
## resolved separately via DNDFallingDamage).
static func step_cost(p_from_level: int, p_to_level: int, p_flying: bool) -> int:
	if p_flying:
		return BASE_STEP_COST
	if p_to_level > p_from_level:
		return CLIMB_COST_MULTIPLIER * (p_to_level - p_from_level)
	return BASE_STEP_COST


## Resolve one movement step between two cells.
## p_str_mod / p_dex_mod: the mover's ability modifiers.
## Returns a MoveResult; on an Athletics failure `allowed` is false and
## `cost` is the (already spent) movement cost.
static func resolve_step(
	rng: RandomNumberGenerator,
	p_from_level: int,
	p_to_level: int,
	p_str_mod: int,
	p_flying: bool = false
) -> MoveResult:
	var r := MoveResult.new()
	if p_flying:
		r.cost = BASE_STEP_COST
		return r

	# Uncontrolled fall (drop of more than 1 level).
	if DNDFallingDamage.is_fall(p_from_level, p_to_level):
		r.cost = BASE_STEP_COST
		r.fell = true
		r.fall_feet = DNDFallingDamage.fall_feet(p_from_level, p_to_level)
		r.reason = "fall"
		return r

	if p_to_level > p_from_level:
		var levels := p_to_level - p_from_level
		r.cost = step_cost(p_from_level, p_to_level, false)
		if can_jump_up(levels, p_str_mod):
			# Jump replaces the Athletics check (when one would apply).
			r.reason = "jump"
			return r
		if levels >= CLIMB_CHECK_THRESHOLD:
			r.needs_check = true
			r.dc = climb_dc(levels)
			var check := DNDAbilityCheck.new()
			check.roll(rng, p_str_mod)
			if not check.meets(r.dc):
				r.allowed = false
				r.reason = "athletics_failed"
			else:
				r.reason = "climb"
		else:
			# 1-level climb: automatic, cost x2 only.
			r.reason = "climb"
		return r

	# Flat or controlled descent (1 level or less).
	r.cost = BASE_STEP_COST
	r.reason = "flat" if p_to_level == p_from_level else "descent"
	return r
