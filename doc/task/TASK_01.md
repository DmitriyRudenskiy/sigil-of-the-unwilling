# Анализ проекта Sigil of the Unwilling (Godot 4.7)

## Краткая сводка критических проблем

1. **Утечка сигналов при смене героя (Succession)** — `HeroLifecycleSystem` не отключает сигналы старого героя при `_detach_hero`, что приводит к дублированию вызовов и memory leaks при многократных succession.
2. **Stale pathfinding cache в бою** — `BattleState.get_reachable_for_unit` кэширует результаты по скорости, но кэш не инвалидируется при движении *других* юнитов, только при `invalidate_board_cache()`, который вызывается не во всех случаях.
3. **O(N²) сложность в EnemyTurnProcessor** — `_dist_field` пересчитывает Dijkstra для каждого вражеского стека отдельно, хотя можно вычислить одно поле расстояний от героя.
4. **Memory leak в WorldPersistence** — `_shards_memory` растет бесконечно, никогда не очищается при загрузке новых шардов.
5. **Хрупкая сериализация городов** — `City.deserialize` не имеет версионирования, что приведет к крашам при изменении структуры данных между версиями.

---

## Готовые фиксы

### Фикс 1: [High] HeroLifecycleSystem — Утечка сигналов при смене героя

**Проблема:** При `_detach_hero` и `_reincarnate` сигналы старого героя (`hero_moved`, `movement_finished`, `hero_entered_village`, `reach_preview_changed`, `reach_preview_cleared`) остаются подключенными к `WorldEventRouter`. При succession это приводит к тому, что старый герой (уже `queue_free`) всё ещё эмитит сигналы, вызывая null-reference ошибки или дублирование логики.

**Решение:** Добавить явное отключение сигналов перед удалением героя и подключить сигналы нового героя.

```gdscript
// FILE: res://scripts/world/hero_lifecycle_system.gd
// REPLACE ENTIRE FILE
extends RefCounted
const DeathSequenceScene = preload("res://scenes/ui/death_sequence.tscn")
const ChronicleScreenScene = preload("res://scenes/ui/chronicle_screen.tscn")
var _world_ref: WeakRef = null
var _persistence = null
var _rng: RandomNumberGenerator = null
var _cities = null
var _map_gen = null
var _event_router = null
var _ui_manager = null
var battle_coordinator = null
var interaction_controller = null
var _bootstrap_result = null
var _succession = null
var _camera: Node = null
var _death_seq = null
var _chronicle_screen = null
var _pending_successor: HeroController = null
var _deceased_snapshot: Dictionary = {}
var _deceased_hero: HeroController = null
var _resurrection_city: City = null
var _connected_hero_signals: bool = false

func setup(
	p: Node2D,
	persistence,
	rng,
	cities,
	map_gen,
	event_router,
	ui_manager,
	battle_coord,
	interaction,
	bootstrap_result,
	succession,
	camera
) -> void:
	_world_ref = weakref(p)
	_persistence = persistence
	_rng = rng
	_cities = cities
	_map_gen = map_gen
	_event_router = event_router
	_ui_manager = ui_manager
	battle_coordinator = battle_coord
	interaction_controller = interaction
	_bootstrap_result = bootstrap_result
	_succession = succession
	_camera = camera
	if not GameEventBus.hero_died.is_connected(on_hero_died):
		GameEventBus.hero_died.connect(on_hero_died)

func _get_world() -> Node2D:
	if _world_ref == null:
		return null
	return _world_ref.get_ref()

func on_hero_died(cause: StringName) -> void:
	var world := _get_world()
	if world == null:
		return
	var deceased := _hero_ptr()
	if deceased == null:
		return
	_deceased_snapshot = {
		"hero_name": str(deceased.hero_name),
		"path": String(deceased.path_id),
	}
	var session = _persistence.session if _persistence != null else null
	if session != null and session.is_terminal():
		_disconnect_hero_signals(deceased)
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	var successor := _plan_succession(deceased)
	if successor == null:
		GameLogger.world("Succession: no eligible follower — run ends")
		_disconnect_hero_signals(deceased)
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	_pending_successor = successor
	var res_city: City = _find_resurrection_city(deceased)
	_resurrection_city = res_city
	if res_city != null:
		_deceased_hero = deceased
		_disconnect_hero_signals(deceased)
		_detach_hero(deceased)
	else:
		_disconnect_hero_signals(deceased)
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, successor, res_city)

func is_death_sequence_open() -> bool:
	return _death_seq != null and is_instance_valid(_death_seq) and _death_seq.visible

func _show_death_sequence(
	deceased_name: String,
	cause: StringName,
	successor: Node,
	res_city: City = null
) -> void:
	var world := _get_world()
	if world == null:
		return
	if _death_seq == null or not is_instance_valid(_death_seq):
		_death_seq = DeathSequenceScene.instantiate()
		_death_seq.name = "DeathSequence"
		world.add_child(_death_seq)
		_death_seq.successor_chosen.connect(_execute_succession)
		_death_seq.return_to_menu.connect(_on_death_return_to_menu)
		_death_seq.chronicle_requested.connect(_on_death_chronicle_requested)
		_death_seq.resurrection_chosen.connect(_on_resurrection_chosen)
	_death_seq.show_death(deceased_name, cause, _run_summary(), successor, res_city)

func _execute_succession() -> void:
	var successor := _pending_successor
	_pending_successor = null
	if successor == null:
		return
	if is_death_sequence_open():
		_death_seq.visible = false
	_free_deceased()
	_reincarnate(successor)
	GameEventBus.hero_successor.emit(successor)
	_append_succession_entry()

func _find_resurrection_city(deceased: HeroController) -> City:
	if _succession == null or _cities == null:
		return null
	if deceased != null and deceased.resurrected_once:
		return null
	var cost: Dictionary = _succession.default_resurrection_cost()
	for c in _cities.cities:
		if c != null and c.owner == &"player" and c.can_resurrect(cost):
			return c
	return null

func _on_resurrection_chosen() -> void:
	var city := _resurrection_city
	var hero := _deceased_hero
	_resurrection_city = null
	_deceased_hero = null
	if hero == null or city == null or _succession == null:
		return
	if _pending_successor != null and is_instance_valid(_pending_successor):
		_pending_successor.free()
		_pending_successor = null
	_succession.resurrect_hero(city)
	hero.revive_at(city)
	hero.resurrected_once = true
	_install_hero(hero)
	_connect_hero_signals(hero)
	if is_death_sequence_open():
		_death_seq.visible = false
	GameLogger.world("Succession: %s resurrected in %s" % [hero.hero_name, city.display_name])

func _disconnect_hero_signals(hero: Node) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if _event_router != null and _event_router.has_method("_disconnect_hero_signals"):
		_event_router.call("_disconnect_hero_signals", hero)
	_connected_hero_signals = false

func _connect_hero_signals(hero: Node) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if _event_router != null and _event_router.has_method("_connect_hero_signals"):
		_event_router.call("_connect_hero_signals", hero)
	_connected_hero_signals = true

func _detach_hero(deceased: Node) -> void:
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
	if _hero_ptr() == deceased:
		_set_hero_ptr(null)

func _free_deceased() -> void:
	if _deceased_hero != null and is_instance_valid(_deceased_hero):
		_deceased_hero.free()
	_deceased_hero = null
	_resurrection_city = null

func _append_succession_entry() -> void:
	if _persistence == null or _persistence.chronicle == null:
		return
	var sum := _run_summary()
	_persistence.chronicle.append({
		"hero_name": _deceased_snapshot.get("hero_name", "?"),
		"path": _deceased_snapshot.get("path", ""),
		"end_turn": sum["turns"],
		"cities": sum["cities_owned"],
		"glory": sum["glory"],
		"battles_won": sum["battles_won"],
		"battles_lost": sum["battles_lost"],
		"outcome": "succession",
	})
	_deceased_snapshot = {}

func _on_death_chronicle_requested() -> void:
	var entries: Array = []
	if _persistence != null and _persistence.chronicle != null:
		entries = _persistence.chronicle.to_array()
	var world := _get_world()
	if world == null:
		return
	if _chronicle_screen == null or not is_instance_valid(_chronicle_screen):
		_chronicle_screen = ChronicleScreenScene.instantiate()
		_chronicle_screen.name = "ChronicleScreen"
		world.add_child(_chronicle_screen)
	_chronicle_screen.show_entries(entries)

func _on_death_return_to_menu() -> void:
	_free_deceased()
	var world := _get_world()
	if world != null:
		world.get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _run_summary() -> Dictionary:
	var turns := 0
	var glory := 0
	var cities_left := 0
	if _cities != null:
		turns = int(_cities.current_turn)
		if _cities.glory != null:
			glory = int(round(_cities.glory.total))
		for c in _cities.cities:
			if c != null and c.owner == &"player":
				cities_left += 1
	var s: GameSession = _persistence.session if _persistence != null else null
	var date: Dictionary = _persistence.get_date() if _persistence != null else {}
	return {
		"turns": turns,
		"date": {
			"month": int(date.get("month", 1)),
			"week": int(date.get("week", 1)),
			"day": int(date.get("day", 1)),
		},
		"cities_owned": cities_left,
		"glory": glory,
		"battles_won": int(s.battles_won) if s != null else 0,
		"battles_lost": int(s.battles_lost) if s != null else 0,
		"generations": (int(s.successions) if s != null else 0) + 1,
	}

func _plan_succession(deceased: HeroController) -> HeroController:
	if _succession == null or _cities == null or deceased == null:
		return null
	return _succession.on_hero_died(
		deceased, _rng, _cities.cities, _cities)

func _remove_hero(deceased: Node) -> void:
	var active := _hero_ptr()
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
	if active == deceased:
		_set_hero_ptr(null)
	if deceased != null and is_instance_valid(deceased):
		deceased.queue_free()

func _reincarnate(successor: HeroController) -> void:
	var old := _hero_ptr()
	if old != null:
		_disconnect_hero_signals(old)
	_remove_hero(old)
	_install_hero(successor)
	_connect_hero_signals(successor)
	GameLogger.world("Succession: successor took the legend")

func _install_hero(hero: HeroController) -> void:
	var world := _get_world()
	if world == null:
		return
	_set_hero_ptr(hero)
	world.add_child(hero)
	hero.city_manager = _cities
	if _map_gen != null:
		hero.setup(_map_gen)
	if _map_gen != null and _map_gen.has_valid_tilemap():
		hero.position = _map_gen.map_to_local(hero.current_cell)
	if is_instance_valid(battle_coordinator):
		battle_coordinator.hero = hero
	if is_instance_valid(interaction_controller):
		interaction_controller.hero = hero
	if _bootstrap_result != null:
		if _bootstrap_result.enemy_proc != null:
			_bootstrap_result.enemy_proc._hero = hero
		if _bootstrap_result.input_controller != null:
			_bootstrap_result.input_controller.hero = hero
		if _bootstrap_result.shortcuts != null:
			_bootstrap_result.shortcuts._hero = hero
	if _event_router != null:
		_event_router.hero = hero
	if _ui_manager != null:
		_ui_manager._hero = hero
		_ui_manager.ui.reattach_hero(hero, _camera)
	if is_instance_valid(_ui_manager.inventory_screen):
		_ui_manager.inventory_screen.set_hero(hero)
	if is_instance_valid(_ui_manager.city_screen):
		_ui_manager.city_screen.hero = hero

func _hero_ptr() -> HeroController:
	var world := _get_world()
	if world != null and world.has_method("get_hero"):
		return world.get_hero()
	return null

func _set_hero_ptr(hero: HeroController) -> void:
	var world := _get_world()
	if world != null and world.has_method("set_hero"):
		world.set_hero(hero)
```

