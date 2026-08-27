extends Node
class_name WorldBattleCoordinator
## Полный боевой цикл: контакт → бой → результаты → слава → дельта.
## Мир прячется/показывается через GameEventBus.
##
## Зависимости внедряются как Callable/Node — координатор не зависит
## от конкретных типов UI и WorldSpawner (DIP). Это позволяет
## headless-тестирование через preload().

const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const UnitStack = preload("res://scripts/unit_stack.gd")

## Сигналы для декомпозиции (мокируются в тестах вместо реального UI).
signal battle_world_hide_requested
signal battle_world_show_requested

var hero: Node = null          # HeroController (Node)
var map_gen: Node = null       # MapGenerator (Node, enemy_stacks dict)
var spawner: Node = null       # WorldSpawner (Node)
var battle_flow: BattleFlow = null
var rng: RandomNumberGenerator = null
var world_ctrl: Node = null
var ui_manager: Node = null    # WorldUIManager — только Node, не типизировано
var camera: Node = null        # Camera2D
var input_controller: Node = null
var world_delta: Node = null   # WorldStateDelta

## Опциональные Callable-хуки (инъекция зависимостей вместо жёстких типов).
var _on_ui_refresh: Callable = Callable()
var _services: ServiceContainer = null

var _pending_enemy_cell: Vector2i = Vector2i(-1, -1)


