extends BaseTest

## Unit-тесты D&D 5e special maneuvers (dnd-battle-system Phase 4, TASK_16..18):
## grapple, shove, condition_manager.

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260925

# ---------- TASK_16: Grapple ----------

func test_grapple_contested_check() -> void:
	var r = DNDGrapple.attempt(rng, 4, 1)
	assert_that(r.grappler_total).is_greater_equal(1 + 4)
	assert_that(r.grappler_total).is_less_equal(20 + 4)
	assert_that(r.success == (r.grappler_total >= r.target_total)).is_true()

func test_grappled_speed_is_zero() -> void:
	assert_that(DNDGrapple.grappled_speed(30)).is_equal(0)

func test_grappler_moves_at_half_speed() -> void:
	assert_that(DNDGrapple.grappler_move_speed(30)).is_equal(15)
	assert_that(DNDGrapple.grappler_move_speed(25)).is_equal(12)

func test_grapple_ends_when_grappler_incapacitated() -> void:
	assert_that(DNDGrapple.ends_when_grappler_incapacitated()).is_true()

func test_grapple_escape() -> void:
	# Escape is a contested check (Athletics vs Athletics), tie keeps the grapple.
	# Contested-check machinery is covered by test_grapple_contested_check;
	# here we assert the API shape and determinism under a fixed seed.
	rng.seed = 12345
	var r1 = DNDGrapple.escape(rng, 5, 5)
	rng.seed = 12345
	var r2 = DNDGrapple.escape(rng, 5, 5)
	assert_that(typeof(r1) == TYPE_BOOL).is_true()
	assert_that(r1).is_equal(r2)

# ---------- TASK_17: Shove ----------

func test_shove_requires_free_hand_and_reach() -> void:
	assert_that(DNDShove.can_shove(false, true)).is_equal("no free hand")
	assert_that(DNDShove.can_shove(true, false)).is_equal("target out of reach")
	assert_that(DNDShove.can_shove(true, true)).is_equal("")

func test_shove_outcomes() -> void:
	# Modifier gap of 20 guarantees a win regardless of d20 (min 1+10 > max 20-10).
	var prone = DNDShove.attempt(rng, 10, -10, DNDShove.ShoveOutcome.PRONE)
	assert_that(prone.outcome).is_equal(DNDShove.ShoveOutcome.PRONE)
	var pushed = DNDShove.attempt(rng, 10, -10, DNDShove.ShoveOutcome.PUSHED)
	assert_that(pushed.outcome).is_equal(DNDShove.ShoveOutcome.PUSHED)

func test_shove_prevented_without_hand() -> void:
	var r = DNDShove.attempt(rng, 6, 0, DNDShove.ShoveOutcome.PRONE, false, true)
	assert_that(r.outcome).is_equal(DNDShove.ShoveOutcome.PREVENTED)

func test_shove_push_distance() -> void:
	assert_that(DNDShove.PUSH_DISTANCE_FEET).is_equal(5)

# ---------- TASK_18: Conditions ----------

func test_all_14_conditions_defined() -> void:
	var values = DNDConditionManager.Condition.values()
	assert_that(values.size()).is_equal(14)
	for c in values:
		assert_that(DNDConditionManager.CONDITION_NAMES.has(c)).is_true()

func test_blinded_effects() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.BLINDED)
	var e = m.get_effects()
	assert_that(e.attack_disadvantage).is_true()
	assert_that(e.attack_advantage_against).is_true()

func test_grappled_speed_zero() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.GRAPPLED)
	assert_that(m.get_effects().speed_zero).is_true()

func test_paralyzed_full_effects() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.PARALYZED)
	var e = m.get_effects()
	assert_that(e.incapacitated).is_true()
	assert_that(e.auto_fail_str_dex_saves).is_true()
	assert_that(e.crit_on_19_20).is_true()
	assert_that(e.attack_advantage_against).is_true()

func test_petrified_immunity() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.PETRIFIED)
	var e = m.get_effects()
	assert_that(e.immune_to_damage).is_true()
	assert_that(e.incapacitated).is_true()

func test_prone_effects() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.PRONE)
	var e = m.get_effects()
	assert_that(e.attack_disadvantage).is_true()
	assert_that(e.attack_advantage_against).is_true()
	assert_that(e.stand_up_costs_half_move).is_true()

func test_restrained_effects() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.RESTRAINED)
	var e = m.get_effects()
	assert_that(e.speed_zero).is_true()
	assert_that(e.attack_disadvantage).is_true()
	assert_that(e.save_disadvantage).is_true()

func test_conditions_stack() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.POISONED)
	m.apply(DNDConditionManager.Condition.BLINDED)
	var e = m.get_effects()
	assert_that(e.attack_disadvantage).is_true()
	assert_that(e.ability_check_disadvantage).is_true()
	assert_that(e.attack_advantage_against).is_true()
	assert_that(m.get_active().size()).is_equal(2)

func test_condition_duration_and_tick() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.POISONED, 3)
	assert_that(m.has(DNDConditionManager.Condition.POISONED)).is_true()
	m.tick()
	m.tick()
	assert_that(m.has(DNDConditionManager.Condition.POISONED)).is_true()
	var expired = m.tick()
	assert_that(expired.size()).is_equal(1)
	assert_that(m.has(DNDConditionManager.Condition.POISONED)).is_false()

func test_condition_until_removed_persists() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.FRIGHTENED, -1)
	m.tick()
	m.tick()
	assert_that(m.has(DNDConditionManager.Condition.FRIGHTENED)).is_true()
	m.remove(DNDConditionManager.Condition.FRIGHTENED)
	assert_that(m.has(DNDConditionManager.Condition.FRIGHTENED)).is_false()

func test_condition_serialization() -> void:
	var m = DNDConditionManager.new()
	m.apply(DNDConditionManager.Condition.STUNNED, 2)
	var m2 = DNDConditionManager.from_dict(m.to_dict())
	assert_that(m2.has(DNDConditionManager.Condition.STUNNED)).is_true()
	assert_that(m2.active[DNDConditionManager.Condition.STUNNED]).is_equal(2)
