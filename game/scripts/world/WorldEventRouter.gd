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
## fog-of-war: карта видимости (наследует WorldBootstrap). null — без fog.
var visibility = null
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
	p_resource_chain: Variant, p_visibility = null,
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
	visibility = p_visibility
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
		# city-navigation: клик по значку города → маршрут героя к городу.
		if not m.city_marker_clicked.is_connected(_on_city_marker_clicked):
			m.city_marker_clicked.connect(_on_city_marker_clicked)


func _on_minimap_cell_activated(cell: Vector2i) -> void:
	if map_gen and map_gen.has_valid_tilemap():
		camera.center_on(map_gen.map_to_local(cell))


## Fog-of-war: пересчёт видимости по диску обзора героя + городов.
func _refresh_visibility() -> void:
	if visibility == null or map_gen == null:
		return
	var sources: Array = []
	if hero != null and hero.current_cell is Vector2i:
		sources.append(hero.current_cell)
	# cities — CityManager (Node), не Array.
	if cities != null:
		for c in cities.cities:
			if c != null and c.owner == &"player" and c.center is Vector2i:
				sources.append(c.center)
	visibility.set_map_size(map_gen.map_width, map_gen.map_height)
	if visibility.recompute(hero.current_cell, sources,
		GameSettings.FOG_HERO_SIGHT, GameSettings.FOG_CITY_SIGHT):
		map_gen.apply_fog(visibility)


func _on_hex_borders_toggled(on: bool) -> void:
	if ui_manager:
		ui_manager.set_hex_borders(on)


# city-navigation: клик по значку города — маршрут героя к городу (D2/D3).
# Центр города может оказаться непроходимой клеткой (relocate не валидирует
# terrain) — тогда ищем ближайшую проходимую.
func _on_city_marker_clicked(city: City) -> void:
	if hero == null or city == null or map_gen == null:
		return
	var target: Vector2i = city.center
	if not map_gen.is_walkable(target):
		target = WorldBootstrap._nearest_walkable(map_gen, target)
	if target != hero.current_cell:
		hero.on_map_clicked(target)


# city-navigation: значки городов обновляем при появлении новых.
func _refresh_city_markers() -> void:
	if ui_manager and cities and ui_manager.get("marker_layer"):
		ui_manager.marker_layer.set_city_markers(cities.cities)


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

	# fog-of-war: герой двинулся — пересчитываем видимость (иначе reach
	# предпросмотр и клики открывали бы неразведённые клетки).
	_refresh_visibility()

	# Try to discover hidden resource nodes
	if resource_node_manager and resource_chain and hero:
		var disc_keys = resource_chain.build_discovery_keys(hero)
		var discover_result: Dictionary = resource_node_manager.try_discover(cell, disc_keys)
		if discover_result.get("discovered", false):
			GameLogger.world("Resource discovered at %s" % cell)

	hero_moved_to.emit(cell)

	# city-in-world: герой стоит на клетке города (столица / захваченная деревня)
	# → открыть экран управления (идемпотентно: уже открыт — ничего не делать).
	if cities and hero and ui_manager and ui_manager.has_method("city_overlay_open"):
		if not ui_manager.city_overlay_open():
			var entered: City = cities.city_at(hero.current_cell)
			if entered != null:
				ui_manager.open_city_screen(entered, hero.current_cell)


func _on_village(cell: Vector2i) -> void:
	## city-in-world: захват создаёт реальный City (CityFactory), повторный заход
	# просто открывает экран. hero_moved эмитится ДО hero_entered_village, поэтому
	# для свежезахваченной деревни открытии экрана — здесь.
	var city: City = null
	if cities:
		city = cities.city_at(cell)
	if city == null:
		var captured := false
		if interaction_controller:
			captured = interaction_controller.capture_village_at(cell)
		if captured:
			# world_delta.add_village — уже сделан внутри capture_village_at.
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

	# fog-of-war: конец хода — пересчёт видимости (города/герой могли смениться).
	_refresh_visibility()

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
	var report: Dictionary = turn_scheduler.execute_turn(ctx)
	_grant_city_income(report)


func _grant_city_income(report: Dictionary) -> void:
	## city-in-world: дань городов (фаза &"city_income") → стратегические ресурсы
	# героя. Внешний эффект — в интеграционном слое, не в процессоре.
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