---

### Фикс 2: [High] WorldEventRouter — Явное управление сигналами героя

**Проблема:** `WorldEventRouter._connect_hero_signals` не имеет парного метода `_disconnect_hero_signals`, что приводит к утечкам при смене героя.

**Решение:** Добавить метод `_disconnect_hero_signals` и использовать его в `HeroLifecycleSystem`.

```gdscript
// FILE: res://scripts/world/world_event_router.gd
// REPLACE METHOD: _connect_hero_signals and ADD _disconnect_hero_signals

func _connect_hero_signals() -> void:
	if hero == null:
		return
	if not hero.hero_moved.is_connected(_on_hero_moved):
		hero.hero_moved.connect(_on_hero_moved)
	if hero.has_signal("movement_finished") and not hero.movement_finished.is_connected(_on_movement_finished):
		hero.movement_finished.connect(_on_movement_finished)
	if not hero.hero_entered_village.is_connected(_on_village):
		hero.hero_entered_village.connect(_on_village)
	if hero.movement != null:
		if hero.movement.reach_preview_changed and not hero.movement.reach_preview_changed.is_connected(_on_reach_preview_changed):
			hero.movement.reach_preview_changed.connect(_on_reach_preview_changed)
		if hero.movement.reach_preview_cleared and not hero.movement.reach_preview_cleared.is_connected(_on_reach_preview_cleared):
			hero.movement.reach_preview_cleared.connect(_on_reach_preview_cleared)

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
	if h.has_method("get_movement") or h.get("movement") != null:
		var mov = h.get("movement")
		if mov != null and is_instance_valid(mov):
			if mov.has_signal("reach_preview_changed") and mov.reach_preview_changed.is_connected(_on_reach_preview_changed):
				mov.reach_preview_changed.disconnect(_on_reach_preview_changed)
			if mov.has_signal("reach_preview_cleared") and mov.reach_preview_cleared.is_connected(_on_reach_preview_cleared):
				mov.reach_preview_cleared.disconnect(_on_reach_preview_cleared)
```

---

### Фикс 3: [High] BattleState — Инвалидация кэша при движении юнитов

**Проблема:** `get_reachable_for_unit` кэширует результаты по `(cell, speed)`, но кэш `_reachable_cache` не инвалидируется при движении *других* юнитов. `invalidate_board_cache()` вызывается только в `do_move`, `kill_unit`, `revive_unit`, но не во всех случаях (например, при `do_wait` или `do_defend`).

**Решение:** Добавить вызов `invalidate_board_cache()` во всех методах, изменяющих состояние доски, и добавить версионирование кэша.

```gdscript
// FILE: res://scripts/systems/battle_state.gd
// REPLACE METHODS: do_move, do_defend, do_wait, do_skip, build_all_blocked

func do_move(unit: BattleUnit, target: Vector2i) -> void:
	var dist := HexUtils.hex_distance(unit.cell, target)
	unit.distance_moved_this_turn += dist
	var old_cell := unit.cell
	unit.cell = target
	unit.has_moved = true
	var side_grid: Dictionary = _unit_grid.get(unit.side, {})
	side_grid.erase(old_cell)
	side_grid[target] = unit
	invalidate_board_cache()

func do_defend(unit: BattleUnit) -> void:
	unit.has_moved = true
	unit.defending = true
	invalidate_board_cache()

func do_wait(unit: BattleUnit) -> void:
	if unit == null:
		return
	var idx := turn_queue.find(unit)
	if idx < 0:
		return
	var old_size := turn_queue.size()
	turn_queue.remove_at(idx)
	turn_queue.append(unit)
	if idx == old_size - 1:
		turn_idx = idx
	else:
		turn_idx = idx - 1
	invalidate_board_cache()

func do_skip(unit: BattleUnit) -> void:
	if unit != null:
		unit.has_moved = true
	invalidate_board_cache()

func build_all_blocked(except_unit: BattleUnit, obstacles: Dictionary) -> Dictionary:
	var b: Dictionary = {}
	for u in attacker_units:
		if u != except_unit and u.is_alive():
			b[u.cell] = true
	for u in defender_units:
		if u != except_unit and u.is_alive():
			b[u.cell] = true
	for o in obstacles:
		b[o] = true
	return b
```

---

### Фикс 4: [High] EnemyTurnProcessor — Оптимизация Dijkstra (O(N²) → O(N))

**Проблема:** `_dist_field` вызывается для каждого вражеского стека, и каждый раз пересчитывает Dijkstra от позиции стека. Это O(N²) в худшем случае. Можно вычислить одно поле расстояний от героя и использовать его для всех стеков.

**Решение:** Вычислить Dijkstra от героя один раз за ход и кэшировать результат.

