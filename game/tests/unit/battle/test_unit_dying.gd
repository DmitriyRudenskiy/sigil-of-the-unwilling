extends BaseTest

## battle-unit-vitals шаг 4 (D4/D6): персонаж, упавший на 0 HP, не умирает —
## он «умирает» со смертельными бросками. Тело остаётся в бою (слот в очереди и
## свой гекс), но действовать и быть целью обычной атаки не может. Настоящая смерть
## — три провала спасброска. Победа считается по «нечем действовать», а не «все мертвы».

## Исполнитель с подставными d20: спасброски случайны, а тесты — нет.
class ScriptedExecutor extends BattleTurnExecutor:
	var scripted: Array[int] = []
	var rolls: int = 0

	func _roll_death_save(unit: BattleState.BattleUnit) -> DNDDeathSaves.DeathSaveResult:
		var d20: int = scripted[min(rolls, scripted.size() - 1)]
		rolls += 1
		return unit.death_saves.roll(null, d20)


func _character(hp: int = 10) -> BattleState.BattleUnit:
	var stack := UnitStack.new(UnitStats.new("dying_hero", "Dying Hero", 1, 1, 10, 5, 0, []), 1)
	var unit := BattleState.BattleUnit.new(stack)
	var p := DnDCombatantProfile.new("dying_hero", "Dying Hero")
	p.max_hp = hp
	unit.dnd_profile = p
	unit.dnd_current_hp = hp
	return unit


func _stack_unit(count: int = 5) -> BattleState.BattleUnit:
	return BattleState.BattleUnit.new(
		UnitStack.new(UnitStats.new("dying_gob", "Dying Goblin", 1, 1, 1, 4, 0, []), count)
	)


## 1 персонаж слева против 1 стека справа — минимальный бой без билдера армий.
func _state() -> BattleState:
	var bs := BattleState.new()
	var hero := _character()
	hero.cell = Vector2i(1, 3)
	hero.uid = 1
	var gob := _stack_unit()
	gob.cell = Vector2i(5, 3)
	gob.uid = 2
	gob.side = BattleState.Side.DEFENDER
	bs.attacker_units.append(hero)
	bs.defender_units.append(gob)
	bs._attacker_alive_count = 1
	bs._defender_alive_count = 1
	bs._rebuild_unit_grid()
	return bs


func _executor(bs: BattleState, scripted: Array[int]) -> ScriptedExecutor:
	var executor = auto_free(ScriptedExecutor.new())
	executor.name = "DyingExecutor"
	executor.scripted = scripted
	add_child(executor)
	executor.setup(bs, BattleAI.new(), {})
	return executor


## Гасим асинхронный хвост перехода хода после спасбросков.
func _stop_coroutine(executor: BattleTurnExecutor) -> void:
	executor._state = BattleTurnExecutor.State.BATTLE_OVER


func _down(bs: BattleState, unit: BattleState.BattleUnit) -> void:
	unit.dnd_current_hp = 0
	BattleActionResolver.kill_unit(bs, unit)


func test_zero_hp_character_goes_dying_not_dead() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	assert_bool(hero.is_dying()).is_true()
	assert_bool(hero.is_downed()).is_true()
	assert_bool(hero.alive).is_true()
	assert_bool(hero.is_alive()).is_false()
	assert_bool(hero.in_battle()).is_true()
	assert_bool(hero.can_act()).is_false()


func test_plain_stack_still_dies() -> void:
	var bs := _state()
	var gob: BattleState.BattleUnit = bs.defender_units[0]
	gob.set_count(0)
	BattleActionResolver.kill_unit(bs, gob)
	assert_bool(gob.alive).is_false()
	assert_bool(gob.is_downed()).is_false()
	assert_bool(gob.in_battle()).is_false()


func test_dying_unit_keeps_its_queue_slot() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	bs.build_queue()
	assert_int(bs.turn_queue.size()).is_equal(2)
	assert_bool(bs.turn_queue.has(hero)).is_true()
	bs.turn_idx = 0
	bs._normalize_active_unit()
	assert_bool(bs.active_unit == hero).is_true()


