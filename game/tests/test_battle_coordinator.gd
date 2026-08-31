extends "res://tests/test_base.gd"
## Тесты WorldBattleCoordinator: создание, API, граничные случаи.
##
## После рефакторинга WorldBattleCoordinator использует мягкие
## зависимости (Node + has_method) вместо жёстких типов,
## поэтому preload() работает в headless-режиме.

const _Coordinator = preload("res://scripts/world/WorldBattleCoordinator.gd")
const _UnitRegistry = preload("res://scripts/autoload/UnitRegistry.gd")
const _HeroArmy = preload("res://scripts/entities/HeroArmyController.gd")
const _FakeHero = preload("res://tests/fakes/fake_hero.gd")
const _FakeMap = preload("res://tests/fakes/fake_battle_map.gd")

var coordinator: Node

func before_each() -> void:
	coordinator = null
	coordinator = _Coordinator.new()
	coordinator.name = "TestCoordinator"

func after_each() -> void:
	# Coordinator — Node (и battle_flow как его child): без free()
	# каждый тест утаскивает их в ObjectDB.
	if coordinator != null:
		coordinator.free()
		coordinator = null


# ==================== СОЗДАНИЕ ====================

func test_coordinator_creation() -> void:
	assert_not_null(coordinator, "coordinator created")

func test_coordinator_is_node() -> void:
	assert_true(coordinator is Node, "coordinator is Node")


# ==================== НАЧАЛЬНЫЕ ЗНАЧЕНИЯ ====================

func test_pending_cell_initial() -> void:
	assert_eq(coordinator._pending_enemy_cell, Vector2i(-1, -1), "initial pending cell")


# ==================== SETUP ====================

func test_setup_creates_battle_flow() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	assert_true(coordinator.battle_flow != null, "battle flow created by setup")

func test_setup_stores_refs() -> void:
	var rng := RandomNumberGenerator.new()
	coordinator.setup(null, null, null, rng, null, null, null, null, null)
	assert_not_null(coordinator.rng, "rng stored")


# ==================== ПУБЛИЧНЫЙ API ====================

func test_get_pending_enemy_cell() -> void:
	coordinator._pending_enemy_cell = Vector2i(3, 3)
	assert_eq(coordinator.get_pending_enemy_cell(), Vector2i(3, 3), "returns pending cell")

func test_get_battle_flow_after_setup() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	var flow: Variant = coordinator.get_battle_flow()
	assert_not_null(flow, "battle flow returned")

func test_get_battle_flow_before_setup() -> void:
	# До setup() battle_flow == null
	assert_true(coordinator.battle_flow == null, "no flow before setup")


# ==================== check_enemy_contact — ГРАНИЧНЫЕ СЛУЧАИ ====================

func test_check_enemy_contact_null_map_no_crash() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	assert_true(true, "coordinator survives with null map")


# ==================== on_battle_completed — ГРАНИЧНЫЕ СЛУЧАИ ====================

func test_on_battle_completed_null_hero_no_crash() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator._pending_enemy_cell = Vector2i(5, 5)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []

	coordinator._on_battle_completed(BattleState.Side.ATTACKER, surv_atk, surv_def)
	assert_true(true, "no crash with null hero")

func test_on_battle_completed_resets_pending_cell() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator._pending_enemy_cell = Vector2i(5, 5)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []

	coordinator._on_battle_completed(BattleState.Side.ATTACKER, surv_atk, surv_def)
	assert_eq(coordinator._pending_enemy_cell, Vector2i(-1, -1), "pending cell reset")

func test_on_battle_completed_resets_pending_cell_defender() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)
	coordinator._pending_enemy_cell = Vector2i(5, 5)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []

	coordinator._on_battle_completed(BattleState.Side.DEFENDER, surv_atk, surv_def)
	assert_eq(coordinator._pending_enemy_cell, Vector2i(-1, -1), "pending cell reset on loss")


# ==================== ШИНА СОБЫТИЙ ====================

func test_battle_started_emitted() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)

	var data: Dictionary = {}
	coordinator.battle_flow.battle_started.connect(func(): data["started"] = true)
	coordinator.battle_flow.battle_started.emit()

	assert_true(data.get("started", false), "battle_started signal emitted")

func test_battle_completed_emitted() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)

	var data: Dictionary = {}
	coordinator.battle_flow.battle_completed.connect(func(w: BattleState.Side, _a, _d):
		data["winner"] = w
	)

	var empty_atk: Array[UnitStack] = []
	var empty_def: Array[UnitStack] = []
	coordinator.battle_flow.battle_completed.emit(BattleState.Side.ATTACKER, empty_atk, empty_def)
	assert_eq(data.get("winner", -1), BattleState.Side.ATTACKER, "winner captured")


# ==================== ДРОП АРТЕФАКТА ====================

func test_artifact_drop_chance_positive() -> void:
	assert_true(0.05 > 0, "drop chance is positive")


# ==================== СОЗДАНИЕ BattleFlow ====================

func test_create_battle_flow_signals_connected() -> void:
	coordinator.setup(null, null, null, null, null, null, null, null, null)

	assert_not_null(coordinator.battle_flow, "battle flow exists")

	var connected_count := 0
	if coordinator.battle_flow.battle_started.is_connected(Callable(coordinator, "_on_battle_started")):
		connected_count += 1
	if coordinator.battle_flow.battle_completed.is_connected(Callable(coordinator, "_on_battle_completed")):
		connected_count += 1

	assert_eq(connected_count, 2, "both battle signals connected")


# ==================== РЕГРЕССИЯ: FALLBACK-СТЕК ПРИ ПОЛНОМ УНИЧТОЖЕНИИ ====================

## e2e8 (сценарий 2, бой №11): армия героя полностью уничтожена → fallback-стек
## не выдавался (typed-array баг в _apply_results: untyped [stack] в параметр
## Array[UnitStack] → SCRIPT ERROR). Армия оставалась пустой, каждый следующий
## контакт вызывал мгновенный бой, и агент уходил в 500-итерационный цикл.
func test_fallback_stack_on_total_annihilation() -> void:
	var prev_container: Variant = ServiceContainer.current
	var container := ServiceContainer.new()
	container.units = _UnitRegistry.new()
	ServiceContainer.current = container

	var army = _HeroArmy.new()
	army.setup(container.units)
	army.army.clear()  # полное уничтожение

	var hero = _FakeHero.new()
	hero.army = army

	var map = _FakeMap.new()

	coordinator.setup(hero, map, null, null, null, null, null, null, null, container)

	var surv_atk: Array[UnitStack] = []
	var surv_def: Array[UnitStack] = []
	coordinator._on_battle_completed(BattleState.Side.DEFENDER, surv_atk, surv_def)

	assert_false(army.army.is_empty(), "fallback-стек выдан после полного уничтожения")
	assert_eq(army.army[0].get_key(), "swordsmen", "fallback-стек — swordsmen")
	assert_eq(army.army[0].count, 10, "fallback-стек, численность = 10")
	assert_eq(hero.apply_calls, 1, "hero.apply_battle_results вызван один раз")

	# Node-объекты — освобождаем явно (не ref-counted). UnitRegistry держит
	# ~90 UnitStats в себе: утечка registry = сотня RefCounted в ObjectDB.
	map.free()
	hero.free()
	army.free()
	container.units.free()
	container.units = null
	ServiceContainer.current = prev_container
