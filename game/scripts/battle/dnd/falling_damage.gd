class_name DNDFallingDamage
extends RefCounted

## D&D 5e Falling Damage (dnd-verticality-falling, TASK_12)
# 1d6 bludgeoning per 10 feet fallen, capped at 20d6.
# Landing: prone unless the creature passes a DEX saving throw DC 15.
#
# Trigger (design.md 0.2): a step that drops MORE than 1 elevation level
# (5 feet) is an uncontrolled fall. A drop of 1 level or less is a
# controlled descent (no damage, no save). Pushed creatures (shove) that
# end up more than 1 level below their start cell fall the same way.
#
# Elevation levels are 5-foot increments (DNDElevationSystem.FEET_PER_LEVEL).

const FEET_PER_LEVEL := 5
const FEET_PER_D6 := 10
const MAX_D6 := 20
const PRONE_SAVE_DC := 15
## Maximum controlled descent per step (levels). More than this = fall.
const CONTROLLED_DROP_LEVELS := 1

class FallResult:
	var fell: bool = false
	var feet: int = 0
	var damage: int = 0
	var prone: bool = false
	var save: DNDSavingThrow.SaveResult = null


## True if dropping from p_from_level to p_to_level is an uncontrolled fall.
static func is_fall(p_from_level: int, p_to_level: int) -> bool:
	return (p_from_level - p_to_level) > CONTROLLED_DROP_LEVELS


## Fall distance in feet (0 when the drop is not a fall).
static func fall_feet(p_from_level: int, p_to_level: int) -> int:
	if not is_fall(p_from_level, p_to_level):
		return 0
	return (p_from_level - p_to_level) * FEET_PER_LEVEL


## Number of d6 dice for a fall of p_feet feet (0..20).
static func dice_count(p_feet: int) -> int:
	return clampi(int(p_feet) / FEET_PER_D6, 0, MAX_D6)


## Roll falling damage for p_feet feet (bludgeoning).
static func roll_damage(p_feet: int, rng: RandomNumberGenerator) -> int:
	var total := 0
	for i in dice_count(p_feet):
		total += rng.randi_range(1, 6)
	return total


## Full resolution: damage + prone + DEX save DC 15.
## p_condition_mgr receives PRONE on a failed save (optional).
## p_proficient adds the proficiency bonus to the save (rarely applies).
static func resolve(
	p_from_level: int,
	p_to_level: int,
	rng: RandomNumberGenerator,
	p_dex_mod: int,
	p_condition_mgr: DNDConditionManager = null,
	p_proficient: bool = false
) -> FallResult:
	var r := FallResult.new()
	if not is_fall(p_from_level, p_to_level):
		return r
	r.fell = true
	r.feet = fall_feet(p_from_level, p_to_level)
	r.damage = roll_damage(r.feet, rng)
	r.save = DNDSavingThrow.roll(rng, p_dex_mod, 0, p_proficient, PRONE_SAVE_DC)
	r.prone = not DNDSavingThrow.succeeded(r.save)
	if r.prone and p_condition_mgr != null:
		p_condition_mgr.apply(DNDConditionManager.Condition.PRONE)
	return r
