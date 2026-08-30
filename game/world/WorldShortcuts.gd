class_name WorldShortcuts
extends Node
## Keyboard shortcuts: I (inventory), F5 (save), F9 (load), Esc (close inventory).

var _persistence
var _ui_manager: WorldUIManager
var _hero: HeroController
var _world_ctrl: Node


func setup(persistence: WorldPersistence, ui_manager: WorldUIManager, hero: HeroController, world_ctrl: Node = null) -> void:
	_persistence = persistence
	_ui_manager = ui_manager
	_hero = hero
	_world_ctrl = world_ctrl


func _unhandled_input(event: InputEvent) -> void:
	# РФ6-4: в бою шорткаты мира не действуют
	if _world_ctrl != null and _world_ctrl.has_method("is_world_visible") and not _world_ctrl.is_world_visible():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_F5:
			# save v3: через WorldController (берёт города и персонажей);
			# fallback — только герой (старый путь).
			var saved := false
			if _world_ctrl != null and _world_ctrl.has_method("save_game"):
				saved = bool(_world_ctrl.save_game())
			elif _persistence:
				saved = _persistence.save_game(_hero)
			if saved:
				GameLogger.world("Quick save OK")
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
