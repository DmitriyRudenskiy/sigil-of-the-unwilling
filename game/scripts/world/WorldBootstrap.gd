class_name WorldBootstrap
extends RefCounted

const _Platform = preload("res://scripts/core/Platform.gd")
const WorldPersistenceScript = preload("res://scripts/world/WorldPersistence.gd")
const ResourceChainServiceScript = preload("res://scripts/world/ResourceChainService.gd")
const WorldShortcutsScript = preload("res://scripts/world/WorldShortcuts.gd")
const EndgameControllerScript = preload("res://scripts/systems/EndgameController.gd")
const _TerrainResourceManager = preload("res://scripts/data/TerrainResourceManager.gd")
const WorldEventRouterScript = preload("res://scripts/world/WorldEventRouter.gd")
const SuccessionControllerScript = preload("res://scripts/world/SuccessionController.gd")
const HeroLifecycleSystemScript = preload("res://scripts/world/HeroLifecycleSystem.gd")

class BootstrapResult:
	var map_gen: Node = null
	var hero: Node = null
	var camera: Node = null
	var input_controller: Node = null
	var spawner: Node = null
	var cities: Node = null
	var battle_coordinator: Node = null
	var interaction_controller: Node = null
	var resource_node_manager: Node = null
	var terrain_resource_manager: Variant = null
	var ui_manager: Node = null
	var world_delta: Variant = null
	var persistence: Variant = null
	var resource_chain: Variant = null
	var turn_scheduler: TurnScheduler = null
	var character_registry: CharacterRegistry = null
	var rng: RandomNumberGenerator = null
	var session: Variant = null
	var loaded_save: SaveData = null
	var map_rect: Rect2 = Rect2(0, 0, 10000, 10000)
	var enemy_proc: Variant = null
	var shortcuts: Node = null
	var endgame: Node = null
	var event_bus_subscribers: Array[Callable] = []

static func run(
	parent: Node2D,
	platform: Variant,
	rng: RandomNumberGenerator,
	shard_seed: int = 0,
	ui_manager: Node = null
) -> BootstrapResult:
	# TASK_19 M1: run() — только оркестрация; порядок фаз сохранён:
	# сервисы → сессия → мир → города/UI → подсистемы → endgame.
	var R := BootstrapResult.new()
	R.rng = rng
	R.ui_manager = ui_manager
	_init_services(parent, R)
	_assert_core_services()
	R.loaded_save = _resolve_session(R, shard_seed)
	rng.seed = R.session.run_seed
	_create_world(parent, R)
	_create_city_layer(parent, platform, R)
	_create_subsystems(parent, R)
	_create_endgame(parent, R)
	return R

static func _assert_core_services() -> void:
	var missing: Array[String] = []
	for k in [&"units", &"resources", &"spells", &"artifacts"]:
		if Services.resolve(k) == null:
			missing.append(str(k))
	if not missing.is_empty():
		push_error("[WorldBootstrap] Missing services: %s" % ", ".join(missing))

static func _create_world(parent: Node2D, R: BootstrapResult) -> void:
	_create_map(parent, R)
	_create_hero(parent, R)
	_init_hero(R)
	_create_camera(parent, R)
	R.map_rect = _compute_map_rect(R)
	_create_input(parent, R)
	_create_spawner(parent, R)

static func _create_city_layer(parent: Node2D, platform: Variant, R: BootstrapResult) -> void:
	_create_cities(parent, R)
	_create_ui(parent, platform, R)
	_create_resource_nodes(parent, R)

static func _create_endgame(parent: Node2D, R: BootstrapResult) -> void:
	R.endgame = EndgameControllerScript.new()
	R.endgame.name = "EndgameController"
	parent.add_child(R.endgame)
	R.endgame.setup(parent, R.battle_coordinator, R.map_gen, R.cities, R.persistence, R.enemy_proc, R.ui_manager)

