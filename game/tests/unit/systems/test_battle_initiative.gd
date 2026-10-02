extends BaseTest
## tactical-combat-implementation (phase 2): initiative ordering.
## Covers: initiative calculation (DEX + class/race for DnD profiles, speed
## proxy for stack units), queue ordering, legacy compatibility flag,
## determinism by seed.


func _make_unit(key: String, attack: int, hp: int, speed: int, defense: int, side: int) -> BattleState.BattleUnit:
	var stats := UnitStats.new(key, key, attack, attack, hp, speed, defense, [])
	var stack := UnitStack.new(stats, 10)
	var u := BattleState.BattleUnit.new(stack)
	u.side = side
	return u


func _make_dnd_unit(key: String, dexterity: int, speed: int, side: int) -> BattleState.BattleUnit:
	var u := _make_unit(key, 4, 50, speed, 3, side)
	var p := DnDCombatantProfile.new(key, key)
	p.abilities = DNDAbilityScores.new(10, dexterity, 10, 10, 10, 10)
	u.dnd_profile = p
	return u


func test_stack_unit_initiative_equals_speed() -> void:
	var u := _make_unit("militia", 4, 40, 7, 3, BattleState.Side.ATTACKER)
	assert_int(u.get_initiative()).is_equal(7)


func test_dnd_unit_initiative_is_10_plus_dex_mod() -> void:
	# DEX 20 -> mod +5 -> 15
	var u := _make_dnd_unit("fighter", 20, 3, BattleState.Side.ATTACKER)
	assert_int(u.get_initiative()).is_equal(15)
	# DEX 10 -> mod 0 -> 10
	var u10 := _make_dnd_unit("fighter", 10, 9, BattleState.Side.ATTACKER)
	assert_int(u10.get_initiative()).is_equal(10)
	# DEX 5 -> mod -3 -> 7 (slower than a speed-9 stack unit)
	var u5 := _make_dnd_unit("fighter", 5, 9, BattleState.Side.ATTACKER)
	assert_int(u5.get_initiative()).is_equal(7)


func test_queue_ordered_by_initiative() -> void:
	var state := BattleState.new()
	# Fast stack unit (speed 9, initiative 9) vs DnD unit DEX 18 (initiative 14).
	var fast := _make_unit("archer", 4, 30, 9, 2, BattleState.Side.ATTACKER)
	var dexy := _make_dnd_unit("rogue", 18, 2, BattleState.Side.DEFENDER)
	state.attacker_units.append(fast)
	state.defender_units.append(dexy)
	state.build_queue()
	assert_that(state.turn_queue.size()).is_equal(2)
	assert_bool(state.turn_queue[0] == dexy).is_true().override_failure_message(
		"higher initiative (DEX 18 -> 14) must act before speed-9 stack unit"
	)


func test_legacy_flag_keeps_speed_order() -> void:
	var state := BattleState.new()
	var fast := _make_unit("archer", 4, 30, 9, 2, BattleState.Side.ATTACKER)
	var dexy := _make_dnd_unit("rogue", 18, 2, BattleState.Side.DEFENDER)
	state.attacker_units.append(fast)
	state.defender_units.append(dexy)
	state.initiative_order = false
	state.build_queue()
	assert_bool(state.turn_queue[0] == fast).is_true().override_failure_message(
		"legacy mode must keep the old speed-first ordering"
	)


func test_tie_breakers_hp_side_uid() -> void:
	var state := BattleState.new()
	# Equal initiative (speed 5): higher HP first.
	var hp_high := _make_unit("heavy", 5, 70, 5, 5, BattleState.Side.DEFENDER)
	var hp_low := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	state.defender_units.append(hp_low)
	state.defender_units.append(hp_high)
	state.build_queue()
	assert_bool(state.turn_queue[0] == hp_high).is_true().override_failure_message(
		"equal initiative: higher HP acts first"
	)

	# Equal initiative + HP: attacker side first.
	var state2 := BattleState.new()
	var atk_u := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.ATTACKER)
	var def_u := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	state2.attacker_units.append(atk_u)
	state2.defender_units.append(def_u)
	state2.build_queue()
	assert_bool(state2.turn_queue[0] == atk_u).is_true().override_failure_message(
		"equal initiative + HP: attacker side acts first"
	)


func test_queue_deterministic_same_seed() -> void:
	# Queue order is seed-independent (pure sorting) — same input, same order.
	var state := BattleState.new()
	var a := _make_dnd_unit("rogue", 18, 2, BattleState.Side.ATTACKER)
	var b := _make_unit("archer", 4, 30, 9, 2, BattleState.Side.ATTACKER)
	var c := _make_dnd_unit("fighter", 14, 4, BattleState.Side.DEFENDER)
	var d := _make_unit("heavy", 5, 70, 4, 5, BattleState.Side.DEFENDER)
	state.attacker_units.append(a)
	state.attacker_units.append(b)
	state.defender_units.append(c)
	state.defender_units.append(d)
	state.build_queue()
	var order1: Array = []
	for u in state.turn_queue:
		order1.append(u.get_key() + str(u.side))
	state.build_queue()
	var order2: Array = []
	for u in state.turn_queue:
		order2.append(u.get_key() + str(u.side))
	assert_that(order1).is_equal(order2).override_failure_message("queue order must be deterministic")
	# Party-based (merged turn order): attacker party (top init 14 >= defender
	# 12) acts first; within each party, initiative desc.
	# Side enum: NONE=0, ATTACKER=1, DEFENDER=2.
	assert_that(order1[0]).is_equal("rogue1")
	assert_that(order1[1]).is_equal("archer1")
	assert_that(order1[2]).is_equal("fighter2")
	assert_that(order1[3]).is_equal("heavy2")


func test_auto_battle_deterministic_by_seed() -> void:
	# Same seed -> identical battle event sequence (initiative order included).
	var emu := BattleEmulator.new()
	var specs: Array = [
		{"id": "militia", "name": "Militia", "attack": 4, "base_damage": 4, "hp": 40, "speed": 5, "defense": 3, "count": 8},
		{"id": "archer", "name": "Archer", "attack": 4, "base_damage": 3, "hp": 30, "speed": 7, "defense": 2, "count": 4, "tags": ["ranged"]},
	]

	var run := func() -> Array:
		var atk_stacks: Array[UnitStack] = []
		var def_stacks: Array[UnitStack] = []
		for s in specs:
			atk_stacks.append(emu.army_stack(s.duplicate(true)) as UnitStack)
			def_stacks.append(emu.army_stack(s.duplicate(true)) as UnitStack)
		var state := BattleState.new()
		state.place_army(atk_stacks, def_stacks)
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		var report: Dictionary = emu.run_auto_battle(state)
		var seq: Array = []
		for e in report.get("events", []):
			seq.append("%d:%s:%s" % [e.get("turn"), e.get("unit"), e.get("action")])
		seq.append("winner=" + str(report.get("winner")))
		return seq

	var r1: Array = run.call()
	var r2: Array = run.call()
	assert_that(r1).is_equal(r2).override_failure_message("same seed must produce the same battle sequence")
	assert_that(r1.size()).is_greater(1)
