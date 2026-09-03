## scripts/WorldController.gd
class_name WorldController
extends Node2D
## Thin facade: delegates bootstrap + event routing, keeps accessors / save-load / camera helpers.

const _Platform = preload("res://scripts/core/Platform.gd")
const WorldEventRouterScript = preload("res://scripts/world/WorldEventRouter.gd")
const WorldBootstrapScript = preload("res://scripts/world/WorldBootstrap.gd")
const SuccessionControllerScript = preload("res://scripts/world/SuccessionController.gd")
const _VisibilityMapScript = preload("res://scripts/core/VisibilityMap.gd")
const ShardManagerScript = preload("res://scripts/core/ShardManager.gd")
const DeathSequenceScript = preload("res://scripts/ui/DeathSequence.gd")
const ChronicleScreenScript = preload("res://scripts/ui/ChronicleScreen.gd")

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
## legend-chronicle: момент смерти — полноэкранная последовательность;
## перерождение отложено до «Знак переходит» (последовательность ≠ молчаливая
## замена). _deceased_snapshot — только строки (hero уже freed на момент
# кнопки, живой реф держать нельзя).
var _death_seq = null
var _chronicle_screen = null
var _pending_successor: HeroController = null
var _deceased_snapshot: Dictionary = {}
## hero-survival: умерший герой, удерживаемый в памяти до выбора игрока
## (воскресение или преемник). null — труп уже освобождён.
var _deceased_hero: HeroController = null
## hero-survival: город с великим храмом-кандидатом на воскрешение.
var _resurrection_city: City = null


func _ready() -> void:
	SoundManager.play_music_cue(&"music_world")
	_rng = RandomNumberGenerator.new()
	# astral-macro: фрагмент активного мира. shard #1 (seed 0) = новая игра,
	# как раньше (случайный/редакторский сид); другие фрагменты — фиксированный сид.
	var _shard := ShardManagerScript.instance().get_active()
	_bootstrap_result = WorldBootstrap.run(self, _Platform, _rng, _shard.seed)

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
func _on_hero_died(cause: StringName) -> void:
	var deceased := get_hero()
	if deceased == null:
		return
	# legend-chronicle: снимаем имя/пути ДО освобождения героя — запись
	# летописи строится по этому снапшоту (живой реф не держим).
	_deceased_snapshot = {
		"hero_name": str(deceased.hero_name),
		"path": String(deceased.path_id),
	}
	# endgame: sticky-терминальное состояние уже зафиксировано Endgame
	# (смерть без преемника) — преемника не выбираем, только убираем героя
	# и показываем момент смерти («цикл оборвался» + «В меню»).
	var session := get_session()
	if session != null and session.is_terminal():
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	var successor := _plan_succession(deceased)
	if successor == null:
		GameLogger.world("Succession: no eligible follower — run ends")
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	# legend-chronicle: перерождение отложено — «Знак переходит» в
	# последовательности вызывает succession-поток (_execute_succession).
	_pending_successor = successor
	# hero-survival: кандидат на воскрешение — город с великим храмом, где
	# герой ещё не воскрешал в этом цикле. Если есть — труп держим в памяти:
	# игрок выбирает между «Воскресить» и «Знак переходит».
	var res_city: City = _find_resurrection_city(deceased)
	_resurrection_city = res_city
	if res_city != null:
		_deceased_hero = deceased
		_detach_hero(deceased)
	else:
		_remove_hero(deceased)
	# _reincarnate с _hero == null работает (old == null → просто добавляет).
	# Труп уже освобождён (res_city == null) — имя берём из снапшота, а не из
	# freed-объекта (use-after-free). Снапшот взят в начале _on_hero_died.
	_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, successor, res_city)


func is_death_sequence_open() -> bool:
	return _death_seq != null and _death_seq.visible


func _show_death_sequence(
	deceased_name: String,
	cause: StringName,
	successor: Node,
	res_city: City = null
) -> void:
	if _death_seq == null:
		_death_seq = DeathSequenceScript.new()
		_death_seq.name = "DeathSequence"
		add_child(_death_seq)
		_death_seq.successor_chosen.connect(_execute_succession)
		_death_seq.return_to_menu.connect(_on_death_return_to_menu)
		_death_seq.chronicle_requested.connect(_on_death_chronicle_requested)
		_death_seq.resurrection_chosen.connect(_on_resurrection_chosen)
	_death_seq.show_death(deceased_name, cause, _run_summary(), successor, res_city)


## Кнопка «Знак переходит»: перерождение + hero_successor + запись в летопись.
func _execute_succession() -> void:
	var successor := _pending_successor
	_pending_successor = null
	if successor == null:
		return
	if is_death_sequence_open():
		_death_seq.visible = false
	# hero-survival: игрок выбрал преемника — удерживаемый труп освобождается.
	_free_deceased()
	_reincarnate(successor)
	GameEventBus.hero_successor.emit(successor)
	_append_succession_entry()


## hero-survival: первый город игрока, где доступно воскрешение (великий храм
## + хранилище под стоимость по умолчанию). null — варианта нет.
func _find_resurrection_city(deceased: HeroController) -> City:
	if _succession == null or _cities == null:
		return null
	if deceased != null and deceased.resurrected_once:
		return null
	var cost: Dictionary = _succession.default_resurrection_cost()
	for c in _cities.cities:
		if c != null and c.owner == &"player" and c.can_resurrect(cost):
			return c
	return null


