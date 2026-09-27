class_name BattleState
extends RefCounted

const _StatusEffects = preload("res://scripts/data/status_effects.gd")
const _BattleTerrain = preload("res://scripts/systems/BattleTerrain.gd")


var attacker_units: Array[BattleUnit] = []
var defender_units: Array[BattleUnit] = []
var active_unit: BattleUnit = null
var turn_queue: Array[BattleUnit] = []
var turn_idx := 0
var is_player_turn := true
var battle_over := false

enum Side { NONE, ATTACKER, DEFENDER }

var battle_winner: BattleState.Side = Side.NONE
var hex_shift_right: bool = true
var terrain_grid: Dictionary = {}
var attacker_hero_bonus: Dictionary[StringName, int] = {
    &"attack": 0,
    &"defense": 0,
    &"spell_power": 0,
    &"knowledge": 0,
}

var defender_hero_bonus: Dictionary[StringName, int] = {
    &"attack": 0,
    &"defense": 0,
    &"spell_power": 0,
    &"knowledge": 0,
}

var _reachable_cache: Dictionary = {}
var _board_version: int = 0
var _cache_sig: String = ""
var _uid := 0

var _unit_grid: Dictionary = {}
var _all_units_cells: Dictionary = {}

var _attacker_alive_count := 0
var _defender_alive_count := 0

const BW := GameNumbers.BATTLE_BOARD_W
const BH := GameNumbers.BATTLE_BOARD_H

class BattleUnit extends RefCounted:
	var stack: UnitStack
	var cell := Vector2i(-1, -1)
	var side: BattleState.Side = Side.ATTACKER
	var alive := true
	var has_moved := false
	var defending := false
	var has_retaliated := false
	var uid := 0
	var statuses: Dictionary = {}
	var max_count: int = 0
	var distance_moved_this_turn: int = 0
	var already_reborn: bool = false
	var spell: StringName = ""
	# Phase 6 (flanking): facing direction as hex neighbour bit (0=east..5=se).
	# Set on placement (attacker→0 east, defender→3 west); used for flanking aspect.
	var facing: int = 0
	# Optional D&D 5e per-character stat block (null = pure stack-model unit).
	var dnd_profile: DnDCombatantProfile = null

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
		stack.count = max(0, value)

	var stats: UnitStats:
		get: return stack.stats if stack != null and stack.stats != null else null

	func get_speed() -> int:
		return stats.speed if stats != null else 0

	func get_base_damage() -> int:
		return stats.base_damage if stats != null else 0

	func get_hp() -> int:
		return stats.hp if stats != null else 1

	func get_defense() -> int:
		return stats.defense if stats != null else 0

	func get_attack() -> int:
		return stats.attack if stats != null else 0

	func has_tag(tag: String) -> bool:
		if stack == null or stack.stats == null:
			return false
		return stack.stats.has_tag(tag)

	func is_ranged() -> bool:
		return has_tag("ranged")

	func is_flying() -> bool:
		return has_tag("flying")

	func is_no_retaliation() -> bool:
		return has_tag("no_retaliation")

	func is_double_strike() -> bool:
		return has_tag("double_strike")

	func has_morale() -> bool:
		return has_tag("morale")

	func is_defending() -> bool:
		return defending

	func add_status(effect: int, duration: int) -> void:
		statuses[effect] = max(statuses.get(effect, 0), duration)

	func clear_debuffs() -> void:
		var to_remove: Array = []
		for eff in statuses:
			if _StatusEffects.is_debuff(eff):
				to_remove.append(eff)
		for eff in to_remove:
			statuses.erase(eff)

	func is_stunned() -> bool:
		for eff in statuses:
			if _StatusEffects.is_stun(eff):
				return true
		return false