static func finalize(parent: Node2D, R: BootstrapResult, visibility, persistence,
				hero_mgr, rng, end_turn_cb: Callable) -> WorldEventRouter:
	R.battle_coordinator.setup(
		R.hero, R.map_gen, R.spawner, rng,
		parent, R.ui_manager, R.camera, R.input_controller, R.world_delta
	)
	var chest_dialog: ArtifactChestDialog = R.ui_manager.chest_dialog if R.ui_manager != null else null
	R.interaction_controller.setup(R.hero, R.spawner, chest_dialog)
	R.interaction_controller.connect_chest_signals()
	R.interaction_controller.world_delta = R.world_delta
	R.interaction_controller.visibility = visibility
	R.interaction_controller.status_cb = (
		R.ui_manager.set_status if R.ui_manager != null and R.ui_manager.has_method("set_status") else Callable())
	persistence.visibility = visibility
	var sight_sources: Array = []
	if R.cities != null:
		for city in R.cities.cities:
			if city != null and city.owner == &"player" and city.center is Vector2i:
				sight_sources.append(city.center)
	visibility.recompute(R.hero.current_cell, sight_sources,
		GameNumbers.FOG_HERO_SIGHT, GameNumbers.FOG_CITY_SIGHT)
	if R.map_gen.has_valid_tilemap():
		R.map_gen.apply_fog(visibility)

	persistence.world_delta = R.world_delta

	var router := WorldEventRouterScript.new()
	router.name = "EventRouter"
	parent.add_child(router)
	router.setup(
		R.hero, R.map_gen, R.camera, R.cities,
		R.battle_coordinator, R.interaction_controller,
		R.resource_node_manager, R.ui_manager,
		R.world_delta, persistence, R.resource_chain,
		visibility,
		Services.resolve(&"resources"),
		R.turn_scheduler,
		R.terrain_resource_manager if R != null else null
	)
	router.end_turn_requested.connect(end_turn_cb)

	var succession := SuccessionControllerScript.new()
	var lifecycle := HeroLifecycleSystemScript.new()
	hero_mgr.setup_lifecycle(lifecycle)
	lifecycle.setup(
		parent, persistence, rng, R.cities, R.map_gen, router,
		R.ui_manager, R.battle_coordinator, R.interaction_controller,
		R, succession, R.camera)

	if R.loaded_save != null:
		persistence.apply_loaded_save(R.loaded_save, build_load_context(R))
		if R.endgame != null:
			R.endgame.restore()
	elif R.map_gen.has_valid_tilemap():
		R.map_gen.apply_fog(visibility)
	return router

static func build_load_context(R: BootstrapResult) -> Variant:
	var ctx := WorldLoadContext.new()
	ctx.map_gen = R.map_gen
	ctx.spawner = R.spawner
	ctx.resource_node_manager = R.resource_node_manager
	ctx.terrain_resource_manager = R.terrain_resource_manager
	ctx.ui_manager = R.ui_manager
	ctx.camera = R.camera
	ctx.hero = R.hero
	ctx.world_delta = R.world_delta
	ctx.cities = R.cities
	ctx.character_registry = R.character_registry
	return ctx

static func _init_services(parent: Node2D, R: BootstrapResult) -> void:
	# TASK_19_1 P3: горячие методы TerrainCostTable больше не делают lazy-ensure.
	TerrainCostTable.ensure()
	var save_manager := SaveManager.new()
	save_manager.name = "SaveManager"
	parent.add_child(save_manager)

	R.persistence = Services.resolve(&"persistence")
	if R.persistence == null:
		R.persistence = WorldPersistenceScript.new(save_manager)
		Services.register_singleton(&"persistence", R.persistence)
	else:
		R.persistence.set_save_manager(save_manager)
	R.resource_chain = ResourceChainServiceScript.new()

static func _resolve_session(R: BootstrapResult, shard_seed: int) -> SaveData:
	var loaded_save: SaveData = R.persistence.pending_save
	R.persistence.pending_save = null
	if shard_seed != 0:
		R.persistence.session = R.persistence.get_session_for_seed(shard_seed)
	elif loaded_save != null:
		R.persistence.session = R.persistence.get_session_for_seed(loaded_save.run_seed)
	else:
		R.persistence.session = R.persistence.get_session_for_seed(R.persistence.get_run_seed())
	R.session = R.persistence.session
	if R.world_delta == null:
		R.world_delta = WorldStateDelta.new()
	return loaded_save

static func _create_map(parent: Node2D, R: BootstrapResult) -> void:
	var map_scene: PackedScene = load("res://scenes/world/MapGenerator.tscn")
	R.map_gen = map_scene.instantiate()
	R.map_gen.name = "MapGenerator"
	R.map_gen.seed_value = R.rng.randi() % 999999
	parent.add_child(R.map_gen)

static func _create_hero(parent: Node2D, R: BootstrapResult) -> void:
	R.hero = HeroController.new()
	R.hero.name = "Hero"
	parent.add_child(R.hero)

## Пассивные эффекты классов на старте партии (early-game-foundation).
## Воин/Следопыт/Плут/Жрец/Друид действуют в бою через тег класса на бойце-герое.
static func _apply_class_effects(hero: Node, profile: HeroBuildProfile) -> void:
	if profile == null or profile.character_class == "cipher":
		return
	var magic: Variant = hero.get("magic")
	if magic == null:
		return
	# Чародей: стартовый боевой spell
	magic.schools[SchoolType.ID.FIRE] = 3
	magic.learn(&"fireball")


