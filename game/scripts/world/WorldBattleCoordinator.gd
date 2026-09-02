extends Node
class_name WorldBattleCoordinator
## Полный боевой цикл: контакт → бой → результаты → слава → дельта.
## Мир прячется/показывается через GameEventBus.
##
## Зависимости внедряются как Callable/Node — координатор не зависит
## от конкретных типов UI и WorldSpawner (DIP). Это позволяет
## headless-тестирование через preload().

const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")
const UnitStack = preload("res://scripts/entities/UnitStack.gd")

## Сигналы для декомпозиции (мокируются в тестах вместо реального UI).
signal battle_world_hide_requested
signal battle_world_show_requested

## enemy-world-ai: вражеский стек уничтожен (до удаления из map_gen) —
## рост планирует его ослабленное возрождение.
signal enemy_stack_defeated(enemy_cell: Vector2i, army: Array)

var hero: Node = null          # HeroController (Node)
var map_gen: Node = null       # MapGenerator (Node, enemy_stacks dict)
var spawner: Node = null       # WorldSpawner (Node)
var battle_flow: BattleFlow = null
var rng: RandomNumberGenerator = null
var world_ctrl: Node = null
var ui_manager: Node = null    # WorldUIManager — только Node, не типизировано
var camera: Node = null        # Camera2D
var input_controller: Node = null
var world_delta: WorldStateDelta = null

## succession-sigil: боевая смерть (поражение + аннигиляция → combat_hp = 0 →
## hero_died). За флагом, чтобы можно было тонко настраивать/отключить.
var battle_death_enabled := true

## Опциональные Callable-хуки (инъекция зависимостей вместо жёстких типов).
var _on_ui_refresh: Callable = Callable()
var _services: ServiceContainer = null

var _pending_enemy_cell: Vector2i = Vector2i(-1, -1)

## enemy-world-ai: роли в бою поменяны (враг — атакующий, герой — защищающийся).
var _roles_swapped := false

## Позиция героя до шага, вызвавшего контакт (для восстановления при отступлении).
var _pre_battle_cell: Vector2i = Vector2i(-1, -1)


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
	delta: WorldStateDelta,
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

## enemy-world-ai: атака с вражеского хода — враг атакующий, герой защищающийся.
func start_enemy_attack(army: Array, enemy_cell: Vector2i) -> void:
	if battle_flow == null or hero == null:
		return
	var enemy_army := _as_unit_stack_array(army)
	if enemy_army.is_empty():
		return
	var stacks: Variant = map_gen.get("enemy_stacks") if map_gen != null else null
	if not (stacks is Dictionary) or not stacks.has(enemy_cell):
		return
	_roles_swapped = true
	_pending_enemy_cell = enemy_cell
	if hero.has_method("force_stop"):
		hero.call("force_stop")

	var enemy_bonus: Dictionary = {}
	if spawner != null and spawner.has_method("get_enemy_defender_bonus"):
		enemy_bonus = spawner.call("get_enemy_defender_bonus")
	var hero_bonus: Dictionary = hero.call("get_battle_bonus") if hero.has_method("get_battle_bonus") else {}
	var hero_army_raw: Variant = hero.call("get_army_for_battle") if hero.has_method("get_army_for_battle") else []
	var hero_army: Array[UnitStack] = _as_unit_stack_array(hero_army_raw)
	var artifact_mods: Dictionary = {}
	var inv: Variant = hero.get("inventory")
	if inv != null and inv.has_method("get_total_modifiers"):
		artifact_mods = inv.call("get_total_modifiers")
	var hero_magic = hero.get("magic") if hero != null else null
	battle_flow.start_battle(
		enemy_army,
		hero_army,
		enemy_bonus,
		hero_bonus,
		{},
		artifact_mods,
		rng.randi(),
		hero_magic
	)


func check_enemy_contact(cell: Vector2i) -> void:
	if map_gen == null:
		return
	var stacks: Variant = map_gen.get("enemy_stacks")
	if not (stacks is Dictionary):
		return
	var enemy_cell := _find_contact_enemy(stacks, cell)
	if enemy_cell == Vector2i(-1, -1):
		return
	# Запоминаем, где герой стоял ДО шага, вызвавшего контакт.
	# При отступлении/поражении герой вернётся туда (иначе он остаётся
	# вплотную к непобеждённому врагу — см. _restore_hero_after_retreat).
	_pre_battle_cell = _capture_pre_battle_cell()
	_start_battle(_as_unit_stack_array(stacks[enemy_cell]), enemy_cell)


