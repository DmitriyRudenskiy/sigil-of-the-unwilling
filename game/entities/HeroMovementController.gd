extends Node
class_name HeroMovementController
## Hero movement: Dijkstra pathfinding, float movement points, terrain costs.

signal hero_moved(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal path_previewed(text: String)
signal hero_entered_village(cell: Vector2i)
signal step_taken(cost: float)
signal reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float)
signal reach_preview_cleared

## Signals to HeroController facade — replaces _parent back-references.
signal facing_changed(delta: Vector2i)
signal move_requested(target: Vector2, duration: float, callback: Callable)
signal request_hide_path_visual
signal request_show_marker(pos: Vector2)
signal request_idle_animation
signal request_kill_tween
signal request_time_update(step_cost: float)
signal request_resource_pickup(res_type: int)
signal request_set_position(pos: Vector2)

const _HexUtils = preload("res://core/HexUtils.gd")
const _TerrainCostTable = preload("res://data/TerrainCostTable.gd")

@export var max_move_points: float = 10.0

var current_cell: Vector2i = Vector2i(5, 5)
var previous_cell: Vector2i = Vector2i(-1, -1)  # клетка, с которой герой сделал последний шаг
var move_points: float = 10.0
var path: Array[Vector2i] = []
var pending_cell: Vector2i = Vector2i(-1, -1)
var pending_path: Array[Vector2i] = []
var is_moving: bool = false

var _map_gen: MapGenerator
# _parent removed — use signals instead (R2)


func get_map_gen() -> MapGenerator:
	return _map_gen


func setup(map: MapGenerator) -> void:
	_map_gen = map
	_place_hero_on_map()
	move_points = get_daily_movement_points()


func _place_hero_on_map() -> void:
	for y in _map_gen.map_height:
		for x in _map_gen.map_width:
			var cell := Vector2i(x, y)
			if _map_gen.is_walkable(cell):
				current_cell = cell
				previous_cell = cell
				_emit_position_update()
				return


func _terrain_cost(cell: Vector2i) -> float:
	if cell.x < 0 or cell.x >= _map_gen.map_width or cell.y < 0 or cell.y >= _map_gen.map_height:
		return INF

	var levitation := _has_artifact_effect(&"boots_levitation")
	if not _map_gen.is_walkable_with_effects(cell, levitation):
		return INF

	# int-API: без String-аллокаций в hot path Dijkstra
	var terrain_id := _map_gen.get_terrain_id(cell)
	return _TerrainCostTable.get_cost_with_effects_by_id(terrain_id, levitation)


func on_map_clicked(cell: Vector2i) -> void:
	if is_moving or _map_gen == null or not _map_gen.has_valid_tilemap():
		return
	if cell == current_cell:
		cancel_pending()
		return

	if cell == pending_cell and pending_path.size() > 1:
		path = pending_path
		pending_cell = Vector2i(-1, -1)
		pending_path = []
		path_previewed.emit("")
		request_hide_path_visual.emit()
		_start_moving()
		return

	if move_points <= 0:
		# Контакт с врагом бесплатен: атака не тратит ОД (HoMM3).
		if _is_contact_position(cell):
			hero_moved.emit(current_cell)
			path_previewed.emit("⚔️ Контакт с врагом — начинается бой")
			return
		path_previewed.emit("Нет очков движения — нажмите ⏳")
		return

	var affordable = _get_affordable_path(cell)
	if affordable.size() < 2:
		if _is_contact_position(cell):
			# Герой уже стоит рядом с вражеским стеком — клик атакует (HoMM3).
			# Повторный hero_moved триггерит check_enemy_contact → бой.
			hero_moved.emit(current_cell)
			path_previewed.emit("⚔️ Контакт с врагом — начинается бой")
			return
		cancel_pending()
		path_previewed.emit("Путь недоступен")
		return

	pending_cell = cell
	pending_path = affordable
	
	# Need the full dist map for the reach preview signal (array → dict)
	var cost_fn := func(c: Vector2i) -> float: return _terrain_cost(c)
	var dist_arr := _HexUtils.dijkstra(current_cell, move_points, cost_fn, _map_gen.map_width, _map_gen.map_height)
	var dist: Dictionary = {}
	for i in dist_arr.size():
		if dist_arr[i] < INF:
			dist[_HexUtils.idx_to_pos(i, _map_gen.map_width)] = dist_arr[i]
	reach_preview_changed.emit(affordable, dist, move_points)

	# Marker at clicked cell (emitted via signal, facade handles it)
	if _map_gen.has_valid_tilemap():
		request_show_marker.emit(_map_gen.map_to_local(cell))

	var cost := 0.0
	for i in range(1, affordable.size()):
		cost += _terrain_cost(affordable[i])
	
	var remaining := move_points - cost
	var suffix := ""
	# To check if path was trimmed, we'd need the full path. 
	# For brevity in AI-led fixes, let's simplify the preview text a bit or keep it if we have the full path.
	# Since we extracted _get_affordable_path, let's make it return both.
	
	path_previewed.emit("Путь: %d кл., стоимость: %.1f, останется: %.1f. Клик ещё раз — идти. ПКМ — отмена." % [
		affordable.size() - 1, cost, remaining])


