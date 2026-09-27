extends BaseTest
## Phase 8 (tactical-battle-system): исход боя — трофеи и ранение героя.
##
## Покрывает чистые функции BattleRewards:
##   * трофеи за победу (опыт + золото) — детерминировано, растут с числом врагов,
##   * условие ранения героя (проиграл И выжил) — truth table,
##   * штраф статов раненого героя (множитель < 1, пол attack>=1 / defense>=0).

func _stack(count: int) -> UnitStack:
	return UnitStack.new(UnitStats.new("g", "g", 5, 3, 5, 3, 2), count)


func test_trophies_empty_army() -> void:
	var t: Dictionary = BattleRewards.compute_trophies([])
	assert_int(int(t.get("xp", -1))).is_equal(0).override_failure_message("empty army -> 0 xp")
	var res: Dictionary = t.get("resources", {})
	assert_int(int(res.get(BattleRewards.VICTORY_GOLD_ID, -1))).is_equal(BattleRewards.VICTORY_GOLD_BASE) \
		.override_failure_message("empty army -> base gold only")


func test_trophies_xp_scales_with_army() -> void:
	var one: Dictionary = BattleRewards.compute_trophies([_stack(10)])
	assert_int(int(one.get("xp", -1))).is_equal(10 * BattleRewards.XP_PER_SOLDIER) \
		.override_failure_message("10 soldiers xp")

	var two: Dictionary = BattleRewards.compute_trophies([_stack(10), _stack(5)])
	assert_int(int(two.get("xp", -1))).is_equal(15 * BattleRewards.XP_PER_SOLDIER) \
		.override_failure_message("10+5 soldiers xp")


func test_trophies_gold_scales() -> void:
	var t: Dictionary = BattleRewards.compute_trophies([_stack(10), _stack(5)])
	var res: Dictionary = t.get("resources", {})
	assert_int(int(res.get(BattleRewards.VICTORY_GOLD_ID, -1))) \
		.is_equal(BattleRewards.VICTORY_GOLD_BASE + 15).override_failure_message("gold = base + defeated count")


func test_wounded_truth_table() -> void:
	assert_bool(BattleRewards.hero_should_be_wounded(true, true)).is_false() \
		.override_failure_message("won+survived -> not wounded")
	assert_bool(BattleRewards.hero_should_be_wounded(true, false)).is_false() \
		.override_failure_message("won -> not wounded")
	assert_bool(BattleRewards.hero_should_be_wounded(false, true)).is_true() \
		.override_failure_message("lost+survived -> wounded")
	assert_bool(BattleRewards.hero_should_be_wounded(false, false)).is_false() \
		.override_failure_message("lost+died -> not wounded (dead)")


func test_wounded_penalty_reduces_stats() -> void:
	assert_bool(BattleRewards.WOUNDED_STAT_MULT < 1.0).is_true() \
		.override_failure_message("wounded multiplier must reduce stats")
	var w: Dictionary = BattleRewards.apply_wounded_penalty(10, 6)
	assert_int(int(w.get("attack", -1))).is_equal(7).override_failure_message("10 atk * 0.7 = 7")
	assert_int(int(w.get("defense", -1))).is_equal(4).override_failure_message("6 def * 0.7 = 4")


func test_wounded_penalty_floors() -> void:
	var w: Dictionary = BattleRewards.apply_wounded_penalty(1, 0)
	assert_int(int(w.get("attack", -1))).is_greater_equal(1).override_failure_message("attack never below 1")
	assert_int(int(w.get("defense", -1))).is_greater_equal(0).override_failure_message("defense never below 0")
