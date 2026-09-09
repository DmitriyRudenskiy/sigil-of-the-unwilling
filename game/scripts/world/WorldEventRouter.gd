class_name WorldEventRouter
extends Node

const ResourceDef = preload("res://scripts/data/ResourceDef.gd")

var hero: Node = null
var map_gen: Node = null
var camera: Node = null
var cities: Node = null
var battle_coordinator: Node = null
var interaction_controller: Node = null
var resource_node_manager: Node = null
var terrain_resource_manager: Variant = null
var ui_manager: Node = null
var world_delta: Variant = null
var persistence: Variant = null
var visibility = null
var resource_chain: Variant = null
var turn_scheduler: TurnScheduler = null
var _resource_registry: Node = null

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
	p_resource_chain: Variant, p_visibility = null,
	p_resource_registry: Node = null,
	p_turn_scheduler: TurnScheduler = null,
	p_terrain_resource_manager: Variant = null
) -> void:
	hero = p_hero
	map_gen = p_map_gen
	camera = p_camera
	cities = p_cities
	battle_coordinator = p_battle_coordinator
	interaction_controller = p_interaction_controller
	resource_node_manager = p_resource_node_manager
	terrain_resource_manager = p_terrain_resource_manager
	ui_manager = p_ui_manager
	world_delta = p_world_delta
	persistence = p_persistence
	resource_chain = p_resource_chain
	visibility = p_visibility
	_resource_registry = p_resource_registry if p_resource_registry != null else Services.resolve(&"resources")
	turn_scheduler = p_turn_scheduler

	_connect_hero_signals()
	_connect_ui_signals()

	if terrain_resource_manager and ui_manager and ui_manager.marker_layer:
		ui_manager.marker_layer.set_terrain_resource_markers(terrain_resource_manager)

func _ready() -> void:
	if hero == null or ui_manager == null:
		_connect_hero_signals()
		_connect_ui_signals()
	_connect_event_bus()

func _connect_hero_signals(p_hero: Node = null) -> void:
	var h: Node = p_hero if p_hero != null else hero
	if h == null or not is_instance_valid(h):
		return
	if not h.hero_moved.is_connected(_on_hero_moved):
		h.hero_moved.connect(_on_hero_moved)
	if h.has_signal("movement_finished") and not h.movement_finished.is_connected(_on_movement_finished):
		h.movement_finished.connect(_on_movement_finished)
	if not h.hero_entered_village.is_connected(_on_village):
		h.hero_entered_village.connect(_on_village)
	if h.get("movement") != null:
		var mov = h.get("movement")
		if mov.reach_preview_changed and not mov.reach_preview_changed.is_connected(_on_reach_preview_changed):
			mov.reach_preview_changed.connect(_on_reach_preview_changed)
		if mov.reach_preview_cleared and not mov.reach_preview_cleared.is_connected(_on_reach_preview_cleared):
			mov.reach_preview_cleared.connect(_on_reach_preview_cleared)

func _disconnect_hero_signals(old_hero: Node = null) -> void:
	var h: Node = old_hero if old_hero != null else hero
	if h == null or not is_instance_valid(h):
		return
	if h.has_signal("hero_moved") and h.hero_moved.is_connected(_on_hero_moved):
		h.hero_moved.disconnect(_on_hero_moved)
	if h.has_signal("movement_finished") and h.movement_finished.is_connected(_on_movement_finished):
		h.movement_finished.disconnect(_on_movement_finished)
	if h.has_signal("hero_entered_village") and h.hero_entered_village.is_connected(_on_village):
		h.hero_entered_village.disconnect(_on_village)
	var mov = h.get("movement")
	if mov != null and is_instance_valid(mov):
		if mov.has_signal("reach_preview_changed") and mov.reach_preview_changed.is_connected(_on_reach_preview_changed):
			mov.reach_preview_changed.disconnect(_on_reach_preview_changed)
		if mov.has_signal("reach_preview_cleared") and mov.reach_preview_cleared.is_connected(_on_reach_preview_cleared):
			mov.reach_preview_cleared.disconnect(_on_reach_preview_cleared)

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
		if not m.city_marker_clicked.is_connected(_on_city_marker_clicked):
			m.city_marker_clicked.connect(_on_city_marker_clicked)

func _on_minimap_cell_activated(cell: Vector2i) -> void:
	if map_gen and map_gen.has_valid_tilemap():
		camera.center_on(map_gen.map_to_local(cell))

func _refresh_visibility() -> void:
	if visibility == null or map_gen == null:
		return
	var sources: Array = []
	if hero != null and hero.current_cell is Vector2i:
		sources.append(hero.current_cell)
	if cities != null:
		for city in cities.cities:
			if city != null and city.owner == &"player" and city.center is Vector2i:
				sources.append(city.center)
	visibility.set_map_size(map_gen.map_width, map_gen.map_height)
	if visibility.recompute(hero.current_cell, sources,
		GameNumbers.FOG_HERO_SIGHT, GameNumbers.FOG_CITY_SIGHT):
		map_gen.apply_fog(visibility)

func _on_hex_borders_toggled(on: bool) -> void:
	if ui_manager:
		ui_manager.set_hex_borders(on)

func _on_city_marker_clicked(city: City) -> void:
	if hero == null or city == null or map_gen == null:
		return
	var target: Vector2i = city.center
	if not map_gen.is_walkable(target):
		target = WorldBootstrap._nearest_walkable(map_gen, target)
	if target != hero.current_cell:
		hero.on_map_clicked(target)

func _refresh_city_markers() -> void:
	if ui_manager and cities and ui_manager.get("marker_layer"):
		ui_manager.marker_layer.set_city_markers(cities.cities)