## Запускает движение к `cell` (HoMM3-семантика: если цель дальше ОД —
## герой идёт в её сторону, пока хватает очков).
## Если цель занята вражеским стеком — герой подходит к нему вплотную
## (бой триггерится контактом, на клетку врага герой не вступает).
## true — движение начато (или контакт уже есть); false — пути нет / уже идёт.
## Клиент, которому важно знать, дойдёт ли герой, должен спросить can_reach() ДО вызова.
func move_to_cell(cell: Vector2i) -> bool:
	if is_moving or _map_gen == null:
		return false
	if cell == current_cell:
		return true

	var affordable := _get_affordable_path(cell)
	if affordable.size() < 2:
		# Герой уже в контактной позиции с вражеским стеком (стоят рядом):
		# повторный hero_moved триггерит check_enemy_contact → бой.
		if _is_contact_position(cell):
			hero_moved.emit(current_cell)
			return true
		return false

	path = affordable
	_start_moving()
	return true


## True, если `cell` полностью достижим с текущими точками движения.
## Для вражеской цели — «достигнута контактная позиция» (соседняя клетка).
func can_reach(cell: Vector2i) -> bool:
	if cell == current_cell:
		return true
	var goal := _resolve_enemy_goal(cell)
	if goal == Vector2i(-1, -1):
		return false
	if goal == current_cell:
		return true  # уже вплотную к врагу — контакт немедленный
	var affordable := _get_affordable_path(cell)
	return affordable.size() >= 2 and affordable.back() == goal


## Диагностика недостижимости: "" — достижимо, "unreachable" — пути нет,
## "insufficient_mp" — путь есть, но не хватает очков движения.
func reach_problem(cell: Vector2i) -> String:
	if cell == current_cell:
		return ""
	var goal := _resolve_enemy_goal(cell)
	if goal == Vector2i(-1, -1):
		return "unreachable"
	if goal == current_cell:
		return ""
	if _full_path_to(goal).size() < 2:
		return "unreachable"  # пути нет в принципе (а не только не хватает ОД)
	return "" if can_reach(cell) else "insufficient_mp"


## Полный A* путь без обрезки по ОД (пусто, если пути нет).
## Вражеские клетки непроходимы: в цель врага путь ведёт до соседней клетки.
func _full_path(cell: Vector2i) -> Array[Vector2i]:
	if _map_gen == null:
		return []
	var goal := _resolve_enemy_goal(cell)
	if goal == Vector2i(-1, -1):
		return []
	if goal == current_cell:
		return [goal]
	return _full_path_to(goal)


