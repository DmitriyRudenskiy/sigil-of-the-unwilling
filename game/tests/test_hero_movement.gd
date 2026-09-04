extends "res://tests/gut_base.gd"
## Регрессионные тесты движения героя (HeroMovementController).
##
## Прикрывают баги, найденные при автопрогоне сценариев:
##  1. move_to_cell запускал ЧАСТИЧНОЕ движение к недостижимой цели —
##     агент ждал 30с ("Movement timeout"), герой оставался на полпути
##     с положительными ОД.
##  2. Если клетка пути становилась непроходимой во время движения,
##     move_points портился до -INF и герой застревал до конца хода.
##
## Запуск:
##   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_hero_movement.gd -gexit

const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")
const _Movement = preload("res://scripts/entities/HeroMovementController.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")


var _map  # MapGenerator (Node2D, без сцены)
var _mov  # HeroMovementController (Node)
var _block_next_step: bool = false  # флаг для теста INF-гарда

func before_each() -> void:
	_block_next_step = false
	_setup_map()

## Узлы (MapGenerator/Node2D и HeroMovementController/Node) — это Object,
## а не RefCounted: без явного free() каждый тест утекает в ObjectDB
## (CanvasItem RID, texture RID'ы, «resources still in use» при выходе).
func after_each() -> void:
	_teardown()

# ==================== УТИЛИТЫ ====================

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
	# Выравниваем террейн в траву — детерминированная проходимость и стоимость 1.0
	for y in _map.map_height:
		for x in _map.map_width:
			_map.model.set_terrain(Vector2i(x, y), _HexUtils.Terrain.GRASS)

	_mov = _Movement.new()
	_mov.set_artifact_effect_fn(func(_e: StringName) -> bool: return false)
	_mov.setup(_map)
	# Имитация визуального слоя: шаги завершаются мгновенно (колбэк из move_requested)
	_mov.move_requested.connect(_on_move_requested)
	_mov.hero_moved.connect(_on_hero_moved)
	# Герой ставится в первую проходимую клетку — (0, 0) на травяной карте
	assert_eq(_mov.current_cell, Vector2i(0, 0), "hero placed on (0,0)")

func _on_move_requested(_pos: Vector2, _dur: float, cb: Callable) -> void:
	cb.call()

## Встроенный «хаос»: по флагу блокируем следующую клетку пути,
## имитируя динамическую непроходимость (враг занял клетку и т.п.).
func _on_hero_moved(cell: Vector2i) -> void:
	if not _block_next_step:
		return
	if _mov.path.size() >= 2:
		_map.model.set_terrain(_mov.path[1], _HexUtils.Terrain.MOUNTAIN)

# ==================== ТЕСТЫ ====================

func test_can_reach_within_mp() -> void:
	# 12 клеток вправо по прямой: 12 шагов x 1.0 ОД > 10 ОД — НЕ достичь
	assert_false(_mov.can_reach(Vector2i(11, 0)), "12 cells away with 10 MP: cannot reach")
	# 5 клеток: 5 x 1.0 = 5.0 ОД — достичь
	assert_true(_mov.can_reach(Vector2i(5, 0)), "5 cells away with 10 MP: can reach")
	assert_true(_mov.can_reach(_mov.current_cell), "current cell always reachable")

func test_move_to_cell_partial_when_insufficient_mp() -> void:
	# Семантика: цель дальше ОД — герой идёт в её сторону, пока хватает ОД
	_mov.move_points = 3.0
	assert_false(_mov.can_reach(Vector2i(5, 0)), "can_reach is false (5 steps > 3 MP)")
	assert_eq(_mov.reach_problem(Vector2i(5, 0)), "insufficient_mp", "diagnosis: insufficient_mp")
	var ok: bool = _mov.move_to_cell(Vector2i(5, 0))
	assert_true(ok, "move_to_cell starts partial movement toward distant target")
	assert_true(_mov.current_cell != Vector2i(0, 0), "hero actually advanced")
	assert_true(_mov.current_cell != Vector2i(5, 0), "hero did not reach the target")
	assert_true(_mov.move_points >= 0.0 and _mov.move_points < 1.0, "MP partially spent (got %s)" % str(_mov.move_points))
	assert_false(_mov.is_moving, "movement stopped after MP exhaustion")

func test_move_to_cell_full_move() -> void:
	var ok: bool = _mov.move_to_cell(Vector2i(5, 0))
	assert_true(ok, "move_to_cell returns true for reachable target")
	assert_eq(_mov.current_cell, Vector2i(5, 0), "hero arrived at target")
	assert_eq(_mov.move_points, 5.0, "MP spent on 5 grass steps")

func test_move_to_cell_unreachable() -> void:
	# Загородить соседей героя (0,0) горами — пути нет никуда
	var start: Vector2i = _mov.current_cell
	for nb in _HexUtils.get_all_neighbors(start):
		_map.model.set_terrain(nb, _HexUtils.Terrain.MOUNTAIN)
	assert_false(_mov.move_to_cell(Vector2i(5, 5)), "move_to_cell returns false when walled in")
	assert_eq(_mov.reach_problem(Vector2i(5, 5)), "unreachable", "diagnosis: unreachable")

func test_blocked_mid_move_does_not_corrupt_mp() -> void:
	# Идём в (4, 0); после первого шага клетка (1,0)... путь A* может
	# пойти не строго по оси X — блокируем реально следующую клетку пути.
	_block_next_step = true
	var ok: bool = _mov.move_to_cell(Vector2i(4, 0))
	assert_true(ok, "move started toward reachable target")
	assert_true(_mov.path.is_empty(), "path cleared after block")
	assert_false(_mov.is_moving, "movement stopped gracefully")
	assert_true(_mov.move_points > 8.0, "MP not corrupted (expected 9.0, got %s)" % str(_mov.move_points))
	# Герой может ходить дальше — MP целы
	assert_true(_mov.can_reach(_mov.current_cell), "hero still functional after mid-move block")

func test_partial_walk_progresses_toward_target() -> void:
	# Прямая регрессия на баг "Movement timeout": агент должен понимать,
	# что при can_reach == false герой остановится на полпути (moving == false),
	# а не ждать прибытия 30 секунд.
	_mov.move_points = 2.0
	assert_false(_mov.can_reach(Vector2i(4, 0)), "4 steps need 4 MP > 2 available")
	var start: Vector2i = _mov.current_cell
	var ok: bool = _mov.move_to_cell(Vector2i(4, 0))
	assert_true(ok, "partial walk starts")
	assert_true(_mov.current_cell != start, "hero moved toward target")
	assert_true(_HexUtils.hex_distance(_mov.current_cell, Vector2i(4, 0)) < _HexUtils.hex_distance(start, Vector2i(4, 0)), "hero is closer to target than before")
	assert_false(_mov.is_moving, "hero stopped (moving == false — сигнал агенту)")
	# После остановки можно идти дальше (MP частично может остаться, но < стоимости шага)
	_mov.move_points = _mov.get_daily_movement_points()
	assert_true(_mov.can_reach(Vector2i(4, 0)), "after refresh hero can reach the target")
