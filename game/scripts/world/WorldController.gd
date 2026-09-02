## scripts/WorldController.gd
class_name WorldController
extends Node2D
## Thin facade: delegates bootstrap + event routing, keeps accessors / save-load / camera helpers.

const _Platform = preload("res://scripts/core/Platform.gd")
const WorldEventRouterScript = preload("res://scripts/world/WorldEventRouter.gd")
const WorldBootstrapScript = preload("res://scripts/world/WorldBootstrap.gd")
const SuccessionControllerScript = preload("res://scripts/world/SuccessionController.gd")
const _VisibilityMapScript = preload("res://scripts/core/VisibilityMap.gd")

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
## fog-of-war: карта видимости мира.
var _visibility = null
var _resource_chain = null
var _event_router: WorldEventRouter = null
var _bootstrap_result: WorldBootstrap.BootstrapResult = null
# succession-sigil: смерть героя → преемник. Чистый RefCounted, headless-safe.
# Типизация через локальный preload (const), а не через global class_name:
# в detached-тестах class_name не регистрируется в classdb → компиляция падает.
var _succession = null


func _ready() -> void:
	SoundManager.play_music_cue(&"music_world")
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
	# fog-of-war: карта видимости мира (создаётся здесь — нужен map_size).
	_visibility = _VisibilityMapScript.new()
	_visibility.set_map_size(_map_gen.map_width, _map_gen.map_height)
	_map_gen.visibility = _visibility
	# fog-of-war: ноды сущностей (враги/ресурсы/сундуки/скроллы/деревни)
	# прячутся на каждом перерисе тумана (MapRenderer.fog_refreshed).
	if _map_gen.renderer != null:
		_map_gen.renderer.fog_refreshed.connect(_on_fog_refreshed)

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
		_world_delta, _persistence, _resource_chain,
		_visibility,
		_bootstrap_result.services.resources if _bootstrap_result.services != null else null,
		_bootstrap_result.turn_scheduler
	)

	# Connect router outward signals
	_event_router.end_turn_requested.connect(_on_end_turn_from_router)

	# succession-sigil: смерть героя → выбор преемника и наследование легенды.
	# hero_died из WorldBattleCoordinator (бой) и need-loop (голод/усталость...).
	_succession = SuccessionControllerScript.new()
	if not GameEventBus.hero_died.is_connected(_on_hero_died):
		GameEventBus.hero_died.connect(_on_hero_died)

	# Load saved game if applicable (восстанавливает fog_explored + пересчитывает).
	if loaded_save != null:
		_persistence.apply_loaded_save(loaded_save, _build_load_context())
		# endgame: сейв мог содержать терминальный забег — показать экран.
		if _bootstrap_result.endgame != null:
			_bootstrap_result.endgame.restore()
	else:
		# fog-of-war: применить видимость к тайлмапу после загрузки/старта.
		if _map_gen.has_valid_tilemap():
			_map_gen.apply_fog(_visibility)

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
		self, _ui_manager, _camera, _bootstrap_result.input_controller, _world_delta,
		_bootstrap_result.services
	)
	# city-in-world: UI создаётся ВСЕГДА (включая headless) → chest_dialog есть.
	var chest_dialog: ArtifactChestDialog = _ui_manager.chest_dialog if _ui_manager != null else null
	interaction_controller.setup(_hero, _bootstrap_result.spawner, chest_dialog)
	interaction_controller.connect_chest_signals()
	interaction_controller.world_delta = _world_delta
	# fog-of-war: gating действий по видимости + статус «клетка не разведена».
	interaction_controller.visibility = _visibility
	interaction_controller.status_cb = (
		_ui_manager.set_status if _ui_manager != null and _ui_manager.has_method("set_status") else Callable())
	_persistence.visibility = _visibility
	# fog-of-war: первый пересчёт видимости: герой + города игрока (как в
	# WorldEventRouter._refresh_visibility — единая логика источников).
	var sight_sources: Array = []
	if _cities != null:
		for c in _cities.cities:
			if c != null and c.owner == &"player" and c.center is Vector2i:
				sight_sources.append(c.center)
	_visibility.recompute(_hero.current_cell, sight_sources,
		GameSettings.FOG_HERO_SIGHT, GameSettings.FOG_CITY_SIGHT)
	if _map_gen.has_valid_tilemap():
		_map_gen.apply_fog(_visibility)


## fog-of-war: перерис тумана → спрятать/показать ноды сущностей.
func _on_fog_refreshed() -> void:
	if _bootstrap_result != null and _bootstrap_result.spawner != null:
		_bootstrap_result.spawner.apply_fog_visibility(_visibility)
	if resource_node_manager != null and resource_node_manager.has_method("apply_fog_visibility"):
		resource_node_manager.apply_fog_visibility(_visibility)


## fog-of-war: карта видимости (SocketController GET_STATE, сценарии).
func get_fog():
	return _visibility


func _on_end_turn_from_router() -> void:
	# Router already executed the turn logic; this hook is for
	# any controller-level side effects (currently none needed).
	pass

# ==================== SUCCESSION-SIGIL: death -> successor ====================

