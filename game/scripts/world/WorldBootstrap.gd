## scripts/world/WorldBootstrap.gd
class_name WorldBootstrap
extends RefCounted
## Composition root: creates all world subsystems, wires signals, returns a result bundle.
## Extracted from WorldController._ready() to keep the controller as a thin facade.

const _Platform = preload("res://scripts/core/Platform.gd")
const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const WorldPersistenceScript = preload("res://scripts/world/WorldPersistence.gd")
const ResourceChainServiceScript = preload("res://scripts/world/ResourceChainService.gd")
const WorldShortcutsScript = preload("res://scripts/world/WorldShortcuts.gd")


## Result bundle returned after bootstrap completes.
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
	var event_bus_subscribers: Array[Callable] = []
	var services: ServiceContainer = null


static func run(
	parent: Node2D,
	platform: Variant,
	rng: RandomNumberGenerator
) -> BootstrapResult:
	var R := BootstrapResult.new()
	R.rng = rng

	# 1. Services
	_init_services(parent, R)

	# 1b. Create ServiceContainer from autoloads
	R.services = ServiceContainer.from_autoloads()
	ServiceContainer.setup_global(R.services)
	var missing := R.services.validate()
	if not missing.is_empty():
		push_error("[WorldBootstrap] Missing services: %s" % ", ".join(missing))

	# 2. Resolve session / seed
	R.loaded_save = _resolve_session(R)
	rng.seed = R.session.run_seed

	# 3. Map
	_create_map(parent, R)

	# 4. Hero
	_create_hero(parent, R)

	# (await process_frame is caller's responsibility)

	# 5. Init hero (requires map)
	_init_hero(R)

	# 6. Camera
	_create_camera(parent, R)
	R.map_rect = _compute_map_rect(R)

	# 7. Input + spawner + cities (city-in-world: города — ПЕРЕД UI:
	#    WorldShortcuts создаётся в _init_ui, потому что ему нужен ui_manager;
	#    провайдер тайлового yield ставится до регистрации столицы).
	_create_input(parent, R)
	_create_spawner(parent, R)
	_create_cities(parent, R)

	# 8. UI (city-in-world: создаётся ВСЕГДА, включая headless — сокет-
	#    сценарии открывают/закрывают city-экран без дисплея)
	_init_ui(parent, platform, R)

	# 9. Subsystems + resource nodes
	_create_subsystems(parent, R)
	_create_resource_nodes(parent, R)

	# Setup resource chain with services
	R.resource_chain.setup(R.services)

	return R


# ==================== PRIVATE ====================

static func _init_services(parent: Node2D, R: BootstrapResult) -> void:
	var save_manager := SaveManager.new()
	save_manager.name = "SaveManager"
	parent.add_child(save_manager)
	R.persistence = WorldPersistenceScript.new(save_manager)
	R.resource_chain = ResourceChainServiceScript.new()


static func _resolve_session(R: BootstrapResult) -> SaveData:
	var loaded_save: SaveData = WorldPersistenceScript.pending_save
	WorldPersistenceScript.pending_save = null
	if loaded_save != null:
		R.persistence.session = R.persistence.get_session_for_seed(loaded_save.run_seed)
	else:
		R.persistence.session = R.persistence.get_session_for_seed(R.persistence.get_run_seed())
	R.session = R.persistence.session
	# Пустой дельта-снимок мира: нужен для save (в новой игре world_delta
	# раньше оставался null -> F5 всегда возвращал false). При загрузке
	# apply_loaded_save пересоздаёт/перезаполняет его из сейва.
	if R.world_delta == null:
		R.world_delta = WorldStateDelta.new()
	return loaded_save


static func _create_map(parent: Node2D, R: BootstrapResult) -> void:
	R.map_gen = MapGenerator.new()
	R.map_gen.name = "MapGenerator"
	R.map_gen.seed_value = R.rng.randi() % 999999
	parent.add_child(R.map_gen)


static func _create_hero(parent: Node2D, R: BootstrapResult) -> void:
	R.hero = HeroController.new()
	R.hero.name = "Hero"
	parent.add_child(R.hero)


static func _init_hero(R: BootstrapResult) -> void:
	R.hero.setup(R.map_gen)
	if R.loaded_save != null:
		R.hero.deserialize(R.loaded_save.hero)
		if R.map_gen.has_valid_tilemap():
			R.hero.position = R.map_gen.map_to_local(R.hero.current_cell)