static func _init_hero(R: BootstrapResult) -> void:
	# Ранняя игра: новая партия стартует без армии (early-game-foundation)
	if R.loaded_save == null:
		R.hero.solo_start = true
	R.hero.setup(R.map_gen)
	R.hero.city_manager = R.cities
	if R.loaded_save != null:
		R.hero.deserialize(R.loaded_save.hero)
		if R.map_gen.has_valid_tilemap():
			R.hero.position = R.map_gen.map_to_local(R.hero.current_cell)
	else:
		var profile = R.persistence.pending_new_game
		if profile != null:
			R.hero.apply_build(profile)
			R.persistence.pending_new_game = null
			_apply_class_effects(R.hero, profile)

static func _create_ui(parent: Node2D, _platform: Variant, R: BootstrapResult) -> void:
	if R.ui_manager == null:
		push_error("WorldBootstrap: WorldUI node not found in scene tree!")
		return
	R.ui_manager.setup(R.hero, R.map_gen, R.camera, R.rng, R.cities)

	if R.cities != null and R.ui_manager.get("marker_layer") != null:
		R.ui_manager.marker_layer.set_city_markers(R.cities.cities)

	var shortcuts := WorldShortcutsScript.new()
	shortcuts.name = "WorldShortcuts"
	shortcuts.setup(R.persistence, R.ui_manager, R.hero, parent)
	parent.add_child(shortcuts)
	R.shortcuts = shortcuts

static func _create_camera(parent: Node2D, R: BootstrapResult) -> void:
	R.camera = WorldCamera.new()
	R.camera.name = "WorldCamera"
	parent.add_child(R.camera)
	var settings: Object = Services.resolve(&"settings")
	if settings:
		R.camera.setup(settings)
	if R.hero != null:
		R.camera.center_on(R.hero.position)

static func _create_input(parent: Node2D, R: BootstrapResult) -> void:
	R.input_controller = WorldInput.new()
	R.input_controller.name = "WorldInput"
	R.input_controller.map = R.map_gen
	R.input_controller.hero = R.hero
	R.input_controller.camera = R.camera
	R.input_controller.world = parent
	parent.add_child(R.input_controller)

static func _create_spawner(parent: Node2D, R: BootstrapResult) -> void:
	R.spawner = WorldSpawner.new()
	R.spawner.name = "WorldSpawner"
	R.spawner.map = R.map_gen
	R.spawner.rng = R.rng
	parent.add_child(R.spawner)
	R.spawner.spawn_all()

static func _create_cities(parent: Node2D, R: BootstrapResult) -> void:
	# Карта строится в generate() (до городов): place_enemies() дёргает
	# MapSpawner._near_city() в runtime — кэш пересчитается, когда города появятся.
	R.cities = CityManager.new()
	R.cities.name = "CityManager"
	parent.add_child(R.cities)
	R.cities.status_message.connect(func(text: String):
		if R.ui_manager: R.ui_manager.set_status(text))
	R.cities.relocation_completed.connect(
		func(city_uid: int, new_center: Vector2i):
			GameEventBus.relocation_completed.emit(city_uid, new_center))

	R.cities.set_tile_yield_provider(func(cell: Vector2i) -> Dictionary:
		return CityYieldTable.yield_for_terrain(R.map_gen.get_terrain_id(cell))
	)

	R.cities.set_buildable_provider(func(cell: Vector2i) -> bool:
		return R.map_gen.is_walkable(cell)
	)

	var capital := City.new()
	capital.display_name = "Перворечье"
	var occupied := _occupied_map_cells(R)
	var center := _place_in_hero_component(R.map_gen, Vector2i(10, 10), occupied)
	capital.center = center

	var shrine_offset := Vector2i(2, -1)
	var shrine_cell := center + shrine_offset
	if not R.map_gen.is_walkable(shrine_cell) or occupied.has(shrine_cell):
		shrine_cell = _nearest_walkable(R.map_gen, center + Vector2i(2, 0))
	capital.special_sites = {shrine_cell: BuildingDefs.SITE_SHRINE}
	capital.owner = &"player"
	CityFactory.apply_starting_kit(capital)
	R.cities.register_city(capital, true)

	var second := CityFactory.create_village(
		_place_in_hero_component(R.map_gen, Vector2i(center.x + 15, center.y), occupied), "Город 2", 0)
	R.cities.register_city(second, false)

	# Столицы записаны. place_enemies уже прошёл в generate() (до городов):
	# пересчитываем детерминированно (тот же seed) с учётом ENEMY_CITY_SPAWN_GAP
	# и пересоздаём вражеские ноды. Иначе стая в 3–7 клетках от столицы
	# захватывает её за 1–2 хода: DEFEAT на ходу 2, ранняя игра неиграбельна.
	if R.map_gen != null and R.map_gen.spawner != null:
		R.map_gen.spawner.set_known_cities(R.cities.cities)
		R.map_gen.spawner.place_enemies()
		if R.spawner != null:
			R.spawner.respawn_enemies()

