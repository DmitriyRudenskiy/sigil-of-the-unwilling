extends Node2D
class_name WorldController
## Composition Root — creates subsystems and wires signals.

# Core references
var _map_gen: MapGenerator
var _hero: HeroController
var _ui: AdventureUI
var _camera: WorldCamera
var _input_controller: WorldInput
var _spawner: WorldSpawner
var _battle_flow: BattleFlow
var _session: GameSession = null
var _rng := RandomNumberGenerator.new()
var _world_delta: WorldStateDelta = null
var _save_manager: SaveManager = null

# Subsystems
var battle_coordinator: WorldBattleCoordinator = null
var interaction_controller: WorldInteractionController = null
var resource_node_manager: ResourceNodeManager = null

# UI
var _ui_layer: CanvasLayer = null
var _inventory_screen: ArtifactInventoryScreen = null
var _chest_dialog: ArtifactChestDialog = null
var _grid_overlay: HexGridOverlay = null
var _marker_layer: MarkerLayer = null


# ==================== INIT ====================

func _ready() -> void:
	_session = GameSession.new(_get_run_seed())
	_rng.seed = _session.run_seed

	_create_map()
	_create_hero()

	await get_tree().process_frame
	_hero.setup(_map_gen)
	_hero.hero_moved.connect(_on_hero_moved)
	_hero.hero_entered_village.connect(_on_village)
	_hero.movement.reach_preview_changed.connect(_on_reach_preview_changed)
	_hero.movement.reach_preview_cleared.connect(_on_reach_preview_cleared)

	# Set camera map bounds
	_camera.set_map_rect(_compute_map_rect())

	_create_ui()
	_create_camera()
	_create_input()
	_create_spawner()
	_create_battle_flow()
	_create_subsystems()
	_create_resource_nodes()
	_create_inventory_screen()
	_create_chest_dialog()
	_create_save_manager()
	_create_marker_layer()

	_world_delta = WorldStateDelta.new()

	Logger.world("Scene ready, seed=%d" % _session.run_seed)

	# Only auto-quit if we are headless AND NOT running the test server
	var is_server := false
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-server"):
			is_server = true
			break

	if (OS.has_feature("headless") or "--autoquit" in OS.get_cmdline_args()) and not is_server:
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _create_subsystems() -> void:
	battle_coordinator = WorldBattleCoordinator.new()
	battle_coordinator.name = "BattleCoordinator"
	battle_coordinator.setup(_hero, _map_gen, _spawner, _battle_flow, _rng)
	add_child(battle_coordinator)

	interaction_controller = WorldInteractionController.new()
	interaction_controller.name = "InteractionController"
	interaction_controller.setup(_hero, _spawner, _chest_dialog)
	interaction_controller.connect_chest_signals()
	add_child(interaction_controller)


func _create_resource_nodes() -> void:
	resource_node_manager = ResourceNodeManager.new()
	resource_node_manager.name = "ResourceNodeManager"
	add_child(resource_node_manager)
	var node_container := Node2D.new()
	node_container.name = "ResourceNodes"
	add_child(node_container)
	resource_node_manager.setup(node_container, _rng)
	# Generate nodes from map data
	var map_data := {
		"terrain": _map_gen.terrain_map.duplicate(),
		"width": _map_gen.map_width,
		"height": _map_gen.map_height,
	}
	resource_node_manager.generate_nodes_for_map(map_data)
	resource_node_manager.resource_discovered.connect(_on_resource_discovered)
	resource_node_manager.resource_extracted.connect(_on_resource_extracted)


# ==================== CREATION ====================

func _create_map() -> void:
	_map_gen = MapGenerator.new()
	_map_gen.name = "MapGenerator"
	_map_gen.seed_value = _rng.randi() % 999999
	add_child(_map_gen)


func _create_hero() -> void:
	_hero = HeroController.new()
	_hero.name = "Hero"
	add_child(_hero)


func _create_ui() -> void:
	_ui = AdventureUI.new()
	add_child(_ui)
	_ui.setup(_hero)
	_ui.end_turn_pressed.connect(_on_end_turn)


func _create_camera() -> void:
	_camera = WorldCamera.new()
	_camera.name = "WorldCamera"
	add_child(_camera)
	if _hero != null:
		_camera.center_on(_hero.position)


func _create_input() -> void:
	_input_controller = WorldInput.new()
	_input_controller.name = "WorldInput"
	_input_controller.map = _map_gen
	_input_controller.hero = _hero
	_input_controller.camera = _camera
	add_child(_input_controller)


func _create_spawner() -> void:
	_spawner = WorldSpawner.new()
	_spawner.name = "WorldSpawner"
	_spawner.map = _map_gen
	_spawner.rng = _rng
	add_child(_spawner)
	_spawner.spawn_all()


func _create_battle_flow() -> void:
	_battle_flow = BattleFlow.new()
	_battle_flow.name = "BattleFlow"
	_battle_flow.battle_started.connect(_on_battle_started)
	_battle_flow.battle_completed.connect(_on_battle_completed)
	add_child(_battle_flow)

	_save_manager = SaveManager.new()
	_save_manager.name = "SaveManager"
	add_child(_save_manager)


