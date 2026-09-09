class_name WorldController
extends Node2D

const _Platform = preload("res://scripts/core/Platform.gd")
const WorldBootstrapScript = preload("res://scripts/world/WorldBootstrap.gd")
const MapGeneratorScript = preload("res://scripts/world/MapGenerator.gd")
const CityManagerScript = preload("res://scripts/world/CityManager.gd")
const WorldUIManagerScript = preload("res://scripts/ui/WorldUIManager.gd")
const WorldStateDeltaScript = preload("res://scripts/world/WorldStateDelta.gd")
const ResourceChainServiceScript = preload("res://scripts/world/ResourceChainService.gd")
const _VisibilityMapScript = preload("res://scripts/core/VisibilityMap.gd")
const ShardManagerScript = preload("res://scripts/core/ShardManager.gd")
const WorldSaveLoadServiceScript = preload("res://scripts/world/WorldSaveLoadService.gd")
const WorldHeroManagerScript = preload("res://scripts/world/WorldHeroManager.gd")

var battle_coordinator: Node = null
var interaction_controller: Node = null
var resource_node_manager: Node = null

var _hero: Node = null
var _map_gen: MapGeneratorScript = null
var _camera: Camera2D = null
var _cities: CityManagerScript = null
@onready var _ui_manager: WorldUIManagerScript = $WorldUI
var _rng: RandomNumberGenerator = null
var _world_delta: WorldStateDeltaScript = null
var _persistence = null
var _visibility: _VisibilityMapScript = null
var _resource_chain: ResourceChainServiceScript = null
var _event_router: WorldEventRouter = null
var _bootstrap_result: WorldBootstrap.BootstrapResult = null
var _succession = null
var _hero_lifecycle = null
var _hero_mgr: WorldHeroManager = null
var _save_svc: WorldSaveLoadService = null

func _lifecycle():
	if _hero_mgr != null:
		return _hero_mgr.get_lifecycle()
	return _hero_lifecycle

func _ready() -> void:
	SoundManager.play_music_cue(&"music_world")
	_rng = RandomNumberGenerator.new()
	var _shard := ShardManagerScript.instance().get_active()
	_bootstrap_result = WorldBootstrapScript.run(self, _Platform, _rng, _shard.seed, _ui_manager)
	_map_gen = _bootstrap_result.map_gen
	_hero = _bootstrap_result.hero
	_camera = _bootstrap_result.camera
	_cities = _bootstrap_result.cities
	battle_coordinator = _bootstrap_result.battle_coordinator
	interaction_controller = _bootstrap_result.interaction_controller
	resource_node_manager = _bootstrap_result.resource_node_manager
	_world_delta = _bootstrap_result.world_delta
	_persistence = _bootstrap_result.persistence
	_resource_chain = _bootstrap_result.resource_chain
	_visibility = _VisibilityMapScript.new()
	_visibility.set_map_size(_map_gen.map_width, _map_gen.map_height)
	_map_gen.visibility = _visibility
	if _map_gen.renderer != null:
		_map_gen.renderer.fog_refreshed.connect(_on_fog_refreshed)
	var loaded_save := _bootstrap_result.loaded_save
	await get_tree().process_frame
	_hero_mgr = WorldHeroManagerScript.new()
	_hero_mgr.setup(_hero)
	_hero_mgr.finit_hero(loaded_save, _map_gen)
	_save_svc = WorldSaveLoadServiceScript.new()
	_save_svc.setup(get_tree(), _persistence, _bootstrap_result, _hero, _cities,
		_world_delta, _ui_manager, resource_node_manager, _map_gen, _camera)
	_camera.set_map_rect(_bootstrap_result.map_rect)
	_event_router = WorldBootstrapScript.finalize(self, _bootstrap_result, _visibility,
		_persistence, _hero_mgr, _rng, _on_end_turn_from_router)
	GameLogger.world("Scene ready, seed=%d" % _persistence.session.run_seed)
	_save_svc.handle_headless_exit(_Platform)

func _on_fog_refreshed() -> void:
	if _bootstrap_result != null and _bootstrap_result.spawner != null:
		_bootstrap_result.spawner.apply_fog_visibility(_visibility)
	if resource_node_manager != null and resource_node_manager.has_method("apply_fog_visibility"):
		resource_node_manager.apply_fog_visibility(_visibility)

func get_fog(): return _visibility
func _on_end_turn_from_router() -> void: pass
func get_camera() -> Camera2D: return _camera
func get_session() -> GameSession: return _save_svc.get_session()
func get_hero() -> HeroController:
	return _hero_mgr.get_hero() if _hero_mgr != null else _hero
func set_hero(hero: HeroController) -> void:
	_hero = hero
	if _hero_mgr != null:
		_hero_mgr.set_hero(hero)
func get_map_gen() -> MapGenerator: return _map_gen
func get_cities() -> CityManager: return _cities
func get_ui_manager() -> WorldUIManager: return _ui_manager
func load_game() -> SaveData: return _save_svc.load_game()
func get_last_save_dict() -> Dictionary: return _save_svc.get_last_save_dict()
func apply_save(data: SaveData) -> void: _save_svc.apply_save(data)
func request_load_game() -> void: _save_svc.request_load_game()
func restart_game(seed_value: int) -> void: _save_svc.restart_game(seed_value)
func is_terminal() -> bool: return _save_svc.is_terminal()
func get_endgame_state() -> Dictionary: return _save_svc.get_endgame_state()
func save_game() -> bool: return _save_svc.save_game()
func is_world_visible() -> bool: return _Platform.is_headless() or visible
func do_end_turn() -> void:
	if _event_router != null and (get_session() == null or not get_session().is_terminal()):
		_event_router.request_end_turn()
func center_camera_on(cell: Vector2i) -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		_camera.center_on(_map_gen.map_to_local(cell))
func try_extract_resource(cell: Vector2i) -> Dictionary:
	return _resource_chain.try_extract(resource_node_manager, _hero, cell)
func show_reach_markers(hero_cell: Vector2i, mp: float, dist: Dictionary) -> void:
	if _ui_manager: _ui_manager.show_reach_markers(hero_cell, mp, dist)
func hide_reach_markers() -> void:
	if _ui_manager:
		_ui_manager.hide_reach_markers()
func _on_hero_died(cause: StringName) -> void:
	var lc = _lifecycle()
	if lc != null:
		lc.on_hero_died(cause)
func is_death_sequence_open() -> bool:
	var lc = _lifecycle()
	return lc != null and lc.is_death_sequence_open()
func _plan_succession(deceased: HeroController) -> HeroController:
	var lc = _lifecycle()
	if lc == null:
		return null
	return lc._plan_succession(deceased)
func _find_resurrection_city(deceased: HeroController) -> City:
	var lc = _lifecycle()
	if lc == null:
		return null
	return lc._find_resurrection_city(deceased)
func _on_resurrection_chosen() -> void:
	var lc = _lifecycle()
	if lc != null:
		lc._on_resurrection_chosen()
func _execute_succession() -> void:
	var lc = _lifecycle()
	if lc != null:
		lc._execute_succession()
