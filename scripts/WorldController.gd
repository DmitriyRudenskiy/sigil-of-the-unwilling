extends Node2D
class_name WorldController
## Composition Root — creates subsystems and wires signals.

# Core references
var _map_gen
var _hero
var _camera
var _input_controller
var _spawner
var _cities
var _rng := RandomNumberGenerator.new()
var _world_delta = null
var _save_manager = null

# Subsystems
var battle_coordinator = null
var interaction_controller = null
var resource_node_manager = null
var _ui_manager = null

# Extracted services
var _resource_chain = null
var _persistence = null

const WorldPersistenceScript = preload("res://scripts/world/WorldPersistence.gd")
const ResourceChainServiceScript = preload("res://scripts/world/ResourceChainService.gd")
const WorldShortcutsScript = preload("res://scripts/world/WorldShortcuts.gd")
const WorldLoadContextScript = preload("res://scripts/world/WorldLoadContext.gd")


func _ready() -> void:
	_init_services()
	var loaded_save := _resolve_session()

	_create_map()
	_create_hero()
	await get_tree().process_frame

	_init_hero(loaded_save)
	_wire_hero_signals()

	_create_camera()
	_camera.set_map_rect(_compute_map_rect())

	_init_ui()
	_create_input()
	_create_spawner()
	_create_cities()

	_world_delta = WorldStateDelta.new()
	_persistence.world_delta = _world_delta

	_create_subsystems()
	_create_resource_nodes()

	# Подписка на шину
	GameEventBus.battle_won.connect(_on_battle_won)
	GameEventBus.turn_ended.connect(_on_turn_ended_bus)

	if loaded_save != null:
		_persistence.apply_loaded_save(loaded_save, _build_load_context())

	GameLogger.world("Scene ready, seed=%d" % _persistence.session.run_seed)
	_handle_headless_exit()


# ==================== INIT HELPERS ====================

func _init_services() -> void:
	_save_manager = SaveManager.new()
	_save_manager.name = "SaveManager"
	add_child(_save_manager)
	_persistence = WorldPersistenceScript.new(_save_manager)
	_resource_chain = ResourceChainServiceScript.new()


func _resolve_session() -> SaveData:
	var loaded_save: SaveData = WorldPersistenceScript.pending_save
	WorldPersistenceScript.pending_save = null
	if loaded_save != null:
		_persistence.session = _persistence.get_session_for_seed(loaded_save.run_seed)
	else:
		_persistence.session = _persistence.get_session_for_seed(_persistence.get_run_seed())
	_rng.seed = _persistence.session.run_seed
	return loaded_save


func _init_hero(loaded_save: SaveData) -> void:
	_hero.setup(_map_gen)
	if loaded_save != null:
		_hero.deserialize(loaded_save.hero)
		if _map_gen.has_valid_tilemap():
			_hero.position = _map_gen.map_to_local(_hero.current_cell)


func _wire_hero_signals() -> void:
	_hero.hero_moved.connect(_on_hero_moved)
	_hero.hero_entered_village.connect(_on_village)
	_hero.movement.reach_preview_changed.connect(_on_reach_preview_changed)
	_hero.movement.reach_preview_cleared.connect(_on_reach_preview_cleared)


func _init_ui() -> void:
	if OS.has_feature("headless"):
		GameLogger.world("Headless mode: skipping UI initialization")
		return
	_ui_manager = WorldUIManager.new()
	_ui_manager.name = "WorldUIManager"
	add_child(_ui_manager)
	_ui_manager.setup(_hero, _map_gen, _camera)
	_ui_manager.ui.end_turn_pressed.connect(_on_end_turn)
	_ui_manager.ui.date_changed.connect(_on_date_changed)
	_ui_manager.ui.minimap_cell_activated.connect(center_camera_on)
	_ui_manager.ui.camera_jump_requested_dir.connect(jump_camera)
	_ui_manager.ui.hex_borders_toggled.connect(set_hex_borders)
	_ui_manager.ui.settings_applied.connect(_on_settings_applied)
	_ui_manager.marker_layer.marker_hovered.connect(_on_marker_hovered)
	_ui_manager.marker_layer.marker_clicked.connect(_on_marker_clicked)


func _handle_headless_exit() -> void:
	var is_server := false
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-server"):
			is_server = true
			break
	if (OS.has_feature("headless") or "--autoquit" in OS.get_cmdline_args()) and not is_server:
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _create_subsystems() -> void:
	battle_coordinator = WorldBattleCoordinator.new()
	battle_coordinator.name = "BattleCoordinator"
	battle_coordinator.setup(
		_hero, _map_gen, _spawner, _rng,
		self, _ui_manager, _camera, _input_controller, _world_delta
	)
	add_child(battle_coordinator)

	interaction_controller = WorldInteractionController.new()
	interaction_controller.name = "InteractionController"
	interaction_controller.setup(_hero, _spawner, _ui_manager.chest_dialog)
	interaction_controller.connect_chest_signals()
	interaction_controller.world_delta = _world_delta
	add_child(interaction_controller)


