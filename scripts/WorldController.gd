extends Node2D
class_name WorldController
## Координатор мира: карта, герой, UI, камера, ввод, спавн, боевой поток.

var _map_gen: MapGenerator
var _hero: HeroController
var _ui: AdventureUI
var _camera: WorldCamera
var _input_controller: WorldInput
var _spawner: WorldSpawner
var _battle_flow: BattleFlow

var _grid_overlay: HexGridOverlay
var _pending_enemy_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	_create_map()
	_create_hero()

	await get_tree().process_frame
	_hero.setup(_map_gen)
	_hero.hero_moved.connect(_on_hero_moved)
	_hero.hero_entered_village.connect(_on_village)

	_create_ui()
	_create_camera()
	_create_input()
	_create_spawner()
	_create_battle_flow()

	print("[World] Scene ready.")

	if OS.has_feature("headless") or "--autoquit" in OS.get_cmdline_args():
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()


func _create_map() -> void:
	_map_gen = MapGenerator.new()
	_map_gen.name = "MapGenerator"
	_map_gen.seed_value = randi() % 999999
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
	add_child(_spawner)
	_spawner.spawn_all()


func _create_battle_flow() -> void:
	_battle_flow = BattleFlow.new()
	_battle_flow.name = "BattleFlow"
	add_child(_battle_flow)
	_battle_flow.battle_started.connect(_on_battle_started)
	_battle_flow.battle_completed.connect(_on_battle_completed)


# ==================== HERO EVENTS ====================
func _on_hero_moved(cell: Vector2i) -> void:
	_camera.follow(_hero)
	_spawner.remove_resource_at(cell)
	_check_enemy_contact(cell)


func _on_village(cell: Vector2i) -> void:
	print("[World] Village captured at ", cell)
	_spawner.capture_village(cell)
	if _ui:
		_ui.add_city("Деревня (%d, %d)" % [cell.x, cell.y])


func _on_end_turn() -> void:
	_hero.end_turn()
	if _ui:
		_ui.refresh_all()


# ==================== ENEMY CONTACT ====================
func _check_enemy_contact(cell: Vector2i) -> void:
	if _map_gen.enemy_stacks.has(cell):
		start_battle(_map_gen.enemy_stacks[cell], cell)
		return
	for nb in HexUtils.get_all_neighbors(cell):
		if _map_gen.enemy_stacks.has(nb):
			start_battle(_map_gen.enemy_stacks[nb], nb)
			return


func start_battle(enemy_army: Array[UnitStack], enemy_cell: Vector2i) -> void:
	_pending_enemy_cell = enemy_cell
	_hero.force_stop()
	_battle_flow.start_battle(_hero.get_army_for_battle(), enemy_army)


# ==================== BATTLE LIFECYCLE ====================
func _on_battle_started() -> void:
	if _ui:
		_ui.visible = false
	visible = false
	_camera.set_process(false)
	_input_controller.set_process_unhandled_input(false)


func _on_battle_completed(winner: String, surv_atk: Array, surv_def: Array) -> void:
	visible = true
	if _ui:
		_ui.visible = true
	_camera.set_process(true)
	_camera.make_current()
	_input_controller.set_process_unhandled_input(true)

	_hero.apply_battle_results(surv_atk)
	if _hero.army.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = randi()
		_hero.army = [UnitRegistry.make_stack("swordsmen", rng)]
		print("[World] Герой разбит: выдан минимальный отряд")

	if winner == "attacker":
		_map_gen.enemy_stacks.erase(_pending_enemy_cell)
		_spawner.remove_enemy_at(_pending_enemy_cell)
		print("[World] Enemy defeated at ", _pending_enemy_cell)
	else:
		print("[World] Battle lost/retreated.")

	_pending_enemy_cell = Vector2i(-1, -1)
	if _ui:
		_ui.refresh_all()


# ==================== CAMERA COMMANDS ====================
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


func set_hex_borders(on: bool) -> void:
	if on and _grid_overlay == null:
		_grid_overlay = HexGridOverlay.new()
		_grid_overlay.map_ref = _map_gen
		_grid_overlay.cam_ref = _camera
		add_child(_grid_overlay)
	if _grid_overlay != null:
		_grid_overlay.enabled = on