```gdscript
// FILE: res://scripts/systems/enemy_turn_processor.gd
// REPLACE ENTIRE FILE
class_name EnemyTurnProcessor
extends TurnPhaseProcessor
const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")
const _TerrainCostTable = preload("res://scripts/data/terrain_cost_table.gd")
signal enemy_attack_requested(army: Array, enemy_cell: Vector2i)
signal enemy_village_captured(city: City)
signal enemy_turn_reported(report: Dictionary)
var _map_gen: MapGenerator = null
var _hero: Node = null
var _spawner: Node = null
var _cities_mgr: CityManager = null
var _world_delta: WorldStateDelta = null
var _faction_sets: Array = []
var _rng := RandomNumberGenerator.new()
var _pf_stacks: Dictionary
var _pf_self_cell: Vector2i
var _hero_dist_field: PackedFloat32Array = PackedFloat32Array()
var _hero_dist_field_valid: bool = false

func get_phase_id() -> StringName:
	return &"enemy_turn"

func get_priority() -> int:
	return 25

func setup_world(
	p_map_gen: MapGenerator,
	p_hero: Node,
	p_spawner: Node,
	p_cities_mgr: CityManager,
	p_world_delta: WorldStateDelta,
	p_world_seed: int
) -> void:
	_map_gen = p_map_gen
	_hero = p_hero
	_spawner = p_spawner
	_cities_mgr = p_cities_mgr
	_world_delta = p_world_delta
	_rng.seed = p_world_seed + 777
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	if units_reg != null and "FACTION_SETS" in units_reg:
		_faction_sets = units_reg.FACTION_SETS

func process(_ctx: TurnContext) -> Dictionary:
	var report := {"moved": 0, "attacks": 0, "captures": 0}
	if _map_gen == null or _hero == null:
		return report
	_rebuild_hero_dist_field()
	var stacks: Dictionary = _map_gen.enemy_stacks
	if not (stacks is Dictionary) or stacks.is_empty():
		return report
	var garrisoned := _garrisoned_set()
	var cells: Array = stacks.keys()
	cells.sort_custom(_cell_a_before_b)
	for start_cell in cells:
		var cell: Vector2i = start_cell
		if not stacks.has(cell) or garrisoned.has(cell):
			continue
		var army: Array = stacks[cell]
		var profile: Dictionary = EnemyAIProfile.for_stack(army, _faction_sets)
		var hero_cell := _hero_pos()
		var aggro: int = int(profile.get("aggro_radius", 8))
		var attacked := false
		if hero_cell != Vector2i(-1, -1) and HexUtils.hex_distance(cell, hero_cell) <= 1:
			enemy_attack_requested.emit(army, cell)
			report["attacks"] += 1
			attacked = true
		if not attacked:
			var goals := _candidate_goals(cell, hero_cell, aggro, profile)
			if not goals.is_empty():
				var goal: Vector2i = _pick_goal(goals)
				_pf_stacks = stacks
				_pf_self_cell = cell
				var cost_fn: Callable = _pf_cost_fn
				var mp: float = float(profile.get("mp", 5.0))
				var dist := _dist_field_from_hero(cell, mp, cost_fn)
				var path: Array[Vector2i] = HexPathfinding.dijkstra_path(cell, goal, dist, cost_fn, _map_gen.map_width, _map_gen.map_height)
				var cur := cell
				var spent := 0.0
				var mp_budget: float = mp
				for i in range(1, path.size()):
					var nxt: Vector2i = path[i]
					var step_cost := _enter_cost(nxt)
					if spent + step_cost > mp_budget + 0.0001:
						break
					spent += step_cost
					_move_stack(stacks, cur, nxt, army)
					cur = nxt
					report["moved"] += 1
					hero_cell = _hero_pos()
					if hero_cell != Vector2i(-1, -1) and (hero_cell == cur or HexUtils.hex_distance(cur, hero_cell) <= 1):
						enemy_attack_requested.emit(army, cur)
						report["attacks"] += 1
						attacked = true
						break
					var city := _city_at(cur)
					if city != null and city.owner == &"player":
						_capture_city(city, cur)
						report["captures"] += 1
						break
				if not attacked:
					hero_cell = _hero_pos()
					if hero_cell != Vector2i(-1, -1) and HexUtils.hex_distance(cur, hero_cell) <= 1:
						enemy_attack_requested.emit(army, cur)
						report["attacks"] += 1
						attacked = true
		if attacked:
			break
	enemy_turn_reported.emit(report)
	return report

func _rebuild_hero_dist_field() -> void:
	_hero_dist_field_valid = false
	var hero_cell := _hero_pos()
	if hero_cell == Vector2i(-1, -1) or _map_gen == null:
		return
	var cost_fn: Callable = _pf_cost_fn_global
	_hero_dist_field = HexPathfinding.dijkstra(hero_cell, 9999.0, cost_fn, _map_gen.map_width, _map_gen.map_height)
	_hero_dist_field_valid = true

func _dist_field_from_hero(cell: Vector2i, mp: float, cost_fn: Callable) -> PackedFloat32Array:
	if _hero_dist_field_valid:
		return _hero_dist_field
	return HexPathfinding.dijkstra(cell, mp, cost_fn, _map_gen.map_width, _map_gen.map_height)

func _pf_cost_fn_global(nxt: Vector2i) -> float:
	if _map_gen == null:
		return INF
	if not _map_gen.is_walkable(nxt):
		return INF
	var tid: int = _map_gen.get_terrain_id(nxt)
	return _TerrainCostTable.get_cost_with_effects_by_id(tid, false)

func _garrisoned_set() -> Dictionary:
	var out := {}
	if _world_delta == null:
		return out
	for item in _world_delta.enemy_growth_state.get("garrisoned", []):
		out[Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))] = true
	return out

func _capture_city(city: City, cell: Vector2i) -> void:
	city.owner = &"enemy"
	if _world_delta != null:
		var garrisoned: Variant = _world_delta.enemy_growth_state.get("garrisoned", null)
		if garrisoned == null:
			garrisoned = []
		_world_delta.enemy_growth_state["garrisoned"] = garrisoned
		if not _garrisoned_set().has(cell):
			garrisoned.append({"x": cell.x, "y": cell.y})
	GameLogger.world("Enemy captured %s at %s" % [city.display_name, str(cell)])
	enemy_village_captured.emit(city)

func _city_at(cell: Vector2i) -> City:
	if _cities_mgr == null:
		return null
	return _cities_mgr.city_at(cell)

func _move_stack(stacks: Dictionary, from: Vector2i, to: Vector2i, army: Array) -> void:
	stacks.erase(from)
	stacks[to] = army
	if _spawner != null and _spawner.has_method("move_enemy_visual"):
		_spawner.move_enemy_visual(from, to)

func _hero_pos() -> Vector2i:
	var raw: Variant = _hero.get("current_cell")
	return raw if raw is Vector2i else Vector2i(-1, -1)

func _candidate_goals(cell: Vector2i, hero_cell: Vector2i, aggro: int, profile: Dictionary) -> Dictionary:
	var goals := {}
	var weights: Dictionary = profile.get("weights", {})
	if _cities_mgr != null:
		for c in _cities_mgr.cities:
			if c.owner != &"player":
				continue
			var d := HexUtils.hex_distance(cell, c.center)
			if d <= aggro:
				goals[c.center] = {"weight": float(weights.get("village", 1.0)), "dist": d}
	if _map_gen != null:
		for rc in _map_gen.resource_cells:
			var d := HexUtils.hex_distance(cell, rc)
			if d <= aggro:
				goals[rc] = {"weight": float(weights.get("resource", 0.6)), "dist": d}
	if hero_cell != Vector2i(-1, -1):
		var d := HexUtils.hex_distance(cell, hero_cell)
		if d <= aggro:
			goals[hero_cell] = {"weight": float(weights.get("hero", 0.8)), "dist": d}
	return goals

func _pick_goal(goals: Dictionary) -> Vector2i:
	var best_cell: Vector2i = Vector2i(-1, -1)
	var best_score := -1.0
	for c in goals.keys():
		var info: Dictionary = goals[c]
		var score := float(info["weight"]) / (float(int(info["dist"])) + 1.0)
		if score > best_score + 0.000001:
			best_score = score
			best_cell = c
		elif score > best_score - 0.000001 and score < best_score + 0.000001:
			if c.x < best_cell.x or (c.x == best_cell.x and c.y < best_cell.y):
				best_cell = c
	return best_cell

func _pf_cost_fn(nxt: Vector2i) -> float:
	if _map_gen == null:
		return INF
	if not _map_gen.is_walkable(nxt):
		return INF
	if _pf_stacks.has(nxt) and nxt != _pf_self_cell:
		return INF
	var tid: int = _map_gen.get_terrain_id(nxt)
	return _TerrainCostTable.get_cost_with_effects_by_id(tid, false)

func _enter_cost(nxt: Vector2i) -> float:
	return _enter_cost_blocked(nxt, {}, Vector2i(-1, -1))

func _enter_cost_blocked(nxt: Vector2i, stacks: Dictionary, self_cell: Vector2i) -> float:
	if _map_gen == null:
		return INF
	if not _map_gen.is_walkable(nxt):
		return INF
	if stacks.has(nxt) and nxt != self_cell:
		return INF
	var tid: int = _map_gen.get_terrain_id(nxt)
	return _TerrainCostTable.get_cost_with_effects_by_id(tid, false)

static func _cell_a_before_b(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y
```

