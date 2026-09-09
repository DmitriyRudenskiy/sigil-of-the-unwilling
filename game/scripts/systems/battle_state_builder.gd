class_name BattleStateBuilder
extends RefCounted

var _attacker_stacks: Array = []
var _defender_stacks: Array = []
var _attacker_artifact_mods: Dictionary = {}
var _defender_artifact_mods: Dictionary = {}
var _attacker_bonus: Dictionary = {}
var _defender_bonus: Dictionary = {}
var _has_hero_bonuses := false
var _max_units_per_side: int = GameNumbers.MAX_UNITS_PER_SIDE

func set_attacker_army(stacks: Array) -> BattleStateBuilder:
	_attacker_stacks = stacks
	return self

func set_defender_army(stacks: Array) -> BattleStateBuilder:
	_defender_stacks = stacks
	return self

func set_attacker_artifact_mods(mods: Dictionary) -> BattleStateBuilder:
	_attacker_artifact_mods = mods
	return self

func set_defender_artifact_mods(mods: Dictionary) -> BattleStateBuilder:
	_defender_artifact_mods = mods
	return self

func set_hero_bonuses(attacker_bonus: Dictionary, defender_bonus: Dictionary) -> BattleStateBuilder:
	_attacker_bonus = attacker_bonus
	_defender_bonus = defender_bonus
	_has_hero_bonuses = true
	return self

func build() -> BattleState:
	var state := BattleState.new()
	build_into(state)
	return state

func build_into(state: BattleState) -> BattleState:
	state._uid = 0

	var attacker_units: Array[BattleState.BattleUnit] = _build_units(state, _attacker_stacks, true)
	var defender_units: Array[BattleState.BattleUnit] = _build_units(state, _defender_stacks, false)

	state._attacker_alive_count = attacker_units.size()
	state._defender_alive_count = defender_units.size()

	_apply_artifact_effects(attacker_units, _attacker_artifact_mods)
	_apply_artifact_effects(defender_units, _defender_artifact_mods)

	if _has_hero_bonuses:
		state.set_hero_bonuses(_attacker_bonus, _defender_bonus)

	state.attacker_units = attacker_units
	state.defender_units = defender_units

	state._rebuild_unit_grid()
	state.invalidate_board_cache()
	state.check_end()

	return state

func _build_units(state: BattleState, stacks: Array, is_atk: bool) -> Array[BattleState.BattleUnit]:
	var units: Array[BattleState.BattleUnit] = []
	var max_stacks := _max_units_per_side
	var current_col := 0 if is_atk else BattleState.BW - 1
	var col_step := 1 if is_atk else -1
	var current_row := 0

	for i in stacks.size():
		if i >= max_stacks:
			GameLogger.battle(
				"%s: лимит юнитов в бою (%d) достигнут."
				% ["Атакующие" if is_atk else "Защитники", max_stacks])
			break
		var input_stack = stacks[i]
		if input_stack == null or not input_stack.is_alive():
			continue

		var stack: UnitStack = input_stack.duplicate_stack()
		if stack == null or stack.stats == null:
			push_error("[Battle] Invalid UnitStack received")
			continue

		var placed := false
		while current_col >= 0 and current_col < BattleState.BW:
			while current_row < BattleState.BH:
				if not _cell_taken(current_col, current_row, units):
					placed = true
					break
				current_row += 1
			if placed:
				break
			current_col += col_step
			current_row = 0

		if not placed:
			push_error("[BattleState] Cannot place stack %d: no free cells in deployment zone." % i)
			continue

		var unit := BattleState.BattleUnit.new(stack)
		unit.cell = Vector2i(current_col, current_row)
		unit.side = BattleState.Side.ATTACKER if is_atk else BattleState.Side.DEFENDER
		unit.alive = true
		unit.has_moved = false
		unit.max_count = stack.count
		unit.uid = state._uid
		state._uid += 1
		units.append(unit)

		current_row += 1
		if current_row >= BattleState.BH:
			current_row = 0
			current_col += col_step

	return units

func _cell_taken(col: int, row: int, units: Array) -> bool:
	for u in units:
		if u.cell.x == col and u.cell.y == row:
			return true
	return false

func _apply_artifact_effects(units: Array[BattleState.BattleUnit], mods: Dictionary) -> void:
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

static func from_existing(
	state: BattleState,
	attacker_stacks: Array,
	defender_stacks: Array
) -> BattleState:
	var builder := BattleStateBuilder.new()
	builder.set_attacker_army(attacker_stacks)
	builder.set_defender_army(defender_stacks)
	builder.build_into(state)
	return state
