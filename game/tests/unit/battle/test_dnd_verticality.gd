extends BaseTest

## Unit-тесты dnd-verticality-falling Phase 1–2 (TASK_11/12):
## DNDVerticalMovement (лазание/полёт/прыжок) и DNDFallingDamage (урон/прон).

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260927


# ---------- 1.1 Climbing cost ----------

func test_flat_step_costs_one() -> void:
	assert_that(DNDVerticalMovement.step_cost(0, 0, false)).is_equal(1)
	assert_that(DNDVerticalMovement.step_cost(2, 2, false)).is_equal(1)

func test_climb_up_costs_double_per_level() -> void:
	# 1 уровень вверх = ×2; 2 уровня = ×4 (×2 за уровень)
	assert_that(DNDVerticalMovement.step_cost(0, 1, false)).is_equal(2)
	assert_that(DNDVerticalMovement.step_cost(0, 2, false)).is_equal(4)
	assert_that(DNDVerticalMovement.step_cost(1, 4, false)).is_equal(6)

func test_controlled_descent_costs_one() -> void:
	assert_that(DNDVerticalMovement.step_cost(1, 0, false)).is_equal(1)
	assert_that(DNDVerticalMovement.step_cost(3, 2, false)).is_equal(1)

func test_fall_step_costs_one() -> void:
	# Падение — cost 1 (урон резолвится отдельно)
	assert_that(DNDVerticalMovement.step_cost(3, 0, false)).is_equal(1)


# ---------- 1.2 Athletics DC ----------

func test_climb_dc_table() -> void:
	assert_that(DNDVerticalMovement.climb_dc(1)).is_equal(10)
	assert_that(DNDVerticalMovement.climb_dc(2)).is_equal(15)
	assert_that(DNDVerticalMovement.climb_dc(3)).is_equal(15)
	assert_that(DNDVerticalMovement.climb_dc(5)).is_equal(15)

func test_single_level_climb_needs_no_check() -> void:
	var r := DNDVerticalMovement.resolve_step(rng, 0, 1, 0, false)
	assert_that(r.allowed).is_true()
	assert_that(r.needs_check).is_false()
	assert_that(r.cost).is_equal(2)
	assert_that(r.reason).is_equal("climb")

func test_difficult_climb_rolls_athletics() -> void:
	# STR mod -5, DC 15: успех только при natural 20 (15 >= 15 — граница).
	var successes := 0
	var total := 0
	for i in 60:
		var r := DNDVerticalMovement.resolve_step(rng, 0, 2, -5, false)
		assert_that(r.needs_check).is_true()
		assert_that(r.dc).is_equal(15)
		total += 1
		if r.allowed:
			successes += 1
	# p(natural 20 в 60 бросках = 0) ≈ 0.05^60 ≈ 0 — хотя бы один успех
	assert_bool(successes >= 1).is_true()
	# Но успехи редки: не более ~15% бросков
	assert_bool(successes <= 10).is_true()

func test_athletics_failure_keeps_unit_and_spends_cost() -> void:
	# STR mod -5, DC 15 → успех только при natural 20.
	var failed := false
	var passed := false
	for i in 40:
		var r := DNDVerticalMovement.resolve_step(rng, 0, 2, -5, false)
		if not r.allowed:
			failed = true
			assert_that(r.reason).is_equal("athletics_failed")
			assert_that(r.cost).is_equal(4)  # очки списаны
		else:
			passed = true
	assert_bool(failed).is_true()
	assert_bool(passed).is_true()


# ---------- 1.3 Flight ----------

func test_flying_ignores_elevation() -> void:
	var r := DNDVerticalMovement.resolve_step(rng, 0, 4, -5, true)
	assert_that(r.allowed).is_true()
	assert_that(r.needs_check).is_false()
	assert_that(r.fell).is_false()
	assert_that(r.cost).is_equal(1)
	assert_that(DNDVerticalMovement.step_cost(0, 5, true)).is_equal(1)

func test_flying_descent_is_not_a_fall() -> void:
	var r := DNDVerticalMovement.resolve_step(rng, 5, 0, 0, true)
	assert_that(r.fell).is_false()
	assert_that(r.cost).is_equal(1)


# ---------- 1.4 Jumping ----------

func test_jump_height_formula() -> void:
	# 3 + STR mod футов
	assert_that(DNDVerticalMovement.jump_height_feet(0)).is_equal(3)
	assert_that(DNDVerticalMovement.jump_height_feet(2)).is_equal(5)
	assert_that(DNDVerticalMovement.jump_height_feet(4)).is_equal(7)
	assert_that(DNDVerticalMovement.jump_height_feet(-1)).is_equal(2)

func test_jump_distance_formula() -> void:
	# 10 + STR mod футов
	assert_that(DNDVerticalMovement.jump_distance_feet(0)).is_equal(10)
	assert_that(DNDVerticalMovement.jump_distance_feet(3)).is_equal(13)

func test_jump_bypasses_athletics_check() -> void:
	# STR mod +2 → 5 футов = 1 уровень: подъём на 1 уровень прыжком, без проверки
	assert_that(DNDVerticalMovement.can_jump_up(1, 2)).is_true()
	var r := DNDVerticalMovement.resolve_step(rng, 0, 1, 2, false)
	assert_that(r.allowed).is_true()
	assert_that(r.needs_check).is_false()
	assert_that(r.reason).is_equal("jump")
	assert_that(r.cost).is_equal(2)  # cost лазания сохраняется

