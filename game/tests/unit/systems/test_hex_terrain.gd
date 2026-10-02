extends BaseTest
## Phase 5 (tactical-battle-system): боевая местность.
##
## Покрывает:
##   * модификаторы типов (защита/высота/блокировка/скорость) — BattleTerrain,
##   * детерминированную генерацию из seed + избегание колонок развёртки,
##   * хранение в BattleState (get/set/clear/generate) + блокировка водой.
##
## T17/D2: местность больше не влияет на урон (лестница перевеса, 02d v1.2);
## её роль — стоимость движения и блокировка (вода).

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