func place_army(
	attacker_stacks: Array[UnitStack],
	defender_stacks: Array[UnitStack],
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {}
) -> void:

	var builder := BattleStateBuilder.new()
	builder.set_attacker_army(attacker_stacks)
	builder.set_defender_army(defender_stacks)
	builder.set_attacker_artifact_mods(attacker_artifact_mods)
	builder.set_defender_artifact_mods(defender_artifact_mods)
	builder.build_into(self)
	# Phase 6 (flanking): static facing. Attacker faces east (bit 0, toward the
	# defender on the right edge); defender faces west (bit 3, toward the attacker
	# on the left edge). Per-move facing update is deferred; static facing already
	# yields a working front/flank/rear model.
	for u in attacker_units:
		u.facing = 0
	for u in defender_units:
		u.facing = 3
	assert(not (attacker_units.is_empty() and defender_units.is_empty()), "place_army: battle has no units")

func build_queue() -> void:
	turn_queue.clear()

	# Party-based turn order (tactical-combat spec, «Инициатива и ходы»):
	# each round one side's whole party acts, then the other. The side with the
	# higher top initiative (speed) acts first; within a party, units act by
	# speed desc, then hp, then uid. (Replaces the old globally speed-sorted
	# interleaved queue.)
	var atk: Array = []
	var def: Array = []
	for u in attacker_units:
		if u.is_alive():
			atk.append(u)
	for u in defender_units:
		if u.is_alive():
			def.append(u)

	var first: Array
	var second: Array
	if _top_initiative(atk) >= _top_initiative(def):
		first = atk
		second = def
	else:
		first = def
		second = atk
	var party_cmp := func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.get_speed() != b.get_speed():
			return a.get_speed() > b.get_speed()
		if a.get_hp() != b.get_hp():
			return a.get_hp() > b.get_hp()
		return a.uid < b.uid
	first.sort_custom(party_cmp)
	second.sort_custom(party_cmp)
	for u in first:
		turn_queue.append(u)
	for u in second:
		turn_queue.append(u)

	# TASK_18 R9 invariants: queue holds exactly the alive units.
	var _alive: int = 0
	for u in attacker_units:
		if u.is_alive():
			_alive += 1
	for u in defender_units:
		if u.is_alive():
			_alive += 1
	for u in turn_queue:
		assert(u.is_alive(), "build_queue: dead unit in turn queue")
	assert(turn_queue.size() == _alive, "build_queue: queue size != alive units")

	turn_idx = -1

func _top_initiative(p: Array) -> int:
	var top := 0
	for u in p:
		top = maxi(top, u.get_speed())
	return top

func advance_turn() -> void:
	turn_idx += 1
	_normalize_active_unit()
	# TASK_18 R9 invariant: after normalization the active unit is alive (or battle is over).
	if active_unit != null:
		assert(active_unit.is_alive() or battle_over, "advance_turn: active unit is dead")

func _normalize_active_unit() -> void:
	while turn_idx < turn_queue.size():
		var u: BattleUnit = turn_queue[turn_idx]
		if u.is_alive():
			break
		turn_idx += 1

	if turn_idx >= turn_queue.size():
		start_new_round()
		return

	active_unit = turn_queue[turn_idx]
	is_player_turn = (active_unit.side == Side.ATTACKER)

func start_new_round() -> void:
	for u in attacker_units:
		if u.is_alive():
			u.has_moved = false
			u.defending = false
			u.distance_moved_this_turn = 0
			u.already_reborn = false

	for u in defender_units:
		if u.is_alive():
			u.has_moved = false
			u.defending = false
			u.distance_moved_this_turn = 0
			u.already_reborn = false

	build_queue()

	if turn_queue.is_empty():
		check_end()
		if not battle_over:
			BattleActionResolver.force_end(self, Side.DEFENDER)
		return

	turn_idx = 0
	active_unit = turn_queue[0]
	is_player_turn = (active_unit.side == Side.ATTACKER)

func get_turn_info() -> String:
	if active_unit == null:
		return ""
	var side_txt := GameText.battle_your_turn() if is_player_turn else GameText.battle_enemy_turn()
	return GameText.battle_turn_info(side_txt, active_unit.get_display_name(), active_unit.get_count())

func get_unit_at(cell: Vector2i, side: BattleState.Side) -> BattleUnit:
	if not _unit_grid.has(side):
		return null
	var u = _unit_grid[side].get(cell, null)
	return u if (u != null and u.is_alive()) else null

