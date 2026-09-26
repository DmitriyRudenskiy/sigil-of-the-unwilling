class_name HeroMovementComponent
extends HeroComponent
## Обёртка над HeroMovementController.
## Перенаправляет вызовы и пробрасывает сигналы.

var _controller: HeroMovementController = null

signal hero_moved(cell: Vector2i)
signal movement_finished(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal path_previewed(text: String)
signal planned_route_changed(committed: bool)
signal reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float)
signal reach_preview_cleared()
signal facing_changed(delta: Vector2i)
signal move_requested(target: Vector2, duration: float, callback: Callable)
signal request_hide_path_visual()
signal request_show_marker(pos: Vector2)
signal request_idle_animation()
signal request_kill_tween()
signal request_time_update(step_cost: float)
signal request_resource_pickup(res_type: int)
signal request_set_position(pos: Vector2)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroMovementController.new()
	_controller.name = "Movement"
	_controller.max_move_points = GameNumbers.HERO_DAILY_MOVEMENT
	add_child(_controller)
	_wire_signals()

func initialize() -> void:
	pass

func setup_map(map: MapGenerator) -> void:
	_controller.set_artifact_effect_fn(_has_artifact_effect)
	_controller.setup(map)

func get_controller() -> HeroMovementController:
	return _controller

func set_controller(v: HeroMovementController) -> void:
	_controller = v

func on_map_clicked(cell: Vector2i) -> void:
	_controller.on_map_clicked(cell)

func move_to_cell(cell: Vector2i) -> bool:
	return _controller.move_to_cell(cell)

func can_reach(cell: Vector2i) -> bool:
	return _controller.can_reach(cell)

func reach_problem(cell: Vector2i) -> String:
	return _controller.reach_problem(cell)

func cancel_pending(clear_text: bool = true) -> void:
	_controller.cancel_pending(clear_text)

func cancel_planned_path() -> void:
	_controller.cancel_planned_path()

func force_stop() -> void:
	_controller.force_stop()

func end_turn_movement() -> void:
	_controller.end_turn_movement()

func auto_follow_at_turn_start() -> void:
	_controller.auto_follow_at_turn_start()

func get_daily_movement_points(movement_mod: int = 0) -> float:
	return _controller.get_daily_movement_points(movement_mod)

func get_current_cell() -> Vector2i:
	return _controller.current_cell

func set_current_cell(cell: Vector2i) -> void:
	_controller.current_cell = cell

func get_move_points() -> float:
	return _controller.move_points

func set_move_points(v: float) -> void:
	_controller.move_points = v

func is_moving() -> bool:
	return _controller.is_moving

func get_planned_path() -> Array[Vector2i]:
	return _controller.planned_path

func set_planned_path(path: Array[Vector2i]) -> void:
	_controller.planned_path = path

func teleport(cell: Vector2i) -> void:
	_controller.teleport(cell)

func end_turn() -> void:
	_controller.end_turn_movement()

func serialize() -> Dictionary:
	return {
		"cell": {"x": _controller.current_cell.x, "y": _controller.current_cell.y},
		"move_points": _controller.move_points,
		"planned_path": _serialize_planned_path(),
	}

func deserialize(data: Dictionary) -> void:
	var c: Dictionary = data.get("cell", {})
	_controller.current_cell = Vector2i(int(c.get("x", 0)), int(c.get("y", 0)))
	_controller.move_points = float(data.get("move_points", _controller.move_points))
	_controller.planned_path = _deserialize_planned_path(data.get("planned_path", []))

func _serialize_planned_path() -> Array:
	var out: Array = []
	for cell in _controller.planned_path:
		out.append({"x": cell.x, "y": cell.y})
	return out

func _deserialize_planned_path(data: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in data:
		if p is Dictionary:
			out.append(Vector2i(int(p.get("x", -1)), int(p.get("y", -1))))
	return out

func _has_artifact_effect(effect: StringName) -> bool:
	if _hero == null:
		return false
	return _hero.has_artifact_effect(effect)

func _wire_signals() -> void:
	_controller.hero_moved.connect(func(c): hero_moved.emit(c))
	_controller.movement_finished.connect(func(c): movement_finished.emit(c))
	_controller.hero_entered_village.connect(func(c): hero_entered_village.emit(c))
	_controller.movement_points_changed.connect(func(c, m): movement_points_changed.emit(c, m))
	_controller.path_previewed.connect(func(t): path_previewed.emit(t))
	_controller.planned_route_changed.connect(func(b): planned_route_changed.emit(b))
	_controller.reach_preview_changed.connect(func(p, d, m): reach_preview_changed.emit(p, d, m))
	_controller.reach_preview_cleared.connect(reach_preview_cleared.emit)
	_controller.facing_changed.connect(func(d): facing_changed.emit(d))
	_controller.move_requested.connect(func(t, d, cb): move_requested.emit(t, d, cb))
	_controller.request_hide_path_visual.connect(request_hide_path_visual.emit)
	_controller.request_show_marker.connect(func(p): request_show_marker.emit(p))
	_controller.request_idle_animation.connect(request_idle_animation.emit)
	_controller.request_kill_tween.connect(request_kill_tween.emit)
	_controller.request_time_update.connect(func(c): request_time_update.emit(c))
	_controller.request_resource_pickup.connect(func(r): request_resource_pickup.emit(r))
	_controller.request_set_position.connect(func(p): request_set_position.emit(p))
