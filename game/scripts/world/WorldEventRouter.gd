## scripts/world/WorldEventRouter.gd
class_name WorldEventRouter
extends Node
## Centralized event routing for the world scene.
## All _on_* handlers extracted from WorldController live here.

const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")
const ResourceDef = preload("res://scripts/data/ResourceDef.gd")


# References — set by WorldController after bootstrap
var hero: Node = null
var map_gen: Node = null
var camera: Node = null
var cities: Node = null
var battle_coordinator: Node = null
var interaction_controller: Node = null
var resource_node_manager: Node = null
var ui_manager: Node = null
var world_delta: Variant = null
var persistence: Variant = null
var resource_chain: Variant = null
var turn_scheduler: TurnScheduler = null  # M0: Ядро — оркестратор фаз хода
var _resource_registry: Node = null


# Outward signals so WorldController can react to specific events
signal end_turn_requested
signal hero_moved_to(cell: Vector2i)
signal village_captured(cell: Vector2i)
signal battle_won_at(cell: Vector2i)
signal resource_extracted_at(cell: Vector2i, resource_id: StringName, amount: int)
signal reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float)
signal reach_preview_cleared
signal marker_clicked(cell: Vector2i)


func setup(
	p_hero: Node, p_map_gen: Node, p_camera: Node, p_cities: Node,
	p_battle_coordinator: Node, p_interaction_controller: Node,
	p_resource_node_manager: Node, p_ui_manager: Node,
	p_world_delta: Variant, p_persistence: Variant,
	p_resource_chain: Variant,
	p_resource_registry: Node = null,
	p_turn_scheduler: TurnScheduler = null
) -> void:
	hero = p_hero
	map_gen = p_map_gen
	camera = p_camera
	cities = p_cities
	battle_coordinator = p_battle_coordinator
	interaction_controller = p_interaction_controller
	resource_node_manager = p_resource_node_manager
	ui_manager = p_ui_manager
	world_delta = p_world_delta
	persistence = p_persistence
	resource_chain = p_resource_chain
	_resource_registry = ServiceLocator.resolve(p_resource_registry, &"resources")
	turn_scheduler = p_turn_scheduler

	# ВАЖНО: _ready() может выполниться ДО setup() (add_child родителя, который
	# уже в дереве), поэтому подключение сигналов hero/ui повторяем здесь —
	# коннекты идемпотентны (is_connected-гард).
	_connect_hero_signals()
	_connect_ui_signals()


func _ready() -> void:
	# Если setup() ещё не вызван, hero/ui_manager == null и коннекты
	# догонятся в setup(). Здесь подключаем только event bus (autoload).
	if hero == null or ui_manager == null:
		_connect_hero_signals()
		_connect_ui_signals()
	_connect_event_bus()


# ==================== HERO SIGNALS ====================

func _connect_hero_signals() -> void:
	if hero:
		if not hero.hero_moved.is_connected(_on_hero_moved):
			hero.hero_moved.connect(_on_hero_moved)
		if not hero.hero_entered_village.is_connected(_on_village):
			hero.hero_entered_village.connect(_on_village)
		if hero.movement.reach_preview_changed and not hero.movement.reach_preview_changed.is_connected(_on_reach_preview_changed):
			hero.movement.reach_preview_changed.connect(_on_reach_preview_changed)
		if hero.movement.reach_preview_cleared and not hero.movement.reach_preview_cleared.is_connected(_on_reach_preview_cleared):
			hero.movement.reach_preview_cleared.connect(_on_reach_preview_cleared)


# ==================== UI SIGNALS ====================

func _connect_ui_signals() -> void:
	if ui_manager and ui_manager.get("ui") and ui_manager.get("marker_layer"):
		var u = ui_manager.ui
		var m = ui_manager.marker_layer
		if not u.end_turn_pressed.is_connected(_on_end_turn):
			u.end_turn_pressed.connect(_on_end_turn)
		if not u.date_changed.is_connected(_on_date_changed):
			u.date_changed.connect(_on_date_changed)
		if not u.minimap_cell_activated.is_connected(_on_minimap_cell_activated):
			u.minimap_cell_activated.connect(_on_minimap_cell_activated)
		if not u.camera_jump_requested_dir.is_connected(_on_camera_jump):
			u.camera_jump_requested_dir.connect(_on_camera_jump)
		if not u.hex_borders_toggled.is_connected(_on_hex_borders_toggled):
			u.hex_borders_toggled.connect(_on_hex_borders_toggled)
		if not u.settings_applied.is_connected(_on_settings_applied):
			u.settings_applied.connect(_on_settings_applied)
		if not m.marker_hovered.is_connected(_on_marker_hovered):
			m.marker_hovered.connect(_on_marker_hovered)
		if not m.marker_clicked.is_connected(_on_marker_clicked):
			m.marker_clicked.connect(_on_marker_clicked)


func _on_minimap_cell_activated(cell: Vector2i) -> void:
	if map_gen and map_gen.has_valid_tilemap():
		camera.center_on(map_gen.map_to_local(cell))


func _on_hex_borders_toggled(on: bool) -> void:
	if ui_manager:
		ui_manager.set_hex_borders(on)


# ==================== EVENT BUS ====================

func _connect_event_bus() -> void:
	GameEventBus.battle_won.connect(_on_battle_won)
	GameEventBus.turn_ended.connect(_on_turn_ended_bus)
	GameEventBus.resource_discovered.connect(_on_resource_discovered)
	GameEventBus.resource_extracted.connect(_on_resource_extracted)
	GameEventBus.resource_exhausted.connect(_on_resource_exhausted)


# ==================== HANDLERS ====================

