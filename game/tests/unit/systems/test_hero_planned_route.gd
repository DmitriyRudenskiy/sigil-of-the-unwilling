extends GdUnitTestSuite

const _MapGenerator = preload("res://scripts/world/MapGenerator.gd")
const _Movement = preload("res://scripts/entities/HeroMovementController.gd")
const _HexUtils = preload("res://scripts/core/HexUtils.gd")


var _map  
var _mov  
var _route_committed := false  

func before_test() -> void:
	_route_committed = false
	_setup_map()

func after_test() -> void:
	_teardown()


func assert_eq_cells(cells: Array, expected: Array, msg: String) -> void:
	assert_that(_cells_to_str(cells)).is_equal(_cells_to_str(expected))

func _cells_to_str(cells: Array) -> String:
	var parts: Array = []
	for c in cells:
		parts.append(str(c))
	return "[" + ", ".join(parts) + "]"

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
	for y in _map.map_height:
		for x in _map.map_width:
			_map.model.set_terrain(Vector2i(x, y), _HexUtils.Terrain.GRASS)

	_mov = _Movement.new()
	_mov.set_artifact_effect_fn(func(_e: StringName) -> bool: return false)
	_mov.setup(_map)
	_mov.move_requested.connect(_on_move_requested)
	_mov.planned_route_changed.connect(_on_planned_route_changed)
	assert_that(_mov.current_cell).is_equal(Vector2i(0, 0))

func _on_move_requested(_pos: Vector2, _dur: float, cb: Callable) -> void:
	cb.call()

func _on_planned_route_changed(committed: bool) -> void:
	_route_committed = committed


func test_second_click_fixates_route() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	assert_that(_mov.pending_cell).is_equal(target)
	assert_bool(_mov.is_moving).is_false()
	assert_bool(_mov.planned_path.is_empty()).is_true()

	_mov.on_map_clicked(target)
	assert_bool(not _mov.is_moving).is_true()
	assert_bool(_mov.planned_path.size() >= 2).is_true()
	assert_that(_mov.planned_path[0]).is_equal(_mov.current_cell)
	assert_that(_mov.planned_path.back()).is_equal(target)
	assert_bool(_route_committed).is_true()

func test_second_click_moves_immediately_when_fixed() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)  
	_mov.on_map_clicked(target)  
	assert_bool(_mov.planned_path.size() >= 2).is_true()
	assert_that(_mov.current_cell).is_equal(Vector2i(0, 0))

	_mov.on_map_clicked(target)
	assert_that(_mov.current_cell).is_equal(target)
	assert_bool(_mov.planned_path.is_empty()).is_true()

func test_auto_follow_reaches_goal_clears_route() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(3, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  
	assert_bool(_mov.planned_path.size() >= 2).is_true()

	_mov.auto_follow_at_turn_start()
	assert_that(_mov.current_cell).is_equal(target)
	assert_bool(_mov.planned_path.is_empty()).is_true()

func test_auto_follow_keeps_remainder_when_out_of_mp() -> void:
	_mov.move_points = 3.0  
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  
	assert_bool(_mov.planned_path.size() >= 2).is_true()

	_mov.auto_follow_at_turn_start()
	assert_that(_mov.current_cell).is_equal(Vector2i(3, 0))
	assert_bool(not _mov.is_moving).is_true()
	assert_that(_mov.move_points).is_equal(0.0)
	assert_eq_cells(_mov.planned_path, [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)],
		"remainder route preserved with head == current_cell")

func test_auto_follow_continues_remainder_next_turn() -> void:
	_mov.move_points = 3.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  
	_mov.auto_follow_at_turn_start()  
	assert_that(_mov.current_cell).is_equal(Vector2i(3, 0))

	_mov.move_points = 10.0
	_mov.auto_follow_at_turn_start()
	assert_that(_mov.current_cell).is_equal(target)
	assert_bool(_mov.planned_path.is_empty()).is_true()

func test_cancel_planned_path() -> void:
	_mov.move_points = 10.0
	var target := Vector2i(5, 0)
	_mov.on_map_clicked(target)
	_mov.on_map_clicked(target)  
	assert_bool(_mov.planned_path.size() >= 2).is_true()

	_mov.cancel_planned_path()
	assert_bool(_mov.planned_path.is_empty()).is_true()
	assert_bool(_route_committed).is_false()

func test_cancel_empty_route_is_noop() -> void:
	_mov.cancel_planned_path()
	assert_bool(_mov.planned_path.is_empty()).is_true()
	assert_bool(_route_committed).is_false()

func test_auto_follow_unreachable_goal_noop() -> void:
	_mov.move_points = 10.0
	var start: Vector2i = _mov.current_cell
	for nb: Vector2i in _HexUtils.get_all_neighbors(start):
		_map.model.set_terrain(nb, _HexUtils.Terrain.MOUNTAIN)
	_mov.on_map_clicked(Vector2i(5, 5))
	_mov.on_map_clicked(Vector2i(5, 5))
	assert_bool(_mov.planned_path.is_empty()).is_true()
	_mov.auto_follow_at_turn_start()
	assert_bool(_mov.is_moving).is_false()
