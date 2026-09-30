class_name WorldSaveLoadService
extends RefCounted

var _tree: SceneTree = null
var _persistence = null
var _bootstrap_result: WorldBootstrap.BootstrapResult = null
var _hero: Node = null
var _cities: Node = null
var _world_delta = null
var _ui_manager: Node = null
var _map_gen: Node = null
var _camera: Node = null
var _resource_node_manager: Node = null

func setup(tree: SceneTree, persistence, bootstrap_result, hero: Node, cities: Node,
		world_delta, ui_manager: Node, resource_node_manager: Node,
		map_gen: Node, camera: Node) -> void:
	_tree = tree
	_persistence = persistence
	_bootstrap_result = bootstrap_result
	_hero = hero
	_cities = cities
	_world_delta = world_delta
	_ui_manager = ui_manager
	_resource_node_manager = resource_node_manager
	_map_gen = map_gen
	_camera = camera

func save_game() -> bool:
	_persistence.world_delta = _world_delta
	var chars: Array = []
	if _bootstrap_result != null and _bootstrap_result.character_registry != null:
		chars = _bootstrap_result.character_registry.serialize()
	return _persistence.save_game(_hero, _cities.cities, chars)

func load_game() -> SaveData:
	return _persistence.load_game()

func get_last_save_dict() -> Dictionary:
	return _persistence.last_save_dict()

func request_load_game() -> void:
	var data = _persistence.request_load_game()
	if data != null:
		_tree.reload_current_scene()

func restart_game(seed_value: int) -> void:
	_persistence.restart_game(seed_value)
	_tree.reload_current_scene()

func apply_save(data: SaveData) -> void:
	_persistence.apply_loaded_save(data, WorldBootstrap.build_load_context(_bootstrap_result))

func get_session() -> GameSession:
	return _persistence.session

func is_terminal() -> bool:
	var s := get_session()
	return s != null and s.is_terminal()

func get_endgame_state() -> Dictionary:
	var s := get_session()
	if s == null:
		return {"state": "RUNNING", "end_reason": ""}
	var names := {GameSession.GameState.RUNNING: "RUNNING",
		GameSession.GameState.VICTORY: "VICTORY",
		GameSession.GameState.DEFEAT: "DEFEAT"}
	return {"state": names.get(s.state, "RUNNING"), "end_reason": s.end_reason}

func handle_headless_exit(platform) -> void:
	if (platform.is_headless() or platform.should_auto_quit()) and not platform.is_test_framework_run():
		await _tree.create_timer(1.0).timeout
		_tree.quit()
