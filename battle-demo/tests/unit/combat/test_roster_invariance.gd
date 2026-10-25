#extends GdUnitTestSuite
# tests/unit/combat/test_roster_invariance.gd
# [AI]: задача 4.11 tasks.md.
# Смена набора не меняет правил: один и тот же бой, сыгранный двумя наборами с
# одним seed и одним скриптованным вводом (пропуск), обязан дать тот же порядок
# ходов по инициативе и те же числа урона.

extends GdUnitTestSuite


func test_same_battle_with_two_rosters() -> void:
	# Наборы различаются идентификатором и одним юнитом с одинаковыми
	# характеристиками: правила не имеют права это заметить.
	var shared := BattleFactory.stats(&"hero", 120, 30, 5, 20)
	var extra_a := BattleFactory.stats(&"extra_a", 90, 15, 8, 12)
	var extra_b := BattleFactory.stats(&"extra_b", 90, 15, 8, 12)
	var a := _play(BattleFactory.roster([shared, extra_a], &"a"))
	var b := _play(BattleFactory.roster([shared, extra_b], &"b"))
	assert_str(a["order"]).is_not_equal("")
	assert_str(b["order"]).is_equal(a["order"])
	assert_str(b["damage"]).is_equal(a["damage"])
	assert_int(b["result"]).is_equal(a["result"])


func test_designed_pair_plays_by_the_same_rules() -> void:
	# Боевые наборы из данных (различаются одним юнитом) оба доигрываются, и в
	# каждом очередь ходов отсортирована по инициативе — другого правила нет.
	for roster_id in DataLibrary.ROSTER_IDS:
		var combat := BattleFactory.state(
			DataLibrary.load_roster(roster_id), _enemies(), 20261024
		)
		BattleFactory.auto_play(combat)
		assert_bool(combat.finished).is_true()
		assert_array(_initiative_trace(combat)).is_equal(_sorted_desc(_initiative_trace(combat)))


func _enemies() -> Array:
	var units := DataLibrary.load_units()
	return [units[DataLibrary.ENEMY_ID]]


## Скриптованный ввод за игрока — пропуск; враг ходит сам. Возвращает след боя:
## порядок ходов и урон, приведённые к виду, где extra_a и extra_b неразличимы.
func _play(roster: RosterData) -> Dictionary:
	var combat := BattleFactory.state(roster, [
		BattleFactory.stats(&"foe_1", 80, 18, 6, 15),
		BattleFactory.stats(&"foe_2", 60, 12, 4, 9),
	], 4242)
	var order: Array = []
	var damage: Array = []
	combat.turn_started.connect(func(unit: BattleUnit) -> void: order.append(_name(unit)))
	while not combat.finished:
		combat.perform(BattleAction.skip(combat.current))
	for action in combat.history:
		for uid in action.damage:
			var who: String = uid.replace("extra_a", "extra_b")
			damage.append("%s>%s:%d" % [_name(action.actor), who, action.damage[uid]])
	return {
		"order": ",".join(order),
		"damage": ",".join(damage),
		"result": combat.result,
	}


func _name(unit: BattleUnit) -> String:
	return String(unit.stats.id).replace("extra_a", "extra_b")


## Инициатива идущих юнитов: очередь обязана быть отсортирована по убыванию.
func _initiative_trace(combat: CombatState) -> Array:
	var values: Array = []
	for unit in combat.order:
		values.append(unit.stats.initiative)
	return values


func _sorted_desc(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort_custom(func(a, b): return a > b)
	return copy
