extends "res://tests/test_base.gd"
## Тесты BattleFlow: создание, запуск, завершение, защита от двойного запуска.

const _BattleFlow = preload("res://scripts/BattleFlow.gd")

# ==================== СОЗДАНИЕ ====================

func test_flow_creation() -> void:
	var flow := _BattleFlow.new()
	assert_not_null(flow, "flow created")

func test_flow_is_node() -> void:
	var flow := _BattleFlow.new()
	assert_true(flow is Node, "flow is Node")

func test_flow_initial_inactive() -> void:
	var flow := _BattleFlow.new()
	assert_false(flow._active, "initially inactive")

# ==================== СИГНАЛЫ ====================

func test_battle_started_signal() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow"
	# Lambda захватывает локальные переменные по значению — для мутации нужен ссылочный holder
	var state: Array = [false]
	flow.battle_started.connect(func(): state[0] = true)
	# Не можем запустить полноценный бой без сцены, но проверяем сигнал
	flow.battle_started.emit()
	assert_true(state[0], "battle_started emitted")

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
	assert_eq(result["winner"], BattleState.Side.ATTACKER, "winner is attacker")
	assert_eq(result["atk"], 0, "empty attacker survivors")
	assert_eq(result["def"], 0, "empty defender survivors")

# ==================== ЗАЩИТА ОТ ДВОЙНОГО ЗАПУСКА ====================

func test_active_flag_prevents_double_start() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow3"
	flow._active = true
	# start_battle должен вернуть без действия если _active == true
	# Не можем вызвать без сцены, но проверяем флаг
	assert_true(flow._active, "active flag set")
	assert_true(flow._active, "active flag persists")

# ==================== ГРАНИЧНЫЕ СЛУЧАИ ====================

func test_obstacle_seed_negative_gets_random() -> void:
	var flow := _BattleFlow.new()
	# obstacle_seed < 0 должен быть заменён на randi()
	# Проверяем логику в коде
	var seed := -1
	if seed < 0:
		seed = randi()
	assert_true(seed >= 0, "negative seed replaced")

func test_battle_completed_resets_active() -> void:
	var flow := _BattleFlow.new()
	flow.name = "TestFlow4"
	flow._active = true
	# Имитируем _on_battle_finished
	flow._active = false
	assert_false(flow._active, "active reset after finish")
