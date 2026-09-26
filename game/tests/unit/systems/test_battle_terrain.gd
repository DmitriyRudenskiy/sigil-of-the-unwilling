extends BaseTest
## Phase 5 (tactical-battle-system): боевая местность.
##
## Покрывает:
##   * модификаторы типов (защита/высота/блокировка/скорость) — BattleTerrain,
##   * детерминированную генерацию из seed + избегание колонок развёртки,
##   * хранение в BattleState (get/set/clear/generate) + блокировка водой,
##   * применение бонусов в уроне (damage_multiplier + BattleDamageResolver).

const _BT := preload("res://scripts/systems/BattleTerrain.gd")
const T := _BT.TerrainType

func _make_state(atk_key: String, def_key: String, atk_count: int, def_count: int) -> BattleState:
	var state := BattleState.new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack(atk_key, atk_count)]
	var def: Array[UnitStack] = [Units.make_fixed_stack(def_key, def_count)]
	state.place_army(atk, def)
	return state

# --- Модификаторы типов (чистые, детерминированные) ---

func test_defense_multipliers() -> void:
	assert_float(_BT.defense_multiplier(T.PLAIN)).is_equal(1.0)
	assert_float(_BT.defense_multiplier(T.FOREST)).is_equal_approx(1.3, 0.0001)
	assert_float(_BT.defense_multiplier(T.HILL)).is_equal_approx(1.5, 0.0001)
	assert_float(_BT.defense_multiplier(T.FORT)).is_equal_approx(1.75, 0.0001)

func test_elevation_and_downhill() -> void:
	assert_int(_BT.elevation(T.PLAIN)).is_equal(0)
	assert_int(_BT.elevation(T.FOREST)).is_equal(0)
	assert_int(_BT.elevation(T.HILL)).is_equal(1)
	assert_int(_BT.elevation(T.FORT)).is_equal(1)
	assert_float(_BT.DOWNHILL_ATTACK_MULT).is_equal_approx(1.2, 0.0001)

func test_water_blocks_others_do_not() -> void:
	assert_bool(_BT.is_blocking(T.WATER)).is_true()
	assert_bool(_BT.is_blocking(T.PLAIN)).is_false()
	assert_bool(_BT.is_blocking(T.FOREST)).is_false()
	assert_bool(_BT.is_blocking(T.HILL)).is_false()
	assert_bool(_BT.is_blocking(T.FORT)).is_false()

func test_speed_multipliers() -> void:
	assert_float(_BT.speed_multiplier(T.PLAIN)).is_equal(1.0)
	assert_float(_BT.speed_multiplier(T.WATER)).is_equal(0.0)
	assert_float(_BT.speed_multiplier(T.FOREST)).is_less(1.0)
	assert_float(_BT.speed_multiplier(T.HILL)).is_less(1.0)
	assert_float(_BT.speed_multiplier(T.FORT)).is_less(1.0)

# --- Генератор ---

func test_generator_deterministic() -> void:
	var g1 = _BT.generate(TestFactories.seeded(42), BattleState.BW, BattleState.BH, 0.1)
	var g2 = _BT.generate(TestFactories.seeded(42), BattleState.BW, BattleState.BH, 0.1)
	var g3 = _BT.generate(TestFactories.seeded(999), BattleState.BW, BattleState.BH, 0.1)
	assert_bool(g1 == g2).is_true().override_failure_message("same seed must give identical terrain")
	assert_bool(g1 == g3).is_false().override_failure_message("different seed should give different terrain")

func test_generator_avoids_deployment_columns() -> void:
	var g = _BT.generate(TestFactories.seeded(123), BattleState.BW, BattleState.BH, 0.3)
	for c in g:
		assert_int(c.x).is_greater(0).override_failure_message("no terrain in left deployment column")
		assert_int(c.x).is_less(BattleState.BW - 1).override_failure_message("no terrain in right deployment column")