---

### Фикс 5: [Medium] WorldPersistence — Очистка старых шардов

**Проблема:** `_shards_memory` растет бесконечно, никогда не очищается. При долгой игре это приводит к утечке памяти.

**Решение:** Очищать шарды, которые не были активны последние N ходов, или ограничить количество хранимых шардов.

```gdscript
// FILE: res://scripts/world/world_persistence.gd
// REPLACE METHOD: save_game

func save_game(hero: HeroController, cities: Array = [], characters: Array = []) -> bool:
	if session == null or hero == null or world_delta == null:
		return false
	var save_data := SaveData.new()
	save_data.run_seed = session.run_seed
	save_data.date = _date.duplicate()
	save_data.hero = hero.serialize()
	if visibility != null:
		world_delta.set_fog_explored(visibility.serialize_explored())
	save_data.world = world_delta.serialize()
	var cities_arr: Array = []
	for c in cities:
		cities_arr.append(c.serialize())
	save_data.cities = cities_arr
	save_data.characters = characters
	save_data.session = session.serialize()
	save_data.chronicle = chronicle.to_array()
	var _mgr := _ShardManager.instance()
	var _active := _mgr.active_id
	save_data.active_shard_id = _active
	var shards_data: Dictionary = _shards_memory.duplicate(true)
	shards_data[_active] = {
		"world": world_delta.serialize(),
		"cities": cities_arr,
		"characters": characters,
		"hero": hero.serialize(),
		"date": _date.duplicate(),
		"run_seed": session.run_seed,
		"last_active_turn": session.current_turn if session != null else 0,
	}
	_prune_old_shards(shards_data, session.current_turn if session != null else 0)
	save_data.shards = shards_data
	_shards_memory = shards_data
	_last_save_dict = save_data.to_dict()
	var err := _save_manager.save_game(save_data)
	if err == SaveManager.SaveError.OK:
		GameLogger.world("Game saved to %s" % SaveManager.SAVE_PATH)
	return err == SaveManager.SaveError.OK

func _prune_old_shards(shards: Dictionary, current_turn: int) -> void:
	const MAX_SHARDS := 10
	const MAX_INACTIVE_TURNS := 50
	if shards.size() <= MAX_SHARDS:
		return
	var to_remove: Array = []
	for shard_id in shards:
		var shard_data: Dictionary = shards[shard_id]
		var last_active: int = int(shard_data.get("last_active_turn", 0))
		if current_turn - last_active > MAX_INACTIVE_TURNS:
			to_remove.append(shard_id)
	for shard_id in to_remove:
		shards.erase(shard_id)
	if shards.size() > MAX_SHARDS:
		var sorted_shards: Array = shards.keys()
		sorted_shards.sort_custom(func(a, b):
			var a_turn: int = int(shards[a].get("last_active_turn", 0))
			var b_turn: int = int(shards[b].get("last_active_turn", 0))
			return a_turn < b_turn
		)
		while shards.size() > MAX_SHARDS:
			var oldest: String = sorted_shards.pop_front()
			shards.erase(oldest)
```

---

### Фикс 6: [Medium] City — Версионирование сериализации

**Проблема:** `City.serialize()` и `City.deserialize()` не имеют версионирования. При изменении структуры данных между версиями игры старые сейвы будут крашить игру.

**Решение:** Добавить поле `version` в сериализованные данные и миграцию при загрузке.

```gdscript
// FILE: res://scripts/world/city.gd
// REPLACE METHODS: serialize and deserialize

const SERIALIZATION_VERSION := 2

func serialize() -> Dictionary:
	var d := {
		"version": SERIALIZATION_VERSION,
		"uid": uid,
		"display_name": display_name,
		"center": {"x": center.x, "y": center.y},
		"reputation": reputation,
		"prosperity": prosperity,
		"level": level,
		"specialization": String(specialization),
		"faction": faction,
		"stronghold_level": stronghold_level,
		"is_capital": is_capital,
		"owner": String(owner),
		"food_stockpile": food_stockpile,
		"starving": starving,
		"scale_tier": scale_tier,
		"auto_resource_mult": auto_resource_mult,
		"upkeep_mult": upkeep_mult,
		"uid_seq": _uid_seq,
	}
	var storage_str: Dictionary = {}
	for k in storage:
		storage_str[String(k)] = float(storage[k])
	d["storage"] = storage_str
	var sites: Array = []
	for cell in special_sites:
		sites.append({"cell": {"x": cell.x, "y": cell.y}, "site": String(special_sites[cell])})
	d["special_sites"] = sites
	var roads_arr: Array = []
	for cell in roads:
		roads_arr.append({"x": cell.x, "y": cell.y})
	d["roads"] = roads_arr
	if resource_ctx != null:
		d["resource_ctx"] = resource_ctx.serialize()
	var pops_arr: Array = []
	for u in pop:
		pops_arr.append(u.serialize())
	d["pop"] = pops_arr
	var bhs_arr: Array = []
	for b in boroughs:
		bhs_arr.append({"cell": {"x": b.cell.x, "y": b.cell.y}, "level": b.level, "uid": b.uid})
	d["boroughs"] = bhs_arr
	var blds_arr: Array = []
	for b in buildings:
		blds_arr.append(b.serialize())
	d["buildings"] = blds_arr
	return d

func deserialize(data: Dictionary) -> void:
	var version: int = int(data.get("version", 1))
	if version < SERIALIZATION_VERSION:
		data = _migrate_city_data(data, version)
	var c: Dictionary = data.get("center", {})
	center = Vector2i(int(c.get("x", -1)), int(c.get("y", -1)))
	reputation = int(data.get("reputation", 0))
	prosperity = clampf(float(data.get("prosperity", 50.0)), 0.0, 100.0)
	level = clampi(int(data.get("level", 1)), 1, ProsperitySystem.CITY_LEVEL_MAX)
	specialization = StringName(data.get("specialization", ""))
	faction = int(data.get("faction", Faction.DEFAULT))
	stronghold_level = int(data.get("stronghold_level", 1))
	is_capital = bool(data.get("is_capital", false))
	display_name = String(data.get("display_name", display_name))
	owner = StringName(data.get("owner", "none"))
	food_stockpile = float(data.get("food_stockpile", 0.0))
	starving = bool(data.get("starving", false))
	scale_tier = int(data.get("scale_tier", 0))
	auto_resource_mult = float(data.get("auto_resource_mult", 1.0))
	upkeep_mult = float(data.get("upkeep_mult", 1.0))
	storage.clear()
	var raw_storage: Dictionary = data.get("storage", {})
	for k in raw_storage:
		storage[StringName(k)] = float(raw_storage[k])
	special_sites.clear()
	for s in data.get("special_sites", []):
		var sc: Dictionary = s.cell
		special_sites[Vector2i(int(sc.get("x", 0)), int(sc.get("y", 0)))] \
			= StringName(s.site)
	roads.clear()
	for rc in data.get("roads", []):
		roads[Vector2i(int(rc.get("x", 0)), int(rc.get("y", 0)))] = true
	if data.has("resource_ctx"):
		ensure_resource_ctx()
		resource_ctx.deserialize(data["resource_ctx"])
	pop.clear()
	for pd in data.get("pop", []):
		pop.append(PopUnit.deserialize(pd))
	boroughs.clear()
	for bd in data.get("boroughs", []):
		var bcell: Dictionary = bd.cell
		var bh := Borough.new()
		bh.cell = Vector2i(int(bcell.get("x", 0)), int(bcell.get("y", 0)))
		bh.level = int(bd.get("level", 1))
		bh.uid = int(bd.get("uid", 0))
		boroughs.append(bh)
	buildings.clear()
	for bl in data.get("buildings", []):
		var def := BuildingDefs.def_by_id(StringName(bl.get("def_id", "")))
		if def == null:
			GameLogger.warn("City.deserialize: неизвестное здание '%s' — пропущено" % bl.get("def_id", ""))
			continue
		buildings.append(UniqueBuilding.deserialize(bl, def))
	_ArenaClusterSystem.invalidate(uid)
	var max_uid := int(data.get("uid_seq", 0))
	for u in pop:
		max_uid = maxi(max_uid, u.uid + 1)
	for b in boroughs:
		max_uid = maxi(max_uid, b.uid + 1)
	for b in buildings:
		max_uid = maxi(max_uid, b.uid + 1)
	_uid_seq = max_uid
	_invalidate_exploited()

func _migrate_city_data(data: Dictionary, from_version: int) -> Dictionary:
	var migrated := data.duplicate(true)
	if from_version < 2:
		if not migrated.has("scale_tier"):
			migrated["scale_tier"] = 0
		if not migrated.has("auto_resource_mult"):
			migrated["auto_resource_mult"] = 1.0
		if not migrated.has("upkeep_mult"):
			migrated["upkeep_mult"] = 1.0
	return migrated
```

