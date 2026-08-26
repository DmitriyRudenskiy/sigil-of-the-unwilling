class_name BattleState
extends RefCounted
## Чистое состояние боя: юниты, очередь ходов, конец боя, кэш bfs.
## Не зависит от Godot-узлов — работает только с данными.

const _StatusEffects = preload("res://scripts/data/StatusEffects.gd")

var attacker_units: Array[BattleUnit] = []
var defender_units: Array[BattleUnit] = []
var active_unit: BattleUnit = null
var turn_queue: Array[BattleUnit] = []
var turn_idx := 0
var is_player_turn := true
var battle_over := false
var battle_winner := ""

var attacker_hero_bonus: Dictionary = {
    "attack": 0,
    "defense": 0,
    "spell_power": 0,
    "knowledge": 0,
}

var defender_hero_bonus: Dictionary = {
    "attack": 0,
    "defense": 0,
    "spell_power": 0,
    "knowledge": 0,
}

# BFS reachable cache
var _reachable_cache: Dictionary = {}
var _board_version: int = 0
var _uid := 0

# Счётчики живых для O(1) check_end
var _attacker_alive_count := 0
var _defender_alive_count := 0

const BW := 17
const BH := 11


# ==================== БОЕВОЙ ЮНИТ ====================
class BattleUnit extends RefCounted:
	var stack: UnitStack
	var cell := Vector2i(-1, -1)
	var side := "attacker"
	var alive := true
	var has_moved := false
	var defending := false
	var has_retaliated := false
	var uid := 0
	var statuses: Dictionary = {}  # StatusEffects.Effect -> int (turns remaining)
	var max_count: int = 0         # For vampiric and rebirth
	var distance_moved_this_turn: int = 0  # For charge
	var already_reborn: bool = false
	var spell: StringName = ""  # Pending spell for spell casting

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

	func get_attack() -> int:
		if stack == null or stack.stats == null:
			return 0
		return stack.stats.attack

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

	func do_defend() -> void:
		defending = true

	func add_status(effect: int, duration: int) -> void:
		statuses[effect] = maxi(statuses.get(effect, 0), duration)

	func clear_debuffs() -> void:
		var to_remove: Array = []
		for eff in statuses.keys():
			if _StatusEffects.is_debuff(eff):
				to_remove.append(eff)
		for eff in to_remove:
			statuses.erase(eff)

	func is_stunned() -> bool:
		for eff in statuses.keys():
			if _StatusEffects.is_stun(eff):
				return true
		return false


# ==================== РАЗМЕЩЕНИЕ АРМИЙ ====================
func place_army(
	attacker_stacks: Array[UnitStack],
	defender_stacks: Array[UnitStack],
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {}
) -> void:
	_uid = 0  # Сброс UID для нового боя
	attacker_units = _build_units(attacker_stacks, true)
	defender_units = _build_units(defender_stacks, false)
	_attacker_alive_count = attacker_units.size()
	_defender_alive_count = defender_units.size()
	_apply_artifact_effects(attacker_units, attacker_artifact_mods)
	_apply_artifact_effects(defender_units, defender_artifact_mods)
	invalidate_board_cache()
	check_end()


# Вспомогательный: убить юнита + обновить счётчики
func _kill_unit(unit: BattleUnit) -> void:
	if not unit.alive: return
	unit.alive = false
	if unit.side == "attacker": _attacker_alive_count -= 1
	else: _defender_alive_count -= 1
	check_end()

func _apply_artifact_effects(units: Array[BattleUnit], mods: Dictionary) -> void:
	if mods.is_empty():
		return
	var flat_hp: int = int(mods.get("stack_hp", 0))
	var percent_hp: float = float(mods.get("stack_hp_percent", 0.0))
	var speed_bonus: int = int(mods.get("stack_speed", 0))
	for u in units:
		if u.stack == null or u.stack.stats == null:
			continue
		if flat_hp > 0 or percent_hp > 0.0:
			var new_hp := float(u.stack.stats.hp)
			new_hp += float(flat_hp)
			new_hp *= (1.0 + percent_hp)
			u.stack.stats = u.stack.stats.duplicate()
			u.stack.stats.hp = int(new_hp)
		if speed_bonus > 0:
			u.stack.stats = u.stack.stats.duplicate()
			u.stack.stats.speed += speed_bonus


func _build_units(stacks: Array, is_atk: bool) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	var sx := 2 if is_atk else BW - 3
	for i in stacks.size():
		var input_stack = stacks[i]
		if input_stack == null or not input_stack.is_alive():
			continue

		var stack: UnitStack = input_stack.duplicate_stack()
		if stack == null or stack.stats == null:
			push_error("[Battle] Invalid UnitStack received")
			continue

		var unit := BattleUnit.new(stack)
		unit.cell = Vector2i(sx + (i % 2), (i / 2) * 2 + 1)
		unit.side = "attacker" if is_atk else "defender"
		unit.alive = true
		unit.has_moved = false
		unit.max_count = stack.count
		unit.uid = _uid
		_uid += 1
		units.append(unit)
	return units