func _on_hero_moved(cell: Vector2i) -> void:
	if camera:
		camera.follow(hero)
	if interaction_controller:
		interaction_controller.collect_resource_at(cell)
		interaction_controller.pickup_scroll_at(cell)
		interaction_controller.check_chest_contact(cell)
	if battle_coordinator:
		battle_coordinator.check_enemy_contact(cell)

	# Try to discover hidden resource nodes
	if resource_node_manager and resource_chain and hero:
		var disc_keys = resource_chain.build_discovery_keys(hero)
		var discover_result: Dictionary = resource_node_manager.try_discover(cell, disc_keys)
		if discover_result.get("discovered", false):
			GameLogger.world("Resource discovered at %s" % cell)

	hero_moved_to.emit(cell)


func _on_village(cell: Vector2i) -> void:
	GameLogger.world("Village captured at %s" % cell)
	if interaction_controller:
		interaction_controller.capture_village_at(cell)

	if world_delta:
		world_delta.add_village(cell)
	if ui_manager:
		ui_manager.ui.add_city("Деревня (%d, %d)" % [cell.x, cell.y])

	village_captured.emit(cell)


func request_end_turn() -> void:
	_on_end_turn()

func _on_end_turn() -> void:
	if hero:
		hero.end_turn()

	if resource_node_manager:
		resource_node_manager.tick_daily()

	var month: int = int(persistence.get_date().get("month", 1))
	if cities:
		GameEventBus.turn_ended.emit(cities.current_turn + 1, month)

	# M0: Ядро — фазы хода (M1-M3) исполняются ПОСЛЕ монолита городов
	# (City.process_turn уже отработал через turn_ended → CityManager).
	_run_turn_scheduler(month)

	if ui_manager:
		ui_manager.refresh_ui()

	end_turn_requested.emit()


func _run_turn_scheduler(month: int) -> void:
	## Собирает TurnContext из текущего состояния мира и запускает фазы.
	if turn_scheduler == null or cities == null:
		return
	var ctx := TurnContext.new()
	ctx.turn_number = int(cities.current_turn)
	var date: Dictionary = persistence.get_date() if persistence != null else {}
	ctx.month = int(date.get("month", 1))
	ctx.week = int(date.get("week", 1))
	ctx.day = int(date.get("day", 1))
	for c in cities.cities:
		ctx.cities.append(c)
	if hero != null:
		ctx.heroes.append(hero)
	turn_scheduler.execute_turn(ctx)


func _on_date_changed(month: int, week: int, day: int) -> void:
	if persistence:
		persistence.set_date(month, week, day)


func _on_settings_applied() -> void:
	if camera and camera.has_method("set_zoom_level"):
		var settings_node = get_node_or_null("/root/Settings")
		if settings_node:
			camera.set_zoom_level(settings_node.get_zoom())


func _on_camera_jump(direction: String) -> void:
	if map_gen == null:
		return
	var center := Vector2i(map_gen.map_width / 2, map_gen.map_height / 2)
	var target: Vector2i
	match direction:
		"N": target = Vector2i(center.x, 2)
		"S": target = Vector2i(center.x, map_gen.map_height - 3)
		"W": target = Vector2i(2, center.y)
		"E": target = Vector2i(map_gen.map_width - 3, center.y)
		_: return
	if map_gen.has_valid_tilemap():
		camera.center_on(map_gen.map_to_local(target))


func _on_battle_won(enemy_cell: Vector2i) -> void:
	if cities:
		cities.add_glory(15.0, &"battle_won")
		# Спринт 6: победа — +репутация столице (CityManager.apply_reputation).
		cities.apply_reputation(cities.capital, CityBalance.REP_VICTORY)


func _on_turn_ended_bus(turn: int, month: int) -> void:
	if cities:
		cities.on_turn_ended(month)


func _on_marker_hovered(cell: Vector2i, cost: float, remaining: float, is_reachable: bool) -> void:
	pass  # Could show tooltip


func _on_marker_clicked(cell: Vector2i, is_reachable: bool) -> void:
	marker_clicked.emit(cell)  # telemetry only; movement handled by WorldInput


func _on_reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float) -> void:
	if ui_manager and hero:
		ui_manager.show_reach_markers(hero.current_cell, mp, dist)
	reach_preview_changed.emit(pts, dist, mp)


func _on_reach_preview_cleared() -> void:
	if ui_manager:
		ui_manager.hide_reach_markers()
	reach_preview_cleared.emit()


# ==================== RESOURCES ====================

func _on_resource_discovered(cell: Vector2i, resource_id: StringName) -> void:
	GameLogger.world("Resource discovered at %s: %s" % [cell, resource_id])
	if world_delta:
		world_delta.add_discovered_node(cell)


func _on_resource_extracted(cell: Vector2i, resource_id: StringName, amount: int) -> void:
	var skill_mult: float = 1.0
	var def: ResourceDef = _resource_registry.get_resource(resource_id) as ResourceDef
	if def:
		if not def.discovery_skill.is_empty() and hero:
			skill_mult = hero.skills.get_yield_multiplier(def.discovery_skill)
	var final_amount: int = max(1, int(amount * skill_mult))
	if hero:
		var actual: int = hero.add_strategic_resource(resource_id, final_amount)
		GameLogger.world("Extracted %d of %s at %s (actual: %d)" % [
			final_amount, resource_id, cell, actual])
	resource_extracted_at.emit(cell, resource_id, final_amount)


func _on_resource_exhausted(cell: Vector2i, resource_id: StringName) -> void:
	GameLogger.world("Resource exhausted at %s: %s" % [cell, resource_id])
	if world_delta:
		world_delta.add_exhausted_node(cell)