static func _init_ui(parent: Node2D, _platform: Variant, R: BootstrapResult) -> void:
	# city-in-world: UI создаётся ВСЕГДА (включая headless) — сокет-сценарии
	# открывают/закрывают city-экран без дисплея.
	R.ui_manager = WorldUIManager.new()
	R.ui_manager.name = "WorldUIManager"
	parent.add_child(R.ui_manager)
	R.ui_manager.setup(R.hero, R.map_gen, R.camera, R.rng)

	# city-navigation: навигационные значки городов (всегда видны, без порога).
	if R.cities != null and R.ui_manager.get("marker_layer") != null:
		R.ui_manager.marker_layer.set_city_markers(R.cities.cities)

	# Shortcuts — после ui_manager: guard по city-оверлею (city-in-world).
	var shortcuts := WorldShortcutsScript.new()
	shortcuts.name = "WorldShortcuts"
	shortcuts.setup(R.persistence, R.ui_manager, R.hero, parent)
	parent.add_child(shortcuts)


static func _create_camera(parent: Node2D, R: BootstrapResult) -> void:
	R.camera = WorldCamera.new()
	R.camera.name = "WorldCamera"
	parent.add_child(R.camera)
	var settings := parent.get_node_or_null("/root/Settings")
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
	parent.add_child(R.input_controller)


static func _create_spawner(parent: Node2D, R: BootstrapResult) -> void:
	R.spawner = WorldSpawner.new()
	R.spawner.name = "WorldSpawner"
	R.spawner.map = R.map_gen
	R.spawner.rng = R.rng
	parent.add_child(R.spawner)
	R.spawner.setup_services(R.services)
	R.spawner.spawn_all()


static func _create_cities(parent: Node2D, R: BootstrapResult) -> void:
	R.cities = CityManager.new()
	R.cities.name = "CityManager"
	parent.add_child(R.cities)
	R.cities.status_message.connect(func(text: String):
		if R.ui_manager: R.ui_manager.set_status(text))
	# Спринт 11: перенос города -> шина событий.
	R.cities.relocation_completed.connect(
		func(city_uid: int, new_center: Vector2i):
			GameEventBus.relocation_completed.emit(city_uid, new_center))

	# FIDSI tile provider (city-in-world): выходы клеток из реального terrain.
	# ВАЖНО: ставится ДО register_city — register_city применяет провайдер
	# только если он уже есть (set_tile_yield_provider ниже его не заменяет).
	R.cities.set_tile_yield_provider(func(cell: Vector2i) -> Dictionary:
		return CityYieldTable.yield_for_terrain(R.map_gen.get_terrain_id(cell))
	)

	# Capital (РФ6-6: проверка проходимости)
	var capital := City.new()
	capital.display_name = "Перворечье"
	var center := Vector2i(10, 10)
	if not R.map_gen.is_walkable(center):
		center = _nearest_walkable(R.map_gen, center)
	capital.center = center
	capital.special_sites = {Vector2i(12, 9): BuildingDefs.SITE_SHRINE}
	# city-in-world: столица принадлежит игроку + стартовый набор (как у
	# захваченной деревни) — с первого хода доступны CITY_BUILD/CITY_HIRE.
	capital.owner = &"player"
	CityFactory.apply_starting_kit(capital)
	R.cities.register_city(capital, true)

	# city-navigation: второй стартовый город ~15 гексов от столицы (не столица;
	# имя на навигационном значке = display_name «Город 2»).
	var second := CityFactory.create_village(
		_nearest_walkable(R.map_gen, Vector2i(center.x + 15, center.y)), "Город 2", 0)
	R.cities.register_city(second, false)


static func _create_subsystems(parent: Node2D, R: BootstrapResult) -> void:
	# M0: Ядро — оркестратор фаз хода. Процессоры (M1 экономика, M2 демография,
	# M3 город) регистрируются сюда по мере готовности (см. следующие шаги
	# внедрения «Каскада сложности»); роутер событий вызывает execute_turn().
	R.turn_scheduler = TurnScheduler.new()

	# M3: Город — масштаб, ёмкости, зонирование (приоритет 5 — раньше
	# экономики, чтобы мультипликаторы были готовы).
	_register_city(R)

	# M1: Экономика — инициализация хранилищ городов и процессор цепочек.
	_register_economy(R)

	# city-in-world: дань городов (приоритет 15 — после экономики, до демографии).
	_register_city_income(R)

	_register_demographics(R)

	R.battle_coordinator = WorldBattleCoordinator.new()
	R.battle_coordinator.name = "BattleCoordinator"
	# setup is called by parent after bootstrap (parent reference needed)
	parent.add_child(R.battle_coordinator)

	# enemy-world-ai: ход и рост врагов (нужен battle_coordinator).
	_register_enemy_ai(R)

	R.interaction_controller = WorldInteractionController.new()
	R.interaction_controller.name = "InteractionController"
	parent.add_child(R.interaction_controller)


