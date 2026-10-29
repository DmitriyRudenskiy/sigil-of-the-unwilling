extends BaseTest

## Срез «Собиратель: узлы ≠ единицы» (задача 4.2 цикла
## `scenario-matrix-behavior-reliability`, T-303). Замер матрицы 2026-10-26
## (`MATRIX_REPEAT=2 … collector 90`): Fighter и Wizard заканчивали забег на **первом
## ходе** с `rare_extracted = 50`, а `resources_per_day` у классов различается в 40 раз
## (1.2 … 50.0). Причина не в политике роли, а в мере цели: `rare_goal = 10` считается
## в ЕДИНИЦАХ (`ScenarioPilot._on_resource_extracted` складывает `amount`), а
## `ResourceType.pickup_amount(GOLD) = 50` на один узел — одно найденное золотое
## месторождение закрывает цель пятикратно и завершает забег.
##
## Задача 4.2 требует, чтобы отчёт различал найденное, достигнутое и извлечённое, и
## прямо запрещает менять цель 10 и определение редкости. Поэтому меняется только
## отчётность: `rare_nodes` (сколько узлов снято со спавнера), `resource_nodes_extracted`
## (сколько узлов снято всего) и `rare_targets_seen` (сколько разных редких клеток
## политика вообще выбирала целью). Кейсы ниже пинят и семантику цели в единицах —
## если её решат менять, красный тест скажет, что менять надо и задачи 4.x.

# (не `const`: статический вызов не является константой времени компиляции)
var _COLLECTOR_TARGET: Dictionary = ScenarioTargets.role("collector")


func _pilot_with_role() -> ScenarioPilot:
	var pilot := ScenarioPilot.new()
	# `_ready` вешает обработчик `resource_extracted`, а он вызывается только в дереве:
	# голый `.new()` молча оставляет счётчики нулями (проверено на красном прогоне).
	add_child(pilot)
	auto_free(pilot)
	pilot.role = CollectorRole.new()
	pilot.role.target = _COLLECTOR_TARGET
	# `start_scenario` наполняет `_rare_ids` из цели роли; голый пилот без мира здесь
	# легален — `_on_resource_extracted` читает только счётчики и `_rare_ids`.
	pilot._rare_ids = _COLLECTOR_TARGET.get("rare_ids", [])
	return pilot


func _extract(pilot: ScenarioPilot, resource_id: StringName) -> void:
	GameEventBus.resource_extracted.emit(Vector2i.ZERO, resource_id,
		ResourceType.pickup_amount(ResourceType.from_name(resource_id)))


func test_gold_node_is_one_node_and_fifty_units() -> void:
	var pilot := _pilot_with_role()

	_extract(pilot, &"gold")

	assert_that(pilot.rare_nodes()).is_equal(1)
	assert_that(pilot.rare_count()).is_equal(50)
	assert_that(pilot.extracted_nodes).is_equal(1)
	assert_that(pilot.extracted_total).is_equal(50)
	# Семантика цели (пин, а не пожелание): один узел золота её закрывает.
	assert_bool(pilot.role.goal_met(pilot)).is_true() \
		.override_failure_message("цель Собирателя считается в единицах: золото 50 ед. закрывает rare_goal=10 одним узлом")


func test_common_node_is_counted_but_not_rare() -> void:
	var pilot := _pilot_with_role()

	_extract(pilot, &"wood")

	assert_that(pilot.extracted_nodes).is_equal(1)
	assert_that(pilot.extracted_total).is_equal(5)
	assert_that(pilot.rare_nodes()).is_equal(0)
	assert_that(pilot.rare_count()).is_equal(0)
	assert_bool(pilot.role.goal_met(pilot)).is_false() \
		.override_failure_message("обычный ресурс не должен приближать редкую цель")


func test_metrics_report_nodes_and_units_side_by_side() -> void:
	var pilot := _pilot_with_role()

	_extract(pilot, &"gold")
	_extract(pilot, &"crystal")
	var metrics: Dictionary = pilot.role.metrics(pilot)

	assert_that(int(metrics.rare_nodes)).is_equal(2)
	assert_that(int(metrics.rare_extracted)).is_equal(55)
	assert_that(int(metrics.resource_nodes_extracted)).is_equal(2)
	assert_that(int(metrics.resources_extracted)).is_equal(55)
	assert_that(int(metrics.rare_goal)).is_equal(10)
	# Разница узлов и единиц — ровно то, что раньше терялось в строке матрицы.
	assert_bool(int(metrics.rare_extracted) > int(metrics.rare_nodes)).is_true() \
		.override_failure_message("единицы обязаны оставаться больше узлов, иначе мера цели снова станет неотличимой")


