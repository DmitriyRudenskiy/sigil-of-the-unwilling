## scripts/WorldController.gd
class_name WorldController
extends Node2D
## Thin facade: delegates bootstrap + event routing, keeps accessors / save-load / camera helpers.

const _Platform = preload("res://scripts/core/Platform.gd")
const WorldEventRouterScript = preload("res://scripts/world/WorldEventRouter.gd")
const WorldBootstrapScript = preload("res://scripts/world/WorldBootstrap.gd")

# Bootstrap result fields (public for external callers)
var battle_coordinator: Node = null
var interaction_controller: Node = null
var resource_node_manager: Node = null

# Internal references
var _hero: Node = null
var _map_gen: Node = null
var _camera: Node = null
var _cities: Node = null
var _ui_manager: Node = null
var _rng: RandomNumberGenerator = null
var _world_delta = null
var _persistence = null
var _resource_chain = null
var _event_router: WorldEventRouter = null
var _bootstrap_result = null


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_bootstrap_result = WorldBootstrap.run(self, _Platform, _rng)

	# Unpack bootstrap result
	_map_gen = _bootstrap_result.map_gen
	_hero = _bootstrap_result.hero
	_camera = _bootstrap_result.camera
	_cities = _bootstrap_result.cities
	battle_coordinator = _bootstrap_result.battle_coordinator
	interaction_controller = _bootstrap_result.interaction_controller
	resource_node_manager = _bootstrap_result.resource_node_manager
	_ui_manager = _bootstrap_result.ui_manager
	_world_delta = _bootstrap_result.world_delta
	_persistence = _bootstrap_result.persistence
	_resource_chain = _bootstrap_result.resource_chain

	var loaded_save := _bootstrap_result.loaded_save

	# Await process frame before hero init (map must be ready)
	await get_tree().process_frame

	# Finish hero init (requires map to be in tree)
	_finit_hero(loaded_save)

	# Set camera map rect
	_camera.set_map_rect(_bootstrap_result.map_rect)

	# Setup battle coordinator & interaction controller (need parent ref)
	_finit_subsystems()

	# Setup world delta
	_persistence.world_delta = _world_delta

	# Create and setup event router
	_event_router = WorldEventRouter.new()
	_event_router.name = "EventRouter"
	add_child(_event_router)
	_event_router.setup(
		_hero, _map_gen, _camera, _cities,
		battle_coordinator, interaction_controller,
		resource_node_manager, _ui_manager,
		_world_delta, _persistence, _resource_chain
	)

	# Connect router outward signals
	_event_router.end_turn_requested.connect(_on_end_turn_from_router)

	# Load saved game if applicable
	if loaded_save != null:
		_persistence.apply_loaded_save(loaded_save, _build_load_context())

	GameLogger.world("Scene ready, seed=%d" % _persistence.session.run_seed)
	_handle_headless_exit()


# ==================== POST-BOOTSTRAP FINISH ====================

func _finit_hero(loaded_save: SaveData) -> void:
	_hero.setup(_map_gen)
	if loaded_save != null:
		_hero.deserialize(loaded_save.hero)
		if _map_gen.has_valid_tilemap():
			_hero.position = _map_gen.map_to_local(_hero.current_cell)


func _finit_subsystems() -> void:
	battle_coordinator.setup(
		_hero, _map_gen, _bootstrap_result.spawner, _rng,
		self, _ui_manager, _camera, _bootstrap_result.input_controller, _world_delta
	)
	interaction_controller.setup(_hero, _bootstrap_result.spawner, _ui_manager.chest_dialog)
	interaction_controller.connect_chest_signals()
	interaction_controller.world_delta = _world_delta


func _on_end_turn_from_router() -> void:
	# Router already executed the turn logic; this hook is for
	# any controller-level side effects (currently none needed).
	pass


# ==================== CAMERA ====================

func get_camera() -> Camera2D:
	return _camera


func center_camera_on(cell: Vector2i) -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		_camera.center_on(_map_gen.map_to_local(cell))


# ==================== ACCESSORS ====================

func get_session() -> GameSession:
	return _persistence.session


func get_hero() -> HeroController:
	return _hero


func get_map_gen() -> MapGenerator:
	return _map_gen


func is_world_visible() -> bool:
	if _Platform.is_headless():
		return true
	return visible

func do_end_turn() -> void:
	# Triggered by SocketController remote command.
	# The router handles the actual turn logic.
	if _event_router:
		# Direct call to router's handler to bypass signal
		_event_router.call("_on_end_turn")


# ==================== SAVE / LOAD ====================

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


func apply_save(data: SaveData) -> void:
	_persistence.apply_loaded_save(data, _build_load_context())


func _build_load_context():
	var ctx := WorldLoadContextScript.new()
	ctx.map_gen = _map_gen
	ctx.spawner = _bootstrap_result.spawner
	ctx.resource_node_manager = resource_node_manager
	ctx.ui_manager = _ui_manager
	ctx.camera = _camera
	ctx.hero = _hero
	ctx.world_delta = _world_delta
	return ctx


# ==================== RESOURCE CHAIN DELEGATION ====================

func try_extract_resource(cell: Vector2i) -> int:
	return _resource_chain.try_extract(resource_node_manager, _hero, cell)


# ==================== MARKER VISUALS (delegated to router via UI) ====================

func show_reach_markers(hero_cell: Vector2i, mp: float, dist: Dictionary) -> void:
	if _ui_manager:
		_ui_manager.show_reach_markers(hero_cell, mp, dist)


func hide_reach_markers() -> void:
	if _ui_manager:
		_ui_manager.hide_reach_markers()


func _handle_headless_exit() -> void:
	if (_Platform.is_headless() or _Platform.should_auto_quit()) and not _Platform.is_test_server():
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()
