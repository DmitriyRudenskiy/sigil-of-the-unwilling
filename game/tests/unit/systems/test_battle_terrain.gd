extends BaseTest
## tactical-combat-implementation (phase 3): battle terrain.
## Covers: modifier table, movement costs (water blocks, forest raises cost),
## damage modifiers (forest/hill/fort defense, hill attack), placement on
## blocked terrain, and the no-terrain regression guard.


func _make_unit(key: String, attack: int, hp: int, speed: int, defense: int, side: int) -> BattleState.BattleUnit:
	var stats := UnitStats.new(key, key, attack, attack, hp, speed, defense, [])
	var stack := UnitStack.new(stats, 10)
	var u := BattleState.BattleUnit.new(stack)
	u.side = side
	return u


func test_defense_bonus_table() -> void:
	assert_float(BattleTerrain.defense_bonus(BattleTerrain.FOREST)).is_equal(0.30)
	assert_float(BattleTerrain.defense_bonus(BattleTerrain.HILL)).is_equal(0.50)
	assert_float(BattleTerrain.defense_bonus(BattleTerrain.FORT)).is_equal(0.75)
	assert_float(BattleTerrain.defense_bonus(BattleTerrain.PLAIN)).is_equal(0.0)
	assert_float(BattleTerrain.defense_bonus(BattleTerrain.WATER)).is_equal(0.0)


func test_move_cost_and_blocked() -> void:
	assert_float(BattleTerrain.move_cost(BattleTerrain.PLAIN)).is_equal(1.0)
	assert_float(BattleTerrain.move_cost(BattleTerrain.FOREST)).is_equal(TerrainCostTable.FOREST)
	assert_bool(BattleTerrain.is_blocked(BattleTerrain.WATER)).is_true()
	assert_bool(BattleTerrain.is_blocked(BattleTerrain.PLAIN)).is_false()
	assert_bool(BattleTerrain.is_blocked(BattleTerrain.FOREST)).is_false()


func test_world_to_battle_mapping() -> void:
	assert_that(BattleTerrain.world_to_battle("mountain")).is_equal(BattleTerrain.HILL)
	assert_that(BattleTerrain.world_to_battle("river")).is_equal(BattleTerrain.WATER)
	assert_that(BattleTerrain.world_to_battle("forest")).is_equal(BattleTerrain.FOREST)
	assert_that(BattleTerrain.world_to_battle("grass")).is_equal(BattleTerrain.PLAIN)
	assert_that(BattleTerrain.world_to_battle("unknown_thing")).is_equal(BattleTerrain.PLAIN)


func test_water_blocks_movement() -> void:
	var state := BattleState.new()
	var u := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.ATTACKER)
	u.cell = Vector2i(8, 5)
	state.attacker_units.append(u)
	var water_cell := Vector2i(9, 5)
	state.set_battle_terrain({water_cell: BattleTerrain.WATER})

	var reachable: Dictionary = state.get_reachable_for_unit(u, func() -> Dictionary: return {})
	assert_bool(reachable.has(water_cell)).is_false().override_failure_message("water cell must not be reachable")


func test_forest_reduces_reach() -> void:
	# Speed 3 on an all-forest board: 2 forest hexes cost 2.5 (reachable),
	# 3 cost 3.75 (not reachable). Plain BFS would allow 3 hexes.
	var state := BattleState.new()
	var u := _make_unit("militia", 4, 40, 3, 3, BattleState.Side.ATTACKER)
	u.cell = Vector2i(8, 5)
	state.attacker_units.append(u)
	var map: Dictionary = {}
	for y in state.BH:
		for x in state.BW:
			var c := Vector2i(x, y)
			if c != u.cell:
				map[c] = BattleTerrain.FOREST
	state.set_battle_terrain(map)

	var reachable: Dictionary = state.get_reachable_for_unit(u, func() -> Dictionary: return {})
	var two_away := Vector2i(10, 5)
	var three_away := Vector2i(11, 5)
	assert_bool(reachable.has(two_away)).is_true().override_failure_message("2 forest hexes (cost 2.5) must be reachable at speed 3")
	assert_bool(reachable.has(three_away)).is_false().override_failure_message("3 forest hexes (cost 3.75) must NOT be reachable at speed 3")


