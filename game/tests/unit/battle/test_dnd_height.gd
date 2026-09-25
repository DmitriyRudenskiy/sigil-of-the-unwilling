extends BaseTest

## Unit-тесты D&D 5e height & positioning (dnd-battle-system Phase 2, TASK_07..10):
## elevation_system, height_modifier, line_of_sight, cover_calculator.

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260925

# ---------- TASK_07: Elevation ----------

func test_elevation_set_get_default() -> void:
	var e = DNDElevationSystem.new(10, 6)
	assert_that(e.get_elevation(Vector2i(3, 2))).is_equal(0)
	e.set_elevation(Vector2i(3, 2), 2)
	assert_that(e.get_elevation(Vector2i(3, 2))).is_equal(2)

func test_elevation_out_of_bounds_is_ground() -> void:
	var e = DNDElevationSystem.new(10, 6)
	e.set_elevation(Vector2i(9, 5), 4)
	assert_that(e.get_elevation(Vector2i(10, 5))).is_equal(0)
	assert_that(e.get_elevation(Vector2i(-1, 0))).is_equal(0)

func test_elevation_height_feet() -> void:
	var e = DNDElevationSystem.new(5, 5)
	e.set_elevation(Vector2i(2, 2), 2)
	assert_that(e.height_feet(Vector2i(2, 2))).is_equal(10)

func test_elevation_high_ground() -> void:
	var e = DNDElevationSystem.new(5, 5)
	e.set_elevation(Vector2i(2, 2), 3)
	assert_that(e.is_high_ground(Vector2i(2, 2))).is_true()
	e.set_elevation(Vector2i(3, 2), 3)
	assert_that(e.is_high_ground(Vector2i(2, 2))).is_false()

func test_elevation_serialization_roundtrip() -> void:
	var e = DNDElevationSystem.new(12, 8)
	e.set_elevation(Vector2i(1, 1), 2)
	e.set_elevation(Vector2i(7, 3), 5)
	var d = e.to_dict()
	var e2 = DNDElevationSystem.from_dict(d)
	assert_that(e2.width).is_equal(12)
	assert_that(e2.height).is_equal(8)
	assert_that(e2.get_elevation(Vector2i(1, 1))).is_equal(2)
	assert_that(e2.get_elevation(Vector2i(7, 3))).is_equal(5)
	assert_that(e2.get_elevation(Vector2i(0, 0))).is_equal(0)

# ---------- TASK_08: High Ground Bonuses ----------

func test_ranged_downhill_table() -> void:
	# Archer on elevation 2 vs target on 0 (spec scenario) -> +1
	assert_that(DNDHeightModifier.attack_bonus(2, 0, true)).is_equal(1)
	assert_that(DNDHeightModifier.attack_bonus(3, 0, true)).is_equal(2)
	assert_that(DNDHeightModifier.attack_bonus(4, 0, true)).is_equal(3)
	assert_that(DNDHeightModifier.attack_bonus(6, 0, true)).is_equal(3)

func test_melee_downhill_table() -> void:
	assert_that(DNDHeightModifier.attack_bonus(1, 0, false)).is_equal(0)
	assert_that(DNDHeightModifier.attack_bonus(2, 0, false)).is_equal(1)
	assert_that(DNDHeightModifier.attack_bonus(3, 0, false)).is_equal(2)
	assert_that(DNDHeightModifier.attack_bonus(5, 0, false)).is_equal(2)

func test_uphill_penalties() -> void:
	# Ranged uphill: unit on 0 shoots target on 2 (spec scenario) -> penalty
	assert_that(DNDHeightModifier.attack_bonus(0, 1, true)).is_equal(-1)
	assert_that(DNDHeightModifier.attack_bonus(0, 2, true)).is_equal(-2)
	assert_that(DNDHeightModifier.attack_bonus(0, 5, true)).is_equal(-2)
	# Melee: 1 level up gives no penalty (spec)
	assert_that(DNDHeightModifier.attack_bonus(0, 1, false)).is_equal(0)
	assert_that(DNDHeightModifier.attack_bonus(0, 2, false)).is_equal(-1)
	assert_that(DNDHeightModifier.attack_bonus(0, 4, false)).is_equal(-3)

func test_same_level_no_modifier() -> void:
	assert_that(DNDHeightModifier.attack_bonus(3, 3, true)).is_equal(0)
	assert_that(DNDHeightModifier.attack_bonus(3, 3, false)).is_equal(0)

func test_ranged_range_bonus_from_height() -> void:
	assert_that(DNDHeightModifier.range_bonus(2, 0)).is_equal(1)
	assert_that(DNDHeightModifier.range_bonus(4, 0)).is_equal(2)
	assert_that(DNDHeightModifier.range_bonus(1, 0)).is_equal(0)
	assert_that(DNDHeightModifier.range_bonus(0, 2)).is_equal(0)