---

## Инструкция по установке и внедрению (Runbook)

### Шаг 1: Создание/Перезапись файлов

```bash
# Резервное копирование оригинальных файлов
cp res://scripts/world/hero_lifecycle_system.gd res://scripts/world/hero_lifecycle_system.gd.bak
cp res://scripts/world/world_event_router.gd res://scripts/world/world_event_router.gd.bak
cp res://scripts/systems/battle_state.gd res://scripts/systems/battle_state.gd.bak
cp res://scripts/systems/enemy_turn_processor.gd res://scripts/systems/enemy_turn_processor.gd.bak
cp res://scripts/world/world_persistence.gd res://scripts/world/world_persistence.gd.bak
cp res://scripts/world/city.gd res://scripts/world/city.gd.bak

# Применение фиксов (замена содержимого файлов)
# Используйте редактор или IDE для замены кода согласно указаниям выше
```

### Шаг 2: Интеграционные изменения

**Изменения в `WorldEventRouter.gd`:**
- Добавить метод `_disconnect_hero_signals(old_hero: Node = null)` (см. Фикс 2).
- Убедиться, что `_connect_hero_signals` проверяет `is_connected` перед подключением.

**Изменения в `HeroLifecycleSystem.gd`:**
- Добавить вызовы `_disconnect_hero_signals(deceased)` перед `_detach_hero` и `_remove_hero`.
- Добавить вызов `_connect_hero_signals(successor)` после `_install_hero(successor)` в `_on_resurrection_chosen` и `_reincarnate`.

**Изменения в `BattleState.gd`:**
- Добавить `invalidate_board_cache()` в методы `do_defend`, `do_wait`, `do_skip`.

**Изменения в `WorldPersistence.gd`:**
- Добавить метод `_prune_old_shards` и вызывать его в `save_game`.

**Изменения в `City.gd`:**
- Добавить константу `SERIALIZATION_VERSION := 2`.
- Добавить поле `"version"` в `serialize()`.
- Добавить метод `_migrate_city_data` для обработки старых версий.

### Шаг 3: Команды для проверки

```bash
# Запуск headless-тестов (если есть тестовый фреймворк)
godot --headless --script res://tests/run_tests.gd

# Запуск игры с логированием
godot --verbose 2>&1 | tee game.log

# Проверка утечек памяти (запустить игру, сделать 5+ succession, проверить рост памяти)
# В редакторе Godot: Debugger → Profiler → Memory
```

### Шаг 4: Критерии приёмки

1. **Succession без утечек:**
   - Запустить игру, довести героя до смерти, выбрать преемника.
   - Повторить 5+ раз.
   - Проверить, что в логах нет ошибок `Invalid call. Nonexistent function 'disconnect'` или `Signal already connected`.
   - Проверить, что память не растет линейно (Debugger → Profiler).

2. **Корректный pathfinding в бою:**
   - Начать бой с 10+ юнитами с каждой стороны.
   - Перемещать юнитов, проверять, что подсветка доступных клеток обновляется корректно.
   - Убедиться, что юниты не могут ходить через клетки, занятые другими юнитами (даже союзниками).

3. **Оптимизация EnemyTurnProcessor:**
   - Запустить игру с 20+ вражескими стеками на карте.
   - Завершить ход, проверить, что ход врагов занимает < 500ms (в логах `EnemyTurnProcessor`).
   - Убедиться, что враги всё ещё корректно движутся к герою и городам.

4. **Сериализация городов:**
   - Сохранить игру, изменить структуру `City.gd` (добавить новое поле), загрузить старый сейв.
   - Убедиться, что игра не крашится, а старые данные мигрируются корректно.

5. **Очистка шардов:**
   - Создать 15+ шардов (через `_ShardManager`), сохранить игру.
   - Проверить, что в `_shards_memory` осталось не более 10 шардов.
   - Убедиться, что активный шард не был удален.

---

## Итоговая таблица

| № | Файл (путь) | Суть изменения | Приоритет |
|---|---|---|---|
| 1 | `res://scripts/world/hero_lifecycle_system.gd` | Явное отключение сигналов старого героя при succession, предотвращение утечек памяти и дублирования вызовов | High |
| 2 | `res://scripts/world/world_event_router.gd` | Добавление метода `_disconnect_hero_signals` для парного отключения сигналов | High |
| 3 | `res://scripts/systems/battle_state.gd` | Инвалидация кэша pathfinding при `do_defend`, `do_wait`, `do_skip`, предотвращение stale данных | High |
| 4 | `res://scripts/systems/enemy_turn_processor.gd` | Оптимизация Dijkstra: вычисление одного поля расстояний от героя вместо N отдельных вычислений (O(N²) → O(N)) | High |
| 5 | `res://scripts/world/world_persistence.gd` | Очистка старых неактивных шардов из `_shards_memory`, предотвращение утечки памяти при долгой игре | Medium |
| 6 | `res://scripts/world/city.gd` | Версионирование сериализации, миграция старых сейвов при изменении структуры данных | Medium |


Для того чтобы полностью избавиться от программного создания элементов интерфейса (кнопок, лейблов, спрайтов и т.д.) через `.new()` в скриптах, мы вынесем их структуру в отдельные `.tscn` сцены. В скриптах останется только инстанцирование готовых сцен и получение ссылок на дочерние узлы через `get_node()` или `$`.

Ниже приведены новые файлы сцен и обновленные скрипты.

### 1. Новые файлы сцен (Создайте их в указанных путях)

**`res://scenes/entities/village_entity.tscn`**
```tscn
[gd_scene format=3]
[node name="VillageEntity" type="Node2D"]
[node name="Sprite" type="Sprite2D" parent="."]
z_index = 5
[node name="Flag" type="Label" parent="."]
offset_left = 18.0
offset_top = -20.0
offset_right = 50.0
offset_bottom = 0.0
theme_override_font_sizes/font_size = 16
text = "🚩"
```

**`res://scenes/entities/resource_entity.tscn`**
```tscn
[gd_scene format=3]
[node name="ResourceEntity" type="Node2D"]
[node name="Icon" type="Label" parent="."]
offset_left = -12.0
offset_top = -12.0
offset_right = 12.0
offset_bottom = 12.0
theme_override_font_sizes/font_size = 24
text = "?"
z_index = 6
```

**`res://scenes/entities/enemy_entity.tscn`**
```tscn
[gd_scene format=3]
[node name="EnemyEntity" type="Node2D"]
[node name="Sprite" type="Sprite2D" parent="."]
z_index = 6
```

**`res://scenes/entities/chest_entity.tscn`**
```tscn
[gd_scene format=3]
[node name="ChestEntity" type="Node2D"]
z_index = 7
[node name="Sprite" type="Sprite2D" parent="."]
```

**`res://scenes/entities/scroll_entity.tscn`**
```tscn
[gd_scene format=3]
[node name="ScrollEntity" type="Node2D"]
z_index = 6
[node name="Sprite" type="Sprite2D" parent="."]
```

**`res://scenes/entities/resource_node.tscn`**
```tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/entities/resource_node.gd" id="1"]
[node name="ResourceNode" type="Node2D"]
script = ExtResource("1")
[node name="Sprite" type="Sprite2D" parent="."]
[node name="Outline" type="Sprite2D" parent="."]
z_index = 1
```

