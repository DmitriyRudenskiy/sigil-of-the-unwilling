extends Node
class_name WorldBattleCoordinator
## Полный боевой цикл: контакт → бой → результаты → слава → дельта.
## Мир прячется/показывается через GameEventBus.

const UnitStack = preload("res://scripts/unit_stack.gd")

var hero: HeroController
var map_gen: MapGenerator
var spawner: WorldSpawner
var battle_flow: BattleFlow
var rng: RandomNumberGenerator
var world_ctrl: Node
var ui_manager: WorldUIManager
var camera: Camera2D
var input_controller: Node
var world_delta: WorldStateDelta

var _pending_enemy_cell: Vector2i = Vector2i(-1, -1)


func setup(
	h: HeroController,
	m: MapGenerator,
	s: WorldSpawner,
	r: RandomNumberGenerator,
	wc: Node,
	ui: WorldUIManager,
	cam: Camera2D,
	inp: Node,
	delta: WorldStateDelta
) -> void:
	hero = h
	map_gen = m
	spawner = s
	rng = r
	world_ctrl = wc
	ui_manager = ui
	camera = cam
	input_controller = inp
	world_delta = delta

	_create_battle_flow()


func _create_battle_flow() -> void:
	battle_flow = BattleFlow.new()
	battle_flow.name = "BattleFlow"
	battle_flow.battle_started.connect(_on_battle_started)
	battle_flow.battle_completed.connect(_on_battle_completed)
	add_child(battle_flow)


# ==================== КОНТАКТ С ВРАГОМ ====================

func check_enemy_contact(cell: Vector2i) -> void:
	if map_gen.enemy_stacks.has(cell):
		_start_battle(map_gen.enemy_stacks[cell], cell)
		return
	for nb in HexUtils.get_all_neighbors(cell):
		if map_gen.enemy_stacks.has(nb):
			_start_battle(map_gen.enemy_stacks[nb], nb)
			return


func _start_battle(enemy_army: Array[UnitStack], enemy_cell: Vector2i) -> void:
	if battle_flow == null or hero == null:
		return
	_pending_enemy_cell = enemy_cell
	hero.force_stop()

	var attacker_bonus: Dictionary = hero.get_battle_bonus()
	var defender_bonus: Dictionary = {}
	if spawner != null:
		defender_bonus = spawner.get_enemy_defender_bonus()

	battle_flow.start_battle(
		hero.get_army_for_battle(),
		enemy_army,
		attacker_bonus,
		defender_bonus,
		hero.inventory.get_total_modifiers(),
		{},
		rng.randi()
	)


# ==================== ЖИЗНЕННЫЙ ЦИКЛ БОЯ ====================

func _on_battle_started() -> void:
	GameEventBus.battle_started.emit()

	if world_ctrl != null:
		world_ctrl.visible = false
	if ui_manager != null:
		ui_manager.set_ui_visible(false)
	if camera != null:
		camera.set_process(false)
	if input_controller != null:
		input_controller.set_process_unhandled_input(false)


func _on_battle_completed(
	winner: String,
	surv_atk: Array[UnitStack],
	surv_def: Array[UnitStack]
) -> void:
	if world_ctrl != null:
		world_ctrl.visible = true
	if ui_manager != null:
		ui_manager.set_ui_visible(true)
	if camera != null:
		camera.set_process(true)
		camera.make_current()
	if input_controller != null:
		input_controller.set_process_unhandled_input(true)

	var enemy_cell := _pending_enemy_cell
	_apply_results(winner, surv_atk, surv_def)

	GameEventBus.battle_completed.emit(winner, enemy_cell)
	if winner == "attacker":
		GameEventBus.battle_won.emit(enemy_cell)
	else:
		GameEventBus.battle_lost.emit(enemy_cell)

	_pending_enemy_cell = Vector2i(-1, -1)


func _apply_results(
	winner: String,
	surv_atk: Array[UnitStack],
	surv_def: Array[UnitStack]
) -> void:
	if hero == null:
		return

	hero.apply_battle_results(surv_atk)

	if hero.army.army.is_empty():
		var fallback: Array[UnitStack] = []
		var stack := Units.make_fixed_stack("swordsmen", 10)
		if stack != null:
			fallback.append(stack)
		hero.army.apply_battle_results(fallback)
		GameLogger.hero("Hero routed: awarded minimal stack")

	if winner == "attacker":
		map_gen.enemy_stacks.erase(_pending_enemy_cell)
		if spawner:
			spawner.remove_enemy_at(_pending_enemy_cell)
		GameLogger.battle("Enemy defeated at %s" % _pending_enemy_cell)

		if world_delta != null:
			world_delta.add_defeated_enemy(_pending_enemy_cell)

		_try_artifact_drop()

		if ui_manager != null:
			ui_manager.refresh_ui()
	else:
		GameLogger.battle("Battle lost / retreated")


func _try_artifact_drop() -> void:
	if hero.inventory == null:
		return
	if rng.randf() < GameSettings.MONSTER_DROP_CHANCE:
		var arts := Artifacts.get_by_rarity(Artifact.Rarity.MINOR)
		if arts.size() > 0:
			var drop := arts[rng.randi() % arts.size()]
			if hero.inventory.add_to_backpack(drop):
				GameLogger.world("Monster drop: %s" % drop.display_name)
			else:
				GameLogger.world("Backpack full, drop lost!")


# ==================== ПУБЛИЧНЫЙ API ====================

func get_pending_enemy_cell() -> Vector2i:
	return _pending_enemy_cell


func get_battle_flow() -> BattleFlow:
	return battle_flow
