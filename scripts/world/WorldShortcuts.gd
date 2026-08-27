class_name WorldShortcuts
extends Node
## Keyboard shortcuts: I (inventory), F5 (save), F9 (load), Esc (close inventory).

var _persistence
var _ui_manager: WorldUIManager


func setup(persistence: WorldPersistence, ui_manager: WorldUIManager) -> void:
	_persistence = persistence
	_ui_manager = ui_manager


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_F5:
			if _persistence:
				# WorldController delegates save_game to persistence
				get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_F9:
			if _persistence:
				var data = _persistence.request_load_game()
				if data != null:
					get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE:
			if _ui_manager and _ui_manager.inventory_screen.visible:
				_ui_manager.inventory_screen.hide()
				get_viewport().set_input_as_handled()
				return


func _toggle_inventory() -> void:
	if _ui_manager:
		_ui_manager.toggle_inventory()
