class_name AdventurerRole
extends ScenarioRole
## autopilot-scenario-matrix: Приключенец — логово второго кольца.
## Политика: охота на отряды 2-го кольца (12..24 от старта), без сбора
## ресурсов; базовый цикл сам защищает город и следит за потребностями.

var _kills := 0
var _tracked_unit: Variant = null
var _tracked_cell := Vector2i(-1, -1)
var _failed_units: Array = []
const HP_PER_PERSONAL_DAMAGE := 170

func _in_ring(cell: Vector2i, pilot: Node) -> bool:
	# Старт = центр города (точка появления героя).
	var start: Vector2i = pilot._city_center()
	if start == Vector2i(-1000, -1000):
		return false
	var d: int = HexUtils.hex_distance(cell, start)
	return d >= MapSpawner.THREAT_RING2_RADIUS and d < MapSpawner.THREAT_RING3_RADIUS

func collect_target(_pilot: Node):
	return Vector2i(-1, -1)  # сбор не нужен — только охота

func enemy_target(pilot: Node):
	if pilot._hero == null or not is_instance_valid(pilot._hero):
		return null
	var map = pilot._map()
	var tracked_cell := Vector2i(-1, -1)
	if _tracked_unit != null:
		for cell in map.enemy_stacks:
			if map.enemy_stacks[cell].has(_tracked_unit):
				tracked_cell = cell
				break
	var personal: UnitStack = pilot._hero.get_hero_battle_stack()
	if personal == null or personal.stats == null:
		return Vector2i(-1, -1)
	var hp_budget := HP_PER_PERSONAL_DAMAGE * maxi(1, personal.stats.base_damage)
	if tracked_cell != Vector2i(-1, -1) and not _in_ring(tracked_cell, pilot):
		var tracked_army: Array = map.enemy_stacks[tracked_cell]
		if not _contains_failed_unit(tracked_army):
			var tracked_hp := 0
			for unit in tracked_army:
				if unit is UnitStack and unit.stats != null:
					tracked_hp += unit.count * unit.stats.hp
			if tracked_hp <= hp_budget:
				_tracked_cell = tracked_cell
				return tracked_cell
	var here: Vector2i = pilot._hero_cell()
	var best := Vector2i(-1, -1)
	var best_route_cost := INF
	var best_hp := INF
	var best_army: Array = []
	for cell in map.enemy_stacks:
		if not _in_ring(cell, pilot):
			continue
		var army_raw: Variant = map.enemy_stacks[cell]
		var army: Array = army_raw if army_raw is Array else []
		if _contains_failed_unit(army):
			continue
		var stack_hp := 0
		for unit in army:
			if unit is UnitStack and unit.stats != null:
				stack_hp += unit.count * unit.stats.hp
		if stack_hp > hp_budget:
			continue
		var d := HexUtils.hex_distance(cell, here, map.hex_shift_right)
		var route_cost := _estimated_route_cost(pilot, cell, here)
		if d > 0 and (route_cost < best_route_cost or (route_cost == best_route_cost and stack_hp < best_hp)):
			best_route_cost = route_cost
			best_hp = stack_hp
			best = cell
			best_army = army
	if best != Vector2i(-1, -1):
		_tracked_unit = best_army[0] if not best_army.is_empty() else null
		_tracked_cell = best
		return best
	_tracked_unit = null
	_tracked_cell = Vector2i(-1, -1)
	return Vector2i(-1, -1)

func _estimated_route_cost(pilot: Node, target_cell: Vector2i, from_cell: Vector2i) -> float:
	var movement = pilot._hero.get_component("Movement")
	if movement != null:
		var controller = movement.get_controller()
		var goal: Vector2i = controller._resolve_enemy_goal(target_cell)
		if goal != Vector2i(-1, -1):
			var path: Array = controller._full_path_to(goal)
			if not path.is_empty():
				return controller._path_cost(path)
	return float(HexUtils.hex_distance(target_cell, from_cell, pilot._map().hex_shift_right))

func on_battle_lost(pilot: Node, cell: Vector2i) -> void:
	var army: Array = pilot._map().enemy_stacks.get(cell, [])
	for unit in army:
		if not _failed_units.has(unit):
			_failed_units.append(unit)
	if army.has(_tracked_unit):
		_tracked_unit = null
		_tracked_cell = Vector2i(-1, -1)

func on_battle_won(pilot: Node, cell: Vector2i) -> void:
	if cell == _tracked_cell or _in_ring(cell, pilot):
		_kills += 1
	if cell == _tracked_cell:
		_tracked_unit = null
		_tracked_cell = Vector2i(-1, -1)

func _contains_failed_unit(army: Array) -> bool:
	for unit in army:
		if _failed_units.has(unit):
			return true
	return false

func goal_met(pilot: Node) -> bool:
	return _kills >= int(target.get("kill_goal", 5))

func metrics(pilot: Node) -> Dictionary:
	return {
		"kills": _kills,
		"kill_goal": int(target.get("kill_goal", 5)),
		"boss_ring": int(target.get("boss_ring", 2)),
		"turns": pilot.turn,
		"hp": int(pilot._hero.combat_hp) if pilot._hero != null and is_instance_valid(pilot._hero) else 0,
		"survived": survived(pilot),
	}
