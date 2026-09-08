extends GdUnitTestSuite

var _view: CityArenaView = null


# 3B: тяжёлая сцена инстанцируется в before_test, чистка в after_test.
func before_test() -> void:
	var packed := load("res://scenes/CityArena.tscn") as PackedScene
	assert_object(packed).is_not_null()
	_view = packed.instantiate() as CityArenaView
	add_child(_view)
	await get_tree().process_frame


func after_test() -> void:
	if _view != null and is_instance_valid(_view):
		_view.free()
		_view = null


func test_arena_smoke() -> void:
	var view := _view
	assert_bool(view._city != null).is_true()

	for i in 3:
		view._on_turn_pressed()
	assert_bool(view._turn == 3).is_true()

	var farm_cell: Vector2i = _first_free_r1(view)
	view._on_palette_pressed(&"farm")
	view._handle_cell_click(farm_cell)
	assert_bool(view._city.cell_is_built(farm_cell)).is_true()

	var d_cell: Vector2i = _first_free_r1(view)
	view._on_palette_pressed(&"district")
	view._handle_cell_click(d_cell)
	assert_bool(view._city.boroughs.size() == 1).is_true()

	view._on_palette_pressed(&"")
	view._handle_cell_click(farm_cell)

	view._on_hire_pressed()
	view._on_level_pressed()

	for i in 10:
		view._on_turn_pressed()
	assert_bool(view._turn == 13).is_true()

	view._on_auto_pressed()
	assert_bool(view._auto).is_true()
	await view._timer.timeout
	await view._timer.timeout
	view._on_auto_pressed()
	assert_bool(not view._auto).is_true()
	assert_bool(view._turn > 13).is_true()

	var score: float = CityArenaModel.score(view._city, view._starve_days)
	assert_bool(score > -100.0).is_true()


func test_cell_click_signal_path() -> void:
	var view := _view
	assert_bool(view._city != null).is_true()

	var cell: Vector2i = _first_free_r1(view)

	view._on_palette_pressed(&"farm")
	assert_bool(view._selected == &"farm").is_true()

	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	view._on_cell_input(view, mb, 0, Vector2.ZERO, Vector2.ZERO, cell)

	assert_bool(view._city.cell_is_built(cell)).is_true()

	view._on_cell_input(view, mb, 0, Vector2.ZERO, Vector2.ZERO, cell)
	assert_bool(view._city.cell_is_built(cell)).is_true()

	var center: Vector2i = Vector2i.ZERO
	view._on_palette_pressed(&"farm")
	view._on_cell_input(view, mb, 0, Vector2.ZERO, Vector2.ZERO, center)
	assert_bool(not view._city.cell_is_built(center)).is_true()

	var me := InputEventMouseMotion.new()
	view._on_cell_input(view, me, 0, Vector2.ZERO, Vector2.ZERO, cell)
	assert_bool(view._city.cell_is_built(cell)).is_true()


func _first_free_r1(view: CityArenaView) -> Vector2i:
	for cell in CityArenaModel.cells_in_arena():
		var cv: Vector2i = cell
		if CityArenaModel.ring_of(cv) == 1 and not view._city.cell_is_built(cv) \
				and not _worker_on(view._city, cv):
			return cv
	return Vector2i.ZERO


func _worker_on(city: City, cv: Vector2i) -> bool:
	for u in city.pop:
		if u.state == PopUnit.State.WORKER and u.tile == cv:
			return true
	return false
