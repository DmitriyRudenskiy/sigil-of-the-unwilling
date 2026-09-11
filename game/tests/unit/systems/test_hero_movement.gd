extends BaseTest




var _map
var _mov
var _block_next_step: bool = false

func before_test() -> void:
	_block_next_step = false
	_setup_map()

func after_test() -> void:
	_teardown()

func _teardown() -> void:
	if _mov != null:
		_mov.free()
		_mov = null
	if _map != null:
		_map.free()
		_map = null

func _setup_map() -> void:
	_teardown()
	_map = MapGenerator.new()
	_map.map_width = 12
	_map.map_height = 12
	_map.seed_value = 1
	_map.generate()
	for y in _map.map_height:
		for x in _map.map_width:
			_map.model.set_terrain(Vector2i(x, y), HexUtils.Terrain.GRASS)

	_mov = HeroMovementController.new()
	_mov.set_artifact_effect_fn(func(_e: StringName) -> bool: return false)
	_mov.setup(_map)
	_mov.move_requested.connect(_on_move_requested)
	_mov.hero_moved.connect(_on_hero_moved)
	assert_that(_mov.current_cell).is_equal(Vector2i(0, 0))

func _on_move_requested(_pos: Vector2, _dur: float, cb: Callable) -> void:
	cb.call()

func _on_hero_moved(cell: Vector2i) -> void:
	if not _block_next_step:
		return
	if _mov.path.size() >= 2:
		_map.model.set_terrain(_mov.path[1], HexUtils.Terrain.MOUNTAIN)

func test_can_reach_within_mp() -> void:
	assert_bool(_mov.can_reach(Vector2i(11, 0))).is_false()
	assert_bool(_mov.can_reach(Vector2i(5, 0))).is_true()
	assert_bool(_mov.can_reach(_mov.current_cell)).is_true()

func test_move_to_cell_partial_when_insufficient_mp() -> void:
	_mov.move_points = 3.0
	assert_bool(_mov.can_reach(Vector2i(5, 0))).is_false()
	assert_that(_mov.reach_problem(Vector2i(5, 0))).is_equal("insufficient_mp")
	var ok: bool = _mov.move_to_cell(Vector2i(5, 0))
	assert_bool(ok).is_true()
	assert_bool(_mov.current_cell != Vector2i(0, 0)).is_true()
	assert_bool(_mov.current_cell != Vector2i(5, 0)).is_true()
	assert_bool(_mov.move_points >= 0.0 and _mov.move_points < 1.0).is_true()
	assert_bool(_mov.is_moving).is_false()

func test_move_to_cell_full_move() -> void:
	var ok: bool = _mov.move_to_cell(Vector2i(5, 0))
	assert_bool(ok).is_true()
	assert_that(_mov.current_cell).is_equal(Vector2i(5, 0))
	assert_that(_mov.move_points).is_equal(5.0)

func test_move_to_cell_unreachable() -> void:
	var start: Vector2i = _mov.current_cell
	for nb in HexUtils.get_all_neighbors(start):
		_map.model.set_terrain(nb, HexUtils.Terrain.MOUNTAIN)
	assert_bool(_mov.move_to_cell(Vector2i(5, 5))).is_false()
	assert_that(_mov.reach_problem(Vector2i(5, 5))).is_equal("unreachable")

func test_blocked_mid_move_does_not_corrupt_mp() -> void:
	_block_next_step = true
	var ok: bool = _mov.move_to_cell(Vector2i(4, 0))
	assert_bool(ok).is_true()
	assert_bool(_mov.path.is_empty()).is_true()
	assert_bool(_mov.is_moving).is_false()
	assert_bool(_mov.move_points > 8.0).is_true()
	assert_bool(_mov.can_reach(_mov.current_cell)).is_true()

func test_partial_walk_progresses_toward_target() -> void:
	_mov.move_points = 2.0
	assert_bool(_mov.can_reach(Vector2i(4, 0))).is_false()
	var start: Vector2i = _mov.current_cell
	var ok: bool = _mov.move_to_cell(Vector2i(4, 0))
	assert_bool(ok).is_true()
	assert_bool(_mov.current_cell != start).is_true()
	assert_bool(HexUtils.hex_distance(_mov.current_cell, Vector2i(4, 0)) < HexUtils.hex_distance(start, Vector2i(4, 0))).is_true()
	assert_bool(_mov.is_moving).is_false()
	_mov.move_points = _mov.get_daily_movement_points()
	assert_bool(_mov.can_reach(Vector2i(4, 0))).is_true()