func test_generator_density() -> void:
	var g = _BT.generate(TestFactories.seeded(7), BattleState.BW, BattleState.BH, 0.1)
	var interior: int = (BattleState.BW - 2) * BattleState.BH
	var expected: int = int(float(interior) * 0.1)
	assert_int(g.size()).is_equal(expected).override_failure_message("terrain cell count must match density")

# --- BattleState: хранение ---

func test_get_hex_terrain_default_plain() -> void:
	var state := BattleState.new()
	assert_int(state.get_hex_terrain(Vector2i(5, 5))).is_equal(T.PLAIN)

func test_set_and_clear_terrain() -> void:
	var state := BattleState.new()
	var cell := Vector2i(5, 5)
	state.set_terrain(cell, T.FOREST)
	assert_int(state.get_hex_terrain(cell)).is_equal(T.FOREST)
	state.clear_terrain()
	assert_int(state.get_hex_terrain(cell)).is_equal(T.PLAIN)

func test_water_blocks_movement() -> void:
	var state := _make_state("swordsmen", "goblins", 20, 20)
	var water_cell := Vector2i(8, 5)
	state.set_terrain(water_cell, T.WATER)
	var atk = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var blocked = state.build_all_blocked(atk, {})
	assert_bool(blocked.has(water_cell)).is_true().override_failure_message("water hex must block movement")

# --- Применение бонусов в уроне ---

func test_forest_defense_reduces_damage_multiplier() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	var plain: float = BattleRules.damage_multiplier(atk, def, 50, 0)
	var forest: float = BattleRules.damage_multiplier(atk, def, 50, 0, 1.0, _BT.defense_multiplier(T.FOREST))
	assert_float(plain).is_greater(1.0)
	assert_float(forest).is_less(plain).override_failure_message("forest must reduce incoming damage")

func test_fort_defense_stronger_than_forest() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	var forest: float = BattleRules.damage_multiplier(atk, def, 50, 0, 1.0, _BT.defense_multiplier(T.FOREST))
	var fort: float = BattleRules.damage_multiplier(atk, def, 50, 0, 1.0, _BT.defense_multiplier(T.FORT))
	assert_float(fort).is_less(forest).override_failure_message("fort must defend better than forest")

func test_downhill_attack_increases_damage_multiplier() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	var flat: float = BattleRules.damage_multiplier(atk, def, 50, 0)
	var downhill: float = BattleRules.damage_multiplier(atk, def, 50, 0, _BT.DOWNHILL_ATTACK_MULT, 1.0)
	assert_float(downhill).is_greater(flat).override_failure_message("attacking downhill must deal more damage")

func test_resolver_applies_terrain_end_to_end() -> void:
	var s1 := _make_state("swordsmen", "goblins", 20, 5)
	var a1 = s1.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var d1 = s1.get_units_by_side(BattleState.Side.DEFENDER)[0]
	a1.cell = Vector2i(5, 5)
	d1.cell = HexUtils.get_neighbor(a1.cell, 0)
	var lost_plain: int = _run_attack(s1, a1, d1, 555)

	var s2 := _make_state("swordsmen", "goblins", 20, 5)
	var a2 = s2.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var d2 = s2.get_units_by_side(BattleState.Side.DEFENDER)[0]
	a2.cell = Vector2i(5, 5)
	d2.cell = HexUtils.get_neighbor(a2.cell, 0)
	s2.set_terrain(d2.cell, T.FORT)
	var lost_fort: int = _run_attack(s2, a2, d2, 555)

	assert_int(lost_fort).is_less_equal(lost_plain).override_failure_message("fort terrain must not increase damage taken")

func _run_attack(state: BattleState, atk: BattleState.BattleUnit, def: BattleState.BattleUnit, seed: int) -> int:
	var before: int = def.get_count()
	var rng := TestFactories.seeded(seed)
	BattleDamageResolver.resolve(state, atk, def, {"is_melee": true, "rng": rng, "atk_bonus": 50, "def_bonus": 0})
	return before - def.get_count()