func _rebuild_unit_grid() -> void:
	_unit_grid = {Side.ATTACKER: {}, Side.DEFENDER: {}}
	_rebuild_all_units_cells()
	for u in attacker_units:
		if u.is_alive():
			_unit_grid[Side.ATTACKER][u.cell] = u
	for u in defender_units:
		if u.is_alive():
			_unit_grid[Side.DEFENDER][u.cell] = u

func _rebuild_all_units_cells() -> void:
	_all_units_cells.clear()
	for u in attacker_units:
		if u.is_alive():
			_all_units_cells[u.cell] = true
	for u in defender_units:
		if u.is_alive():
			_all_units_cells[u.cell] = true

func get_units_by_side(side: BattleState.Side) -> Array[BattleUnit]:
	return attacker_units if side == Side.ATTACKER else defender_units

func get_reachable_for_unit(unit: BattleUnit, blocked_fn: Callable) -> Dictionary:
	if unit == null:
		return {}

	if unit.is_flying():
		var blocked: Dictionary = blocked_fn.call()
		var result: Dictionary = {}

		for y in BH:
			for x in BW:
				var c := Vector2i(x, y)

				if c == unit.cell:
					continue

				if blocked.has(c):
					continue

				var dist: int = HexUtils.hex_distance(unit.cell, c, hex_shift_right)
				if dist <= unit.get_speed():
					result[c] = dist

		return result

	# Phase 9: тактические проявления класса (Следопыт +движение в лесу).
	var eff_speed: int = unit.get_speed() + HeroTactics.movement_bonus(unit, get_hex_terrain(unit.cell))
	return get_reachable(
		unit.cell,
		eff_speed,
		blocked_fn,
		unit
	)

func get_reachable(cell: Vector2i, speed: int, blocked_fn: Callable, _unit: BattleUnit = null) -> Dictionary:
	var blocked: Dictionary = blocked_fn.call()

	var sig := _cache_signature(blocked, _unit)
	
	if not _reachable_cache.has(sig):
		_reachable_cache[sig] = {}
	
	var sig_cache: Dictionary = _reachable_cache[sig]
	if sig_cache.has(cell):
		var speed_cache: Dictionary = sig_cache[cell]
		if speed_cache.has(speed):
			return speed_cache[speed].duplicate()

	var reachable := HexPathfinding.bfs_reachable(cell, speed, blocked, BW, BH, hex_shift_right)

	if not sig_cache.has(cell):
		sig_cache[cell] = {}
	sig_cache[cell][speed] = reachable
	return reachable.duplicate()

func _cache_signature(blocked: Dictionary, unit: BattleUnit = null) -> String:
	if unit != null:
		return str(_board_version) + "|" + str(unit.uid)
	
	var cells: Array = blocked.keys()
	cells.sort()
	var s := ""
	for c in cells:
		s += str(c) + ","
	return str(_board_version) + "|" + s

func get_unreachable_ring(unit: BattleUnit, blocked_fn: Callable) -> Dictionary:
	if unit == null:
		return {}

	if unit.is_flying():
		var blocked: Dictionary = blocked_fn.call()
		var speed := unit.get_speed()
		var f_ring: Dictionary = {}
		for y in BH:
			for x in BW:
				var c := Vector2i(x, y)
				if c == unit.cell or blocked.has(c):
					continue
				if HexUtils.hex_distance(unit.cell, c, hex_shift_right) == speed + 1:
					f_ring[c] = HexUtils.hex_distance(unit.cell, c, hex_shift_right)
		return f_ring

	var near: Dictionary = get_reachable(unit.cell, unit.get_speed() + 1, blocked_fn, unit)
	var reach: Dictionary = get_reachable(unit.cell, unit.get_speed(), blocked_fn, unit)
	var ring: Dictionary = {}
	for cell in near:
		if not reach.has(cell):
			ring[cell] = near[cell]
	return ring

func invalidate_board_cache() -> void:
	_board_version += 1
	_reachable_cache.clear()
	_rebuild_all_units_cells()

