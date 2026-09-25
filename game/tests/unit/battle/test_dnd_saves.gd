extends BaseTest

## Unit-тесты D&D 5e saving throws & death (dnd-battle-system Phase 5, TASK_19..20):
## saving_throw, death_saves.

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260925

# ---------- TASK_19: Saving Throws ----------

func test_save_roll_formula() -> void:
	var r = DNDSavingThrow.roll(rng, 3, 2, true, 15, 12)
	assert_that(r.total).is_equal(12 + 3 + 2)
	assert_that(r.dc).is_equal(15)

func test_save_no_proficiency_when_unproficient() -> void:
	var r = DNDSavingThrow.roll(rng, 3, 5, false, 10, 8)
	assert_that(r.total).is_equal(8 + 3)

func test_save_dc_formula() -> void:
	assert_that(DNDSavingThrow.calculate_dc(2, 3)).is_equal(13)
	assert_that(DNDSavingThrow.calculate_dc(2, 3, 1)).is_equal(14)
	assert_that(DNDSavingThrow.calculate_dc(0, 0)).is_equal(8)

func test_save_critical_success_on_20() -> void:
	var r = DNDSavingThrow.roll(rng, -5, 0, false, 30, 20)
	assert_that(r.result).is_equal(DNDSavingThrow.ThrowResult.CRITICAL_SUCCESS)
	assert_that(DNDSavingThrow.succeeded(r)).is_true()

func test_save_critical_failure_on_1() -> void:
	var r = DNDSavingThrow.roll(rng, 5, 5, true, 1, 1)
	assert_that(r.result).is_equal(DNDSavingThrow.ThrowResult.CRITICAL_FAILURE)
	assert_that(DNDSavingThrow.succeeded(r)).is_false()

func test_save_success_and_failure() -> void:
	var win = DNDSavingThrow.roll(rng, 0, 0, false, 15, 15)
	assert_that(win.result).is_equal(DNDSavingThrow.ThrowResult.SUCCESS)
	var lose = DNDSavingThrow.roll(rng, 0, 0, false, 10, 9)
	assert_that(lose.result).is_equal(DNDSavingThrow.ThrowResult.FAILURE)

func test_save_uses_rng_when_no_override() -> void:
	var r = DNDSavingThrow.roll(rng, 0, 0, false, 10)
	assert_that(r.d20).is_between(1, 20)
	assert_that(r.total).is_equal(r.d20)

# ---------- TASK_20: Death Saving Throws ----------

func test_death_save_starts_dying() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	assert_that(d.state).is_equal(DNDDeathSaves.State.DYING)

func test_death_save_natural_20_regains_hp() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	var r = d.roll(rng, 20)
	assert_that(r.regained_hp).is_true()
	assert_that(d.state).is_equal(DNDDeathSaves.State.HEALTHY)

func test_death_save_natural_1_two_failures() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	d.roll(rng, 1)
	assert_that(d.failures).is_equal(2)
	d.roll(rng, 1)
	assert_that(d.is_dead()).is_true()

func test_death_save_three_successes_stable() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	for i in 3:
		d.roll(rng, 12)
	assert_that(d.is_stable()).is_true()
	assert_that(d.state).is_equal(DNDDeathSaves.State.STABLE)

func test_death_save_three_failures_death() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	for i in 3:
		d.roll(rng, 3)
	assert_that(d.is_dead()).is_true()
	assert_that(d.state).is_equal(DNDDeathSaves.State.DEAD)

func test_death_save_mixed_thresholds() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	d.roll(rng, 10)
	assert_that(d.successes).is_equal(1)
	d.roll(rng, 9)
	assert_that(d.failures).is_equal(1)

func test_death_save_stabilize_via_medicine() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	d.stabilize()
	assert_that(d.is_stable()).is_true()

func test_death_save_heal_wakes_conscious() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	d.roll(rng, 12)
	d.heal(2)
	assert_that(d.state).is_equal(DNDDeathSaves.State.HEALTHY)
	assert_that(d.successes).is_equal(0)
	assert_that(d.failures).is_equal(0)

func test_death_save_stable_heal_wakes() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	d.stabilize()
	d.heal(1)
	assert_that(d.state).is_equal(DNDDeathSaves.State.HEALTHY)

func test_death_save_serialization() -> void:
	var d = DNDDeathSaves.new()
	d.die_start()
	d.roll(rng, 12)
	var d2 = DNDDeathSaves.from_dict(d.to_dict())
	assert_that(d2.state).is_equal(d.state)
	assert_that(d2.successes).is_equal(d.successes)
	assert_that(d2.failures).is_equal(d.failures)
