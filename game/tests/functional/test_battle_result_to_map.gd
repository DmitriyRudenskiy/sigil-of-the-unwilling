extends BaseTest

## AC5 (docs/14 §6): «Продолжить» в финале → flow завершает бой
## (battle_completed) — переход на карту (world_battle_coordinator слушает тот же
## сигнал и возвращает карту).

func test_continue_finishes_battle_flow() -> void:
	var flow := BattleFlow.new()
	add_child(flow)
	var finished := [false]
	flow.battle_completed.connect(
		func(_w: BattleState.Side, _a: Array[UnitStack], _d: Array[UnitStack]) -> void:
			finished[0] = true
	)

	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	await await_millis(200)

	flow._on_battle_finished(BattleState.Side.ATTACKER, [], [], battle)
	var ui: Node = battle.get_node("BattleUI")
	assert_bool(ui._end_overlay.visible).is_true()

	ui._continue_btn.emit_signal("pressed")
	await await_millis(100)
	assert_bool(finished[0]).is_true().override_failure_message(
		"«Продолжить» обязан завершать бой в flow (AC5: один выход → карта)")