func _connect_event_bus() -> void:
	GameEventBus.battle_won.connect(_on_battle_won)
	GameEventBus.turn_ended.connect(_on_turn_ended_bus)
	GameEventBus.resource_discovered.connect(_on_resource_discovered)
	GameEventBus.resource_extracted.connect(_on_resource_extracted)
	GameEventBus.resource_exhausted.connect(_on_resource_exhausted)

func _on_hero_moved(cell: Vector2i) -> void:
	if camera:
		camera.follow(hero)
	if interaction_controller:
		interaction_controller.collect_resource_at(cell)
		if terrain_resource_manager:
			var harvested = terrain_resource_manager.harvest(cell)
			var res_id: Variant = harvested.get("res_id", null)
			var amount: int = harvested.get("amount", 0)
			if res_id != null and amount > 0:
				GameEventBus.resource_extracted.emit(cell, res_id, amount)
				if ui_manager and ui_manager.marker_layer:
					ui_manager.marker_layer.refresh_terrain_markers()
		interaction_controller.pickup_scroll_at(cell)
		interaction_controller.check_chest_contact(cell)
	if battle_coordinator:
		battle_coordinator.check_enemy_contact(cell)

	var is_still_moving := false
	if hero != null and hero.movement != null:
		is_still_moving = hero.movement.is_moving
	if not is_still_moving:
		_refresh_visibility()

	if resource_node_manager and resource_chain and hero:
		var disc_keys = resource_chain.build_discovery_keys(hero)
		var discover_result: Dictionary = resource_node_manager.try_discover(cell, disc_keys)
		if discover_result.get("discovered", false):
			GameLogger.world("Resource discovered at %s" % cell)

	hero_moved_to.emit(cell)

	if cities and hero and ui_manager and ui_manager.has_method("city_overlay_open"):
		if not ui_manager.city_overlay_open():
			var entered: City = cities.city_at(hero.current_cell)
			if entered != null:
				ui_manager.open_city_screen(entered, hero.current_cell)

func _on_movement_finished(_cell: Vector2i) -> void:

	_refresh_visibility()

func _on_village(cell: Vector2i) -> void:
	var city: City = null
	if cities:
		city = cities.city_at(cell)
	if city == null:
		var captured := false
		if interaction_controller:
			captured = interaction_controller.capture_village_at(cell)
		if captured:
			var seed: int = persistence.session.run_seed if persistence != null else 0
			city = CityFactory.create_village(
				cell, CityFactory.village_name(seed, cell), seed)
			cities.register_city(city)
			_refresh_city_markers()
			if ui_manager:
				ui_manager.ui.add_city(city.display_name)
				village_captured.emit(cell)
			GameLogger.world("Village captured at %s: %s" % [cell, city.display_name])
	if city != null and ui_manager:
		var hero_cell: Vector2i = hero.current_cell if hero else cell
		ui_manager.open_city_screen(city, hero_cell)

func request_end_turn() -> void:
	_on_end_turn()

func _on_end_turn() -> void:
	if hero:
		hero.end_turn()

	_refresh_visibility()

	if resource_node_manager:
		resource_node_manager.tick_daily()

	var month: int = int(persistence.get_date().get("month", 1))
	if cities:
		GameEventBus.turn_ended.emit(cities.current_turn + 1, month)

	_run_turn_scheduler(month)

	if ui_manager:
		ui_manager.refresh_ui()

	end_turn_requested.emit()

func _run_turn_scheduler(month: int) -> void:
	if turn_scheduler == null or cities == null:
		return
	var ctx := TurnContext.new()
	ctx.turn_number = int(cities.current_turn)
	var date: Dictionary = persistence.get_date() if persistence != null else {}
	ctx.month = int(date.get("month", 1))
	ctx.week = int(date.get("week", 1))
	ctx.day = int(date.get("day", 1))
	for city in cities.cities:
		ctx.cities.append(city)
	if hero != null:
		ctx.heroes.append(hero)
	var report: Dictionary = turn_scheduler.execute_turn(ctx)
	_grant_city_income(report)

func _grant_city_income(report: Dictionary) -> void:
	var phases: Dictionary = report.get("phases", {})
	var income: Dictionary = phases.get(&"city_income", {})
	if income.is_empty():
		return
	var totals: Dictionary = income.get("total", {})
	for rid in totals:
		var amount: int = int(totals[rid])
		if amount > 0 and hero != null:
			hero.add_strategic_resource(rid, float(amount))
			GameLogger.world("Городская дань: +%d %s" % [amount, String(rid)])

func _on_date_changed(month: int, week: int, day: int) -> void:
	if persistence:
		persistence.set_date(month, week, day)

func _on_settings_applied() -> void:
	if camera and camera.has_method("set_zoom_level"):
		var settings_node: Object = Services.resolve(&"settings")
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
		cities.apply_reputation(cities.capital, GameNumbers.REP_VICTORY)

func _on_turn_ended_bus(turn: int, month: int) -> void:
	if cities:
		cities.on_turn_ended(month)

func _on_marker_hovered(cell: Vector2i, cost: float, remaining: float, is_reachable: bool) -> void:
	pass

func _on_marker_clicked(cell: Vector2i, is_reachable: bool) -> void:
	marker_clicked.emit(cell)

func _on_reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float) -> void:
	if ui_manager and hero:
		ui_manager.show_reach_markers(hero.current_cell, mp, dist)
	reach_preview_changed.emit(pts, dist, mp)

func _on_reach_preview_cleared() -> void:
	if ui_manager:
		ui_manager.hide_reach_markers()
	reach_preview_cleared.emit()

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