func _damage_for(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, seed: int) -> int:
	var rng := TestFactories.seeded(seed)
	var res: Dictionary = BattleDamageResolver.resolve(state, atk, def, {"is_melee": true, "rng": rng})
	return int(res.get("damage", 0))


func test_defense_bonus_in_damage() -> void:
	# Same armies, same seed: defender on fort takes strictly less damage.
	var mk := func(terrain: String) -> Dictionary:
		var state := BattleState.new()
		var atk := _make_unit("militia", 6, 40, 5, 0, BattleState.Side.ATTACKER)
		var def := _make_unit("goblins", 3, 10, 5, 3, BattleState.Side.DEFENDER)
		atk.cell = Vector2i(8, 4)
		def.cell = Vector2i(8, 5)
		state.attacker_units.append(atk)
		state.defender_units.append(def)
		if terrain != BattleTerrain.PLAIN:
			state.set_battle_terrain({def.cell: terrain})
		return {"state": state, "atk": atk, "def": def}

	var plain: Dictionary = mk.call(BattleTerrain.PLAIN)
	var fort: Dictionary = mk.call(BattleTerrain.FORT)
	var forest: Dictionary = mk.call(BattleTerrain.FOREST)
	var dmg_plain := _damage_for(plain["state"], plain["atk"], plain["def"], 99)
	var dmg_fort := _damage_for(fort["state"], fort["atk"], fort["def"], 99)
	var dmg_forest := _damage_for(forest["state"], forest["atk"], forest["def"], 99)
	assert_int(dmg_fort).is_less(dmg_plain).override_failure_message("fort (+75% def) must reduce damage")
	assert_int(dmg_forest).is_less(dmg_plain).override_failure_message("forest (+30% def) must reduce damage")


func test_hill_attack_bonus() -> void:
	var mk := func(atk_terrain: String) -> Dictionary:
		var state := BattleState.new()
		var atk := _make_unit("militia", 6, 40, 5, 0, BattleState.Side.ATTACKER)
		var def := _make_unit("goblins", 3, 10, 5, 3, BattleState.Side.DEFENDER)
		atk.cell = Vector2i(8, 4)
		def.cell = Vector2i(8, 5)
		state.attacker_units.append(atk)
		state.defender_units.append(def)
		if atk_terrain != BattleTerrain.PLAIN:
			state.set_battle_terrain({atk.cell: atk_terrain})
		return {"state": state, "atk": atk, "def": def}

	var plain: Dictionary = mk.call(BattleTerrain.PLAIN)
	var hill: Dictionary = mk.call(BattleTerrain.HILL)
	var dmg_plain := _damage_for(plain["state"], plain["atk"], plain["def"], 99)
	var dmg_hill := _damage_for(hill["state"], hill["atk"], hill["def"], 99)
	assert_int(dmg_hill).is_greater(dmg_plain).override_failure_message("attacker on hill (+20% atk) must deal more damage")


func test_placement_avoids_water() -> void:
	var state := BattleState.new()
	# Water wall across the middle of the board.
	var map: Dictionary = {}
	for x in state.BW:
		map[Vector2i(x, state.BH / 2)] = BattleTerrain.WATER
	state.set_battle_terrain(map)

	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 20))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 20))
	state.place_army(atk, def)

	for u in state.attacker_units:
		assert_bool(state.is_cell_blocked(u.cell)).is_false().override_failure_message("attacker must not be placed on water")
	for u in state.defender_units:
		assert_bool(state.is_cell_blocked(u.cell)).is_false().override_failure_message("defender must not be placed on water")


func test_no_terrain_behavior_unchanged() -> void:
	# Regression guard: empty terrain map -> plain BFS reachability (speed = hexes).
	var state := BattleState.new()
	var u := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.ATTACKER)
	u.cell = Vector2i(8, 5)
	state.attacker_units.append(u)
	var reachable: Dictionary = state.get_reachable_for_unit(u, func() -> Dictionary: return {})
	# Open board: a cell 5 hexes away is reachable, 6 is not.
	var five_away := Vector2i(13, 5)
	var six_away := Vector2i(14, 5)
	assert_bool(reachable.has(five_away)).is_true().override_failure_message("5 hexes at speed 5 must be reachable on plain board")
	assert_bool(reachable.has(six_away)).is_false().override_failure_message("6 hexes at speed 5 must NOT be reachable")
