extends "res://tests/gut_base.gd"

## Тест отступления: BattleTurnExecutor + BattleState: ретрит → 50% стеков.


func test_retreat_smoke() -> void:
	var errors := _check_retreat_smoke()
	assert_eq(errors, 0, "test_retreat_smoke — no errors")

func _check_retreat_smoke() -> int:
	var errors := 0

	var state: BattleState = load("res://scripts/systems/BattleState.gd").new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 40))
	atk.append(Units.make_fixed_stack("archers", 20))
	atk.append(Units.make_fixed_stack("mages", 10))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))

	state.place_army(atk, def)

	state.force_end(BattleState.Side.DEFENDER)

	if not state.battle_over:
		printerr("force_end should set battle_over")
		errors += 1

	var survivors: Array = state.get_retreat_survivors(BattleState.Side.ATTACKER)

	if survivors.size() != 2:
		printerr("retreat survivors should be 2, got %d" % survivors.size())
		errors += 1

	var total := 0
	for s in survivors:
		total += s.count

	if total != 30:
		printerr("total retreat survivors should be 30 (20 + 10), got %d" % total)
		errors += 1

	if survivors.size() > 0 and survivors[0].count != 20:
		printerr("first retreat stack should have 20 (40/2), got %d" % survivors[0].count)
		errors += 1

	return errors