func _create_inventory_screen() -> void:
	if _ui_layer == null:
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "WorldUILayer"
		_ui_layer.layer = 30
		add_child(_ui_layer)

	_inventory_screen = ArtifactInventoryScreen.new()
	_inventory_screen.name = "ArtifactInventoryScreen"
	_inventory_screen.visible = false
	_inventory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_inventory_screen)


func _create_chest_dialog() -> void:
	if _ui_layer == null:
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "WorldUILayer"
		_ui_layer.layer = 30
		add_child(_ui_layer)

	_chest_dialog = ArtifactChestDialog.new()
	_chest_dialog.name = "ArtifactChestDialog"
	_chest_dialog.visible = false
	_chest_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_chest_dialog)


# ==================== HERO EVENTS ====================

func _on_hero_moved(cell: Vector2i) -> void:
	_camera.follow(_hero)
	interaction_controller.collect_resource_at(cell)
	interaction_controller.pickup_scroll_at(cell)
	battle_coordinator.check_enemy_contact(cell)
	interaction_controller.check_chest_contact(cell)

	# Addendum 10: Try to discover hidden resource nodes
	if resource_node_manager:
		var disc_keys := _build_discovery_keys()
		resource_node_manager.try_discover(cell, disc_keys)


func _on_village(cell: Vector2i) -> void:
	Logger.world("Village captured at %s" % cell)
	interaction_controller.capture_village_at(cell)
	if _ui:
		_ui.add_city("Деревня (%d, %d)" % [cell.x, cell.y])


func _on_end_turn() -> void:
	_hero.end_turn()
	# Tick resource nodes
	if resource_node_manager:
		resource_node_manager.tick_daily()
	if _ui:
		_ui.refresh_all()


# ==================== BATTLE LIFECYCLE (callbacks for BattleFlow signals) ====================

func _on_battle_started() -> void:
	if _ui:
		_ui.visible = false
	visible = false
	_camera.set_process(false)
	_input_controller.set_process_unhandled_input(false)


func _on_battle_completed(winner: String, surv_atk: Array[UnitStack], surv_def: Array[UnitStack]) -> void:
	visible = true
	if _ui:
		_ui.visible = true
	_camera.set_process(true)
	_camera.make_current()
	_input_controller.set_process_unhandled_input(true)

	battle_coordinator.on_battle_completed(winner, surv_atk, surv_def)

	if _ui:
		_ui.refresh_all()


# ==================== CAMERA ====================

func get_camera() -> Camera2D:
	return _camera


func center_camera_on(cell: Vector2i) -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		_camera.center_on(_map_gen.map_to_local(cell))


func jump_camera(direction: String) -> void:
	if _map_gen == null:
		return
	var center := Vector2i(_map_gen.map_width / 2, _map_gen.map_height / 2)
	match direction:
		"N": center_camera_on(Vector2i(center.x, 2))
		"S": center_camera_on(Vector2i(center.x, _map_gen.map_height - 3))
		"W": center_camera_on(Vector2i(2, center.y))
		"E": center_camera_on(Vector2i(_map_gen.map_width - 3, center.y))


func _create_marker_layer() -> void:
	_marker_layer = MarkerLayer.new()
	_marker_layer.name = "MarkerLayer"
	_marker_layer.setup(_map_gen)
	add_child(_marker_layer)
	_marker_layer.marker_hovered.connect(_on_marker_hovered)
	_marker_layer.marker_clicked.connect(_on_marker_clicked)


func set_hex_borders(on: bool) -> void:
	if on and _grid_overlay == null:
		_grid_overlay = HexGridOverlay.new()
		_grid_overlay.map_ref = _map_gen
		_grid_overlay.cam_ref = _camera
		add_child(_grid_overlay)
	if _grid_overlay != null:
		_grid_overlay.enabled = on


# ==================== INPUT ====================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE:
			if _inventory_screen != null and _inventory_screen.visible:
				_inventory_screen.hide()
				get_viewport().set_input_as_handled()
				return


func _toggle_inventory() -> void:
	if _inventory_screen == null:
		return

	if _inventory_screen.visible:
		_inventory_screen.hide()
	else:
		_inventory_screen.setup(_hero.inventory)
		_inventory_screen.show()


func _get_run_seed() -> int:
	if OS.has_feature("editor"):
		return GameSettings.EDITOR_SEED
	return int(Time.get_unix_time_from_system()) & 0x7FFFFFFF

func get_session() -> GameSession:
	return _session


# ==================== SAVE / LOAD ====================

func save_game() -> bool:
	var save_data := SaveData.new()
	save_data.run_seed = _session.run_seed
	save_data.hero = _hero.serialize()
	save_data.world = _world_delta.serialize()
	_save_manager = _save_manager if _save_manager != null else SaveManager.new()
	return _save_manager.save_game(save_data)

# ==================== SAVE / LOAD ====================