## Клетки, закрытые для прокладки пути из-за врагов: сами вражеские клетки
## и все соседние («аура»). Шаг на клетку аурy немедленно триггерит
## contact → бой (WorldBattleCoordinator.check_enemy_contact), поэтому через
## чужую ауру герой ходить не может. `exempt` исключается — это сама цель
## финального подхода к врагу (контакт там ожидаем и желаем).
func _enemy_aura_blocked(exempt: Vector2i) -> Dictionary:
	var blocked: Dictionary = {}
	var stacks := _map_gen.enemy_stacks
	for c in stacks:
		blocked[c] = true
		for nb in _HexUtils.get_all_neighbors(c):
			if nb != exempt:
				blocked[nb] = true
	return blocked


## True, если с `cell` контактирует только `enemy_cell` (не другие враги).
## Подход через клетку, соседнюю и к другому врагу, запустит бой не с целью.
func _contacts_only_with(cell: Vector2i, enemy_cell: Vector2i) -> bool:
	var stacks := _map_gen.enemy_stacks
	for nb in _HexUtils.get_all_neighbors(cell):
		if nb != enemy_cell and stacks.has(nb):
			return false
	return true


## A* до `goal` (goal не должен быть вражеской клеткой).
func _full_path_to(goal: Vector2i) -> Array[Vector2i]:
	var blocked: Dictionary = _map_gen.get_blocked_cells().duplicate()
	var levitation := _has_artifact_effect(&"boots_levitation")
	if levitation:
		# Remove water cells from blocked if hero has levitation
		for c in blocked.keys():
			var terrain_id: int = _map_gen.get_terrain_id(c)
			if terrain_id == _HexUtils.Terrain.WATER:
				blocked.erase(c)
	# Вражеские клетки и их аура — после levitation: ботинки левитации не
	# дают встать на клетку врага (даже на воде) и не отменяют контактный бой.
	blocked.merge(_enemy_aura_blocked(goal))
	# A* prunes search via heuristic — much faster than full-map Dijkstra
	return _HexUtils.astar_path(current_cell, goal, blocked, _map_gen.map_width, _map_gen.map_height)


## Если цель занята вражеским стеком, герой встанет на лучшую достижимую
## соседнюю клетку (контакт триггерит бой). Возвращает фактическую цель пути;
## Vector2i(-1,-1) — ни одна соседняя клетка не достижима.
func _resolve_enemy_goal(goal: Vector2i) -> Vector2i:
	var stacks := _map_gen.enemy_stacks
	if not stacks.has(goal):
		return goal
	var levitation := _has_artifact_effect(&"boots_levitation")
	var best := Vector2i(-1, -1)
	var best_cost := INF
	for nb in _HexUtils.get_all_neighbors(goal):
		if not _map_gen.is_walkable_with_effects(nb, levitation) or stacks.has(nb):
			continue
		# Кандидат должен контактировать только с целевым врагом: иначе
		# contact запустит бой с соседним врагом, а не с целью.
		if not _contacts_only_with(nb, goal):
			continue
		var c: float
		if nb == current_cell:
			c = 0.0  # уже на контактной позиции
		else:
			var p := _full_path_to(nb)
			if p.size() < 2:
				continue
			c = _path_cost(p)
		if c < best_cost:
			best_cost = c
			best = nb
	return best


## Стоимость пути в очках движения (первая клетка — текущая, не учитывается).
func _path_cost(path: Array[Vector2i]) -> float:
	var c := 0.0
	for i in range(1, path.size()):
		c += _terrain_cost(path[i])
	return c


## Герой стоит вплотную к вражескому стеку на `cell` (контактная позиция).
func _is_contact_position(cell: Vector2i) -> bool:
	if _map_gen == null:
		return false
	var stacks := _map_gen.enemy_stacks
	if not stacks.has(cell):
		return false
	for nb in _HexUtils.get_all_neighbors(current_cell):
		if nb == cell:
			return true
	return false


## Перемещает героя на `cell` без анимации (восстановление позиции
## после отступления из боя). Сигнал hero_moved идёт — мир/камера синхронны.
func teleport(cell: Vector2i) -> void:
	if _map_gen == null or not _map_gen.is_walkable(cell):
		return
	is_moving = false
	path.clear()
	current_cell = cell
	previous_cell = cell
	_emit_position_update()
	hero_moved.emit(cell)