func build_all_blocked(except_unit: BattleUnit, obstacles: Dictionary) -> Dictionary:
	var b: Dictionary = _all_units_cells.duplicate()
	if except_unit != null and except_unit.is_alive():
		b.erase(except_unit.cell)
	for o in obstacles:
		b[o] = true
	for c in terrain_grid:
		if _BattleTerrain.is_blocking(int(terrain_grid[c])):
			b[c] = true
	return b


func get_hex_terrain(cell: Vector2i) -> int:
	return int(terrain_grid.get(cell, _BattleTerrain.TerrainType.PLAIN))

func set_terrain(cell: Vector2i, t: int) -> void:
	terrain_grid[cell] = t
	invalidate_board_cache()

func clear_terrain() -> void:
	terrain_grid.clear()
	invalidate_board_cache()


func generate_terrain(rng: RandomNumberGenerator, density: float = 0.1) -> void:
	terrain_grid = _BattleTerrain.generate(rng, BW, BH, density)
	invalidate_board_cache()

# --- Phase 6: flanking (фланг/тыл) -----------------------------------------

## Neighbour bit (0..5) of `to` relative to `from`, or -1 if not adjacent.
func _neighbor_bit(from: Vector2i, to: Vector2i) -> int:
	for b in 6:
		if HexUtils.get_neighbor(from, b, hex_shift_right) == to:
			return b
	return -1

## Attack aspect of `attacker_cell` relative to `defender`'s facing:
## 0=front, 1=flank (±60°), 2=rear (±120°..180°), -1 if not adjacent
## (melee-only flanking; ranged/non-neighbour → no flanking).
func attack_aspect(attacker_cell: Vector2i, defender: BattleUnit) -> int:
	if defender == null:
		return -1
	var b := _neighbor_bit(defender.cell, attacker_cell)
	if b < 0:
		return -1
	var diff := (b - defender.facing) % 6
	if diff < 0:
		diff += 6
	if diff == 0:
		return 0
	if diff == 1 or diff == 5:
		return 1
	return 2

func check_end() -> BattleState.Side:
	if battle_over:
		return battle_winner

	if _attacker_alive_count == 0:
		BattleActionResolver.force_end(self, Side.DEFENDER)
	elif _defender_alive_count == 0:
		BattleActionResolver.force_end(self, Side.ATTACKER)

	return battle_winner

func get_survivors(side: BattleState.Side) -> Array[UnitStack]:
	var r: Array[UnitStack] = []
	var units := attacker_units if side == Side.ATTACKER else defender_units
	for u in units:
		if u.is_alive():
			r.append(u.stack)
	return r

func get_retreat_survivors(side: BattleState.Side) -> Array[UnitStack]:
	var all_survivors: Array[UnitStack] = []
	var units := get_units_by_side(side)

	for u in units:
		if u.is_alive():
			var stack: UnitStack = u.stack.duplicate_stack()
			stack.count = max(
				1,
				int(ceil(float(stack.count) * GameNumbers.RETREAT_SURVIVAL_RATIO))
			)
			all_survivors.append(stack)

	all_survivors.sort_custom(func(a: UnitStack, b: UnitStack): return a.count > b.count)
	var result: Array[UnitStack] = []
	for i in min(GameNumbers.RETREAT_STACK_LIMIT, all_survivors.size()):
		result.append(all_survivors[i])

	return result

func set_hero_bonuses(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> void:
	attacker_hero_bonus = _normalize_hero_bonus(attacker_bonus)
	defender_hero_bonus = _normalize_hero_bonus(defender_bonus)

func _normalize_hero_bonus(bonus: Dictionary) -> Dictionary[StringName, int]:
	return {
		&"attack": int(bonus.get(&"attack", bonus.get("attack", 0))),
		&"defense": int(bonus.get(&"defense", bonus.get("defense", 0))),
		&"spell_power": int(bonus.get(&"spell_power", bonus.get("spell_power", 0))),
		&"knowledge": int(bonus.get(&"knowledge", bonus.get("knowledge", 0))),
	}