# ==================== ОЧЕРЕДЬ ХОДОВ ====================
func build_queue() -> void:
	turn_queue.clear()

	for u in attacker_units:
		if u.is_alive():
			turn_queue.append(u)

	for u in defender_units:
		if u.is_alive():
			turn_queue.append(u)

	turn_queue.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.get_speed() != b.get_speed():
			return a.get_speed() > b.get_speed()

		if a.get_hp() != b.get_hp():
			return a.get_hp() > b.get_hp()

		if a.side != b.side:
			return a.side == "attacker"

		return a.uid < b.uid
	)

	turn_idx = -1


func advance_turn() -> void:
	turn_idx += 1
	_normalize_active_unit()


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
	is_player_turn = (active_unit.side == "attacker")


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
			force_end("defender")
		return

	turn_idx = 0
	active_unit = turn_queue[0]
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

				var dist: int = HexUtils.hex_distance(unit.cell, c)
				if dist <= unit.get_speed():
					result[c] = dist

			return result

	return get_reachable(
		unit.cell,
		unit.get_speed(),
		blocked_fn,
		unit
	)


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
func apply_attack(
	atk: BattleUnit,
	def: BattleUnit,
	is_melee_attack: bool,
	rng: RandomNumberGenerator,
	consume_action: bool = true
) -> Dictionary:
	if atk == null or def == null or not atk.is_alive() or not def.is_alive():
		return {}

	var bonuses := _get_hero_bonuses(atk, def)
	var attacker_bonus := bonuses[0]
	var defender_bonus := bonuses[1]
	var first_strike_triggered := _apply_first_strike(atk, def, is_melee_attack, rng, attacker_bonus, defender_bonus)
	var charge_mult := _get_charge_multiplier(atk)
	var result := BattleRules.calculate_attack(atk, def, is_melee_attack, rng, attacker_bonus, defender_bonus)
	if result.is_empty(): return result

	if first_strike_triggered:
		result["first_strike"] = true
	result = _apply_charge(atk, def, result, charge_mult)
	def.set_count(def.get_count() - int(result.get("kills", 0)))
	if consume_action: atk.has_moved = true

	_apply_status_procs(atk, def, rng, result)
	if def.get_count() <= 0: _kill_unit(def)
	_apply_vampiric(atk, result)
	_apply_breath(atk, def, result, rng)
	_apply_saltpeter(atk, def, rng, result)
	_apply_rebirth(def, rng, result)

	invalidate_board_cache()
	check_end()
	return result

# ---------- Вспомогательные методы атаки ----------
func _get_hero_bonuses(atk: BattleUnit, def: BattleUnit) -> Array:
	var atk_bonus := int(attacker_hero_bonus.get("attack", 0)) if atk.side == "attacker" else int(defender_hero_bonus.get("attack", 0))
	var def_bonus := int(defender_hero_bonus.get("defense", 0)) if def.side == "defender" else int(attacker_hero_bonus.get("defense", 0))
	return [atk_bonus, def_bonus]

func _apply_first_strike(atk: BattleUnit, def: BattleUnit, is_melee: bool, rng: RandomNumberGenerator, atk_bonus: int, def_bonus: int) -> bool:
	if not (is_melee and def.has_tag("first_strike") and not def.has_retaliated): return false
	def.has_retaliated = true
	var fs_result = BattleRules.calculate_attack(def, atk, true, rng, def_bonus, atk_bonus)
	if not fs_result.is_empty():
		atk.set_count(atk.get_count() - int(fs_result.get("kills", 0)))
		if atk.get_count() <= 0: _kill_unit(atk)
	return true

func _get_charge_multiplier(atk: BattleUnit) -> float:
	return 1.5 if (atk.has_tag("charge") and atk.distance_moved_this_turn >= 3) else 1.0

func _apply_charge(atk: BattleUnit, def: BattleUnit, result: Dictionary, charge_mult: float) -> Dictionary:
	if charge_mult <= 1.0: return result
	result["damage"] = int(result["damage"] * charge_mult)
	var hp: int = maxi(1, def.get_hp())
	result["kills"] = maxi(1, result["damage"] / hp)
	result["kills"] = mini(result["kills"], def.get_count())
	result["charge"] = true
	return result

func _apply_status_procs(atk: BattleUnit, def: BattleUnit, rng: RandomNumberGenerator, result: Dictionary) -> void:
	if atk.has_tag("petrify") and rng.randf() < 0.20:
		def.add_status(_StatusEffects.Effect.PETRIFIED, 1)
		result["petrify"] = true
	if atk.has_tag("blind") and rng.randf() < 0.20:
		def.add_status(_StatusEffects.Effect.BLIND, 1)
		result["blind"] = true

func _apply_vampiric(atk: BattleUnit, result: Dictionary) -> void:
	if not atk.has_tag("vampiric") or int(result.get("kills", 0)) <= 0: return
	var healed := mini(int(result.get("kills", 0)), atk.max_count - atk.get_count())
	if healed > 0:
		atk.set_count(atk.get_count() + healed)
		result["vampiric"] = healed