func _create_resource_nodes() -> void:
	resource_node_manager = ResourceNodeManager.new()
	resource_node_manager.name = "ResourceNodeManager"
	add_child(resource_node_manager)
	var node_container := Node2D.new()
	node_container.name = "ResourceNodes"
	add_child(node_container)
	resource_node_manager.setup(node_container, _rng)
	# Generate nodes from map data
	var map_data := {
		"terrain": _map_gen.terrain_grid.duplicate(),
		"width": _map_gen.map_width,
		"height": _map_gen.map_height,
	}
	resource_node_manager.generate_nodes_for_map(map_data)
	# Подписка на шину вместо прямых сигналов
	GameEventBus.resource_discovered.connect(_on_resource_discovered)
	GameEventBus.resource_extracted.connect(_on_resource_extracted)
	GameEventBus.resource_exhausted.connect(_on_resource_exhausted)


# ==================== CREATION ====================

func _create_map() -> void:
	_map_gen = MapGenerator.new()
	_map_gen.name = "MapGenerator"
	_map_gen.seed_value = _rng.randi() % 999999
	add_child(_map_gen)


func _create_hero() -> void:
	_hero = HeroController.new()
	_hero.name = "Hero"
	add_child(_hero)


func _create_camera() -> void:
	_camera = WorldCamera.new()
	_camera.name = "WorldCamera"
	add_child(_camera)
	if _hero != null:
		_camera.center_on(_hero.position)


func _create_input() -> void:
	_input_controller = WorldInput.new()
	_input_controller.name = "WorldInput"
	_input_controller.map = _map_gen
	_input_controller.hero = _hero
	_input_controller.camera = _camera
	add_child(_input_controller)


func _create_spawner() -> void:
	_spawner = WorldSpawner.new()
	_spawner.name = "WorldSpawner"
	_spawner.map = _map_gen
	_spawner.rng = _rng
	add_child(_spawner)
	_spawner.spawn_all()


# ==================== CITY SYSTEM ====================
func _create_cities() -> void:
	_cities = CityManager.new()
	_cities.name = "CityManager"
	add_child(_cities)
	_cities.status_message.connect(func(text: String):
		if _ui_manager: _ui_manager.set_status(text))

	# Регистрация столицы
	var capital := City.new()
	capital.display_name = "Перворечье"
	capital.center = Vector2i(10, 10)
	capital.special_sites = {Vector2i(12, 9): BuildingDefs.SITE_SHRINE}
	_cities.register_city(capital, true)

	# Провайдер FIDSI тайлов (заглушка — заменить на реальный MapGen)
	_cities.set_tile_yield_provider(func(_cell: Vector2i) -> Dictionary:
		return {&"food": 5.0, &"industry": 5.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	)

	# Create shortcuts node
	var shortcuts := WorldShortcutsScript.new()
	shortcuts.name = "WorldShortcuts"
	shortcuts.call("setup", _persistence, _ui_manager)
	add_child(shortcuts)


# ==================== HERO EVENTS ====================

func _on_hero_moved(cell: Vector2i) -> void:
	_camera.follow(_hero)
	interaction_controller.collect_resource_at(cell)
	interaction_controller.pickup_scroll_at(cell)
	battle_coordinator.check_enemy_contact(cell)
	interaction_controller.check_chest_contact(cell)

	# Addendum 10: Try to discover hidden resource nodes
	if resource_node_manager:
		var disc_keys = _resource_chain.build_discovery_keys(_hero)
		resource_node_manager.try_discover(cell, disc_keys)


func _on_village(cell: Vector2i) -> void:
	GameLogger.world("Village captured at %s" % cell)
	interaction_controller.capture_village_at(cell)

	if _world_delta:
		_world_delta.add_village(cell)
	if _ui_manager:
		_ui_manager.ui.add_city("Деревня (%d, %d)" % [cell.x, cell.y])


func _on_end_turn() -> void:
	_hero.end_turn()
	# Tick resource nodes
	if resource_node_manager:
		resource_node_manager.tick_daily()

	var month: int = int(_persistence.get_date().get("month", 1))
	GameEventBus.turn_ended.emit(_cities.current_turn + 1, month)

	if _ui_manager:
		_ui_manager.refresh_ui()


func _on_date_changed(month: int, week: int, day: int) -> void:
	_persistence.set_date(month, week, day)


func _on_settings_applied() -> void:
	if _camera and _camera.has_method("set_zoom_level"):
		var settings_node = get_node_or_null("/root/Settings")
		if settings_node:
			_camera.set_zoom_level(settings_node.get_zoom())


# ==================== EVENT BUS HANDLERS ====================

func _on_battle_won(enemy_cell: Vector2i) -> void:
	if _cities:
		_cities.add_glory(15.0, &"battle_won")


func _on_turn_ended_bus(turn: int, month: int) -> void:
	if _cities:
		_cities.on_turn_ended(month)


# ==================== CAMERA ====================

func get_camera() -> Camera2D:
	return _camera


func center_camera_on(cell: Vector2i) -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		_camera.center_on(_map_gen.map_to_local(cell))


func jump_camera(direction: String) -> void:
	if _map_gen == null:
		return
	var center := Vector2i(_map_gen.map_width / 2, _map_gen.map_height / 2)
	match direction:
		"N": center_camera_on(Vector2i(center.x, 2))
		"S": center_camera_on(Vector2i(center.x, _map_gen.map_height - 3))
		"W": center_camera_on(Vector2i(2, center.y))
		"E": center_camera_on(Vector2i(_map_gen.map_width - 3, center.y))


func set_hex_borders(on: bool) -> void:
	if _ui_manager:
		_ui_manager.set_hex_borders(on)


# ==================== INPUT (delegated to WorldShortcuts) ====================

func _toggle_inventory() -> void:
	if _ui_manager:
		_ui_manager.toggle_inventory()


# ==================== ACCESSORS ====================

func get_session() -> GameSession:
	return _persistence.session

# Public accessors for SocketController / external callers
func get_hero() -> HeroController:
	return _hero

func get_map_gen() -> MapGenerator:
	return _map_gen

func is_world_visible() -> bool:
	return visible

func do_end_turn() -> void:
	_on_end_turn()


# ==================== SAVE / LOAD (delegated) ====================

func save_game() -> bool:
	_persistence.world_delta = _world_delta
	return _persistence.save_game(_hero)


func load_game() -> SaveData:
	return _persistence.load_game()


func request_load_game() -> void:
	var data = _persistence.request_load_game()
	if data != null:
		get_tree().reload_current_scene()


func restart_game(seed_value: int) -> void:
	_persistence.restart_game(seed_value)
	get_tree().reload_current_scene()


func show_reach_markers(hero_cell: Vector2i, mp: float, dist: Dictionary) -> void:
	if _ui_manager:
		_ui_manager.show_reach_markers(hero_cell, mp, dist)


func hide_reach_markers() -> void:
	if _ui_manager:
		_ui_manager.hide_reach_markers()


func _on_marker_hovered(cell: Vector2i, cost: float, remaining: float, is_reachable: bool) -> void:
	# Could show tooltip; for now pass through
	pass


func _on_marker_clicked(cell: Vector2i, is_reachable: bool) -> void:
	if is_reachable and _hero:
		_hero.movement.on_map_clicked(cell)


func _on_reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float) -> void:
	if _ui_manager:
		_ui_manager.show_reach_markers(_hero.current_cell, mp, dist)