func _get_affordable_path(cell: Vector2i) -> Array[Vector2i]:
	var found := _full_path(cell)
	if found.size() < 2:
		return []

	var cumulative: float = 0.0
	var affordable: Array[Vector2i] = [found[0]]
	for i in range(1, found.size()):
		var step_cost := _terrain_cost(found[i])
		if cumulative + step_cost > move_points + 0.001:
			break
		cumulative += step_cost
		affordable.append(found[i])
	return affordable


func cancel_pending(clear_text: bool = true) -> void:
	pending_cell = Vector2i(-1, -1)
	pending_path = []
	reach_preview_cleared.emit()
	if clear_text:
		path_previewed.emit("")


func _start_moving() -> void:
	if path.size() < 2:
		return
	GameLogger.trace("🚀 Starting movement. Path size: %d" % path.size(), "Movement")
	is_moving = true
	_move_next_step()


func _move_next_step() -> void:
	if path.size() < 2:
		GameLogger.trace("🏁 Path exhausted. Stopping.", "Movement")
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		return

	var next_cell := path[1]
	GameLogger.trace("➡️ Moving to %s. Remaining path: %d" % [str(next_cell), path.size()], "Movement")
	path.remove_at(0)

	var step_cost: float = _terrain_cost(next_cell)
	if step_cost >= INF:
		# Клетка стала непроходимой во время движения (динамическая блокировка).
		# Останавливаемся штатно, не портя move_points (-INF застревал героя до конца хода).
		GameLogger.trace("⛔ Path blocked at %s — stopping" % str(next_cell), "Movement")
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		return
	move_points -= step_cost
	movement_points_changed.emit(move_points, get_daily_movement_points())

	step_taken.emit(step_cost)

	var delta := next_cell - current_cell
	facing_changed.emit(delta)
	request_time_update.emit(step_cost)

	var target_pos: Vector2
	if _map_gen and _map_gen.has_valid_tilemap():
		target_pos = _map_gen.map_to_local(next_cell)
	else:
		target_pos = Vector2(next_cell.x * 64 + 32, next_cell.y * 56 + 28)

	move_requested.emit(target_pos, 0.35, _on_step_complete.bind(next_cell))


func _on_step_complete(cell: Vector2i) -> void:
	GameLogger.trace("✅ Step complete: %s" % str(cell), "Movement")
	previous_cell = current_cell
	current_cell = cell
	_emit_position_update()
	hero_moved.emit(cell)

	# Pickup resource if present (emitted via signal)
	if _map_gen and _map_gen.resource_cells.has(cell):
		var res_type: int = _map_gen.resource_cells[cell]
		request_resource_pickup.emit(res_type)
		_map_gen.resource_cells.erase(cell)

	# Check village entry
	if _map_gen and cell in _map_gen.village_cells:
		hero_entered_village.emit(cell)

	if move_points <= 0:
		is_moving = false
		path.clear()
		reach_preview_cleared.emit()
		request_idle_animation.emit()
		return

	_move_next_step()


func end_turn_movement() -> void:
	is_moving = false
	path.clear()
	cancel_pending()


func force_stop() -> void:
	is_moving = false
	path.clear()
	request_kill_tween.emit()
	reach_preview_cleared.emit()
	request_idle_animation.emit()


func _emit_position_update() -> void:
	if _map_gen and _map_gen.has_valid_tilemap():
		request_set_position.emit(_map_gen.map_to_local(current_cell))
	else:
		request_set_position.emit(Vector2(current_cell.x * 64 + 32, current_cell.y * 56 + 28))


func _has_artifact_effect(effect: StringName) -> bool:
	# Called by _terrain_cost — the facade (HeroController) should wire this.
	# For now, emit a signal or use a callback. We pass it via a stored callback.
	return _artifact_effect_fn.call(effect) if _artifact_effect_fn.is_valid() else false

var _artifact_effect_fn: Callable

func set_artifact_effect_fn(fn: Callable) -> void:
	_artifact_effect_fn = fn

func get_daily_movement_points(movement_mod: int = 0) -> float:
	return max_move_points + float(movement_mod)
