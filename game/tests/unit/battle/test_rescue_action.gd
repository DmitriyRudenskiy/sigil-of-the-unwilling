extends BaseTest

## battle-unit-vitals шаг 5 (D5): «Спасение» — действие, которым персонаж
## поднимает умирающего товарища. Спасатель проверяет высшую ментальную
## характеристику (INT/WIS/CHA) против DC 10: успех — тот стабилен, nat 20 —
## приходит в себя на 1 HP, провал не меняет ничего, кроме потраченного действия.

const DC := BattleActionResolver.RESCUE_DC


func _character(
	key: String,
	uid: int,
	side: BattleState.Side,
	cell: Vector2i,
	intelligence: int = 10
) -> BattleState.BattleUnit:
	var stack := UnitStack.new(UnitStats.new(key, key.to_upper(), 1, 1, 10, 5, 0, []), 1)
	var unit := BattleState.BattleUnit.new(stack)
	var p := DnDCombatantProfile.new(key, key.to_upper())
	p.max_hp = 10
	p.abilities = DNDAbilityScores.new(10, 10, 10, intelligence, 10, 10)
	unit.dnd_profile = p
	unit.dnd_current_hp = 10
	unit.uid = uid
	unit.side = side
	unit.cell = cell
	return unit


func _stack_unit(
	key: String,
	uid: int,
	side: BattleState.Side,
	cell: Vector2i
) -> BattleState.BattleUnit:
	var unit := BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new(key, key.to_upper(), 1, 1, 1, 4, 0, []), 5)
	)
	unit.uid = uid
	unit.side = side
	unit.cell = cell
	return unit


## Слева — умирающий и спасатель вплотную к нему, справа — враг, чтобы бой не
## закончился в момент, когда тест ещё не начался.
func _state(intelligence: int = 10) -> BattleState:
	var bs := BattleState.new()
	var dying_cell := Vector2i(4, 4)
	var dying := _character("rescue_dying", 1, BattleState.Side.ATTACKER, dying_cell)
	var rescuer_cell: Vector2i = HexUtils.get_all_neighbors(dying_cell, bs.hex_shift_right)[0]
	var rescuer := _character(
		"rescue_hero", 2, BattleState.Side.ATTACKER, rescuer_cell, intelligence
	)
	var foe := _stack_unit("rescue_foe", 3, BattleState.Side.DEFENDER, Vector2i(12, 4))
	bs.attacker_units.append(dying)
	bs.attacker_units.append(rescuer)
	bs.defender_units.append(foe)
	bs._attacker_alive_count = 2
	bs._defender_alive_count = 1
	bs._rebuild_unit_grid()
	dying.dnd_current_hp = 0
	BattleActionResolver.kill_unit(bs, dying)
	return bs


func _pair(bs: BattleState) -> Array[BattleState.BattleUnit]:
	return [bs.attacker_units[1], bs.attacker_units[0]]


func test_rescue_stabilizes_on_success() -> void:
	var bs := _state()
	var pair := _pair(bs)
	var result := BattleActionResolver.rescue_unit(bs, pair[0], pair[1], DC)
	assert_str(str(result.get("result", ""))).is_equal("stabilized")
	assert_bool(pair[1].is_stable()).is_true()
	assert_bool(pair[1].is_dying()).is_false()


func test_rescue_modifier_uses_highest_mental_score() -> void:
	var bs := _state(20)
	var pair := _pair(bs)
	var result := BattleActionResolver.rescue_unit(bs, pair[0], pair[1], DC - 5)
	assert_int(int(result["d20"])).is_equal(DC - 5)
	assert_bool(pair[1].is_stable()).is_true()


func test_natural_twenty_wakes_the_dying() -> void:
	var bs := _state()
	var pair := _pair(bs)
	var result := BattleActionResolver.rescue_unit(bs, pair[0], pair[1], 20)
	assert_str(str(result.get("result", ""))).is_equal("rescued_wakes")
	assert_bool(pair[1].is_alive()).is_true()
	assert_int(pair[1].dnd_current_hp).is_equal(1)
	assert_int(bs._attacker_alive_count).is_equal(2)


func test_failure_changes_nothing_but_costs_the_action() -> void:
	var bs := _state()
	var pair := _pair(bs)
	var result := BattleActionResolver.rescue_unit(bs, pair[0], pair[1], 1)
	assert_str(str(result.get("result", ""))).is_equal("failed")
	assert_bool(pair[1].is_dying()).is_true()
	assert_bool(pair[0].has_moved).is_true()


func test_rescue_requires_adjacent_dying_ally() -> void:
	var bs := _state()
	var pair := _pair(bs)
	var rescuer: BattleState.BattleUnit = pair[0]
	var dying: BattleState.BattleUnit = pair[1]
	assert_dict(BattleActionResolver.rescue_unit(bs, rescuer, bs.defender_units[0], 20)).is_empty()
	# Стабилизированного спасать не от чего.
	bs.stabilize_downed_unit(dying)
	assert_dict(BattleActionResolver.rescue_unit(bs, rescuer, dying, 20)).is_empty()
	# Мёртвого не вернуть этим действием вовсе.
	var dead := _character("rescue_dead", 9, BattleState.Side.ATTACKER, Vector2i(6, 6))
	bs.attacker_units.append(dead)
	bs._rebuild_unit_grid()
	dead.dnd_current_hp = 0
	BattleActionResolver.kill_unit(bs, dead)
	bs.finish_downed_unit(dead)
	assert_dict(BattleActionResolver.rescue_unit(bs, rescuer, dead, 20)).is_empty()


func test_rescue_requires_adjacency() -> void:
	var bs := _state()
	var pair := _pair(bs)
	pair[0].cell = Vector2i(12, 12)
	assert_dict(BattleActionResolver.rescue_unit(bs, pair[0], pair[1], 20)).is_empty()
	assert_bool(pair[1].is_dying()).is_true()


func test_rescue_needs_a_fresh_actor() -> void:
	var bs := _state()
	var pair := _pair(bs)
	pair[0].has_moved = true
	assert_dict(BattleActionResolver.rescue_unit(bs, pair[0], pair[1], 20)).is_empty()
	assert_bool(pair[1].is_dying()).is_true()


## Стеку проверять характеристику нечем — спасает только персонаж.
func test_plain_stack_cannot_rescue() -> void:
	var bs := _state()
	var dying: BattleState.BattleUnit = bs.attacker_units[0]
	var stack := _stack_unit("rescue_stack", 8, BattleState.Side.ATTACKER, dying.cell)
	stack.cell = HexUtils.get_all_neighbors(dying.cell, bs.hex_shift_right)[0]
	bs.attacker_units.append(stack)
	bs._rebuild_unit_grid()
	assert_dict(BattleActionResolver.rescue_unit(bs, stack, dying, 20)).is_empty()
	assert_bool(dying.is_dying()).is_true()


## Чужой ход: пока исполнитель не ждёт ввода игрока, действие невозможно.
func test_rescue_outside_player_input_is_ignored() -> void:
	var bs := _state()
	var pair := _pair(bs)
	var executor := auto_free(BattleTurnExecutor.new()) as BattleTurnExecutor
	executor.name = "RescueExecutor"
	add_child(executor)
	executor.setup(bs, BattleAI.new(), {})
	executor.request_rescue(pair[1])
	assert_bool(pair[1].is_dying()).is_true()
	assert_bool(pair[0].has_moved).is_false()
