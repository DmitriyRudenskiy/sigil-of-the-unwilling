extends BaseTest

func test_retreat_smoke() -> void:
	var state: BattleState = BattleState.new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 40))
	atk.append(Units.make_fixed_stack("archers", 20))
	atk.append(Units.make_fixed_stack("mages", 10))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))

	state.place_army(atk, def)

	BattleActionResolver.force_end(state, BattleState.Side.DEFENDER)

	assert_bool(state.battle_over).is_true().override_failure_message("force_end should set battle_over")

	var survivors: Array = state.get_retreat_survivors(BattleState.Side.ATTACKER)

	assert_int(survivors.size()).is_equal(2).override_failure_message("retreat survivors should be 2")

	var total := 0
	for s in survivors:
		total += s.count

	assert_int(total).is_equal(30).override_failure_message("total retreat survivors should be 30 (20 + 10)")

	assert_int(survivors[0].count).is_equal(20).override_failure_message("first retreat stack should have 20 (40/2)")
