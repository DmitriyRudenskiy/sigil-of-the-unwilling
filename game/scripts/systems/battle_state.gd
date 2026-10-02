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

# T12: ГСЧ d20-пути (D&D-персонажи). Основной флоу лестницы детерминирован
# и его не использует; бой с dnd-юнитами детерминирован по seed_dnd().
var dnd_rng := RandomNumberGenerator.new()


func seed_dnd(p_seed: int) -> void:
	dnd_rng.seed = p_seed
## tactical-combat: per-unit initiative ordering in build_queue().
## Compatibility flag: legacy speed-first ordering for old tests/replays.
var initiative_order := true

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
## tactical-combat: per-cell battle terrain (cell -> BattleTerrain type).
## Empty = all plain (legacy behavior, BFS fast path).
var battle_terrain: Dictionary = {}

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
	# Assigning a profile initializes the HP pool to max_hp, so a D&D character
	# is alive out of the box even when BattleStateBuilder.init_dnd_hp() is
	# bypassed (e.g. tests that construct units directly). Re-assigning a
	# profile never resets an already-initialized (damaged) pool.
	var dnd_profile: DnDCombatantProfile:
		set(value):
			dnd_profile = value
			if value != null and dnd_current_hp < 0:
				dnd_current_hp = value.max_hp
	# dnd-live-battle-wiring: current HP pool of a D&D character. -1 = not yet
	# initialized (pure stack model, or a D&D unit not yet set up).
	var dnd_current_hp: int = -1
	# Направление (фасад) юнита для флангов/тыла (tactical-combat фаза 5).
	# (-1,-1) = не инициализировано (тестовые юниты) → считается FRONT.
	# NOTE(merge): переименовано facing -> facade, т.к. remote-tactical-battle-system
	# использует facing:int (hex-бит) для attack_aspect; оба фланг-механизма живут вместе.
	var facade: Vector2i = Vector2i(-1, -1)

	## Initiative (tactical-combat spec): dexterity + class/race modifiers.
	## DnD-profile units use 10 + DEX modifier (5e: no class-based initiative
	## bonus exists); pure stack-model units use speed as the agility proxy.
	func get_initiative() -> int:
		if dnd_profile != null:
			return 10 + dnd_profile.abilities.get_dex_mod()
		return get_speed()

	func _init(p_stack = null) -> void:
		stack = p_stack

	## dnd-live-battle-wiring: true if this unit is a per-character D&D combatant.
	func is_dnd_character() -> bool:
		return dnd_profile != null

	## Initialize the D&D HP pool from the profile (called at battle setup).
	func init_dnd_hp() -> void:
		if dnd_profile != null:
			dnd_current_hp = dnd_profile.max_hp

	func is_alive() -> bool:
		if is_dnd_character():
			return alive and dnd_current_hp > 0
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
		if is_dnd_character():
			return maxi(1, dnd_current_hp)
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
	_resolve_blocked_placement()

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

	# Unified turn order (merge of both battle systems): party-based structure
	# (tactical-battle-system Phase 3) — each round one side's party acts, then
	# the other; the side with the higher top initiative goes first. Within a
	# party, units act by initiative (DEX + class/race for DnD profiles, speed
	# proxy for stacks) when initiative_order, else speed; then hp, side, uid.
	var first: Array
	var second: Array
	if _top_initiative(atk) >= _top_initiative(def):
		first = atk
		second = def
	else:
		first = def
		second = atk
	var party_cmp := func(a: BattleUnit, b: BattleUnit) -> bool:
		var sa: int = a.get_initiative() if initiative_order else a.get_speed()
		var sb: int = b.get_initiative() if initiative_order else b.get_speed()
		if sa != sb:
			return sa > sb
		if a.get_hp() != b.get_hp():
			return a.get_hp() > b.get_hp()
		if a.side != b.side:
			return a.side == Side.ATTACKER
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
	# Unified (merge): top initiative uses get_initiative() (DEX + class/race
	# for DnD profiles, speed proxy for stacks) when initiative_order, else speed.
	var top := 0
	for u in p:
		var v: int = u.get_initiative() if initiative_order else u.get_speed()
		top = maxi(top, v)
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

## tactical-combat: set the battle terrain map (cell -> terrain type).
func set_battle_terrain(map: Dictionary) -> void:
	battle_terrain.clear()
	for c in map:
		battle_terrain[c] = str(map[c])
	invalidate_board_cache()

func get_terrain_at(cell: Vector2i) -> String:
	return str(battle_terrain.get(cell, BattleTerrain.PLAIN))

func is_cell_blocked(cell: Vector2i) -> bool:
	return BattleTerrain.is_blocked(get_terrain_at(cell))

## tactical-combat: blocked terrain (water) forbids placement — relocate the
## affected unit to the nearest free in-bounds cell.
func _resolve_blocked_placement() -> void:
	if battle_terrain.is_empty():
		return
	for u in attacker_units:
		_relocate_if_blocked(u)
	for u in defender_units:
		_relocate_if_blocked(u)

func _relocate_if_blocked(u: BattleUnit) -> void:
	if u == null or not u.is_alive() or not is_cell_blocked(u.cell):
		return
	var target := _find_nearest_free_cell(u.cell)
	if target == Vector2i(-1, -1):
		return
	var side_grid: Dictionary = _unit_grid.get(u.side, {})
	side_grid.erase(u.cell)
	side_grid[target] = u
	_all_units_cells.erase(u.cell)
	_all_units_cells[target] = true
	u.cell = target
	invalidate_board_cache()

func _find_nearest_free_cell(from: Vector2i) -> Vector2i:
	var dist := HexPathfinding.dijkstra(
		from, 1000.0,
		func(_c: Vector2i) -> float: return 1.0,
		BW, BH, hex_shift_right
	)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in BH:
		for x in BW:
			var c := Vector2i(x, y)
			if _all_units_cells.has(c) or is_cell_blocked(c):
				continue
			var d: float = dist[HexUtils.pos_to_idx(c, BW)]
			if d < best_d:
				best_d = d
				best = c
	return best

func get_reachable_for_unit(unit: BattleUnit, blocked_fn: Callable) -> Dictionary:
	if unit == null:
		return {}

	# tactical-combat: ground movement on a terrained board uses costed
	# Dijkstra (forest/hill raise the cost, water blocks). Flying units
	# ignore terrain (they fly over it).
	if not unit.is_flying() and BattleTerrain.map_has_effects(battle_terrain):
		var blocked_t: Dictionary = blocked_fn.call()
		for c in battle_terrain:
			if BattleTerrain.is_blocked(str(battle_terrain[c])):
				blocked_t[c] = true
		var dist := HexPathfinding.dijkstra(
			unit.cell, float(unit.get_speed()),
			func(c: Vector2i) -> float: return BattleTerrain.move_cost(get_terrain_at(c)),
			BW, BH, hex_shift_right
		)
		var reachable: Dictionary = {}
		for y in BH:
			for x in BW:
				var c := Vector2i(x, y)
				if c == unit.cell:
					continue
				var d: float = dist[HexUtils.pos_to_idx(c, BW)]
				if d < INF:
					reachable[c] = d
		return reachable

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