func test_counters_reset_between_profiles_in_one_process() -> void:
	# Матрица гоняет 11 профилей в одном процессе: непройденный сброс = второй класс
	# начинает забег с чужой добычей (класс дефекта T-204, только про числа).
	var pilot := _pilot_with_role()
	_extract(pilot, &"gold")
	assert_that(pilot.rare_nodes()).is_equal(1)

	pilot._reset_extraction_counters()

	assert_that(pilot.rare_nodes()).is_equal(0)
	assert_that(pilot.rare_count()).is_equal(0)
	assert_that(pilot.extracted_nodes).is_equal(0)
	assert_that(pilot.extracted_total).is_equal(0)


func test_rare_targets_seen_counts_distinct_cells_only() -> void:
	var pilot := _FakeCollectorPilot.new()
	var role := CollectorRole.new()
	role.target = _COLLECTOR_TARGET

	# Две клетки с кристаллом: цель — ближайшая; повторный выбор той же клетки не
	# считается новым «в поле зрения».
	pilot._map_gen.resource_cells[Vector2i(2, 0)] = ResourceType.ID.CRYSTAL
	pilot._map_gen.resource_cells[Vector2i(6, 0)] = ResourceType.ID.GEMS
	pilot._spawner.res[Vector2i(2, 0)] = ResourceType.ID.CRYSTAL
	pilot._spawner.res[Vector2i(6, 0)] = ResourceType.ID.GEMS

	assert_bool(role.collect_target(pilot) == Vector2i(2, 0)).is_true() \
		.override_failure_message("ближайший редкий узел должен выбираться целью")
	role.collect_target(pilot)
	assert_that(int(role.metrics(pilot).get("rare_targets_seen", -1))).is_equal(1)

	# Первая клетка собрана (у спавнера её больше нет) — политика берёт следующую.
	pilot._spawner.res.erase(Vector2i(2, 0))
	pilot._map_gen.resource_cells.erase(Vector2i(2, 0))
	assert_bool(role.collect_target(pilot) == Vector2i(6, 0)).is_true() \
		.override_failure_message("после сбора цели целью должен стать следующий редкий узел")
	assert_that(int(role.metrics(pilot).get("rare_targets_seen", -1))).is_equal(2)
	pilot.free()


func test_no_rare_nodes_leaves_targets_seen_empty_and_returns_null() -> void:
	var pilot := _FakeCollectorPilot.new()
	var role := CollectorRole.new()
	role.target = _COLLECTOR_TARGET
	pilot._map_gen.resource_cells[Vector2i(3, 0)] = ResourceType.ID.WOOD
	pilot._spawner.res[Vector2i(3, 0)] = ResourceType.ID.WOOD

	assert_bool(role.collect_target(pilot) == null).is_true() \
		.override_failure_message("нет редких узлов — базовая логика сбора, а не ложная цель")
	assert_that(int(role.metrics(pilot).get("rare_targets_seen", -1))).is_equal(0)
	pilot.free()


class _FakeSpawner extends Node:
	var res: Dictionary = {}

	func get_res_type_at(cell: Vector2i) -> int:
		return int(res.get(cell, -1))


class _FakeMap extends RefCounted:
	var resource_cells: Dictionary = {}


class _FakeCollectorPilot extends Node:
	var _spawner := _FakeSpawner.new()
	var _map_gen := _FakeMap.new()
	var _world = null
	var turn := 1
	var extracted_total := 0
	var extracted_nodes := 0
	var _rare_count := 0
	var _rare_nodes := 0

	func _init() -> void:
		add_child(_spawner)

	func _map() -> RefCounted:
		return _map_gen

	func _hero_cell() -> Vector2i:
		return Vector2i.ZERO

	func rare_count() -> int:
		return _rare_count

	func rare_nodes() -> int:
		return _rare_nodes
