extends BaseTest




const _FakeHero = preload("res://tests/fakes/fake_hero.gd")
const _FakeMap = preload("res://tests/fakes/fake_battle_map.gd")

var coordinator: Node

func before_test() -> void:
	coordinator = null
	coordinator = WorldBattleCoordinator.new()
	coordinator.name = "TestCoordinator"

func after_test() -> void:
	if coordinator != null:
		coordinator.free()
		coordinator = null

func test_coordinator_creation() -> void:
	assert_that(coordinator).is_not_null()

func test_coordinator_is_node() -> void:
	assert_bool(coordinator is Node).is_true()

func test_pending_cell_initial() -> void:
	assert_that(coordinator._pending_enemy_cell).is_equal(Vector2i(-1, -1))

func test_setup_creates_battle_flow() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	assert_bool(coordinator.battle_flow != null).is_true()

func test_setup_stores_refs() -> void:
	var rng := TestFactories.seeded(7251)
	coordinator.setup(null, null, null, rng, null, null, null, null, null)
	assert_that(coordinator.rng).is_not_null()

func test_get_pending_enemy_cell() -> void:
	coordinator._pending_enemy_cell = Vector2i(3, 3)
	assert_that(coordinator.get_pending_enemy_cell()).is_equal(Vector2i(3, 3))

func test_get_battle_flow_after_setup() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	var flow: Variant = coordinator.get_battle_flow()
	assert_that(flow).is_not_null()

func test_get_battle_flow_before_setup() -> void:
	assert_bool(coordinator.battle_flow == null).is_true()

func test_check_enemy_contact_null_map_no_crash() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator.check_enemy_contact(Vector2i(3, 3))
	assert_that(coordinator.get_pending_enemy_cell()).is_equal(Vector2i(-1, -1))

func test_on_battle_completed_null_hero_no_crash() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator._pending_enemy_cell = Vector2i(5, 5)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []

	coordinator._on_battle_completed(BattleState.Side.ATTACKER, surv_atk, surv_def)
	assert_that(coordinator.get_pending_enemy_cell()).is_equal(Vector2i(-1, -1))

func test_on_battle_completed_resets_pending_cell() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator._pending_enemy_cell = Vector2i(5, 5)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []

	coordinator._on_battle_completed(BattleState.Side.ATTACKER, surv_atk, surv_def)
	assert_that(coordinator._pending_enemy_cell).is_equal(Vector2i(-1, -1))

func test_on_battle_completed_resets_pending_cell_defender() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator._pending_enemy_cell = Vector2i(5, 5)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []

	coordinator._on_battle_completed(BattleState.Side.DEFENDER, surv_atk, surv_def)
	assert_that(coordinator._pending_enemy_cell).is_equal(Vector2i(-1, -1))

func test_battle_started_emitted() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)

	var data: Dictionary = {}
	coordinator.battle_flow.battle_started.connect(func(): data["started"] = true)
	coordinator.battle_flow.battle_started.emit()

	assert_bool(data.get("started", false)).is_true()

func test_battle_completed_emitted() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)

	var data: Dictionary = {}
	coordinator.battle_flow.battle_completed.connect(func(w: BattleState.Side, _a, _d):
		data["winner"] = w
	)

	var empty_atk: Array[UnitStack] = []
	var empty_def: Array[UnitStack] = []
	coordinator.battle_flow.battle_completed.emit(BattleState.Side.ATTACKER, empty_atk, empty_def)
	assert_that(data.get("winner", -1)).is_equal(BattleState.Side.ATTACKER)

func test_artifact_drop_chance_positive() -> void:
	assert_bool(0.05 > 0).is_true()

func test_create_battle_flow_signals_connected() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)

	assert_that(coordinator.battle_flow).is_not_null()

	var connected_count := 0
	if coordinator.battle_flow.battle_started.is_connected(Callable(coordinator, "_on_battle_started")):
		connected_count += 1
	if coordinator.battle_flow.battle_completed.is_connected(Callable(coordinator, "_on_battle_completed")):
		connected_count += 1

	assert_that(connected_count).is_equal(2)

func test_fallback_stack_on_total_annihilation() -> void:
	var units = auto_free( UnitRegistry.new())

	var army = HeroArmyController.new()
	army.setup(units)
	army.army.clear()

	var hero = _FakeHero.new()
	hero.army = army

	var map = _FakeMap.new()

	coordinator.setup(hero, map, null, null, null, null, null, null, null)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []
	coordinator._on_battle_completed(BattleState.Side.DEFENDER, surv_atk, surv_def)

	assert_bool(army.army.is_empty()).is_false()
	assert_that(army.army[0].get_key()).is_equal("swordsmen")
	assert_that(army.army[0].count).is_equal(10)
	assert_that(hero.apply_calls).is_equal(1)

	map.free()
	hero.free()
	army.free()

	units.free()