func save_game() -> bool:
	var save_data := SaveData.new()
	save_data.run_seed = _session.run_seed
	save_data.hero = _hero.serialize()
	save_data.world = _world_delta.serialize()
	_save_manager = _save_manager if _save_manager != null else SaveManager.new()
	return _save_manager.save_game(save_data)

func load_game() -> SaveData:
	return _save_manager.load_game()

func restart_game(seed: int) -> void:
	WorldController.next_seed = seed
	get_tree().reload_current_scene()

func show_reach_markers(hero_cell: Vector2i, mp: float, dist: Dictionary) -> void:
	if _marker_layer:
		_marker_layer.show_markers(hero_cell, mp, dist)



func hide_reach_markers() -> void:
	if _marker_layer:
		_marker_layer.hide_markers()


func _on_marker_hovered(cell: Vector2i, cost: float, remaining: float, is_reachable: bool) -> void:
	# Could show tooltip; for now pass through


func _on_marker_clicked(cell: Vector2i, is_reachable: bool) -> void:
	if is_reachable and _hero:
		_hero.movement.on_map_clicked(cell)


func _on_reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float) -> void:
	if _marker_layer:
		_marker_layer.show_markers(_hero.current_cell, mp, dist)


func _on_reach_preview_cleared() -> void:
	if _marker_layer:
		_marker_layer.hide_markers()


func _compute_map_rect() -> Rect2:
	if _map_gen:
		return _map_gen.get_map_world_rect()
	return Rect2(0, 0, 10000, 10000)


# ==================== RESOURCE CHAIN HELPERS ====================

func _build_discovery_keys() -> Dictionary:
	var keys: Dictionary = {}
	keys[&"nature_sense"] = _hero.skills.get(&"nature_sense")
	keys[&"keen_eye"] = _hero.skills.get(&"keen_eye")
	keys[&"navigation"] = _hero.skills.get(&"navigation")
	keys[&"geology"] = _hero.skills.get(&"geology")
	keys[&"alchemy"] = _hero.skills.get(&"alchemy")
	keys["time"] = _hero.time.get_period_name()
	# Check for undead/lizard army tags
	var army_stacks := _hero.army.get_army_for_battle()
	for stack in army_stacks:
		var unit_def := UnitRegistry.get(stack.unit_id)
		if unit_def:
			for tag in unit_def.get_tags():
				if tag in [&"undead", &"lizard"]:
					keys[tag] = true
	return keys


func _build_extraction_keys() -> Dictionary:
	var keys: Dictionary = {}
	# Tags from army units
	var army_stacks := _hero.army.get_army_for_battle()
	for stack in army_stacks:
		var unit_def := UnitRegistry.get(stack.unit_id)
		if unit_def:
			for tag in unit_def.get_tags():
				keys[tag] = true
	# Skills
	for skill in _hero.skills.get_all():
		keys[skill] = _hero.skills.get(skill)
	# Units
	for stack in army_stacks:
		keys[stack.unit_id] = true
	# Tools
	for tool_type in HeroTools.TOOL_TYPES:
		keys[tool_type] = _hero.tools.has_tool(tool_type)
	# Fire capability
	keys["fire"] = false  # Would need spell check; simplified for now
	return keys


func try_extract_resource(cell: Vector2i) -> int:
	if resource_node_manager == null:
		return 0
	var keys := _build_extraction_keys()
	var amount := resource_node_manager.try_extract(cell, keys)
	return amount


func _on_resource_discovered(cell: Vector2i, resource_id: StringName) -> void:
	Logger.world("Resource discovered at %s: %s" % [cell, resource_id])


func _on_resource_extracted(cell: Vector2i, resource_id: StringName, amount: int) -> void:
	var skill_mult: float = 1.0
	var def := ResourceRegistry.get(resource_id)
	if def:
		if not def.discovery_skill.is_empty():
			skill_mult = _hero.skills.get_yield_multiplier(def.discovery_skill)
	var final_amount := max(1, int(amount * skill_mult))
	var actual := _hero.add_strategic_resource(resource_id, final_amount)
	Logger.world("Extracted %d of %s at %s (actual: %d)" % [final_amount, resource_id, cell, actual])


func apply_save(data: SaveData) -> void:
	if data == null or not data.is_valid():
		return

	# Rebuild map from seed
	_session.run_seed = data.run_seed
	_rng.seed = data.run_seed

	# Apply world deltas after generation
	_world_delta.deserialize(data.world)

	# Restore hero state
	_hero.deserialize(data.hero)
	_hero.setup(_map_gen)

	# Remove defeated enemies and collected resources
	for cell in _world_delta.defeated_enemies:
		_map_gen.enemy_stacks.erase(cell)
		_spawner.remove_enemy_at(cell)

	for cell in _world_delta.removed_resources:
		_map_gen.resource_cells.erase(cell)
		_spawner.remove_resource_at(cell)

	for cell in _world_delta.opened_chests:
		_spawner.remove_chest_at(cell)

	Logger.world("Loaded save: seed=%d, cell=%s" % [data.run_seed, str(_hero.current_cell)])