func test_jump_cannot_reach_two_levels() -> void:
	# Даже STR 20 (+5): 8 футов < 10 футов (2 уровня)
	assert_that(DNDVerticalMovement.can_jump_up(2, 5)).is_false()
	# STR 24 (+7): 10 футов = ровно 2 уровня
	assert_that(DNDVerticalMovement.can_jump_up(2, 7)).is_true()


# ---------- 2.1 Falling damage: 1d6 / 10ft, cap 20d6 ----------

func test_fall_threshold() -> void:
	assert_that(DNDFallingDamage.is_fall(1, 0)).is_false()   # 5фт — контролируемый
	assert_that(DNDFallingDamage.is_fall(2, 0)).is_true()    # 10фт — падение
	assert_that(DNDFallingDamage.is_fall(0, 0)).is_false()
	assert_that(DNDFallingDamage.is_fall(0, 2)).is_false()   # подъём — не падение

func test_fall_feet() -> void:
	assert_that(DNDFallingDamage.fall_feet(1, 0)).is_equal(0)
	assert_that(DNDFallingDamage.fall_feet(2, 0)).is_equal(10)
	assert_that(DNDFallingDamage.fall_feet(4, 0)).is_equal(20)
	assert_that(DNDFallingDamage.fall_feet(6, 1)).is_equal(25)

func test_dice_count_all_distances() -> void:
	assert_that(DNDFallingDamage.dice_count(0)).is_equal(0)
	assert_that(DNDFallingDamage.dice_count(9)).is_equal(0)
	assert_that(DNDFallingDamage.dice_count(10)).is_equal(1)
	assert_that(DNDFallingDamage.dice_count(19)).is_equal(1)
	assert_that(DNDFallingDamage.dice_count(20)).is_equal(2)
	assert_that(DNDFallingDamage.dice_count(100)).is_equal(10)
	assert_that(DNDFallingDamage.dice_count(199)).is_equal(19)
	assert_that(DNDFallingDamage.dice_count(200)).is_equal(20)
	assert_that(DNDFallingDamage.dice_count(250)).is_equal(20)  # кап
	assert_that(DNDFallingDamage.dice_count(5000)).is_equal(20)

func test_roll_damage_bounds() -> void:
	# 10 футов = 1d6: 1..6
	for i in 20:
		var d: int = DNDFallingDamage.roll_damage(10, rng)
		assert_bool(d >= 1 and d <= 6).is_true()
	# 200+ футов = 20d6: 20..120
	for i in 20:
		var d: int = DNDFallingDamage.roll_damage(250, rng)
		assert_bool(d >= 20 and d <= 120).is_true()
	# <10 футов — 0
	assert_that(DNDFallingDamage.roll_damage(5, rng)).is_equal(0)


# ---------- 2.2/2.3 Prone + DEX save DC 15 ----------

func test_controlled_descent_no_damage() -> void:
	var cond := DNDConditionManager.new()
	var r := DNDFallingDamage.resolve(1, 0, rng, 0, cond)
	assert_that(r.fell).is_false()
	assert_that(r.damage).is_equal(0)
	assert_that(cond.has(DNDConditionManager.Condition.PRONE)).is_false()

func test_failed_save_applies_prone() -> void:
	# DEX mod -5: успех только при natural 20 → чаще провал
	var cond := DNDConditionManager.new()
	var prone_count := 0
	var damage_total := 0
	for i in 30:
		var r := DNDFallingDamage.resolve(4, 0, rng, -5, cond)
		assert_that(r.fell).is_true()
		assert_that(r.feet).is_equal(20)
		assert_bool(r.damage >= 2 and r.damage <= 12).is_true()  # 2d6
		damage_total += r.damage
		if r.prone:
			prone_count += 1
		cond.remove(DNDConditionManager.Condition.PRONE)
	assert_bool(prone_count > 0).is_true()
	assert_that(DNDFallingDamage.PRONE_SAVE_DC).is_equal(15)

func test_successful_save_no_prone() -> void:
	# DEX mod +5: natural 10+ проходит DC 15 → реже prone
	var cond := DNDConditionManager.new()
	var prone_count := 0
	for i in 30:
		var r := DNDFallingDamage.resolve(2, 0, rng, 5, cond)
		if r.prone:
			prone_count += 1
		cond.remove(DNDConditionManager.Condition.PRONE)
	assert_bool(prone_count < 30).is_true()

func test_natural_20_always_saves() -> void:
	# p_d20 через roll: natural 20 → CRITICAL_SUCCESS даже при DEX -5
	var cond := DNDConditionManager.new()
	var save := DNDSavingThrow.roll(rng, -5, 0, false, 15, 20)
	assert_that(DNDSavingThrow.succeeded(save)).is_true()
	# natural 1 → провал даже при DEX +5
	var save_fail := DNDSavingThrow.roll(rng, 5, 0, false, 15, 1)
	assert_that(DNDSavingThrow.succeeded(save_fail)).is_false()
