class_name DNDCoverCalculator

## D&D 5e Cover System
# Derived from 3D line of sight over the elevation map:
#   FULL  — line of fire blocked (target cannot be targeted)
#   HALF  — a wall within 1 level (5 ft) of the line of fire (+2 AC, +2 DEX saves)
#   NONE  — clear line of fire
# THREE_QUARTERS is kept for completeness but the elevation model does not
# produce it (needs per-face wall geometry, out of scope).

enum CoverLevel {
	NONE,
	HALF,
	THREE_QUARTERS,
	FULL
}

const AC_BONUS := {CoverLevel.NONE: 0, CoverLevel.HALF: 2, CoverLevel.THREE_QUARTERS: 5, CoverLevel.FULL: 99}
const DEX_SAVE_BONUS := {CoverLevel.NONE: 0, CoverLevel.HALF: 2, CoverLevel.THREE_QUARTERS: 5, CoverLevel.FULL: 99}

## Clearance (in feet) at or below which a wall counts as half cover.
const HALF_COVER_CLEARANCE_FEET := 5.0


## Cover for the target against an attack from the attacker's cell.
static func calculate(elev: DNDElevationSystem, attacker: Vector2i, target: Vector2i) -> CoverLevel:
	var clearance := DNDLineOfSight.min_clearance(elev, attacker, target)
	if clearance < 0.0:
		return CoverLevel.FULL
	if clearance <= HALF_COVER_CLEARANCE_FEET:
		return CoverLevel.HALF
	return CoverLevel.NONE


## AC bonus for a cover level (FULL = 99, i.e. untargetable).
static func ac_bonus(level: CoverLevel) -> int:
	return int(AC_BONUS[level])


## DEX save bonus for a cover level.
static func dex_save_bonus(level: CoverLevel) -> int:
	return int(DEX_SAVE_BONUS[level])


## A target behind full cover cannot be targeted.
static func is_targetable(level: CoverLevel) -> bool:
	return level != CoverLevel.FULL


## Human-readable description for UI.
static func describe(level: CoverLevel) -> String:
	match level:
		CoverLevel.NONE: return "no cover"
		CoverLevel.HALF: return "half cover (+2 AC)"
		CoverLevel.THREE_QUARTERS: return "three-quarters cover (+5 AC)"
		CoverLevel.FULL: return "full cover (untargetable)"
	return "no cover"
