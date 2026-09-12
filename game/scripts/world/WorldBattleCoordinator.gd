extends Node
class_name WorldBattleCoordinator


const _BattleHandoff = preload("res://scripts/systems/BattleHandoff.gd")

signal battle_world_hide_requested
signal battle_world_show_requested

signal enemy_stack_defeated(enemy_cell: Vector2i, army: Array)

var hero: Node = null
var map_gen: Node = null
var spawner: Node = null
var battle_flow: BattleFlow = null
var rng: RandomNumberGenerator = null
var world_ctrl: Node = null
var ui_manager: Node = null
var camera: Node = null
var input_controller: Node = null
var world_delta: WorldStateDelta = null

var battle_death_enabled := true

var _on_ui_refresh: Callable = Callable()

var _pending_enemy_cell: Vector2i = Vector2i(-1, -1)

var _roles_swapped := false

var _pre_battle_cell: Vector2i = Vector2i(-1, -1)

func setup(
	h: Node,
	m: Node,
	s: Node,
	r: RandomNumberGenerator,
	wc: Node,
	ui: Node,
	cam: Node,
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

func set_ui_refresh_hook(callback: Callable) -> void:
	_on_ui_refresh = callback

func _create_battle_flow() -> void:
	battle_flow = BattleFlow.new()
	battle_flow.name = "BattleFlow"
	battle_flow.battle_started.connect(_on_battle_started)
	battle_flow.battle_completed.connect(_on_battle_completed)
	add_child(battle_flow)

## Враг атакует героя (роли перевёрнуты).
func start_enemy_attack(army: Array, enemy_cell: Vector2i) -> void:
	if battle_flow == null or hero == null:
		return
	var stacks: Variant = map_gen.get("enemy_stacks") if map_gen != null else null
	if not (stacks is Dictionary) or not stacks.has(enemy_cell):
		return
	_launch_battle(army, enemy_cell, true)

func check_enemy_contact(cell: Vector2i) -> void:
	if map_gen == null:
		return
	var stacks: Variant = map_gen.get("enemy_stacks")
	if not (stacks is Dictionary):
		return
	var enemy_cell := _find_contact_enemy(stacks, cell)
	if enemy_cell == Vector2i(-1, -1):
		return

	# Друид: дикие животные 1-го кольца убегают без боя (early-game-foundation)
	if _hero_is_druid() and _stacks_are_wild(stacks[enemy_cell]):
		stacks.erase(enemy_cell)
		if spawner != null and spawner.has_method("remove_enemy_at"):
			spawner.call("remove_enemy_at", enemy_cell)
		GameLogger.hero("Дикие животные отступили перед друидом")
		return

	_pre_battle_cell = _capture_pre_battle_cell()
	_launch_battle(stacks[enemy_cell], enemy_cell, false)

func _hero_is_druid() -> bool:
	if hero == null:
		return false
	var cls: Variant = hero.get("hero_class")
	return str(cls) == "druid"

func _stacks_are_wild(stacks_raw: Variant) -> bool:
	if not (stacks_raw is Array) or (stacks_raw as Array).is_empty():
		return false
	for s in stacks_raw:
		if s is UnitStack and GameNumbersHero.WILD_ANIMAL_KEYS.has(s.get_key()):
			return true
	return false

func _find_contact_enemy(stacks: Dictionary, cell: Vector2i) -> Vector2i:
	if stacks.has(cell):
		return cell
	for nb in HexUtils.get_all_neighbors(cell):
		if stacks.has(nb):
			return nb
	return Vector2i(-1, -1)

func _capture_pre_battle_cell() -> Vector2i:
	if hero == null:
		return Vector2i(-1, -1)
	var mov = hero.get("movement")
	if mov != null:
		var prev = mov.get("previous_cell")
		if prev is Vector2i:
			return prev
	return Vector2i(-1, -1)

## Единая точка запуска боя: сбор и валидация данных через BattleHandoff.
func _launch_battle(
	enemy_army_raw: Variant,
	enemy_cell: Vector2i,
	p_roles_swapped: bool
) -> void:
	if battle_flow == null or hero == null:
		return
	var handoff: BattleHandoff = _BattleHandoff.collect(
		hero, enemy_army_raw, enemy_cell, spawner, rng, p_roles_swapped
	)
	if not handoff.is_valid:
		GameLogger.warn(
			"Battle handoff invalid: %s" % ", ".join(handoff.validation_errors),
			"BattleCoordinator"
		)
		return

	_pending_enemy_cell = enemy_cell
	_roles_swapped = p_roles_swapped
	if hero.has_method("force_stop"):
		hero.call("force_stop")

	battle_flow.start_battle(
		handoff.get_attacker_army(),
		handoff.get_defender_army(),
		handoff.get_attacker_bonus(),
		handoff.get_defender_bonus(),
		handoff.get_attacker_artifact_mods(),
		handoff.get_defender_artifact_mods(),
		handoff.obstacle_seed,
		handoff.get_hero_magic()
	)

func _on_battle_started() -> void:
	GameEventBus.battle_started.emit()
	battle_world_hide_requested.emit()

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
	var hero_survivors: Array[UnitStack] = surv_def if _roles_swapped else surv_atk

	# Личный боец не юнит армии: отделяем и переводим в HP героя
	var fighter_alive := false
	var fighter_hp := 1
	for i in range(hero_survivors.size() - 1, -1, -1):
		if hero_survivors[i] != null and hero_survivors[i].get_key() == GameNumbersHero.HERO_BATTLE_KEY:
			fighter_alive = hero_survivors[i].is_alive()
			fighter_hp = hero_survivors[i].count
			hero_survivors.remove_at(i)
	
	if hero.has_method("apply_battle_results"):
		hero.call("apply_battle_results", hero_survivors)
	if fighter_alive and hero.has_method("set_combat_hp"):
		hero.call("set_combat_hp", max(1, fighter_hp))

	var army_ref: Variant = hero.get("army")
	if army_ref != null:
		if army_ref is HeroArmyController:
			if army_ref.army.is_empty():
				var stack: UnitStack = _make_fallback_stack()
				if stack != null:
					var minimal: Array[UnitStack] = [stack]
					army_ref.apply_battle_results(minimal)
					GameLogger.hero("Hero routed: awarded minimal stack")

	if battle_death_enabled and not hero_won and hero != null:
		# Ранняя игра: герой не погибает в одном бою — раненый выживает (early-game-foundation)
		if hero.has_method("set_combat_hp") and not fighter_alive:
			hero.call("set_combat_hp", 1)

	if hero_won:
		if map_gen != null:
			var stacks: Variant = map_gen.get("enemy_stacks")
			if stacks is Dictionary:
				var defeated_army: Array = stacks.get(_pending_enemy_cell, [])
				stacks.erase(_pending_enemy_cell)
				enemy_stack_defeated.emit(_pending_enemy_cell, defeated_army)
		if spawner != null and spawner.has_method("remove_enemy_at"):
			spawner.call("remove_enemy_at", _pending_enemy_cell)
		GameLogger.battle("Enemy defeated at %s" % _pending_enemy_cell)

		if world_delta != null and world_delta.has_method("add_defeated_enemy"):
			world_delta.call("add_defeated_enemy", _pending_enemy_cell)

		_try_artifact_drop()

		if _on_ui_refresh.is_valid():
			_on_ui_refresh.call()
		elif ui_manager != null and ui_manager.has_method("refresh_ui"):
			ui_manager.call("refresh_ui")
	else:
		_restore_hero_after_retreat()
		GameLogger.battle("Battle lost / retreated")

func _restore_hero_after_retreat() -> void:
	if hero == null or map_gen == null:
		return
	var mov = hero.get("movement")
	if mov == null or not mov.has_method("teleport"):
		return
	var target := _pre_battle_cell
	_pre_battle_cell = Vector2i(-1, -1)
	if target == Vector2i(-1, -1) or not _is_safe_from_enemies(target):
		target = _find_nearest_safe_cell(mov)
	if target == Vector2i(-1, -1):
		return
	GameLogger.world("Hero retreats to %s after battle" % str(target))
	mov.call("teleport", target)

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
	var units_reg: Node = Services.resolve(&"units")
	if units_reg != null and units_reg.has_method("make_fixed_stack"):
		return units_reg.make_fixed_stack("swordsmen", 10)
	return UnitStack.new(null, 10)

func _try_artifact_drop() -> void:
	if hero == null:
		return
	var inv: Variant = hero.get("inventory")
	if inv == null or not inv.has_method("add_to_backpack"):
		return
	if rng.randf() < GameNumbers.MONSTER_DROP_CHANCE:
		var art_reg: Node = Services.resolve(&"artifacts")
		var arts: Array[Artifact] = art_reg.get_by_rarity(Artifact.Rarity.MINOR)
		if arts.size() > 0:
			var drop: Artifact = arts[rng.randi() % arts.size()]
			if inv.call("add_to_backpack", drop):
				GameLogger.world("Monster drop: %s" % drop.display_name)
			else:
				GameLogger.world("Backpack full, drop lost!")

func get_pending_enemy_cell() -> Vector2i:
	return _pending_enemy_cell

func get_battle_flow() -> BattleFlow:
	return battle_flow
