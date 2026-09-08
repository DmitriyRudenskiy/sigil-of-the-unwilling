class_name WorldInput
extends Node2D

var map: MapGenerator = null
var hero: HeroController = null
var camera: WorldCamera = null
var world: Node = null


func _unhandled_input(event: InputEvent) -> void:
	if map == null or hero == null or camera == null:
		return
	if world != null and world.has_method("is_terminal") and world.is_terminal():
		return
	if world != null and world.has_method("is_death_sequence_open") \
			and world.is_death_sequence_open():
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.step_zoom(1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.step_zoom(-1)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		hero.cancel_planned_path()
		hero.cancel_pending()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if not map.has_valid_tilemap():
			return
		var cell := map.local_to_map(get_global_mouse_position())
		if cell.x >= 0 and cell.x < map.map_width and cell.y >= 0 and cell.y < map.map_height:
			hero.on_map_clicked(cell)
