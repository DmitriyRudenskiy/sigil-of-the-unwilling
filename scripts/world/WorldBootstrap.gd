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

	# 7. UI
	_init_ui(parent, platform, R)

	# 8. Input, spawner, cities, subsystems, resource nodes
	_create_input(parent, R)
	_create_spawner(parent, R)
	_create_cities(parent, R)
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



static func _init_ui(parent: Node2D, platform: Variant, R: BootstrapResult) -> void:
	if platform.is_headless():
		GameLogger.world("Headless mode: skipping UI initialization")
		return
	R.ui_manager = WorldUIManager.new()
	R.ui_manager.name = "WorldUIManager"
	parent.add_child(R.ui_manager)
	R.ui_manager.setup(R.hero, R.map_gen, R.camera)


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

	# Capital (РФ6-6: проверка проходимости)
	var capital := City.new()
	capital.display_name = "Перворечье"
	var center := Vector2i(10, 10)
	if not R.map_gen.is_walkable(center):
		center = _nearest_walkable(R.map_gen, center)
	capital.center = center
	capital.special_sites = {Vector2i(12, 9): BuildingDefs.SITE_SHRINE}
	R.cities.register_city(capital, true)

	# FIDSI tile provider (stub)
	R.cities.set_tile_yield_provider(func(_cell: Vector2i) -> Dictionary:
		return {&"food": 5.0, &"industry": 5.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	)

	# Shortcuts
	var shortcuts := WorldShortcutsScript.new()
	shortcuts.name = "WorldShortcuts"
	shortcuts.setup(R.persistence, R.ui_manager, R.hero, parent)
	parent.add_child(shortcuts)


static func _create_subsystems(parent: Node2D, R: BootstrapResult) -> void:
	R.battle_coordinator = WorldBattleCoordinator.new()
	R.battle_coordinator.name = "BattleCoordinator"
	# setup is called by parent after bootstrap (parent reference needed)
	parent.add_child(R.battle_coordinator)

	R.interaction_controller = WorldInteractionController.new()
	R.interaction_controller.name = "InteractionController"
	parent.add_child(R.interaction_controller)


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
	return start


static func _compute_map_rect(R: BootstrapResult) -> Rect2:
	if R.map_gen:
		return R.map_gen.get_map_world_rect()
	return Rect2(0, 0, 10000, 10000)