**`res://scenes/entities/dest_marker.gd`** (Выносим внутренний класс в отдельный скрипт)
```gdscript
extends Node2D
class_name DestMarker

const _HexDraw = preload("res://scripts/core/hex_draw.gd")

var active := false
var _t := 0.0

func _process(d: float) -> void:
	if active:
		_t += d
		queue_redraw()

func show_at(pos: Vector2) -> void:
	position = pos
	active = true
	queue_redraw()

func hide_marker() -> void:
	active = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var r := 36.0 + sin(_t * 6.0) * 4.0
	var pts := _HexDraw.points(r)
	draw_polyline(pts, Color(1.0, 0.25, 0.2, 0.95), 3.0)
```

**`res://scenes/entities/dest_marker.tscn`**
```tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/entities/DestMarker.gd" id="1"]
[node name="DestMarker" type="Node2D"]
script = ExtResource("1")
```

**`res://scenes/entities/status_orb.gd`** (Выносим внутренний класс в отдельный скрипт)
```gdscript
extends Node2D
class_name StatusOrb

var _ratio: float = 1.0
var _t := 0.0

func _ready() -> void:
	position = Vector2(0, -40)
	z_index = 11

func _process(d: float) -> void:
	_t += d
	queue_redraw()

func set_ratio(r: float) -> void:
	_ratio = clampf(r, 0.0, 1.0)

func _draw() -> void:
	var color: Color
	if _ratio >= 0.4:
		color = Color(0.2, 0.85, 0.2, 0.9)
	elif _ratio >= 0.1:
		color = Color(1.0, 0.85, 0.1, 0.9)
	else:
		color = Color(0.9, 0.2, 0.2, 0.9)
	var r := 6.0 + sin(_t * 3.0) * 1.5
	draw_circle(Vector2.ZERO, r, color)
```

**`res://scenes/entities/status_orb.tscn`**
```tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/entities/StatusOrb.gd" id="1"]
[node name="StatusOrb" type="Node2D"]
script = ExtResource("1")
```

**`res://scenes/entities/hero_visuals.tscn`**
```tscn
[gd_scene format=3]
[node name="HeroVisuals" type="Node2D"]
[node name="Fallback" type="Sprite2D" parent="."]
z_index = 10
[node name="Anim" type="AnimatedSprite2D" parent="."]
z_index = 10
```

**`res://scenes/world/map_generator.tscn`**
```tscn
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/world/map_generator.gd" id="1"]
[node name="MapGenerator" type="Node2D"]
script = ExtResource("1")
[node name="TileMapTerrain" type="TileMapLayer" parent="."]
[node name="TileMapDecor" type="TileMapLayer" parent="."]
[node name="ResourceLayer" type="Node2D" parent="."]
```

---

### 2. Обновление существующих сцен и скриптов

#### `res://scenes/ui/battle_ui.tscn`
Замените `VBoxContainer` для списка инициативы на `ItemList`, чтобы не создавать `Label` динамически:
```tscn
[node name="initiative_panel" type="PanelContainer" parent="."]
anchor_left = 1.0
anchor_right = 1.0
anchor_top = 0.0
anchor_bottom = 1.0
offset_left = -190.0
offset_top = 100.0
offset_bottom = -80.0
[node name="initiative_list" type="ItemList" parent="initiative_panel"]
theme_override_constants/v_separation = 4
```

#### `res://scripts/ui/battle_ui.gd`
Обновите тип переменной и метод `update_initiative`:
```gdscript
# ...
@onready var _initiative_list: ItemList = $initiative_panel/initiative_list
# ...

func update_initiative(units: Array[BattleState.BattleUnit], active_unit: BattleState.BattleUnit) -> void:
	_initiative_list.clear()
	for unit in units:
		if unit == null:
			continue
		var text = "%s x%d" % [
			unit.get_display_name().left(8),
			unit.get_count()
		]
		var idx = _initiative_list.add_item(text)
		if unit == active_unit:
			_initiative_list.set_item_custom_fg_color(idx, Color.GOLD)
		elif unit.side == BattleState.Side.ATTACKER:
			_initiative_list.set_item_custom_fg_color(idx, Color(0.7, 0.85, 1.0))
		else:
			_initiative_list.set_item_custom_fg_color(idx, Color(1.0, 0.75, 0.7))
```

#### `res://scripts/world/world_spawner.gd`
Добавьте константы сцен и замените методы спавна:
```gdscript
# Добавьте в начало скрипта:
const VillageEntityScene = preload("res://scenes/entities/village_entity.tscn")
const ResourceEntityScene = preload("res://scenes/entities/resource_entity.tscn")
const EnemyEntityScene = preload("res://scenes/entities/enemy_entity.tscn")
const ChestEntityScene = preload("res://scenes/entities/chest_entity.tscn")
const ScrollEntityScene = preload("res://scenes/entities/scroll_entity.tscn")

# ...

func _spawn_villages() -> void:
	for cell in map.village_cells:
		var v = VillageEntityScene.instantiate()
		v.set_meta("cell", cell)
		var sp = v.get_node("Sprite")
		sp.texture = _cached_texture("village", func() -> ImageTexture:
			var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
			for y in 20:
				var half_w := int((24 - y) * 0.8)
				if half_w > 0:
					img.fill_rect(Rect2i(24 - half_w, y, half_w * 2, 1), Color(0.7, 0.2, 0.1))
			img.fill_rect(Rect2i(10, 20, 29, 22), Color(0.6, 0.5, 0.3))
			return ImageTexture.create_from_image(img))
		v.position = map.map_to_local(cell)
		add_child(v)
		_village_nodes[cell] = v

func _spawn_resources() -> void:
	var icons := ["🪵", "🧪", "🪨", "🟡", "🔷", "💎", "🪙"]
	for cell in map.resource_cells:
		var res_type: int = map.resource_cells[cell]
		var r = ResourceEntityScene.instantiate()
		r.set_meta("cell", cell)
		r.set_meta("res_type", res_type)
		var lbl = r.get_node("Icon")
		lbl.text = icons[res_type] if res_type < icons.size() else "?"
		r.position = map.map_to_local(cell)
		add_child(r)
		_resource_nodes[cell] = r

func _make_enemy_node(cell: Vector2i, army: Array) -> Node2D:
	if army.is_empty():
		return null
	var e = EnemyEntityScene.instantiate()
	e.set_meta("enemy_cell", cell)
	var sp = e.get_node("Sprite")
	var first_unit = army[0]
	var key: String = first_unit.get_key()
	var portrait_path := UnitSprites.find_portrait_small(key)
	if portrait_path != "":
		sp.texture = load(portrait_path)
	else:
		sp.texture = PlaceholderTexture.circle(20, Color(0.7, 0.15, 0.1), Color(0.2, 0.05, 0.05))
	e.position = map.map_to_local(cell)
	return e

func _spawn_chests() -> void:
	var chest_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		chest_rng.seed = MapConfig.EDITOR_SEED
	var placed := 0
	var attempts := 0
	while placed < MapConfig.CHEST_COUNT and attempts < MapConfig.CHEST_PLACE_ATTEMPTS:
		attempts += 1
		var cell := Vector2i(chest_rng.randi_range(MapConfig.SPAWN_CHEST_MIN_BORDER, map.map_width - 4), chest_rng.randi_range(MapConfig.SPAWN_CHEST_MIN_BORDER, map.map_height - 4))
		if not map.is_walkable(cell): continue
		if map.enemy_stacks.has(cell) or map.resource_cells.has(cell) or cell in map.village_cells: continue
		if _chests.has(cell): continue
		var nearby_enemy := false
		for nb in HexUtils.get_all_neighbors(cell):
			if map.enemy_stacks.has(nb):
				nearby_enemy = true
				break
		if nearby_enemy: continue
		var art_reg: Node = ServiceLocator.resolve(null, &"artifacts")
		var artifact: Artifact = art_reg.random_of_rarity(Artifact.Rarity.MINOR, chest_rng)
		if artifact == null: continue
		var chest := ArtifactChest.new()
		chest.id = "chest_%s" % cell
		chest.artifact = artifact
		chest.cell = cell
		chest.gold_reward = chest_rng.randi_range(MapConfig.CHEST_GOLD_MIN, MapConfig.CHEST_GOLD_MAX)
		_chests[cell] = chest
		
		var n = ChestEntityScene.instantiate()
		n.position = map.map_to_local(cell)
		var sp = n.get_node("Sprite")
		sp.texture = _cached_texture("chest", func() -> ImageTexture:
			var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(0, 0, 32, 4), Color(0.8, 0.6, 0.2))
			img.fill_rect(Rect2i(0, 4, 32, 15), Color(0.6, 0.4, 0.1))
			img.fill_rect(Rect2i(0, 19, 32, 5), Color(0.4, 0.25, 0.08))
			return ImageTexture.create_from_image(img))
		add_child(n)
		_chest_nodes[cell] = n
		placed += 1

func _spawn_scrolls() -> void:
	var scroll_count: int = max(2, map.map_width / 3)
	var placed: int = 0
	var attempts: int = 0
	var chest_rng := rng if rng != null else RandomNumberGenerator.new()
	while placed < scroll_count and attempts < MapConfig.SPAWN_SCROLL_MAX_ATTEMPTS:
		attempts += 1
		var cell := Vector2i(chest_rng.randi_range(MapConfig.SPAWN_CHEST_MIN_BORDER, map.map_width - 4), chest_rng.randi_range(MapConfig.SPAWN_CHEST_MIN_BORDER, map.map_height - 4))
		if not map.is_walkable(cell): continue
		if map.enemy_stacks.has(cell) or map.resource_cells.has(cell) or cell in map.village_cells: continue
		if _chests.has(cell): continue
		if _scrolls.has(cell): continue
		var spell_reg: Node = ServiceLocator.resolve(null, &"spells")
		var all_spells: Array = spell_reg.get_all_spells()
		if all_spells.is_empty(): continue
		var spell = all_spells[chest_rng.randi() % all_spells.size()]
		_scrolls[cell] = spell.id
		
		var n = ScrollEntityScene.instantiate()
		n.position = map.map_to_local(cell)
		var sp = n.get_node("Sprite")
		sp.texture = _cached_texture("scroll", func() -> ImageTexture:
			var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(0, 0, 24, 32), Color(0.3, 0.15, 0.5))
			img.fill_rect(Rect2i(0, 0, 4, 32), Color(0.5, 0.3, 0.7))
			img.fill_rect(Rect2i(20, 0, 4, 32), Color(0.5, 0.3, 0.7))
			return ImageTexture.create_from_image(img))
		add_child(n)
		_scroll_nodes[cell] = n
		placed += 1

func capture_village(cell: Vector2i) -> bool:
	if not _village_nodes.has(cell):
		return false
	var node: Node2D = _village_nodes[cell]
	var flag := node.get_node_or_null("Flag")
	if flag != null:
		flag.text = "🏳️"
		return true
	return false
```

