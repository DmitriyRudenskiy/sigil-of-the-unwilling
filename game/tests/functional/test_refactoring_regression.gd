extends GdUnitTestSuite

func test_battle_state_side_enum_order() -> void:
	assert_that(BattleState.Side.NONE).is_equal(0)
	assert_that(BattleState.Side.ATTACKER).is_equal(1)
	assert_that(BattleState.Side.DEFENDER).is_equal(2)

func test_battle_completed_signal_type() -> void:
	var flow := BattleFlow.new()
	flow.name = "TestFlow"
	var holder: Dictionary = {"winner": -1}
	flow.battle_completed.connect(func(w: BattleState.Side, _a, _d):
		holder["winner"] = w
	)
	flow.battle_completed.emit(BattleState.Side.DEFENDER, [], [])
	assert_that(holder["winner"]).is_equal(BattleState.Side.DEFENDER)
	flow.free()

func test_dijkstra_returns_array() -> void:
	var cost_fn: Callable = func(c: Vector2i) -> float: return 1.0
	var result = HexPathfinding.dijkstra(Vector2i(0, 0), 5.0, cost_fn, 10, 10)
	assert_bool(result is PackedFloat32Array).is_true()

func test_array_to_dict_conversion() -> void:
	var arr := PackedFloat32Array([1.0, 2.0, INF, 3.0])
	var w := 2
	var dict: Dictionary = {}
	for i in arr.size():
		if arr[i] < INF:
			dict[HexUtils.idx_to_pos(i, w)] = arr[i]
	assert_that(dict.size()).is_equal(3)
	assert_bool(dict.has(Vector2i(0, 0))).is_true()
	assert_bool(dict.has(Vector2i(1, 1))).is_true()
	assert_bool(dict.has(Vector2i(0, 1))).is_false()

func test_executor_has_paused_property() -> void:
	var executor := BattleTurnExecutor.new()
	executor.name = "TestExecutor"
	assert_that(executor._paused).is_equal(false)
	executor._paused = true
	assert_bool(executor._paused).is_true()
	executor._paused = false
	executor.free()

func test_deserialize_unknown_slot_warns() -> void:
	var inv := HeroInventory.new()
	var data: Dictionary = {
		"equipped": {"99": "some_artifact"},
		"backpack": []
	}
	inv.deserialize(data)
	for slot in inv.equipped:
		assert_that(inv.equipped[slot]).is_null()

func test_deserialize_valid_slot() -> void:
	var inv := HeroInventory.new()
	var data: Dictionary = {
		"equipped": {"0": "nonexistent_artifact"},
		"backpack": []
	}
	inv.deserialize(data)
	for slot in inv.equipped:
		assert_that(inv.equipped[slot]).is_null()

func test_resource_chain_service_no_cache_fields() -> void:
	var service := ResourceChainService.new()
	assert_int(service._discovery_cache.size()).is_equal(0)
	assert_int(service._extraction_cache.size()).is_equal(0)

func test_action_resolver_has_revive_unit() -> void:
	var resolver := BattleActionResolver.new()
	assert_bool(resolver.has_method("revive_unit")).is_true()

func test_map_generator_has_get_terrain_id() -> void:
	var mg := MapGenerator.new()
	mg.name = "TestMG"
	assert_bool(mg.has_method("get_terrain_id")).is_true()
	mg.free()

func test_map_generator_get_terrain_id_null_model() -> void:
	var mg := MapGenerator.new()
	mg.name = "TestMG2"
	var tid = mg.get_terrain_id(Vector2i(0, 0))
	assert_that(tid).is_equal(HexUtils.Terrain.GRASS)
	mg.free()

func test_movement_signal_emits_dict() -> void:
	var hc := HeroMovementController.new()
	hc.name = "TestHMC"
	var holder: Array = [false]
	hc.reach_preview_changed.connect(func(_pts, _dist: Dictionary, _mp):
		holder[0] = true
	)
	hc.reach_preview_changed.emit([], {}, 0.0)
	assert_bool(holder[0]).is_true()
	hc.free()

func test_battle_ui_scene_has_skeleton() -> void:
	var scene := load("res://scenes/ui/BattleUI.tscn")
	assert_bool(scene != null).is_true()
	var battle_ui := scene.instantiate() as BattleUI
	battle_ui.name = "TestBattleUI"
	assert_bool(battle_ui.has_method("_connect_skeleton")).is_true()
	assert_that(battle_ui.get_node_or_null("bottom_bar").get_child_count()).is_equal(7)
	assert_bool(battle_ui.get_node_or_null("collapse_btn") != null).is_true()
	assert_bool(battle_ui.has_method("set_status")).is_true()
	assert_bool(battle_ui.has_method("update_initiative")).is_true()
	battle_ui.free()
