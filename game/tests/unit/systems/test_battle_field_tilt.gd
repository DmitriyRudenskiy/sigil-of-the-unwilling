extends BaseTest

## alpha-battle-field 1.1: наклон плоскости поля — один пересчёт клетки в экран.
##
## Наклон живёт в двух местах: узел тайлмапа (носитель тайлов) и `field_point()`
## (всё остальное — подсветки, курсор, обводка, фигуры, камера). Проверяем не
## «красиво ли», а два инварианта, без которых поле расходится с кликом:
##  • каждая клетка поля возвращается той же клеткой, если кликнуть в её точку:
##    обратный ход `global_to_map` обязан разворачивать наклон сам;
##  • наклон укорочивает поле по вертикали и не трогает горизонталь, а локальная
##    сетка (`HexGrid` считает по ней дистанции и пути) остаётся без наклона —
##    то есть `TILT = 1.0` был бы сегодняшним плоским полем, и правила не менялись.


var _original_size := Vector2i(1920, 1080)


func before_test() -> void:
	_original_size = get_tree().root.size


func after_test() -> void:
	super.after_test()
	get_tree().root.size = _original_size
	await get_tree().process_frame


func _battle() -> Node:
	get_tree().root.size = _original_size
	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	auto_free(battle)
	add_child(battle)
	await await_millis(300)
	return battle


## Тайлмап поля берётся у самого представления: `setup()` переименовывает узел,
## и поиск по типу мог бы вернуть не тот слой.
func _tm(view: BattleView) -> TileMapLayer:
	return view._tile_map


## Клик в точку клетки обязан попадать в неё — для всех 99 клеток поля.
func test_every_cell_round_trips_under_the_tilt() -> void:
	var battle: Node = await _battle()
	var view := _view_of(battle)
	assert_object(_tm(view)).is_not_null()
	var misses := 0
	for y in BattleState.BH:
		for x in BattleState.BW:
			var cell := Vector2i(x, y)
			var where: Vector2i = view.global_to_map(view.to_global(view.field_point(cell)))
			if where != cell:
				misses += 1
	assert_int(misses).is_zero().override_failure_message(
		"наклонное поле: %d клеток из %d теряют клик" % [misses, BattleState.BW * BattleState.BH])


## Наклон применён к экранной точке и не тронул локальную сетку: x клетки совпадает
## с плоским полем, y укорочен ровно в `TILT` раз.
func test_tilt_shortens_the_screen_point_only() -> void:
	var battle: Node = await _battle()
	var view := _view_of(battle)
	var tm := _tm(view)
	var flat: Vector2 = tm.map_to_local(Vector2i(0, 1))
	var tilted: Vector2 = view.field_point(Vector2i(0, 1))
	assert_float(tilted.x).is_equal_approx(flat.x, 0.001) \
		.override_failure_message("наклон тронул горизонталь клетки")
	assert_float(tilted.y).is_equal_approx(flat.y * BattleView.TILT, 0.001) \
		.override_failure_message("клетка укорочена не в TILT раз")


## Мера поля для камеры: высота укорочена наклоном, ширина и запас по краям не
## тронуты — иначе `fit_camera` вписывает не то, что нарисовано.
func test_field_size_follows_the_tilt() -> void:
	var battle: Node = await _battle()
	var view := _view_of(battle)
	var tm := _tm(view)
	# Мера поля — разность концов, а не координата дальнего угла: `map_to_local`
	# даёт центр клетки от начала тайла, и нулевая клетка смещена на половину соты.
	var zero: Vector2 = tm.map_to_local(Vector2i.ZERO)
	var corner: Vector2 = tm.map_to_local(Vector2i(BattleState.BW - 1, BattleState.BH - 1))
	var flat := corner - zero
	var field: Vector2 = view.field_size()
	assert_float(field.x).is_equal_approx(absf(flat.x) + 60.0, 0.001) \
		.override_failure_message("ширина поля не должна зависеть от наклона")
	assert_float(field.y).is_equal_approx(absf(flat.y) * BattleView.TILT + 60.0, 0.001) \
		.override_failure_message("высота поля не равна плоской высоте в TILT раз")

func _view_of(battle: Node) -> BattleView:
	return battle.get_node("BattleView") as BattleView