## GameEventBus.hero_died(cause: StringName): выбрать преемника, перенести
## легенду, заменить активного героя. Возврат преемника = легенда
## продолжается; преемника нет → run заканчивается (EndgameController уже
## поставил DEFEAT — он подключён первым; тут только убираем труп).
func _on_hero_died(_cause: StringName) -> void:
	var deceased := get_hero()
	if deceased == null:
		return
	# endgame: sticky-терминальное состояние уже зафиксировано Endgame
	# (смерть без преемника) — преемника не выбираем, только убираем героя.
	var session := get_session()
	if session != null and session.is_terminal():
		_remove_hero(deceased)
		return
	var successor := _plan_succession(deceased)
	if successor == null:
		GameLogger.world("Succession: no eligible follower — run ends")
		_remove_hero(deceased)
		return
	_reincarnate(successor)
	GameEventBus.hero_successor.emit(successor)

## Выбрать преемника через SuccessionController. Возвращает HeroController либо
## null (преемника нет). Отдельно от _reincarnate — чтобы проверять выбор
## без полного перепричинения (тесты, headless).
func _plan_succession(deceased: HeroController) -> HeroController:
	if _succession == null or _cities == null or deceased == null:
		return null
	return _succession.on_hero_died(
		deceased, _rng, _cities.cities, _cities)

## Убрать героя из дерева (смерть без преемника / замена на преемника).
func _remove_hero(deceased: Node) -> void:
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
		deceased.free()
	if _hero == deceased:
		_hero = null


## Заменить активного героя на преемника: новый в дереве, инициализирован,
## ВСЕ потребители героя переподключены на него (battle/interaction/враги/
## ввод/router/UI — иначе freed-референсы = краш на следующем кадре).
func _reincarnate(successor: HeroController) -> void:
	var old := _hero
	_hero = successor
	_remove_hero(old)
	add_child(successor)
	successor.setup(_map_gen)
	if _map_gen != null and _map_gen.has_valid_tilemap():
		successor.position = _map_gen.map_to_local(successor.current_cell)
	if is_instance_valid(battle_coordinator):
		battle_coordinator.hero = successor
	if is_instance_valid(interaction_controller):
		interaction_controller.hero = successor
	if _bootstrap_result != null:
		# enemy-world-ai: без этого вражеский ИИ смотрит на freed-героя.
		if _bootstrap_result.enemy_proc != null:
			_bootstrap_result.enemy_proc._hero = successor
		# endgame: ввод кликов по карте тоже держит реф на героя.
		if _bootstrap_result.input_controller != null:
			_bootstrap_result.input_controller.hero = successor
		if _bootstrap_result.shortcuts != null:
			_bootstrap_result.shortcuts._hero = successor
	if _event_router != null:
		_event_router.hero = successor
		_event_router._connect_hero_signals()
	if _ui_manager != null:
		_ui_manager._hero = successor
		_ui_manager.ui.reattach_hero(successor, _camera)
		if is_instance_valid(_ui_manager.inventory_screen):
			_ui_manager.inventory_screen.set_hero(successor)
		if is_instance_valid(_ui_manager.city_screen):
			_ui_manager.city_screen.hero = successor
	GameLogger.world("Succession: successor took the legend")


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


## city-in-world: доступ для SocketController (CITY_* команды, GET_STATE).
func get_cities() -> CityManager:
	return _cities


func get_ui_manager() -> WorldUIManager:
	return _ui_manager


func is_world_visible() -> bool:
	if _Platform.is_headless():
		return true
	return visible

func do_end_turn() -> void:
	# Triggered by SocketController remote command.
	# endgame: в терминальном состоянии ходы не проходят (sticky).
	if get_session() != null and get_session().is_terminal():
		return
	if _event_router:
		_event_router.request_end_turn()


## endgame: забег в терминальном состоянии (VICTORY/DEFEAT)?
func is_terminal() -> bool:
	var s := get_session()
	return s != null and s.is_terminal()


## endgame: состояние забега для SocketController GET_STATE / сценариев.
func get_endgame_state() -> Dictionary:
	var s := get_session()
	if s == null:
		return {"state": "RUNNING", "end_reason": ""}
	var names := {GameSession.GameState.RUNNING: "RUNNING",
		GameSession.GameState.VICTORY: "VICTORY",
		GameSession.GameState.DEFEAT: "DEFEAT"}
	return {"state": names.get(s.state, "RUNNING"), "end_reason": s.end_reason}


# ==================== SAVE / LOAD ====================

func save_game() -> bool:
	_persistence.world_delta = _world_delta
	# save v3: города и персонажи (Каскад Сложности).
	var chars: Array = []
	if _bootstrap_result != null and _bootstrap_result.character_registry != null:
		chars = _bootstrap_result.character_registry.serialize()
	return _persistence.save_game(_hero, _cities.cities, chars)


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
	var ctx := WorldLoadContext.new()
	ctx.map_gen = _map_gen
	ctx.spawner = _bootstrap_result.spawner
	ctx.resource_node_manager = resource_node_manager
	ctx.ui_manager = _ui_manager
	ctx.camera = _camera
	ctx.hero = _hero
	ctx.world_delta = _world_delta
	# save v3: города и персонажи (Каскад Сложности).
	ctx.cities = _cities
	if _bootstrap_result != null:
		ctx.character_registry = _bootstrap_result.character_registry
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