static func _register_city(R: BootstrapResult) -> void:
	## M3: Город — процессор фазы города (масштаб/ёмкости/зоны). Сигналы
	## пробрасываются в GameEventBus (интеграционный слой).
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
	## enemy-world-ai: ход врагов (25) + рост (30). Детерминированы seed'ом мира.
	if R.turn_scheduler == null or R.map_gen == null or R.cities == null:
		return
	var seed: int = R.session.run_seed if R.session != null else 0

	var proc := EnemyTurnProcessor.new()
	proc.setup_world(R.map_gen, R.hero, R.spawner, R.cities, R.world_delta, seed)
	R.turn_scheduler.register_processor(proc)

	var growth := EnemyGrowthSystem.new()
	growth.setup_growth(R.map_gen, R.spawner, R.cities, R.world_delta, seed)
	R.turn_scheduler.register_processor(growth)

	# Проводка: атака врага → бой со сменой ролей (враг — атакующий).
	proc.enemy_attack_requested.connect(R.battle_coordinator.start_enemy_attack)
	# Проводка: уничтоженный стек → ослабленное возрождение.
	R.battle_coordinator.enemy_stack_defeated.connect(growth.on_stack_defeated)

	# UI: угрожающие маркеры (стеки в радиусе агрессии от героя).
	if R.ui_manager != null and R.ui_manager.marker_layer != null:
		# ponytail: узкие captures (Node, не R) — цикл R->scheduler->proc->lambda->R
		# удерживал бы весь граф после выхода (RefCounted-циклы Godot не собирает).
		var hero := R.hero
		var map_gen := R.map_gen
		var ui := R.ui_manager
		var markers = R.ui_manager.marker_layer
		proc.enemy_turn_reported.connect(
			func(report: Dictionary) -> void:
				var cells: Array = []
				var hp: Variant = hero.get("current_cell") if hero != null else null
				if hp is Vector2i:
					# fog-of-war: кольцо агрессии — только для видимых стеков.
					var fog = map_gen.visibility
					for c in map_gen.enemy_stacks:
						if HexUtils.hex_distance(hp, c) <= GameSettings.ENEMY_AGGRO_RADIUS \
								and (fog == null or fog.is_visible(c)):
							cells.append(c)
				markers.set_threat_markers(cells)
				# Статус-строка: враги действовали в этом ходу.
				if int(report.get("moved", 0)) > 0:
					ui.set_status("Враги движутся")
		)

static func _register_economy(R: BootstrapResult) -> void:
	## M1: Экономика — инициализирует city.resource_ctx (лимиты из
	## ResourceRegistry), регистрирует EconomicTurnProcessor в планировщике
	## и пробрасывает его сигналы в GameEventBus (интеграционный слой).
	if R.turn_scheduler == null or R.cities == null:
		return

	# Лимиты ресурсов из реестра (если доступен).
	var defs: Array[ResourceDef] = []
	if R.services != null and R.services.resources != null:
		defs = R.services.resources.get_all()
	for c in R.cities.cities:
		c.ensure_resource_ctx(defs)

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
	## city-in-world: дань городов → ресурсы героя (отчёт читает WorldEventRouter).
	if R.turn_scheduler == null:
		return
	R.turn_scheduler.register_processor(CityIncomeProcessor.new())


static func _register_demographics(R: BootstrapResult) -> void:
	## M2: Демография — реестр персонажей + процессор фазы. Сигналы
	## пробрасываются в GameEventBus (интеграционный слой).
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
		func(character_uid: int, need_id: StringName):
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
	R.resource_node_manager.setup(node_container, R.rng, R.services.resources, R.map_gen.map_to_local)

	var map_data := {
		"terrain": R.map_gen.terrain_grid.duplicate(),
		"width": R.map_gen.map_width,
		"height": R.map_gen.map_height,
	}
	R.resource_node_manager.generate_nodes_for_map(map_data)


static func _nearest_walkable(map_gen: MapGenerator, start: Vector2i) -> Vector2i:
	if map_gen == null or map_gen.model == null:
		return start
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while queue.size() > 0:
		var cell = queue.pop_front()
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