## Лёгкая установка: все параметры — Node/Variant, нет жёстких типов.
## Это позволяет preload() в headless-режиме.
func setup(
	h: Node,
	m: Node,
	s: Node,
	r: RandomNumberGenerator,
	wc: Node,
	ui: Node,
	cam: Node,
	inp: Node,
	delta: Node,
	services: ServiceContainer = null
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
	_services = services
	if _services == null and ServiceContainer.current != null:
		_services = ServiceContainer.current

	_create_battle_flow()

## Установить callable для обновления UI после боя.
func set_ui_refresh_hook(callback: Callable) -> void:
	_on_ui_refresh = callback


func _create_battle_flow() -> void:
	battle_flow = BattleFlow.new()
	battle_flow.name = "BattleFlow"
	battle_flow.battle_started.connect(_on_battle_started)
	battle_flow.battle_completed.connect(_on_battle_completed)
	add_child(battle_flow)


# ==================== КОНТАКТ С ВРАГОМ ====================

func check_enemy_contact(cell: Vector2i) -> void:
	if map_gen == null or not map_gen.has_method("enemy_stacks"):
		return
	var stacks: Dictionary = map_gen.get("enemy_stacks")
	if stacks.has(cell):
		_start_battle(stacks[cell], cell)
		return
	for nb in HexUtils.get_all_neighbors(cell):
		if stacks.has(nb):
			_start_battle(stacks[nb], nb)
			return


func _start_battle(enemy_army: Array[UnitStack], enemy_cell: Vector2i) -> void:
	if battle_flow == null or hero == null:
		return
	_pending_enemy_cell = enemy_cell
	if hero.has_method("force_stop"):
		hero.call("force_stop")

	var attacker_bonus: Dictionary = hero.call("get_battle_bonus") if hero.has_method("get_battle_bonus") else {}
	var defender_bonus: Dictionary = {}
	if spawner != null and spawner.has_method("get_enemy_defender_bonus"):
		defender_bonus = spawner.call("get_enemy_defender_bonus")

	var attacker_army: Array[UnitStack] = hero.call("get_army_for_battle") if hero.has_method("get_army_for_battle") else []
	var artifact_mods: Dictionary = {}
	if hero.has_method("inventory"):
		var inv = hero.call("inventory")
		if inv != null and inv.has_method("get_total_modifiers"):
			artifact_mods = inv.call("get_total_modifiers")

	battle_flow.start_battle(
		attacker_army,
		enemy_army,
		attacker_bonus,
		defender_bonus,
		artifact_mods,
		{},
		rng.randi()
	)


# ==================== ЖИЗНЕННЫЙ ЦИКЛ БОЯ ====================

func _on_battle_started() -> void:
	GameEventBus.battle_started.emit()
	battle_world_hide_requested.emit()

	## Деактивация мира через безопасные callable-вызовы.
	if world_ctrl != null and world_ctrl.has_method("set_visible"):
		world_ctrl.set_visible(false)
	if ui_manager != null and ui_manager.has_method("set_ui_visible"):
		ui_manager.call("set_ui_visible", false)
	if camera != null and camera.has_method("set_process"):
		camera.set_process(false)
	if input_controller != null and input_controller.has_method("set_process_unhandled_input"):
		input_controller.set_process_unhandled_input(false)


func _on_battle_completed(
	winner: BattleState.Side,
	surv_atk: Array[UnitStack],
	surv_def: Array[UnitStack]
) -> void:
	## Возобновление мира.
	if world_ctrl != null and world_ctrl.has_method("set_visible"):
		world_ctrl.set_visible(true)
	if ui_manager != null and ui_manager.has_method("set_ui_visible"):
		ui_manager.call("set_ui_visible", true)
	if camera != null:
		if camera.has_method("set_process"):
			camera.set_process(true)
		if camera.has_method("make_current"):
			camera.make_current()
	if input_controller != null and input_controller.has_method("set_process_unhandled_input"):
		input_controller.set_process_unhandled_input(true)

	battle_world_show_requested.emit()

	var enemy_cell := _pending_enemy_cell
	_apply_results(winner, surv_atk, surv_def)

	GameEventBus.battle_completed.emit(winner, enemy_cell)
	if winner == BattleState.Side.ATTACKER:
		GameEventBus.battle_won.emit(enemy_cell)
	else:
		GameEventBus.battle_lost.emit(enemy_cell)

	_pending_enemy_cell = Vector2i(-1, -1)


func _apply_results(
	winner: BattleState.Side,
	surv_atk: Array[UnitStack],
	surv_def: Array[UnitStack]
) -> void:
	if hero == null:
		return

	if hero.has_method("apply_battle_results"):
		hero.call("apply_battle_results", surv_atk)

	## Fallback при полном уничтожении армии.
	if hero.has_method("get_army"):
		var army_ref = hero.call("get_army")
		if army_ref != null and army_ref.has_method("get_army"):
			var army_list = army_ref.call("get_army")
			if army_list.is_empty():
				var fallback: Array[UnitStack] = []
				var stack = _make_fallback_stack()
				if stack != null:
					fallback.append(stack)
				if army_ref.has_method("apply_battle_results"):
					army_ref.call("apply_battle_results", fallback)
				GameLogger.hero("Hero routed: awarded minimal stack")

	if winner == BattleState.Side.ATTACKER:
		if map_gen != null and map_gen.has_method("enemy_stacks"):
			var stacks: Dictionary = map_gen.get("enemy_stacks")
			stacks.erase(_pending_enemy_cell)
		if spawner != null and spawner.has_method("remove_enemy_at"):
			spawner.call("remove_enemy_at", _pending_enemy_cell)
		GameLogger.battle("Enemy defeated at %s" % _pending_enemy_cell)

		if world_delta != null and world_delta.has_method("add_defeated_enemy"):
			world_delta.call("add_defeated_enemy", _pending_enemy_cell)

		_try_artifact_drop()

		## UI refresh через хук (инъекция вместо прямого вызова).
		if _on_ui_refresh.is_valid():
			_on_ui_refresh.call()
		elif ui_manager != null and ui_manager.has_method("refresh_ui"):
			ui_manager.call("refresh_ui")
	else:
		GameLogger.battle("Battle lost / retreated")


func _make_fallback_stack() -> UnitStack:
	## Безопасный вызов без жёсткой зависимости от autoload Units.
	var units_reg: Node = _get_units_registry()
	if units_reg != null and units_reg.has_method("make_fixed_stack"):
		return units_reg.make_fixed_stack("swordsmen", 10)
	# Fallback: создать стек вручную
	return UnitStack.new(null, 10)

func _get_units_registry() -> Node:
	if _services != null and _services.units != null:
		return _services.units
	if ServiceContainer.current != null and ServiceContainer.current.units != null:
		return ServiceContainer.current.units
	return Units  # fallback: autoload

func _get_artifacts_registry() -> Node:
	if _services != null and _services.artifacts != null:
		return _services.artifacts
	if ServiceContainer.current != null and ServiceContainer.current.artifacts != null:
		return ServiceContainer.current.artifacts
	return Artifacts  # fallback: autoload


func _try_artifact_drop() -> void:
	if hero == null or not hero.has_method("inventory"):
		return
	var inv = hero.call("inventory")
	if inv == null or not inv.has_method("add_to_backpack"):
		return
	if rng.randf() < GameSettings.MONSTER_DROP_CHANCE:
		var art_reg: Node = _get_artifacts_registry()
		var arts := art_reg.get_by_rarity(Artifact.Rarity.MINOR)
		if arts.size() > 0:
			var drop := arts[rng.randi() % arts.size()]
			if inv.call("add_to_backpack", drop):
				GameLogger.world("Monster drop: %s" % drop.display_name)
			else:
				GameLogger.world("Backpack full, drop lost!")


# ==================== ПУБЛИЧНЫЙ API ====================

func get_pending_enemy_cell() -> Vector2i:
	return _pending_enemy_cell


func get_battle_flow() -> BattleFlow:
	return battle_flow