#### `res://scripts/entities/resource_node.gd`
Замените создание спрайтов на получение из сцены:
```gdscript
func _setup_visual() -> void:
	sprite = $Sprite
	outline = $Outline
	_update_visual()
```

#### `res://scripts/entities/hero_visual_controller.gd`
Удалите внутренние классы `DestMarker` и `StatusOrb` (они вынесены в отдельные файлы). Обновите логику:
```gdscript
const HeroVisualsScene = preload("res://scenes/entities/hero_visuals.tscn")
const DestMarkerScene = preload("res://scenes/entities/dest_marker.tscn")
const StatusOrbScene = preload("res://scenes/entities/status_orb.tscn")

var _visuals: Node2D = null

func build_visual() -> void:
	if _visuals != null:
		return
	_visuals = HeroVisualsScene.instantiate()
	_parent.add_child(_visuals)
	
	_fallback = _visuals.get_node("Fallback")
	_anim = _visuals.get_node("Anim")
	
	var sheet_path := _find_sheet()
	if sheet_path != "":
		var sheet_res := load(sheet_path)
		if sheet_res is ImageTexture:
			_build_anim_from_sheet((sheet_res as ImageTexture).get_image())
			
	if _anim.sprite_frames == null or _anim.sprite_frames.get_animation_names().is_empty():
		_fallback.texture = PlaceholderTexture.circle(20, Color(0.9, 0.7, 0.1), Color(0.3, 0.2, 0.0))
		_fallback.visible = true
		_anim.visible = false
	else:
		_fallback.visible = false
		_anim.visible = true

func setup_path_visual() -> void:
	if _marker == null:
		_marker = DestMarkerScene.instantiate()
		_parent.get_parent().add_child(_marker)
	if _status_orb == null:
		_status_orb = StatusOrbScene.instantiate()
		_status_orb.name = "StatusOrb"
		_parent.add_child(_status_orb)
```

#### `res://scripts/world/map_generator.gd`
Упростите `_ensure_layers`, так как узлы уже есть в сцене:
```gdscript
func _ensure_layers() -> void:
	_tile_map = $TileMapTerrain
	_decor_layer = $TileMapDecor
	_resource_layer = $ResourceLayer
	
	var tileset := TileAtlas.build_hex_tileset()
	if tileset == null:
		push_error("TileAtlas: не удалось построить hex-тайлсет (нет %s)" % TileAtlas.SHEET_PATH)
	else:
		_tile_map.tile_set = tileset
		_decor_layer.tile_set = tileset
```

#### `res://scripts/world/world_bootstrap.gd`
Замените создание `MapGenerator` через `.new()` на инстанцирование сцены:
```gdscript
static func _create_map(parent: Node2D, R: BootstrapResult) -> void:
	var map_scene = load("res://scenes/world/map_generator.tscn")
	R.map_gen = map_scene.instantiate()
	R.map_gen.name = "MapGenerator"
	R.map_gen.seed_value = R.rng.randi() % 999999
	R.map_gen.setup_services(R.services)
	parent.add_child(R.map_gen)
```

Проработка архитектуры тестирования, миграция на **gdUnit4** и переход на стандартизированный **`tugcantopaloglu/godot-mcp`** — это отличный шаг к зрелости проекта. Текущие самописные TCP-серверы (`SocketController`, `mcp_interaction_server`) и CLI-скрипты (`godot_operations`) создают избыточную нагрузку и дублируют функционал, который уже решен сообществом.

Ниже представлен комплексный план рефакторинга, структуры тестов и стратегии покрытия.

---

### 1. Очистка проекта: Удаление самописного MCP и GUT

#### 🗑️ Что нужно удалить (Следы кастомных решений)
1. **Удалить файлы кастомного MCP и сокет-серверов:**
   - `scripts/autoload/SocketController.gd`
   - `scripts/autoload/mcp_interaction_server.gd`
   - `scripts/autoload/mcp_command_module.gd`
   - `scripts/autoload/mcp_modules/` (вся папка)
   - `scripts/autoload/godot_operations.gd` (CLI-костыли для headless-режима)
2. **Удалить следы GUT (если они остались):**
   - Папку `addons/gut/`.
   - Упоминания `extends "res://addons/gut/test.gd"` в старых тестах.
   - Автозагрузку `Gut` в `Project Settings -> Autoload`.
3. **Очистить `Project.godot`:** Убрать все кастомные аргументы командной строки (`--test-server`, `--socket-server`, `--debug-godot`), которые использовались для запуска самописных серверов.

#### ⚙️ Интеграция `tugcantopaloglu/godot-mcp`
1. Установите плагин через AssetLib или git-сабмодуль в `res://addons/godot-mcp/`.
2. Включите его в `Project Settings -> Plugins`.
3. **Как это меняет тестирование:** Вместо написания TCP-клиента на Python для отправки JSON-команд (`{"action": "MOVE_TO", "x": 10, "y": 5}`), ваш внешний тестовый клиент (или AI-агент) подключается к MCP-серверу и использует встроенные инструменты плагина:
   - `execute_script` / `eval` для выполнения GDScript.
   - `get_node_property` / `call_method` для прямого взаимодействия с автозагрузками.
   - `change_scene` для навигации.

---

### 2. Структура тестов (gdUnit4)

gdUnit4 требует четкого разделения на Unit, Integration и E2E тесты. Тесты должны лежать в папке `res://test/` (или рядом с исходниками, но с префиксом `Test`, однако вынос в `test/` чище).