func _apply_breath(atk: BattleUnit, def: BattleUnit, result: Dictionary, rng: RandomNumberGenerator) -> void:
	if atk.has_tag("breath"):
		result["breath_kills"] = _apply_breath_damage(atk, def, int(result["damage"]) * 0.5, rng)

func _apply_saltpeter(atk: BattleUnit, def: BattleUnit, rng: RandomNumberGenerator, result: Dictionary) -> void:
	if atk.has_tag("saltpeter"):
		result["saltpeter_kills"] = _apply_saltpeter_explosion(atk, def, rng)

func _apply_rebirth(def: BattleUnit, rng: RandomNumberGenerator, result: Dictionary) -> void:
	if def.get_count() <= 0 and def.has_tag("rebirth") and not def.already_reborn:
		if rng.randf() < 0.20:
			def.already_reborn = true
			def.set_count(int(def.max_count * 0.5))
			def.alive = true
			result["rebirth"] = true


func _apply_breath_damage(atk: BattleUnit, original_def: BattleUnit, breath_dmg: int, rng: RandomNumberGenerator) -> int:
	var total_kills := 0
	var neighbors := HexUtils.get_all_neighbors(original_def.cell)
	for nb in neighbors:
		# Check both sides for victims
		for side_str in ["attacker", "defender"]:
			var victim := get_unit_at(nb, side_str)
			if victim == null or not victim.is_alive():
				continue
			if victim == atk or victim == original_def:
				continue
			var hp := maxi(1, victim.get_hp())
			var kills := maxi(1, breath_dmg / hp)
			kills = mini(kills, victim.get_count())
			victim.set_count(victim.get_count() - kills)
			total_kills += kills
			if victim.get_count() <= 0:
				_kill_unit(victim)
	return total_kills


func _apply_saltpeter_explosion(atk: BattleUnit, original_def: BattleUnit, rng: RandomNumberGenerator) -> int:
	"""Saltpeter doubles damage to adjacent units on hit."""
	var total_kills := 0
	var base_dmg := atk.get_base_damage()
	var explosion_dmg := int(base_dmg * GameSettings.SALTPETER_EXPLOSION_DMG_MULT)
	var neighbors := HexUtils.get_all_neighbors(original_def.cell)
	for nb in neighbors:
		for side_str in ["attacker", "defender"]:
			var victim := get_unit_at(nb, side_str)
			if victim == null or not victim.is_alive():
				continue
			if victim == atk:
				continue
			var hp := maxi(1, victim.get_hp())
			var kills := maxi(1, explosion_dmg / hp)
			kills = mini(kills, victim.get_count())
			victim.set_count(victim.get_count() - kills)
			total_kills += kills
			if victim.get_count() <= 0:
				_kill_unit(victim)
	return total_kills


func do_move(unit: BattleUnit, target: Vector2i) -> void:
	var dist := HexUtils.hex_distance(unit.cell, target)
	unit.distance_moved_this_turn += dist
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


func force_end(winner: String) -> void:
	battle_over = true
	battle_winner = winner

# ==================== ПРОВЕРКА КОНЦА БОЯ ====================
func check_end() -> String:
	if battle_over:
		return battle_winner

	if _attacker_alive_count == 0:
		force_end("defender")
	elif _defender_alive_count == 0:
		force_end("attacker")

	return battle_winner


func get_survivors(side: String) -> Array[UnitStack]:
	var r: Array[UnitStack] = []
	var units := attacker_units if side == "attacker" else defender_units
	for u in units:
		if u.is_alive():
			r.append(u.stack)
	return r


func get_retreat_survivors(side: String) -> Array[UnitStack]:
	var all_survivors: Array[UnitStack] = []
	var units := get_units_by_side(side)

	for u in units:
		if u.is_alive():
			var stack: UnitStack = u.stack.duplicate_stack()
			stack.count = maxi(
				1,
				int(ceil(float(stack.count) * BattleRules.RETREAT_SURVIVAL_RATIO))
			)
			all_survivors.append(stack)

	# Sort by count descending and keep top 2
	all_survivors.sort_custom(func(a: UnitStack, b: UnitStack): return a.count > b.count)
	var result: Array[UnitStack] = []
	for i in mini(2, all_survivors.size()):
		result.append(all_survivors[i])

	return result


func set_hero_bonuses(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> void:
	attacker_hero_bonus = _normalize_hero_bonus(attacker_bonus)
	defender_hero_bonus = _normalize_hero_bonus(defender_bonus)


func _normalize_hero_bonus(bonus: Dictionary) -> Dictionary:
	return {
		"attack": int(bonus.get("attack", 0)),
		"defense": int(bonus.get("defense", 0)),
		"spell_power": int(bonus.get("spell_power", 0)),
		"knowledge": int(bonus.get("knowledge", 0)),
	}