static func _create_subsystems(parent: Node2D, R: BootstrapResult) -> void:
	R.turn_scheduler = TurnScheduler.new()

	_register_city(R)

	_register_economy(R)

	_register_city_income(R)

	_register_demographics(R)

	_create_battle(parent, R)

	_register_enemy_ai(R)

	R.interaction_controller = WorldInteractionController.new()
	R.interaction_controller.name = "InteractionController"
	parent.add_child(R.interaction_controller)

static func _create_battle(parent: Node2D, R: BootstrapResult) -> void:
	R.battle_coordinator = WorldBattleCoordinator.new()
	R.battle_coordinator.name = "BattleCoordinator"
	parent.add_child(R.battle_coordinator)

static func _register_city(R: BootstrapResult) -> void:
	if R.turn_scheduler == null or R.cities == null:
		return

	var city_proc := CityTurnProcessor.new()
	R.turn_scheduler.register_processor(city_proc)

	city_proc.city_scale_changed.connect(
		func(city_uid: int, new_scale: int):
			GameEventBus.scale_shift.emit(city_uid, new_scale))
	city_proc.zone_violation.connect(
		func(city_uid: int, cell: Vector2i):
			GameEventBus.zone_violation.emit(city_uid, cell))
	city_proc.reputation_changed.connect(
		func(city_uid: int, value: int, band: int):
			GameEventBus.reputation_changed.emit(city_uid, value, band))
	city_proc.migration_occurred.connect(
		func(city_uid: int, immigrants: int, emigrants: int):
			GameEventBus.migration_occurred.emit(city_uid, immigrants, emigrants))
	city_proc.city_level_up.connect(
		func(city_uid: int, new_level: int):
			GameEventBus.city_level_up.emit(city_uid, new_level))
	city_proc.raid_occurred.connect(
		func(city_uid: int, repelled: bool):
			GameEventBus.raid_occurred.emit(city_uid, repelled))
	city_proc.city_event_occurred.connect(
		func(city_uid: int, event_id: StringName):
			GameEventBus.city_event_occurred.emit(city_uid, event_id))

static func _register_enemy_ai(R: BootstrapResult) -> void:
	if R.turn_scheduler == null or R.map_gen == null or R.cities == null:
		return
	var seed_val: int = R.session.run_seed if R.session != null else 0

	var proc := EnemyTurnProcessor.new()
	proc.setup_world(R.map_gen, R.hero, R.spawner, R.cities, R.world_delta, seed_val)
	R.turn_scheduler.register_processor(proc)
	R.enemy_proc = proc

	var growth := EnemyGrowthSystem.new()
	growth.setup_growth(R.map_gen, R.spawner, R.cities, R.world_delta, seed_val)
	R.turn_scheduler.register_processor(growth)

	proc.enemy_attack_requested.connect(R.battle_coordinator.start_enemy_attack)
	R.battle_coordinator.enemy_stack_defeated.connect(growth.on_stack_defeated)

	if R.ui_manager != null and R.ui_manager.marker_layer != null:
		var hero := R.hero
		var map_gen := R.map_gen
		var ui := R.ui_manager
		var markers = R.ui_manager.marker_layer
		proc.enemy_turn_reported.connect(
			func(report: Dictionary) -> void:
				var cells: Array = []
				var hp: Variant = hero.get("current_cell") if hero != null else null
				if hp is Vector2i:
					var fog = map_gen.visibility
					for cell in map_gen.enemy_stacks:
						if HexUtils.hex_distance(hp, cell) <= GameNumbers.ENEMY_AGGRO_RADIUS \
								and (fog == null or fog.is_visible(cell)):
							cells.append(cell)
				markers.set_threat_markers(cells)
				if int(report.get("moved", 0)) > 0:
					ui.set_status("Враги движутся")
		)

