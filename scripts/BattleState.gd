class_name BattleState
extends RefCounted
## Чистое состояние боя: юниты, очередь ходов, конец боя, кэш bfs.
## Не зависит от Godot-узлов — работает только с данными.

var attacker_units: Array[BattleUnit] = []
var defender_units: Array[BattleUnit] = []
var active_unit: BattleUnit = null
var turn_queue: Array[BattleUnit] = []
var turn_idx := 0
var is_player_turn := true
var battle_over := false

# BFS reachable cache
var _reachable_cache: Dictionary = {}
var _board_version: int = 0
var _uid := 0

const BW := 17
const BH := 11


# ==================== БОЕВОЙ ЮНИТ ====================
class BattleUnit extends RefCounted:
	var stack = null
	var cell := Vector2i(-1, -1)
	var side := "attacker"
	var alive := true
	var has_moved := false
	var defending := false
	var uid := 0

	func _init(p_stack = null) -> void:
		stack = p_stack

	func is_alive() -> bool:
		return alive and stack != null and stack.is_alive()

	func get_key() -> String:
		if stack == null:
			return ""
		return stack.get_key()

	func get_display_name() -> String:
		if stack == null:
			return ""
		return stack.get_display_name()

	func get_count() -> int:
		if stack == null:
			return 0
		return stack.count

	func set_count(value: int) -> void:
		if stack == null:
			alive = false
			return
		stack.count = maxi(0, value)
		if stack.count <= 0:
			alive = false

	func get_speed() -> int:
		if stack == null or stack.stats == null:
			return 0
		return stack.stats.speed

	func get_base_damage() -> int:
		if stack == null or stack.stats == null:
			return 0
		return stack.stats.base_damage

	func get_hp() -> int:
		if stack == null or stack.stats == null:
			return 1
		return stack.stats.hp

	func get_defense() -> int:
		if stack == null or stack.stats == null:
			return 0
		return stack.stats.defense


# ==================== КЛОНИРОВАНИЕ ====================
func duplicate() -> BattleState:
	var copy := BattleState.new()
	copy.attacker_units = attacker_units.duplicate()
	copy.defender_units = defender_units.duplicate()
	copy.active_unit = active_unit
	copy.turn_queue = turn_queue.duplicate()
	copy.turn_idx = turn_idx
	copy.is_player_turn = is_player_turn
	copy.battle_over = battle_over
	copy._board_version = _board_version
	return copy


# ==================== РАЗМЕЩЕНИЕ АРМИЙ ====================
func place_army(attacker_stacks: Array, defender_stacks: Array) -> void:
	attacker_units = _build_units(attacker_stacks, true)
	defender_units = _build_units(defender_stacks, false)
	invalidate_board_cache()


func _build_units(stacks: Array, is_atk: bool) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	var sx := 2 if is_atk else BW - 3
	for i in stacks.size():
		var input_stack = stacks[i]
		if input_stack == null or not input_stack.is_alive():
			continue

		var stack = input_stack.duplicate_stack()
		if stack == null or stack.stats == null:
			push_error("[Battle] Invalid UnitStack received")
			continue

		var unit := BattleUnit.new(stack)
		unit.cell = Vector2i(sx + (i % 2), (i / 2) * 2 + 1)
		unit.side = "attacker" if is_atk else "defender"
		unit.alive = true
		unit.has_moved = false
		unit.uid = _uid
		_uid += 1
		units.append(unit)
	return units


# ==================== ОЧЕРЕДЬ ХОДОВ ====================
func build_queue() -> void:
	turn_queue.clear()
	turn_queue.append_array(attacker_units)
	turn_queue.append_array(defender_units)
	turn_queue.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.get_speed() > b.get_speed()
	)