func test_dying_unit_is_not_a_normal_attack_target() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	var gob: BattleState.BattleUnit = bs.defender_units[0]
	_down(bs, hero)
	assert_bool(bs.get_unit_at(hero.cell, BattleState.Side.ATTACKER) == null).is_true()
	assert_dict(BattleActionResolver.apply_attack(bs, gob, hero, true)).is_empty()
	assert_dict(BattleActionResolver.apply_attack(bs, hero, gob, true)).is_empty()


func test_body_still_occupies_its_hex() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	assert_bool(bs._all_units_cells.has(hero.cell)).is_true()


func test_three_failures_kill() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	hero.death_saves.failures = 2
	var executor := _executor(bs, [1])
	executor._run_death_saves(hero)
	assert_int(hero.death_saves.state).is_equal(DNDDeathSaves.State.DEAD)
	assert_bool(hero.alive).is_false()
	assert_bool(hero.in_battle()).is_false()
	_stop_coroutine(executor)


func test_natural_twenty_recovers_one_hp() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	var executor := _executor(bs, [20])
	executor._run_death_saves(hero)
	assert_bool(hero.is_alive()).is_true()
	assert_int(hero.dnd_current_hp).is_equal(1)
	assert_bool(hero.can_act()).is_true()
	assert_int(bs._attacker_alive_count).is_equal(1)
	_stop_coroutine(executor)


func test_three_successes_stabilize() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	hero.death_saves.successes = 2
	var executor := _executor(bs, [10])
	executor._run_death_saves(hero)
	assert_int(hero.death_saves.state).is_equal(DNDDeathSaves.State.STABLE)
	assert_bool(hero.is_stable()).is_true()
	assert_bool(hero.can_act()).is_false()
	_stop_coroutine(executor)


## Стабилизированный хода не имеет вовсе: бросков нет, очередь идёт дальше.
func test_stable_unit_does_not_roll() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	hero.death_saves.stabilize()
	var executor := _executor(bs, [1])
	executor._run_death_saves(hero)
	assert_int(executor.rolls).is_equal(0)
	assert_int(hero.death_saves.state).is_equal(DNDDeathSaves.State.STABLE)
	_stop_coroutine(executor)


func test_rescue_stabilizes_dying_ally() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	assert_bool(bs.stabilize_downed_unit(hero)).is_true()
	assert_bool(hero.is_stable()).is_true()
	assert_bool(hero.is_dying()).is_false()
	# Стабилизированного повторно «спасать» не за что, здорового — тем более.
	assert_bool(bs.stabilize_downed_unit(hero)).is_false()
	assert_bool(bs.stabilize_downed_unit(bs.defender_units[0])).is_false()


func test_get_downed_units_lists_bodies() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	assert_int(bs.get_downed_units(BattleState.Side.ATTACKER).size()).is_equal(0)
	_down(bs, hero)
	var downed: Array[BattleState.BattleUnit] = bs.get_downed_units(BattleState.Side.ATTACKER)
	assert_int(downed.size()).is_equal(1)
	assert_bool(downed[0] == hero).is_true()


## D6: сторона, у которой остались только умирающие, проигрывает — «нечем действовать».
func test_side_with_only_dying_units_loses() -> void:
	var bs := _state()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	assert_bool(bs.battle_over).is_true()
	assert_int(bs.battle_winner).is_equal(BattleState.Side.DEFENDER)


## ...но если на стороне есть кем действовать, бой продолжается.
func test_battle_continues_while_someone_can_act() -> void:
	var bs := _state()
	var ally := _character(8)
	ally.cell = Vector2i(2, 3)
	ally.uid = 3
	bs.attacker_units.append(ally)
	bs._attacker_alive_count = 2
	bs._rebuild_unit_grid()
	var hero: BattleState.BattleUnit = bs.attacker_units[0]
	_down(bs, hero)
	assert_bool(bs.battle_over).is_false()
	assert_int(bs._attacker_alive_count).is_equal(1)