static func _register_economy(R: BootstrapResult) -> void:
	if R.turn_scheduler == null or R.cities == null:
		return

	var defs: Array[ResourceDef] = []
	var resources_reg: Node = Services.resolve(&"resources")
	if resources_reg != null:
		defs = resources_reg.get_all()
	for city in R.cities.cities:
		city.ensure_resource_ctx(defs)

	var econ := EconomicTurnProcessor.new()
	R.turn_scheduler.register_processor(econ)

	econ.production_completed.connect(
		func(city_uid: int, chain_id: StringName, outputs: Dictionary):
			GameEventBus.production_completed.emit(city_uid, chain_id, outputs))
	econ.upkeep_failed.connect(
		func(building_uid: int, resource_id: StringName):
			GameEventBus.upkeep_failed.emit(building_uid, resource_id))
	econ.resource_depleted.connect(
		func(city_uid: int, resource_id: StringName):
			GameEventBus.resource_depleted.emit(city_uid, resource_id))

static func _register_city_income(R: BootstrapResult) -> void:
	if R.turn_scheduler == null:
		return
	R.turn_scheduler.register_processor(CityIncomeProcessor.new())

static func _register_demographics(R: BootstrapResult) -> void:
	if R.turn_scheduler == null or R.cities == null:
		return

	R.character_registry = CharacterRegistry.new()
	var demo := DemographicTurnProcessor.new()
	demo.setup(R.character_registry)
	R.turn_scheduler.register_processor(demo)

	demo.character_born.connect(
		func(character_uid: int, city_uid: int, _name: String):
			GameEventBus.character_born.emit(city_uid, character_uid))
	demo.character_died.connect(
		func(character_uid: int, city_uid: int, _cause: StringName):
			GameEventBus.character_died.emit(city_uid, character_uid))
	demo.character_need_critical.connect(
		func(character_uid: int, need_id: int):
			GameEventBus.character_need_critical.emit(character_uid, need_id))
	demo.disease_outbreak.connect(
		func(city_uid: int, character_uid: int):
			GameEventBus.disease_outbreak.emit(city_uid, character_uid))

static func _create_resource_nodes(parent: Node2D, R: BootstrapResult) -> void:
	R.resource_node_manager = ResourceNodeManager.new()
	R.resource_node_manager.name = "ResourceNodeManager"
	parent.add_child(R.resource_node_manager)

	var node_container := Node2D.new()
	node_container.name = "ResourceNodes"
	parent.add_child(node_container)
	R.resource_node_manager.setup(node_container, R.rng, Resources, R.map_gen.map_to_local)

	var map_data := {
		"terrain": R.map_gen.terrain_grid.duplicate(),
		"width": R.map_gen.map_width,
		"height": R.map_gen.map_height,
	}
	R.resource_node_manager.generate_nodes_for_map(map_data)

	R.terrain_resource_manager = _TerrainResourceManager.new()
	R.terrain_resource_manager.name = "TerrainResourceManager"
	parent.add_child(R.terrain_resource_manager)
	R.terrain_resource_manager.attach_delta(R.world_delta)
	R.terrain_resource_manager.generate(map_data)

static func _place_in_hero_component(
	map_gen: MapGenerator, preferred: Vector2i, excluded: Dictionary = {} ) -> Vector2i:
	var comp: Dictionary = map_gen.reachable_cells
	var cand := _nearest_walkable(map_gen, preferred)

	if not excluded.has(cand) and (comp.is_empty() or comp.has(cand)):
		return cand

	var best: Vector2i = Vector2i(-1, -1)
	var best_d := INT32_MAX
	var cells: Array = comp.keys() if not comp.is_empty() else [cand]

	for cell in cells:
		if excluded.has(cell):
			continue
		var d := HexUtils.hex_distance(preferred, cell)
		if d < best_d:
			best_d = d
			best = cell

	if best_d == INT32_MAX:
		return cand
	return best

static func _occupied_map_cells(R: BootstrapResult) -> Dictionary:
	var out: Dictionary = R.map_gen.enemy_stacks.duplicate()
	for cell in R.map_gen.resource_cells:
		out[cell] = true
	if R.spawner != null:
		for cell in R.spawner.chest_cells():
			out[cell] = true
	return out

static func _nearest_walkable(map_gen: MapGenerator, start: Vector2i) -> Vector2i:
	if map_gen == null or map_gen.model == null:
		return start
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var head := 0
	while head < queue.size():
		var cell = queue[head]
		head += 1
		if map_gen.is_walkable(cell):
			return cell
		for nb in HexUtils.get_all_neighbors(cell):
			if map_gen.is_in_bounds(nb) and not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	push_error("WorldBootstrap: no walkable cell found from %s" % start)
	return start

static func _compute_map_rect(R: BootstrapResult) -> Rect2:
	if R.map_gen:
		return R.map_gen.get_map_world_rect()
	return Rect2(0, 0, 10000, 10000)