func advance_turn() -> void:
	turn_idx += 1
	if turn_idx >= turn_queue.size():
		turn_idx = 0
		for u in turn_queue:
			u.has_moved = false
			u.defending = false

	while turn_idx < turn_queue.size():
		var u: BattleUnit = turn_queue[turn_idx]
		if u.is_alive():
			break
		turn_idx += 1

	if turn_idx >= turn_queue.size():
		# Все юниты мертвы — не должно произойти, бой должен уже закончиться
		battle_over = true
		return

	active_unit = turn_queue[turn_idx]
	is_player_turn = (active_unit.side == "attacker")


func get_turn_info() -> String:
	if active_unit == null:
		return ""
	var side_txt := "Ваш ход" if is_player_turn else "Ход противника"
	return "%s: %s (%d)" % [side_txt, active_unit.get_display_name(), active_unit.get_count()]


# ==================== ПОИСК ЮНИТОВ ====================
func get_unit_at(cell: Vector2i, side: String) -> BattleUnit:
	var units := attacker_units if side == "attacker" else defender_units
	for u in units:
		if u.is_alive() and u.cell == cell:
			return u
	return null


func get_units_by_side(side: String) -> Array[BattleUnit]:
	return attacker_units if side == "attacker" else defender_units


# ==================== КЭШИРОВАННЫЙ BFS ====================
func get_reachable(cell: Vector2i, speed: int, blocked_fn: Callable, unit: BattleUnit = null) -> Dictionary:
	var uid := -1 if unit == null else unit.uid
	var key := "%d:%d:%d:%d:%d" % [cell.x, cell.y, speed, _board_version, uid]
	if _reachable_cache.has(key):
		return _reachable_cache[key].duplicate()

	var blocked: Dictionary = blocked_fn.call()
	var reachable := HexUtils.bfs_reachable(cell, speed, blocked, BW, BH)
	_reachable_cache[key] = reachable.duplicate()
	return reachable


func invalidate_board_cache() -> void:
	_board_version += 1
	_reachable_cache.clear()


# ==================== ПОСТРОЕНИЕ БЛОКИРОВКИ ====================
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


# ==================== АТАКА (расчёт урона) ====================
func calc_attack_result(atk: BattleUnit, def: BattleUnit) -> Dictionary:
	if def == null:
		return {}

	var count := atk.get_count()
	var bd := atk.get_base_damage()
	var def_stat := def.get_defense()
	var reduction := clampf(float(def_stat) * 0.03, 0.0, 0.7)
	var dmg := maxi(1, int(float(count * bd) * (1.0 - reduction)))
	if def.defending:
		dmg = maxi(1, dmg / 2)
	var hp := maxi(1, def.get_hp())
	var kills := maxi(1, dmg / hp)

	return {
		"damage": dmg,
		"kills": kills,
	}


func apply_attack(atk: BattleUnit, def: BattleUnit) -> Dictionary:
	var result := calc_attack_result(atk, def)
	if result.is_empty():
		return result

	def.set_count(def.get_count() - result["kills"])
	atk.has_moved = true

	if def.get_count() <= 0:
		def.alive = false
		invalidate_board_cache()
		check_end()

	return result


func do_move(unit: BattleUnit, target: Vector2i) -> void:
	unit.cell = target
	unit.has_moved = true
	invalidate_board_cache()


func do_defend(unit: BattleUnit) -> void:
	unit.has_moved = true
	unit.defending = true


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


func do_skip(unit: BattleUnit) -> void:
	if unit != null:
		unit.has_moved = true


# ==================== ПРОВЕРКА КОНЦА БОЯ ====================
func check_end() -> String:
	if battle_over:
		return ""

	var aa := false
	var da := false
	for u in attacker_units:
		if u.is_alive():
			aa = true
			break
	for u in defender_units:
		if u.is_alive():
			da = true
			break

	if not aa:
		battle_over = true
		return "defender"
	elif not da:
		battle_over = true
		return "attacker"
	return ""


func get_survivors(side: String) -> Array[UnitStack]:
	var r: Array[UnitStack] = []
	var units := attacker_units if side == "attacker" else defender_units
	for u in units:
		if u.is_alive():
			r.append(u.stack)
	return r
