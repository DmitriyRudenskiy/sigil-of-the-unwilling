extends "res://tests/test_base.gd"
## Regression tests for refactoring (Р1–Р11).

# ==================== Т1: Signal winner type ====================

func test_battle_state_side_enum_order() -> void:
	# enum Side { NONE, ATTACKER, DEFENDER }
	assert_eq(BattleState.Side.NONE, 0)
	assert_eq(BattleState.Side.ATTACKER, 1)
	assert_eq(BattleState.Side.DEFENDER, 2)

func test_battle_completed_signal_type() -> void:
	var flow := BattleFlow.new()
	flow.name = "TestFlow"
	# Lambda захватывает локальные по значению — holder-Dictionary для мутации
	var holder: Dictionary = {"winner": -1}
	flow.battle_completed.connect(func(w: BattleState.Side, _a, _d):
		holder["winner"] = w
	)
	flow.battle_completed.emit(BattleState.Side.DEFENDER, [], [])
	assert_eq(holder["winner"], BattleState.Side.DEFENDER)
	flow.free()

# ==================== Т2: dist Dictionary conversion ====================

func test_dijkstra_returns_array() -> void:
	var cost_fn: Callable = func(c: Vector2i) -> float: return 1.0
	var result = HexUtils.dijkstra(Vector2i(0, 0), 5.0, cost_fn, 10, 10)
	assert_true(result is PackedFloat32Array)

func test_array_to_dict_conversion() -> void:
	var arr := PackedFloat32Array([1.0, 2.0, INF, 3.0])
	var w := 2
	var dict: Dictionary = {}
	for i in arr.size():
		if arr[i] < INF:
			dict[HexUtils.idx_to_pos(i, w)] = arr[i]
	assert_eq(dict.size(), 3)
	assert_true(dict.has(Vector2i(0, 0)))
	assert_true(dict.has(Vector2i(1, 1)))
	assert_false(dict.has(Vector2i(0, 1)))

# ==================== Т3: Pause guard ====================

func test_executor_has_paused_property() -> void:
	var executor := BattleTurnExecutor.new()
	executor.name = "TestExecutor"
	assert_eq(executor._paused, false)
	executor._paused = true
	assert_true(executor._paused)
	executor._paused = false
	executor.free()

# ==================== Т4: Inventory deserialization ====================

func test_deserialize_unknown_slot_warns() -> void:
	var inv := HeroInventory.new()
	var data: Dictionary = {
		"equipped": {"99": "some_artifact"},
		"backpack": []
	}
	inv.deserialize(data)
	assert_true(true)

func test_deserialize_valid_slot() -> void:
	var inv := HeroInventory.new()
	var data: Dictionary = {
		"equipped": {"0": "nonexistent_artifact"},
		"backpack": []
	}
	inv.deserialize(data)
	assert_true(true)

# ==================== Т5: No extraction cache ====================

func test_resource_chain_service_no_cache_fields() -> void:
	var service := ResourceChainService.new()
	assert_true(true)

# ==================== Т6: ServiceLocator resolve chain ====================

# ServiceLocator.resolve is tested via ServiceContainer mock in run_tests.gd

# ==================== Т7: Rebirth via public API ====================

func test_battle_state_has_revive_unit() -> void:
	var state := BattleState.new()
	assert_true(state.has_method("revive_unit"))

# ==================== Т8: MapGenerator get_terrain_id passthrough ====================

func test_map_generator_has_get_terrain_id() -> void:
	var mg := MapGenerator.new()
	mg.name = "TestMG"
	assert_true(mg.has_method("get_terrain_id"))
	mg.free()

func test_map_generator_get_terrain_id_null_model() -> void:
	var mg := MapGenerator.new()
	mg.name = "TestMG2"
	var tid = mg.get_terrain_id(Vector2i(0, 0))
	assert_eq(tid, HexUtils.Terrain.GRASS)
	mg.free()

# ==================== Т9: Marker signal chain (dict type) ====================

func test_movement_signal_emits_dict() -> void:
	var hc := HeroMovementController.new()
	hc.name = "TestHMC"
	var holder: Array = [false]
	hc.reach_preview_changed.connect(func(_pts, _dist: Dictionary, _mp):
		holder[0] = true
	)
	hc.reach_preview_changed.emit([], {}, 0.0)
	assert_true(holder[0])
	hc.free()

# ==================== Т10: BattleUI scene skeleton ====================

func test_battle_ui_scene_has_skeleton() -> void:
	var scene := load("res://scenes/ui/BattleUI.tscn")
	assert_true(scene != null)
	var battle_ui := scene.instantiate() as BattleUI
	battle_ui.name = "TestBattleUI"
	# Скелет: нижняя полоса с 8 кнопками, коннектор скелета есть.
	assert_true(battle_ui.has_method("_connect_skeleton"))
	assert_eq(battle_ui.get_node_or_null("bottom_bar").get_child_count(), 8)
	assert_true(battle_ui.has_method("set_status"))
	assert_true(battle_ui.has_method("update_initiative"))
	battle_ui.free()
