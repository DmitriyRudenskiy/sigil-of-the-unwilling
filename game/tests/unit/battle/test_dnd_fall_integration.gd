extends BaseTest

## Integration-тест dnd-verticality-falling Phase 3:
## бой на возвышенности — shove/push с обрыва → падение → урон → prone.
## Плюс: единая точка входа battle_bridge и порядок resolution.

var rng: RandomNumberGenerator

func before_test() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20260928


func _make_profile(p_id: String, p_str: int, p_dex: int) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(p_id, "Unit %s" % p_id)
	p.abilities = DNDAbilityScores.new(p_str, p_dex, 10, 10, 10, 10)
	return p


func test_push_off_ledge_causes_fall() -> void:
	# Юнит на обрыве (level 2), клетка за обрывом — level 0.
	var ledge := 2
	var below := 0
	var fall := DNDShove.push_fall_feet(ledge, below)
	assert_that(fall).is_equal(10)  # 2 уровня × 5 футов

	# Full resolution через bridge: урон 1d6 + prone-чек
	var victim := _make_profile("v", 10, 10)
	var cond := DNDConditionManager.new()
	var r := DnDBattleBridge.resolve_fall(victim, ledge, below, rng, cond)
	assert_that(r.fell).is_true()
	assert_that(r.feet).is_equal(10)
	assert_bool(r.damage >= 1 and r.damage <= 6).is_true()
	# prone ⇔ провал save (DC 15, DEX mod 0)
	assert_bool(r.prone == cond.has(DNDConditionManager.Condition.PRONE)).is_true()
	assert_bool(r.prone == not DNDSavingThrow.succeeded(r.save)).is_true()


func test_push_to_same_level_is_safe() -> void:
	var fall := DNDShove.push_fall_feet(2, 2)
	assert_that(fall).is_equal(0)
	var r := DnDBattleBridge.resolve_fall(_make_profile("a", 10, 10), 2, 2, rng)
	assert_that(r.fell).is_false()
	assert_that(r.damage).is_equal(0)


func test_push_one_level_down_is_controlled() -> void:
	# 1 уровень (5 футов) — контролируемый спуск, не падение
	var fall := DNDShove.push_fall_feet(1, 0)
	assert_that(fall).is_equal(0)


func test_movement_step_off_cliff_falls() -> void:
	# Шаг с level 3 на level 0: падение 15 футов → 1d6
	var step := DNDVerticalMovement.resolve_step(rng, 3, 0, 0, false)
	assert_that(step.fell).is_true()
	assert_that(step.fall_feet).is_equal(15)
	assert_that(step.cost).is_equal(1)

	var victim := _make_profile("m", 10, 14)
	var cond := DNDConditionManager.new()
	var r := DnDBattleBridge.resolve_fall(victim, 3, 0, rng, cond)
	assert_that(r.feet).is_equal(15)
	assert_bool(r.damage >= 1 and r.damage <= 6).is_true()


func test_full_battle_sequence_push_fall_damage_prone() -> void:
	# Сценарий: атакующий на обрыве (level 2) швевает жертву (level 2)
	# за край (level 0). Шов успешен (конtested check), жертва падает.
	var attacker := _make_profile("atk", 18, 10)  # STR +4
	var victim := _make_profile("vic", 10, 10)    # STR 0, DEX 0
	var cond := DNDConditionManager.new()

	# 1. Shove (PUSHED outcome)
	var shove := DNDShove.attempt(rng, 4, 0, DNDShove.ShoveOutcome.PUSHED)
	# С seed 20260928 конкретный исход; проверяем оба пути детерминированно.
	if shove.outcome == DNDShove.ShoveOutcome.PUSHED:
		# 2. Push с обрыва: клетка назначения level 0
		var fall_feet := DNDShove.push_fall_feet(2, 0)
		assert_that(fall_feet).is_equal(10)
		# 3. Падение: урон + prone-чек
		var fall := DnDBattleBridge.resolve_fall(victim, 2, 0, rng, cond)
		assert_that(fall.fell).is_true()
		assert_bool(fall.damage >= 1 and fall.damage <= 6).is_true()
		assert_bool(fall.prone == cond.has(DNDConditionManager.Condition.PRONE)).is_true()
	else:
		# Шов не удался — падения нет
		assert_that(DNDShove.push_fall_feet(2, 2)).is_equal(0)


func test_fall_resolution_does_not_disturb_initiative() -> void:
	# 3.2: падение резолвится в момент перемещения — порядок инициативы
	# (отсортированный список) остаётся неизменным.
	var tracker := DnDBattleBridge.build_initiative(
		[_make_profile("a", 10, 16), _make_profile("b", 10, 8)], rng
	)
	var order_before: Array = tracker.turn_order.duplicate()
	# Падение юнита a — без влияния на трекер
	var a: DnDCombatantProfile = _make_profile("a", 10, 16)
	DnDBattleBridge.resolve_fall(a, 3, 0, rng)
	assert_that(tracker.turn_order.size()).is_equal(order_before.size())
	for i in order_before.size():
		assert_that(str(tracker.turn_order[i].id)).is_equal(str(order_before[i].id))
		assert_that(tracker.turn_order[i].initiative).is_equal(order_before[i].initiative)
