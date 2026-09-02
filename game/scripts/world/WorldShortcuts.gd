class_name WorldShortcuts
extends Node
## Keyboard shortcuts: I (inventory), F5 (save), F9 (load), Esc (close
## city overlay / inventory). city-in-world: пока открыт city-оверлей,
## только Esc действует (I/F5/F9 блокируются) — Esc проверяет город ПЕРЕД
## инвентарём.

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
	# endgame: терминальное состояние — шорткаты мира не действуют
	# (F5-сейв после конца забега бессмыслен, экран уже открыт).
	if _world_ctrl != null and _world_ctrl.has_method("is_terminal") and _world_ctrl.is_terminal():
		return
	# legend-chronicle: последовательность смерти открыта — шорткаты мира
	# не действуют (момент, а не фон).
	if _world_ctrl != null and _world_ctrl.has_method("is_death_sequence_open") \
			and _world_ctrl.is_death_sequence_open():
		return

	# city-in-world: city-оверлей открыт — только Esc закрывает его;
	# I/F5/F9 игнорируются (мир под оверлеем заморожен для ввода).
	if _city_overlay_open():
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
				_ui_manager.close_city_screen()
				get_viewport().set_input_as_handled()
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


func _city_overlay_open() -> bool:
	return _ui_manager != null and _ui_manager.city_overlay_open()


func _toggle_inventory() -> void:
	if _ui_manager:
		_ui_manager.toggle_inventory()