## Вражеская клетка, дающая контакт с `cell` (сама клетка или соседняя).
## Vector2i(-1,-1), если контакта нет.
func _find_contact_enemy(stacks: Dictionary, cell: Vector2i) -> Vector2i:
	if stacks.has(cell):
		return cell
	for nb in HexUtils.get_all_neighbors(cell):
		if stacks.has(nb):
			return nb
	return Vector2i(-1, -1)


## Клетка, на которой герой стоял до последнего шага.
func _capture_pre_battle_cell() -> Vector2i:
	if hero == null:
		return Vector2i(-1, -1)
	var mov = hero.get("movement")
	if mov != null:
		var prev = mov.get("previous_cell")
		if prev is Vector2i:
			return prev
	return Vector2i(-1, -1)


## enemy_stacks хранится в Dictionary как обычный Array — приводим к типизированному.
static func _as_unit_stack_array(v: Variant) -> Array[UnitStack]:
	var out: Array[UnitStack] = []
	if v is Array:
		for s in v:
			if s is UnitStack:
				out.append(s)
	return out


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

	var attacker_army_raw: Variant = hero.call("get_army_for_battle") if hero.has_method("get_army_for_battle") else []
	var attacker_army: Array[UnitStack] = _as_unit_stack_array(attacker_army_raw)
	var artifact_mods: Dictionary = {}
	var inv: Variant = hero.get("inventory")
	if inv != null and inv.has_method("get_total_modifiers"):
		artifact_mods = inv.call("get_total_modifiers")

	var hero_magic = hero.get("magic") if hero != null else null
	battle_flow.start_battle(
		attacker_army,
		enemy_army,
		attacker_bonus,
		defender_bonus,
		artifact_mods,
		{},
		rng.randi(),
		hero_magic
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
	var hero_won: bool = _hero_won(winner)
	_apply_results(winner, surv_atk, surv_def)

	GameEventBus.battle_completed.emit(winner, enemy_cell)
	if hero_won:
		GameEventBus.battle_won.emit(enemy_cell)
	else:
		GameEventBus.battle_lost.emit(enemy_cell)

	_pending_enemy_cell = Vector2i(-1, -1)
	_roles_swapped = false


## enemy-world-ai: победил ли ГЕРОЙ (при свопе ролей герой — защищающийся).
func _hero_won(winner: BattleState.Side) -> bool:
	if _roles_swapped:
		return winner == BattleState.Side.DEFENDER
	return winner == BattleState.Side.ATTACKER


func _apply_results(
	winner: BattleState.Side,
	surv_atk: Array[UnitStack],
	surv_def: Array[UnitStack]
) -> void:
	if hero == null:
		return

	var hero_won: bool = _hero_won(winner)
	## Выжившие юниты героя: при свопе герой — защищающаяся сторона.
	var hero_survivors: Array[UnitStack] = surv_def if _roles_swapped else surv_atk

	if hero.has_method("apply_battle_results"):
		hero.call("apply_battle_results", hero_survivors)

	## Fallback при полном уничтожении армии (РФ5-2: типизированный доступ)
	var army_ref: Variant = hero.get("army")
	if army_ref != null:
		if army_ref is HeroArmyController:
			if army_ref.army.is_empty():
				var stack: UnitStack = _make_fallback_stack()
				if stack != null:
					# Типизированный массив: untyped `[stack]` в параметр
					# Array[UnitStack] — runtime-ошибка в Godot 4.7 (бой с полным
					# уничтожением армии оставлял героя без минимального стека).
					var minimal: Array[UnitStack] = [stack]
					army_ref.apply_battle_results(minimal)
					GameLogger.hero("Hero routed: awarded minimal stack")

	## succession-sigil: боевая смерть. При поражении полное уничтожение армии
	## обнуляет combat_hp; combat_hp <= 0 = герой пал. Тогда — hero_died(&"battle")
	## и отступление ОТКЛАЫВАЕТСЯ. Гат за battle_death_enabled.
	if battle_death_enabled and not hero_won and hero != null:
		if hero_survivors.is_empty() and hero.has_method("set_combat_hp"):
			hero.call("set_combat_hp", 0)
		if hero.has_method("is_combat_dead") and hero.call("is_combat_dead"):
			hero.call("mark_combat_dead")
			GameEventBus.hero_died.emit(&"battle")
			GameLogger.hero("Hero died in battle at %s" % _pending_enemy_cell)
			return

	if hero_won:
		if map_gen != null:
			var stacks: Variant = map_gen.get("enemy_stacks")
			if stacks is Dictionary:
				## Снимок армии ДО удаления — для планирования роста (enemy-world-ai).
				var defeated_army: Array = stacks.get(_pending_enemy_cell, [])
				stacks.erase(_pending_enemy_cell)
				enemy_stack_defeated.emit(_pending_enemy_cell, defeated_army)
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
		_restore_hero_after_retreat()
		GameLogger.battle("Battle lost / retreated")


## После отступления/поражения возвращает героя на позицию ДО контакта
## (или на ближайшую безопасную клетку, если та сама даёт контакт).
## Без этого герой остаётся на/вплотную к клетке непобеждённого врага, и любой
## следующий шаг повторно триггерит бой с тем же врагом (герой «заперт»).
func _restore_hero_after_retreat() -> void:
	if hero == null or map_gen == null:
		return
	var mov = hero.get("movement")
	if mov == null or not mov.has_method("teleport"):
		return
	var target := _pre_battle_cell
	_pre_battle_cell = Vector2i(-1, -1)
	if target == Vector2i(-1, -1) or not _is_safe_from_enemies(target):
		# Позиция до контакта неизвестна или сама даёт контакт (например,
		# герой шёл вдоль врага). Ищем ближайшую безопасную клетку.
		target = _find_nearest_safe_cell(mov)
	if target == Vector2i(-1, -1):
		return
	GameLogger.world("Hero retreats to %s after battle" % str(target))
	mov.call("teleport", target)


## Ближайшая безопасная клетка (не вражеская, без врагов по соседству) в
## радиусе 1..4 от текущей позиции героя. Vector2i(-1,-1), если не найдена.
func _find_nearest_safe_cell(mov) -> Vector2i:
	var from_raw: Variant = mov.get("current_cell") if mov != null else null
	if not (from_raw is Vector2i):
		return Vector2i(-1, -1)
	var from: Vector2i = from_raw
	for r in range(1, 5):
		var best := Vector2i(-1, -1)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := from + Vector2i(dx, dy)
				if HexUtils.hex_distance(from, c) != r:
					continue
				if map_gen.has_method("is_walkable") and not map_gen.is_walkable(c):
					continue
				if not _is_safe_from_enemies(c):
					continue
				if best == Vector2i(-1, -1):
					best = c
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)


