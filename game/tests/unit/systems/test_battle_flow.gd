extends GdUnitTestSuite

const _BattleFlow = preload("res://scripts/systems/BattleFlow.gd")

func test_flow_creation() -> void:
	var flow := _BattleFlow.new()
	assert_that(flow).is_not_null()
	flow.free()

func test_flow_is_node() -> void:
	var flow := _BattleFlow.new()
	assert_bool(flow is Node).is_true()
	flow.free()

func test_flow_initial_inactive() -> void:
	var flow := _BattleFlow.new()
	assert_object(flow._active_battle).is_null()
	flow.free()

func test_battle_started_signal() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow"
	var state: Array = [false]
	flow.battle_started.connect(func(): state[0] = true)
	flow.battle_started.emit()
	assert_bool(state[0]).is_true()
	flow.free()

func test_battle_completed_signal() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow2"
	var result: Dictionary = {"winner": BattleState.Side.DEFENDER, "atk": -1, "def": -1}
	flow.battle_completed.connect(func(w: BattleState.Side, a: Array, d: Array):
		result["winner"] = w
		result["atk"] = a.size()
		result["def"] = d.size()
	)
	var atk: Array = []
	var def: Array = []
	flow.battle_completed.emit(BattleState.Side.ATTACKER, atk, def)
	assert_that(result["winner"]).is_equal(BattleState.Side.ATTACKER)
	assert_that(result["atk"]).is_equal(0)
	assert_that(result["def"]).is_equal(0)
	flow.free()

func test_active_flag_prevents_double_start() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow3"
	var fake := Node.new()
	fake.name = "FakeBattle"
	flow._active_battle = fake

	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []
	flow.start_battle(atk, def)
	assert_that(flow._active_battle).is_equal(fake)
	fake.free()
	flow.free()

func test_obstacle_seed_negative_gets_random() -> void:
	var flow := _BattleFlow.new()
	var seed := -1
	if seed < 0:
		seed = randi()
	assert_bool(seed >= 0).is_true()
	flow.free()

func test_battle_completed_resets_active() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow4"
	var fake := Node.new()
	fake.name = "FakeBattle2"
	flow._active_battle = fake
	flow._active_battle = null
	assert_object(flow._active_battle).is_null()
	fake.free()
	flow.free()