## hero-survival: «Воскресить» — герой возвращается в город с великим храмом.
## Цикл не оборвался: записи в летопись нет, hero_successor не эмитится.
func _on_resurrection_chosen() -> void:
	var city := _resurrection_city
	var hero := _deceased_hero
	_resurrection_city = null
	_deceased_hero = null
	if hero == null or city == null or _succession == null:
		return
	# Воскрешение заменяет преемника: pending-преемник освобождается.
	if _pending_successor != null and is_instance_valid(_pending_successor):
		_pending_successor.free()
	_pending_successor = null
	# Экран блокирует ходы — хранилище с момента проверки не меняется.
	_succession.resurrect_hero(city)
	hero.revive_at(city)
	hero.resurrected_once = true
	_install_hero(hero)
	if is_death_sequence_open():
		_death_seq.visible = false
	GameLogger.world("Succession: %s resurrected in %s" % [hero.hero_name, city.display_name])


## hero-survival: убрать героя из мира без free (выбор игрока ещё впереди).
func _detach_hero(deceased: Node) -> void:
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
	if _hero == deceased:
		_hero = null


## hero-survival: освободить удерживаемый труп (преемник / «В меню»).
func _free_deceased() -> void:
	if _deceased_hero != null and is_instance_valid(_deceased_hero):
		_deceased_hero.free()
	_deceased_hero = null
	_resurrection_city = null


## legend-chronicle: запись завершённого цикла (умерший герой).
func _append_succession_entry() -> void:
	if _persistence == null or _persistence.chronicle == null:
		return
	var sum := _run_summary()
	_persistence.chronicle.append({
		"hero_name": _deceased_snapshot.get("hero_name", "?"),
		"path": _deceased_snapshot.get("path", ""),
		"end_turn": sum["turns"],
		"cities": sum["cities_owned"],
		"glory": sum["glory"],
		"battles_won": sum["battles_won"],
		"battles_lost": sum["battles_lost"],
		"outcome": "succession",
	})
	_deceased_snapshot = {}


## legend-chronicle: «Летопись» из последовательности смерти.
func _on_death_chronicle_requested() -> void:
	var entries: Array = []
	if _persistence != null and _persistence.chronicle != null:
		entries = _persistence.chronicle.to_array()
	if _chronicle_screen == null:
		_chronicle_screen = ChronicleScreenScript.new()
		_chronicle_screen.name = "ChronicleScreen"
		add_child(_chronicle_screen)
	_chronicle_screen.show_entries(entries)


func _on_death_return_to_menu() -> void:
	# hero-survival: труп без родителя — освободить явно, иначе утечка.
	_free_deceased()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## Сводка забега для DeathSequence (тот же формат, что у endgame).
func _run_summary() -> Dictionary:
	var turns := 0
	var glory := 0
	var cities_left := 0
	if _cities != null:
		turns = int(_cities.current_turn)
		if _cities.glory != null:
			glory = int(round(_cities.glory.total))
		for c in _cities.cities:
			if c != null and c.owner == &"player":
				cities_left += 1
	var s: GameSession = get_session()
	var date: Dictionary = _persistence.get_date() if _persistence != null else {}
	return {
		"turns": turns,
		"date": {
			"month": int(date.get("month", 1)),
			"week": int(date.get("week", 1)),
			"day": int(date.get("day", 1)),
		},
		"cities_owned": cities_left,
		"glory": glory,
		"battles_won": int(s.battles_won) if s != null else 0,
		"battles_lost": int(s.battles_lost) if s != null else 0,
		"generations": (int(s.successions) if s != null else 0) + 1,
	}

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
	_remove_hero(old)
	_install_hero(successor)
	GameLogger.world("Succession: successor took the legend")


## hero-survival: поставить героя в мир (общая часть перерождения и
## воскрешения): в дерево, setup, перенаправить рефы во всех системах.
func _install_hero(hero: HeroController) -> void:
	_hero = hero
	add_child(hero)
	hero.city_manager = _cities
	# Гвард — для headless-тестов (карты нет); в игре _map_gen всегда есть.
	if _map_gen != null:
		hero.setup(_map_gen)
	if _map_gen != null and _map_gen.has_valid_tilemap():
		hero.position = _map_gen.map_to_local(hero.current_cell)
	if is_instance_valid(battle_coordinator):
		battle_coordinator.hero = hero
	if is_instance_valid(interaction_controller):
		interaction_controller.hero = hero
	if _bootstrap_result != null:
		# enemy-world-ai: без этого вражеский ИИ смотрит на freed-героя.
		if _bootstrap_result.enemy_proc != null:
			_bootstrap_result.enemy_proc._hero = hero
		# endgame: ввод кликов по карте тоже держит реф на героя.
		if _bootstrap_result.input_controller != null:
			_bootstrap_result.input_controller.hero = hero
		if _bootstrap_result.shortcuts != null:
			_bootstrap_result.shortcuts._hero = hero
	if _event_router != null:
		_event_router.hero = hero
		_event_router._connect_hero_signals()
	if _ui_manager != null:
		_ui_manager._hero = hero
		_ui_manager.ui.reattach_hero(hero, _camera)
		if is_instance_valid(_ui_manager.inventory_screen):
			_ui_manager.inventory_screen.set_hero(hero)
		if is_instance_valid(_ui_manager.city_screen):
			_ui_manager.city_screen.hero = hero



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

## astral-macro (v7): последний сериализованный сейв для проверки round-trip
## через сокет (SAVE_GAME).
func get_last_save_dict() -> Dictionary:
	return _persistence.last_save_dict()


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

