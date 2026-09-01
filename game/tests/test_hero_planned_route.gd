extends RefCounted
## Тесты планирования маршрута и автохода (HeroMovementController).
##
## Покрывают hero-path-planning:
##  1. Фикация маршрута 2-м кликом (состоятельный режим).
##  2. Немедленное движение при зафиксированном маршруте (2-й клик).
##  3. Автоход в начале хода: достижение цели → очистка маршрута.
##  4. Автоход с остатком ходов → маршрут сохраняется на следующий ход.
##  5. Отмена маршрута (cancel_planned_path).
##
## Запуск: godot --headless -s tests/run_tests.gd

const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")
const _Movement = preload("res://scripts/entities/HeroMovementController.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")

var _passed := 0
var _failed := 0
var _errors: Array[String] = []

var _map  # MapGenerator (Node2D, без сцены)
var _mov  # HeroMovementController (Node)
var _route_committed := false  # флаг-наблюдатель за planned_route_changed

func before_each() -> void:
	_route_committed = false
	_setup_map()

func after_each() -> void:
	_teardown()

# ==================== УТИЛИТЫ ====================

func _pass(msg: String) -> void:
	_passed += 1
	print("[PASS] %s" % msg)

func _fail(msg: String) -> void:
	_failed += 1
	_errors.append(msg)
	printerr("[FAIL] %s" % msg)

func assert_true(val: bool, msg: String) -> void:
	if val:
		_pass(msg)
	else:
		_fail(msg)

func assert_false(val: bool, msg: String) -> void:
	assert_true(not val, msg)

func assert_eq(a: Variant, b: Variant, msg: String) -> void:
	if a == b:
		_pass(msg)
	else:
		_fail("%s (got %s, expected %s)" % [msg, str(a), str(b)])

func assert_eq_cells(cells: Array, expected: Array, msg: String) -> void:
	if cells != expected:
		_fail("%s (got %s, expected %s)" % [msg, _cells_to_str(cells), _cells_to_str(expected)])
	else:
		_pass(msg)

func _cells_to_str(cells: Array) -> String:
	var parts: Array = []
	for c in cells:
		parts.append(str(c))
	return "[" + ", ".join(parts) + "]"

func get_results() -> String:
	# Раннер вызывает before_each один лишний раз после последнего теста —
	# освобождаем сиротский сетап, иначе он уйдёт в ObjectDB/ResourceCache.
	_teardown()
	var lines := _errors.duplicate()
	lines.append("")
	lines.append("Results: %d passed, %d failed" % [_passed, _failed])
	if _failed == 0:
		lines.append("ALL TESTS PASSED")
	else:
		lines.append("SOME TESTS FAILED")
	return "\n".join(lines)

# ==================== SETUP ====================

func _teardown() -> void:
	if _mov != null:
		_mov.free()
		_mov = null
	if _map != null:
		_map.free()
		_map = null


func _setup_map() -> void:
	_teardown()
	_map = _MapGenerator.new()
	_map.map_width = 12
	_map.map_height = 12
	_map.seed_value = 1
	_map.generate()
	# Выравнием террейн в траву — детерминированная проходимость и стоимость 1.0
	for y in _map.map_height:
		for x in _map.map_width:
			_map.model.set_terrain(Vector2i(x, y), _HexUtils.Terrain.GRASS)

	_mov = _Movement.new()
	_mov.set_artifact_effect_fn(func(_e: StringName) -> bool: return false)
	_mov.setup(_map)
	# Имитация визуального слоя: шаги завершаются мгновенно (колбэк из move_requested)
	_mov.move_requested.connect(_on_move_requested)
	_mov.planned_route_changed.connect(_on_planned_route_changed)
	# Герой ставится в первую проходимую клетку — (0, 0) на травяной карте
	assert_eq(_mov.current_cell, Vector2i(0, 0), "hero placed on (0,0)")

func _on_move_requested(_pos: Vector2, _dur: float, cb: Callable) -> void:
	cb.call()

func _on_planned_route_changed(committed: bool) -> void:
	_route_committed = committed

# ==================== ТЕСТЫ ====================

## 2-й клик фиксирует маршрут: путь сохраняется, герой НЕ двигается.
func test_second_click_fixates_route() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(5, 0)
	# Первый клик — превью (set pending).
	_mov.on_map_clicked(target)
	assert_eq(_mov.pending_cell, target, "first click sets pending target")
	assert_false(_mov.is_moving, "no movement after first click")
	assert_true(_mov.planned_path.is_empty(), "route not yet fixed")

	# Второй клик — фиксация маршрута.
	_mov.on_map_clicked(target)
	assert_true(not _mov.is_moving, "hero does not move on fixate")
	assert_true(_mov.planned_path.size() >= 2, "planned_path has full path (size >= 2)")
	assert_eq(_mov.planned_path[0], _mov.current_cell, "planned_path head == current_cell")
	assert_eq(_mov.planned_path.back(), target, "planned_path tail == target")
	assert_true(_route_committed, "planned_route_changed(true) emitted on fixate")

