#extends GdUnitTestSuite
# tests/unit/combat/test_status_effects.gd
# [AI]: сгенерировано по задаче 4.4 tasks.md.
# Статусы: длительность в ходах владельца, тики, ненакладывание.

extends GdUnitTestSuite


func _unit(id: StringName, max_hp: int = 100, attack: int = 10) -> BattleUnit:
	return BattleUnit.new(BattleFactory.stats(id, max_hp, attack, 0, 10), BattleUnit.SIDE_PLAYER, 0)


func test_bleed_ticks_damage_on_owner_turn() -> void:
	var unit := _unit(&"victim")
	unit.apply_status(&"bleed")
	var outcome := unit.begin_turn()
	assert_int(unit.hp).is_equal(95)
	assert_bool(outcome.can_act).is_true()


func test_status_expires_after_its_duration() -> void:
	var unit := _unit(&"victim")
	unit.apply_status(&"bleed")
	unit.begin_turn()
	unit.end_turn()
	unit.begin_turn()
	unit.end_turn()
	assert_bool(unit.has_status(&"bleed")).is_false()
	unit.begin_turn()
	# Две тика по 5 прошли, третьего нет: урон не накапливается и не возобновляется.
	assert_int(unit.hp).is_equal(90)


func test_stun_blocks_action() -> void:
	var unit := _unit(&"stunned")
	unit.apply_status(&"stun")
	var outcome := unit.begin_turn()
	assert_bool(outcome.can_act).is_false()


func test_stun_leaves_only_pass_available() -> void:
	var roster := BattleFactory.roster([BattleFactory.stats(&"stunned", 100, 10, 0, 20)])
	var combat := BattleFactory.state(roster, [BattleFactory.stats(&"foe", 100, 5, 0, 5)], 3)
	combat.current.apply_status(&"stun")
	var actions := combat.legal_actions(combat.current)
	assert_int(actions.size()).is_equal(1)
	assert_int(actions[0].kind).is_equal(BattleAction.Kind.PASS)


func test_stun_is_gone_next_turn() -> void:
	var unit := _unit(&"stunned")
	unit.apply_status(&"stun")
	assert_bool(unit.begin_turn().can_act).is_false()
	unit.end_turn()
	assert_bool(unit.begin_turn().can_act).is_true()


func test_weaken_multiplies_attack() -> void:
	var unit := _unit(&"weak", 100, 30)
	unit.apply_status(&"weaken")
	assert_int(unit.effective_attack()).is_equal(21)


func test_regen_heals_up_to_cap() -> void:
	var unit := _unit(&"healer", 100)
	unit.deal_damage(40)
	unit.apply_status(&"regen")
	unit.begin_turn()
	assert_int(unit.hp).is_equal(66)
	unit.hp = 100
	unit.begin_turn()
	assert_int(unit.hp).is_equal(100)


func test_same_status_refreshes_instead_of_stacking() -> void:
	var unit := _unit(&"victim")
	unit.apply_status(&"bleed")
	unit.apply_status(&"bleed")
	assert_int(int(unit.durations[&"bleed"])).is_equal(2)
	unit.begin_turn()
	assert_int(unit.hp).is_equal(95)


func test_unknown_status_is_rejected() -> void:
	var unit := _unit(&"victim")
	assert_bool(BattleUnit.STATUSES.has(&"mind_control")).is_false()


func test_focus_grows_only_after_first_turn() -> void:
	var unit := _unit(&"caster")
	assert_int(unit.focus).is_equal(BattleUnit.FOCUS_START)
	unit.begin_turn()
	assert_int(unit.focus).is_equal(BattleUnit.FOCUS_START)
	unit.end_turn()
	unit.begin_turn()
	assert_int(unit.focus).is_equal(BattleUnit.FOCUS_START + BattleUnit.FOCUS_GAIN)


func test_focus_is_capped() -> void:
	var unit := _unit(&"caster")
	for _turn in 20:
		unit.begin_turn()
		unit.end_turn()
	assert_int(unit.focus).is_equal(BattleUnit.FOCUS_MAX)