func _on_reach_preview_cleared() -> void:
	if _ui_manager:
		_ui_manager.hide_reach_markers()


func _compute_map_rect() -> Rect2:
	if _map_gen:
		return _map_gen.get_map_world_rect()
	return Rect2(0, 0, 10000, 10000)


# ==================== RESOURCE CHAIN (delegated) ====================

func _build_extraction_keys() -> Dictionary:
	return _resource_chain.build_extraction_keys(_hero)


func _invalidate_extraction_cache() -> void:
	_resource_chain.invalidate_extraction_cache()


func try_extract_resource(cell: Vector2i) -> int:
	return _resource_chain.try_extract(resource_node_manager, _hero, cell)


func _on_resource_discovered(cell: Vector2i, resource_id: StringName) -> void:
	GameLogger.world("Resource discovered at %s: %s" % [cell, resource_id])

	if _world_delta:
		_world_delta.add_discovered_node(cell)


const ResourceDef = preload("res://scripts/data/ResourceDef.gd")

func _on_resource_extracted(cell: Vector2i, resource_id: StringName, amount: int) -> void:
	var skill_mult: float = 1.0
	var def: ResourceDef = Resources.get_resource(resource_id)
	if def:
		if not def.discovery_skill.is_empty():
			skill_mult = _hero.skills.get_yield_multiplier(def.discovery_skill)
	var final_amount: int = max(1, int(amount * skill_mult))
	var actual: int = _hero.add_strategic_resource(resource_id, final_amount)
	GameLogger.world("Extracted %d of %s at %s (actual: %d)" % [final_amount, resource_id, cell, actual])


func _on_resource_exhausted(cell: Vector2i, resource_id: StringName) -> void:
	GameLogger.world("Resource exhausted at %s: %s" % [cell, resource_id])

	if _world_delta:
		_world_delta.add_exhausted_node(cell)


func apply_save(data: SaveData) -> void:
	_persistence.apply_loaded_save(data, _build_load_context())


func _build_load_context():
	var ctx := WorldLoadContextScript.new()
	ctx.map_gen = _map_gen
	ctx.spawner = _spawner
	ctx.resource_node_manager = resource_node_manager
	ctx.ui_manager = _ui_manager
	ctx.camera = _camera
	ctx.hero = _hero
	ctx.world_delta = _world_delta
	return ctx