# ---------- TASK_10: 3D Line of Sight ----------

func test_los_flat_ground_clear() -> void:
	var e = DNDElevationSystem.new(10, 6)
	assert_that(DNDLineOfSight.has_line_of_sight(e, Vector2i(0, 0), Vector2i(9, 5))).is_true()

func test_los_same_cell() -> void:
	var e = DNDElevationSystem.new(5, 5)
	assert_that(DNDLineOfSight.has_line_of_sight(e, Vector2i(2, 2), Vector2i(2, 2))).is_true()

func test_los_wall_blocks() -> void:
	# Spec scenario: wall between archer and target.
	var e = DNDElevationSystem.new(10, 6)
	e.set_elevation(Vector2i(2, 0), 3)  # 15-ft wall on a flat row
	assert_that(DNDLineOfSight.has_line_of_sight(e, Vector2i(0, 0), Vector2i(4, 0))).is_false()

func test_los_over_low_wall() -> void:
	# Shooter on a 2-level rise clears a 1-level wall.
	var e = DNDElevationSystem.new(10, 6)
	e.set_elevation(Vector2i(0, 0), 2)
	e.set_elevation(Vector2i(2, 0), 1)
	assert_that(DNDLineOfSight.has_line_of_sight(e, Vector2i(0, 0), Vector2i(4, 0))).is_true()

func test_los_diagonal_wall_blocks() -> void:
	var e = DNDElevationSystem.new(10, 10)
	e.set_elevation(Vector2i(2, 2), 2)
	assert_that(DNDLineOfSight.has_line_of_sight(e, Vector2i(0, 0), Vector2i(4, 4))).is_false()

# ---------- TASK_09: Cover ----------

func test_cover_full_when_blocked() -> void:
	var e = DNDElevationSystem.new(10, 6)
	e.set_elevation(Vector2i(2, 0), 3)
	var cover = DNDCoverCalculator.calculate(e, Vector2i(0, 0), Vector2i(4, 0))
	assert_that(cover).is_equal(DNDCoverCalculator.CoverLevel.FULL)
	assert_that(DNDCoverCalculator.is_targetable(cover)).is_false()

func test_cover_half_when_wall_below_line() -> void:
	# Spec scenario: target behind a wall 1 level below the line of fire.
	var e = DNDElevationSystem.new(10, 6)
	e.set_elevation(Vector2i(0, 0), 2)
	e.set_elevation(Vector2i(2, 0), 1)
	e.set_elevation(Vector2i(4, 0), 2)
	var cover = DNDCoverCalculator.calculate(e, Vector2i(0, 0), Vector2i(4, 0))
	assert_that(cover).is_equal(DNDCoverCalculator.CoverLevel.HALF)
	assert_that(DNDCoverCalculator.ac_bonus(cover)).is_equal(2)
	assert_that(DNDCoverCalculator.dex_save_bonus(cover)).is_equal(2)

func test_cover_none_when_clear() -> void:
	var e = DNDElevationSystem.new(10, 6)
	assert_that(DNDCoverCalculator.calculate(e, Vector2i(0, 0), Vector2i(9, 0))).is_equal(DNDCoverCalculator.CoverLevel.NONE)
	assert_that(DNDCoverCalculator.ac_bonus(DNDCoverCalculator.CoverLevel.NONE)).is_equal(0)

func test_cover_bonuses_table() -> void:
	assert_that(DNDCoverCalculator.ac_bonus(DNDCoverCalculator.CoverLevel.HALF)).is_equal(2)
	assert_that(DNDCoverCalculator.ac_bonus(DNDCoverCalculator.CoverLevel.THREE_QUARTERS)).is_equal(5)
	assert_that(DNDCoverCalculator.is_targetable(DNDCoverCalculator.CoverLevel.HALF)).is_true()

# ---------- Integration: attack roll + high ground ----------

func test_attack_roll_includes_height_bonus() -> void:
	var e = DNDElevationSystem.new(10, 6)
	e.set_elevation(Vector2i(0, 0), 2)
	var shooter := Vector2i(0, 0)
	var target := Vector2i(4, 0)
	var bonus = DNDHeightModifier.attack_bonus(e.get_elevation(shooter), e.get_elevation(target), true)
	assert_that(bonus).is_equal(1)
	var roll = DNDAttackRoll.new()
	var total = roll.roll(rng, 2, 2, bonus)
	assert_that(total).is_equal(roll.d20_result + 2 + 2 + bonus)