## 2-й клик по зафиксированному маршруту → немедленное движение.
func test_second_click_moves_immediately_when_fixed() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)  # first
	_mov.on_map_clicked(target)  # fixate
	assert_true(_mov.planned_path.size() >= 2, "route fixed")
	assert_eq(_mov.current_cell, Vector2i(0, 0), "still at origin after fixate")

	# Повторный 2-й клик (pending_cell всё ещё target) → немедленное движение.
	# Headless: движение синхронно, поэтому к моменту возврата из on_map_clicked
	# герой уже дошёл до цели (это и доказывает «немедленно», а не в следующий ход).
	_mov.on_map_clicked(target)
	assert_eq(_mov.current_cell, target, "hero moved immediately on 2nd click (headless)")
	assert_true(_mov.planned_path.is_empty(), "route cleared after reaching goal")

## Автоход достигает цели → маршрут очищается.
func test_auto_follow_reaches_goal_clears_route() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(3, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  # fixate
	assert_true(_mov.planned_path.size() >= 2, "route fixed to (3,0)")

	_mov.auto_follow_at_turn_start()
	# Headless: движение синхронно, к моменту возврата герой уже в цели.
	assert_eq(_mov.current_cell, target, "hero reached goal via auto_follow")
	assert_true(_mov.planned_path.is_empty(), "route cleared when goal reached")

## Автоход исчерпал ходы → маршрут сохраняется (остаток) на следующий ход.
func test_auto_follow_keeps_remainder_when_out_of_mp() -> void:
	_mov.move_points = 3.0  # только 3 шага
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  # fixate full path to (5,0)
	assert_true(_mov.planned_path.size() >= 2, "route fixed to (5,0)")

	_mov.auto_follow_at_turn_start()
	# 3 шага: (0,0)->(1,0)->(2,0)->(3,0), MP исчерпаны.
	assert_eq(_mov.current_cell, Vector2i(3, 0), "hero stopped at (3,0) out of MP")
	assert_true(not _mov.is_moving, "movement stopped (out of MP)")
	assert_eq(_mov.move_points, 0.0, "MP exhausted (0.0)")
	# Остаток маршрута: [(3,0),(4,0),(5,0)], голова == current_cell.
	assert_eq_cells(_mov.planned_path, [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)],
		"remainder route preserved with head == current_cell")

## Повторный автоход проходит остаток маршрута до цели.
func test_auto_follow_continues_remainder_next_turn() -> void:
	_mov.move_points = 3.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  # fixate
	_mov.auto_follow_at_turn_start()  # дошёл до (3,0), остаток [(3,0),(4,0),(5,0)]
	assert_eq(_mov.current_cell, Vector2i(3, 0), "at (3,0) after first auto_follow")

	# Новый ход: ходы сброшены, остаток автоходится.
	_mov.move_points = 10.0
	_mov.auto_follow_at_turn_start()
	assert_eq(_mov.current_cell, target, "auto_follow finished remainder to (5,0)")
	assert_true(_mov.planned_path.is_empty(), "route cleared after finishing remainder")

## Отмена маршрута очищает planned_path и эмитирует committed=false.
func test_cancel_planned_path() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  # fixate
	assert_true(_mov.planned_path.size() >= 2, "route fixed")

	_mov.cancel_planned_path()
	assert_true(_mov.planned_path.is_empty(), "route cleared on cancel")
	assert_false(_route_committed, "planned_route_changed(false) emitted on cancel")

## Отмена пустого маршрута — бездействие (без исключений). Никакого сигнала.
func test_cancel_empty_route_is_noop() -> void:
	# before_each уже обнулял _route_committed = false; проверяем, что
	# отмена пустого маршрута НЕ эмитит сигнал (остаётся false).
	_mov.cancel_planned_path()
	assert_true(_mov.planned_path.is_empty(), "empty route stays empty")
	assert_false(_route_committed, "no signal emitted for empty route")

## Цель недостижима: автоход не запускает движение и не падает.
func test_auto_follow_unreachable_goal_noop() -> void:
	_mov.move_points = 10.0
	# Загородим соседей героя горами — пути никуда нет.
	var start: Vector2i = _mov.current_cell
	for nb: Vector2i in _HexUtils.get_all_neighbors(start):
		_map.model.set_terrain(nb, _HexUtils.Terrain.MOUNTAIN)
	# Попытка зафиксировать маршрут: _full_path вернёт пустой/одиночный.
	_mov.on_map_clicked(Vector2i(5, 5))
	_mov.on_map_clicked(Vector2i(5, 5))
	assert_true(_mov.planned_path.is_empty(), "route not fixed when goal unreachable")
	# Автоход должен отработать без падений и без движения.
	_mov.auto_follow_at_turn_start()
	assert_false(_mov.is_moving, "no movement when route unreachable")
