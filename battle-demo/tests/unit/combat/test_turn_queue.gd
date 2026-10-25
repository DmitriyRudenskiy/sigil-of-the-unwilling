#extends GdUnitTestSuite
# tests/unit/combat/test_turn_queue.gd
# [AI]: сгенерировано по задаче 4.2 tasks.md.
# Очередь ходов: инициатива, тай-брейки, пропуск мёртвых.

extends GdUnitTestSuite

const PLAYER := BattleUnit.SIDE_PLAYER
const ENEMY := BattleUnit.SIDE_ENEMY


func _unit(id: StringName, initiative: int, side: int, slot: int) -> BattleUnit:
	return BattleUnit.new(BattleFactory.stats(id, 50, 10, 5, initiative), side, slot)


func test_order_by_initiative_descending() -> void:
	var units: Array[BattleUnit] = [
		_unit(&"slow", 5, PLAYER, 0),
		_unit(&"fast", 15, PLAYER, 1),
		_unit(&"mid", 10, ENEMY, 0),
	]
	var ordered := TurnQueue.order(units)
	assert_array(ordered.map(func(u): return String(u.stats.id))).is_equal(["fast", "mid", "slow"])


func test_tie_gives_player_side_first() -> void:
	var units: Array[BattleUnit] = [
		_unit(&"enemy_a", 10, ENEMY, 0),
		_unit(&"player_a", 10, PLAYER, 0),
	]
	var ordered := TurnQueue.order(units)
	assert_int(ordered[0].side).is_equal(PLAYER)


func test_tie_within_side_ordered_by_slot() -> void:
	var units: Array[BattleUnit] = [
		_unit(&"p2", 10, PLAYER, 2),
		_unit(&"p0", 10, PLAYER, 0),
		_unit(&"p1", 10, PLAYER, 1),
	]
	var ordered := TurnQueue.order(units)
	assert_array(ordered.map(func(u): return u.slot)).is_equal([0, 1, 2])


func test_order_independent_of_input_order() -> void:
	var first := _unit(&"a", 9, PLAYER, 0)
	var second := _unit(&"b", 12, PLAYER, 1)
	var third := _unit(&"c", 12, ENEMY, 0)
	var forward: Array[BattleUnit] = [first, second, third]
	var shuffled: Array[BattleUnit] = [third, first, second]
	assert_array(TurnQueue.order(forward).map(func(u): return String(u.stats.id))) \
		.is_equal(TurnQueue.order(shuffled).map(func(u): return String(u.stats.id)))


func test_dead_units_are_skipped() -> void:
	var roster := BattleFactory.roster([
		BattleFactory.stats(&"first", 50, 10, 5, 20),
		BattleFactory.stats(&"second", 50, 10, 5, 10),
	])
	var combat := BattleFactory.state(roster, [BattleFactory.stats(&"foe", 500, 1, 0, 1)], 7)
	var started: Array = []
	combat.turn_started.connect(func(unit: BattleUnit) -> void: started.append(String(unit.stats.id)))
	var dead := combat.order[0]
	assert_str(dead.uid()).is_equal("first#0")
	dead.deal_damage(9999)

	for _turn in 6:
		if combat.finished:
			break
		combat.perform(BattleAction.skip(combat.current))
	assert_bool(started.has("first")).is_false()
	assert_bool(started.has("second")).is_true()
	assert_bool(started.has("foe")).is_true()