```text
res://
├── scripts/               # Исходный код игры
├── test/
│   ├── unit/              # Изолированные тесты (без сцены или с моками)
│   │   ├── entities/      # TestHeroInventory.gd, TestUnitStack.gd
│   │   ├── systems/       # TestBattleDamageResolver.gd, TestCity.gd
│   │   └── world/         # TestMapModel.gd, TestHexPathfinding.gd
│   ├── integration/       # Тесты связок систем (с загрузкой сцен)
│   │   ├── TestWorldBootstrap.gd
│   │   └── TestBattleFlow.gd
│   └── e2e/               # Сценарии, запускаемые через MCP-клиент
│       └── mcp_scenarios/ # Python/TS скрипты для MCP
└── project.godot
```

---

### 3. Стратегия покрытия кода (Coverage)

| Уровень | Что тестируем | Инструменты gdUnit4 | Примеры классов |
| :--- | :--- | :--- | :--- |
| **Unit (70%)** | Чистая логика, математика, стейт-машины, баланс. Без `Node` дерева. | `GdUnitTestSuite`, `assert_that()`, `mock()` | `City`, `BattleState`, `SpellCaster`, `HeroInventory`, `HexUtils` |
| **Integration (20%)** | Взаимодействие систем, загрузка сцен, работа Автозагрузок. | `add_child_autoload()`, `await_signal()`, `scene_tree()` | `WorldBootstrap`, `BattleFlow`, `TurnScheduler`, `CityManager` |
| **E2E / MCP (10%)** | Полные пользовательские сценарии, UI, сохранение/загрузка. | Внешний MCP-клиент (Python `pytest` + `mcp`) | Прохождение боя, постройка города, смерть героя |

---

### 4. Миграция синтаксиса: GUT ➔ gdUnit4

| GUT (Старое) | gdUnit4 (Новое) |
| :--- | :--- |
| `extends "res://addons/gut/test.gd"` | `extends GdUnitTestSuite` |
| `assert_eq(a, b)` | `assert_that(a).is_equal(b)` |
| `assert_true(x)` | `assert_bool(x).is_true()` |
| `assert_false(x)` | `assert_bool(x).is_false()` |
| `assert_null(x)` | `assert_that(x).is_null()` |
| `yield(yield_to(sig, 2.0))` | `await await_signal(sig, 2.0)` |
| `stub(MyClass, "method").to_return(x)` | `do_return(x).on(mock(MyClass)).method()` |

---

### 5. Примеры архитектуры тестов (Код)

#### А. Unit-тест: Логика Города (`City.gd`)
Класс `City` — это `RefCounted`, он идеален для быстрых Unit-тестов без инициализации движка.

```gdscript
# res://test/unit/world/TestCity.gd
extends GdUnitTestSuite

var city: City

func before() -> void:
    city = City.new()
    city.center = Vector2i(10, 10)
    city.display_name = "Testopolis"
    city.owner = &"player"
    city.ensure_resource_ctx([])

func test_city_initial_state() -> void:
    assert_int(city.pop_total()).is_equal(0)
    assert_bool(city.starving).is_false()

func test_city_food_consumption_workers() -> void:
    city.add_migrant(PopUnit.State.WORKER, 1)
    city.add_migrant(PopUnit.State.WORKER, 1)
    
    var expected := 2.0 * CityBalance.FOOD_PER_WORKER
    assert_float(city.food_consumption()).is_equal(expected)

func test_city_overpopulation_limit() -> void:
    # Мокаем лимит жилья
    city.stronghold_level = 1 
    for i in range(15):
        city.add_migrant(PopUnit.State.WORKER, 1)
        
    assert_int(city.over_limit()).is_greater(0)
```

#### Б. Unit-тест: Боевая система (`BattleDamageResolver.gd`)
Тестируем чистую математику урона и статус-эффекты.

```gdscript
# res://test/unit/systems/TestBattleDamageResolver.gd
extends GdUnitTestSuite

func test_vampiric_healing_on_kill() -> void:
    var atk_stats := UnitStats.new("vampire", "Vampire", 10, 5, 20, 5, 5, ["vampiric"])
    var atk_stack := UnitStack.new(atk_stats, 10)
    atk_stack.count = 5 # Потерял 5 юнитов
    
    var def_stats := UnitStats.new("peasant", "Peasant", 1, 1, 5, 3, 1, [])
    var def_stack := UnitStack.new(def_stats, 10)
    
    var atk_unit := BattleState.BattleUnit.new(atk_stack)
    var def_unit := BattleState.BattleUnit.new(def_stack)
    
    # Эмулируем результат боя, где вампир убил 2 крестьян
    var result := {"kills": 2, "damage": 10}
    
    BattleDamageResolver._apply_vampiric(atk_unit, result)
    
    assert_int(atk_unit.get_count()).is_equal(7) # 5 + 2
    assert_int(result.get("vampiric", 0)).is_equal(2)
```

#### В. Integration-тест: Загрузка Автозагрузок и Bootstrap
Для тестов, требующих `ServiceLocator` или Автозагрузки, используем `add_child_autoload`.

```gdscript
# res://test/integration/TestWorldBootstrap.gd
extends GdUnitTestSuite

func before() -> void:
    # Регистрируем необходимые автозагрузки для тестов
    add_child_autoload("res://scripts/autoload/settings.gd", "Settings")
    add_child_autoload("res://scripts/autoload/unit_registry.gd", "Units")
    add_child_autoload("res://scripts/autoload/resource_registry.gd", "Resources")

func test_world_bootstrap_creates_hero_and_map() -> void:
    var dummy_parent := Node2D.new()
    add_child(dummy_parent)
    
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    
    # Запуск бутстрапа
    var result := WorldBootstrap.run(dummy_parent, null, rng, 0)
    
    assert_that(result.hero).is_not_null()
    assert_that(result.map_gen).is_not_null()
    assert_that(result.cities).is_not_null()
    assert_int(result.cities.cities.size()).is_greater(0)
    
    # Очистка
    dummy_parent.queue_free()
```

---

### 6. Рефакторинг под `tugcantopaloglu/godot-mcp`

Вместо того чтобы плодить кастомные JSON-роутеры (как был `SocketController`), мы создаем **один фасад-мост** (`McpTestBridge`), который MCP-клиент будет опрашивать через стандартный инструмент `call_method` или `eval`.

#### Шаг 1: Создание фасада для MCP
Создайте `res://scripts/testing/McpTestBridge.gd` и добавьте его в Autoload (только для dev-сборок или через `OS.has_feature("editor")`).

```gdscript
# res://scripts/testing/McpTestBridge.gd
extends Node
class_name McpTestBridge

# MCP Клиент вызовет это через: call_method("/root/McpTestBridge", "get_state")
func get_state() -> Dictionary:
    var wc = get_node_or_null("/root/World")
    if wc and wc.has_method("get_state"):
        # Используем ваш WorldStateSerializer
        var serializer = load("res://scripts/autoload/world_state_serializer.gd").new()
        return serializer.get_state(wc, null)
    return {"error": "World not loaded"}

# MCP Клиент вызовет это через: call_method("/root/McpTestBridge", "move_hero", [10, 15])
func move_hero(x: int, y: int) -> Dictionary:
    var wc = get_node_or_null("/root/World")
    if wc and wc.has_method("get_hero"):
        var hero = wc.get_hero()
        if hero and hero.has_method("move_to_cell"):
            var success = hero.move_to_cell(Vector2i(x, y))
            return {"success": success, "cell": {"x": x, "y": y}}
    return {"error": "Cannot move"}

func end_turn() -> void:
    var wc = get_node_or_null("/root/World")
    if wc: wc.do_end_turn()
```

#### Шаг 2: Использование в E2E тестах (Python + MCP Client)
Теперь ваш внешний тестовый скрипт (например, на Python с использованием `mcp` SDK) выглядит так:

```python
# e2e/test_gameplay_loop.py
import asyncio
from mcp import ClientSession

async def test_hero_movement_and_turn():
    async with ClientSession(...) as session:
        # 1. Двигаем героя
        move_result = await session.call_tool(
            "godot_call_method", 
            arguments={
                "node_path": "/root/McpTestBridge", 
                "method": "move_hero", 
                "args": [12, 14]
            }
        )
        assert move_result["success"] == True

        # 2. Завершаем ход
        await session.call_tool(
            "godot_call_method", 
            arguments={"node_path": "/root/McpTestBridge", "method": "end_turn"}
        )

        # 3. Проверяем состояние
        state = await session.call_tool(
            "godot_call_method", 
            arguments={"node_path": "/root/McpTestBridge", "method": "get_state"}
        )
        assert state["mode"] == "world"
        assert state["hero_pos"]["x"] == 12
```