## Клетка безопасна: на ней и на соседних нет вражеских стеков.
func _is_safe_from_enemies(cell: Vector2i) -> bool:
	var stacks: Variant = map_gen.get("enemy_stacks")
	if not (stacks is Dictionary):
		return false
	if stacks.has(cell):
		return false
	for nb in HexUtils.get_all_neighbors(cell):
		if stacks.has(nb):
			return false
	return true


func _make_fallback_stack() -> UnitStack:
	## Безопасный вызов без жёсткой зависимости от autoload Units.
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	if units_reg != null and units_reg.has_method("make_fixed_stack"):
		return units_reg.make_fixed_stack("swordsmen", 10)
	# Fallback: создать стек вручную
	return UnitStack.new(null, 10)


func _try_artifact_drop() -> void:
	if hero == null:
		return
	var inv: Variant = hero.get("inventory")
	if inv == null or not inv.has_method("add_to_backpack"):
		return
	if rng.randf() < GameSettings.MONSTER_DROP_CHANCE:
		var art_reg: Node = ServiceLocator.resolve(null, &"artifacts")
		var arts: Array[Artifact] = art_reg.get_by_rarity(Artifact.Rarity.MINOR)
		if arts.size() > 0:
			var drop: Artifact = arts[rng.randi() % arts.size()]
			if inv.call("add_to_backpack", drop):
				GameLogger.world("Monster drop: %s" % drop.display_name)
			else:
				GameLogger.world("Backpack full, drop lost!")


# ==================== ПУБЛИЧНЫЙ API ====================

func get_pending_enemy_cell() -> Vector2i:
	return _pending_enemy_cell


func get_battle_flow() -> BattleFlow:
	return battle_flow

