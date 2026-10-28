extends BaseTest

## Контраст боевой последовательности атаки (`BattleAttackSequence`, T-227 С-4).
##
## Машина на 194 строки не называлась ни одним тестом, хотя ею живёт весь удар:
## `BattleTurnExecutor` только перекладывает стрики в `next_strike()` и решает по
## `is_retaliating()/strikes_left()/can_retaliate()`, можно ли бить дальше. Проверки
## поэтому не «урон нанесён», а переходы состояний и отказ от действия: сколько
## стриков выдано, что считается выстрелом, когда контратака доступна и когда она
## отменена, и кто получает лишний ход за Триумф.
##
## Исполнитель — записчик: машина зовёт `_on_action_completed()`, `_transition_to()`
## и `_run_ai_turn()`, и именно эти вызовы (а не внутренности исполнителя) и есть
## контракт. Урон настоящий, но проверяется только выживаемость сторон: результат
## броска здесь не предмет теста, поэтому защита заведомо выше атаки.

const DEFENSE := 20
const SIDE_COUNT := 20


## Записывает обращения машины к исполнителю, ничего не исполняя.
class RecordingExecutor extends BattleTurnExecutor:

	var completed := 0
	var transitions: Array = []
	var ai_turns := 0
	var attacks: Array = []

	func _on_action_completed() -> void:
		completed += 1

	func _transition_to(new_state: BattleTurnExecutor.State) -> void:
		transitions.append(new_state)

	func _run_ai_turn() -> void:
		ai_turns += 1


func _unit(
	key: String,
	uid: int,
	side: BattleState.Side,
	cell: Vector2i,
	tags: Array = []
) -> BattleState.BattleUnit:
	var stack := UnitStack.new(
		UnitStats.new(key, key.to_upper(), 1, 1, 10, 5, DEFENSE, tags), SIDE_COUNT
	)
	var unit := BattleState.BattleUnit.new(stack)
	unit.uid = uid
	unit.side = side
	unit.cell = cell
	return unit


## Персонаж (D&D-анкета): в отличие от стека, удар его не убивает, а роняет без
## сознания — юнит остаётся в сетке поля.
func _character(
	key: String,
	uid: int,
	side: BattleState.Side,
	cell: Vector2i
) -> BattleState.BattleUnit:
	var stack := UnitStack.new(
		UnitStats.new(key, key.to_upper(), 1, 1, 10, 5, DEFENSE, []), 1
	)
	var unit := BattleState.BattleUnit.new(stack)
	var profile := DnDCombatantProfile.new(key, key.to_upper())
	profile.max_hp = 10
	profile.abilities = DNDAbilityScores.new(10, 10, 10, 10, 10, 10)
	unit.dnd_profile = profile
	unit.dnd_current_hp = 10
	unit.uid = uid
	unit.side = side
	unit.cell = cell
	return unit


func _state(att: BattleState.BattleUnit, dfn: BattleState.BattleUnit) -> BattleState:
	var bs := BattleState.new()
	bs.attacker_units.append(att)
	bs.defender_units.append(dfn)
	bs._attacker_alive_count = 1
	bs._defender_alive_count = 1
	bs._rebuild_unit_grid()
	return bs


## Пара «атакующий в (4,4) + защитник вплотную»: соседняя клетка берётся из
## `HexUtils`, чтобы тест не зависел от принятого сдвига ряда.
func _melee_pair(att_key: String, dfn_key: String, att_tags: Array = []) -> BattleState:
	var probe := BattleState.new()
	var near := Vector2i(4, 4)
	return _state(
		_unit(att_key, 1, BattleState.Side.ATTACKER, near, att_tags),
		_unit(
			dfn_key, 2, BattleState.Side.DEFENDER,
			HexUtils.get_all_neighbors(near, probe.hex_shift_right)[0]
		)
	)


func _seq(bs: BattleState, executor: BattleTurnExecutor) -> BattleAttackSequence:
	var seq := BattleAttackSequence.new()
	seq.setup(bs, executor)
	return seq


func _executor() -> RecordingExecutor:
	var executor: RecordingExecutor = auto_free(RecordingExecutor.new()) as RecordingExecutor
	add_child(executor)
	executor.execute_attack.connect(
		func(atk: BattleState.BattleUnit, dfn: BattleState.BattleUnit, result: Dictionary) -> void:
			executor.attacks.append([atk, dfn, result])
	)
	return executor


func test_melee_attack_hands_the_second_strike_back_to_the_caller() -> void:
	var bs := _melee_pair("seq_att", "seq_dfm")
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, bs.defender_units[0])

	assert_bool(seq.has_active()).override_failure_message(
		"удар не активен сразу после start_attack").is_true()
	assert_that(seq.strikes_left()).override_failure_message(
		"одиночный удар не должен оставлять стриков").is_equal(0)
	assert_that(executor.attacks.size()).is_equal(1)
	assert_bool(seq.is_retaliating()).is_false()

	# Второй вызов — это «анимация доиграла»: стриков нет, машина обязана закрыть ход.
	seq.next_strike()
	assert_bool(seq.has_active()).override_failure_message(
		"после исчерпания стриков удар остался активным").is_false()
	assert_that(executor.completed).override_failure_message(
		"закрытие удара не сообщило исполнителю о завершении действия").is_equal(1)


func test_double_strike_grants_exactly_one_extra_strike() -> void:
	var bs := _melee_pair("seq_double", "seq_dfm_d", ["double_strike"])
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)
	assert_that(seq.strikes_left()).override_failure_message(
		"double_strike обязан оставить ровно один из двух стриков").is_equal(1)
	assert_that(executor.attacks.size()).is_equal(1)

	seq.next_strike()
	assert_that(seq.strikes_left()).is_equal(0)
	assert_that(executor.attacks.size()).override_failure_message(
		"второй стрик не прошёл через resolver").is_equal(2)

	seq.next_strike()
	assert_bool(seq.has_active()).is_false()
	assert_that(executor.attacks.size()).override_failure_message(
		"третий удар там, где два: тег прочитан как счётчик, а не как пара").is_equal(2)


## Выстрел дальше `GameNumbersBattle.RANGED_MAX_RANGE` — не «удар послабее», а
## отменённое действие: машина обязана вернуть ход, не входя в анимацию.
func test_ranged_shot_beyond_line_of_sight_is_cancelled() -> void:
	var bs := _state(
		_unit("seq_archer", 1, BattleState.Side.ATTACKER, Vector2i(0, 0), ["ranged"]),
		_unit("seq_far", 2, BattleState.Side.DEFENDER, Vector2i(0, 9))
	)
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)

	assert_bool(seq.has_active()).override_failure_message(
		"выстрел за предел дальности превратился в удар").is_false()
	assert_that(executor.completed).override_failure_message(
		"отменённый выстрел не вернул ход").is_equal(1)
	assert_that(executor.attacks.size()).is_equal(0)


## Тот же лучник вплотную: «дистанция > 1» не выполняется, значит это драка, и именно
## она открывает право на контратаку (иначе «выстрел в упор» отнимал бы ответный удар).
func test_ranged_shooter_in_melee_fights_melee() -> void:
	var bs := _melee_pair("seq_archer2", "seq_near", ["ranged"])
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)

	assert_that(executor.attacks.size()).is_equal(1)
	assert_bool(dfn.is_alive()).override_failure_message(
		"питомец умер от одного удара — тест про переходы больше не валиден").is_true()
	assert_bool(seq.can_retaliate()).override_failure_message(
		"выстрел в упор не стал ближним — контратаки нет").is_true()


func test_retaliation_is_charged_to_the_survivor() -> void:
	var bs := _melee_pair("seq_att2", "seq_dfm2")
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)
	assert_bool(dfn.is_alive()).is_true()
	assert_bool(seq.can_retaliate()).is_true()

	seq.start_retaliation()

	assert_bool(seq.is_retaliating()).override_failure_message(
		"фаза контратаки не помечена — исполнитель закроет её как обычный удар").is_true()
	assert_object(seq.attacker()).is_equal(dfn)
	assert_object(seq.defender()).is_equal(att)
	assert_that(seq.strikes_left()).override_failure_message(
		"контратака обязана давать ровно один стрик").is_equal(0)
	assert_bool(dfn.has_retaliated).override_failure_message(
		"контратака не помечена использованной").is_true()
	assert_that(executor.attacks.size()).is_equal(2)
	assert_bool(att.has_retaliated).override_failure_message(
		"контратака засчитана тому, кто её не наносил").is_false()


func test_retaliation_refuses_when_the_counterstriker_cannot_strike() -> void:
	var bs := _melee_pair("seq_noret", "seq_dfm3", ["no_retaliation"])
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)
	assert_bool(dfn.is_alive()).is_true()
	assert_bool(seq.can_retaliate()).override_failure_message(
		"тег no_retaliation у атакующего не закрыл контратаку").is_false()


func test_retaliation_refuses_a_dead_counterstriker() -> void:
	var bs := _melee_pair("seq_att3", "seq_dfm4")
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)
	BattleActionResolver.kill_unit(bs, dfn)
	assert_bool(seq.can_retaliate()).override_failure_message(
		"мёртвый защитник получил право контратаковать").is_false()


## Без активной пары машина не имеет права ни на что: `next_strike` и `can_retaliate`
## приходят из колбэка анимации, который может догнать уже закрытый удар.
func test_idle_sequence_answers_refusally() -> void:
	var bs := _melee_pair("seq_idle1", "seq_idle2")
	var executor := _executor()
	var seq := _seq(bs, executor)

	assert_bool(seq.has_active()).is_false()
	assert_bool(seq.can_retaliate()).is_false()
	assert_object(seq.attacker()).is_null()
	assert_object(seq.defender()).is_null()

	seq.next_strike()
	assert_that(executor.completed).override_failure_message(
		"пустой next_strike не закрыл действие").is_equal(1)
	assert_that(executor.attacks.size()).is_equal(0)


func test_attack_without_a_living_target_completes_the_action() -> void:
	var bs := _melee_pair("seq_att4", "seq_dead")
	var att: BattleState.BattleUnit = bs.attacker_units[0]
	var dfn: BattleState.BattleUnit = bs.defender_units[0]
	BattleActionResolver.kill_unit(bs, dfn)
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, dfn)
	assert_bool(seq.has_active()).is_false()
	assert_that(executor.completed).is_equal(1)

	seq.start_attack(att, null)
	assert_that(executor.completed).override_failure_message(
		"удар по null-цели не вернул ход").is_equal(2)
	assert_that(executor.attacks.size()).is_equal(0)


## Лишний ход за моралью (T17/D2): не процент, а детерминированный Триумф последнего
## удара. Проверяются обе половины: чужой удар и чужая зона — отказа, свой Триумф —
## ход тому же игроку.
func test_morale_extra_turn_needs_the_units_own_triumph() -> void:
	var bs := _melee_pair("seq_morale", "seq_dfm5")
	var unit: BattleState.BattleUnit = bs.attacker_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)
	bs.active_unit = unit
	bs.is_player_turn = true
	unit.has_moved = true

	assert_bool(seq.try_morale_extra_turn()).override_failure_message(
		"без последнего удара выдан лишний ход").is_false()
	assert_bool(unit.has_moved).is_true()

	# Свой удар, но не Триумф: тот же юнит, другая зона — отказа.
	seq._last_strike_unit = unit
	seq._last_strike_zone = BattleRules.ZONE_SUCCESS
	assert_bool(seq.try_morale_extra_turn()).override_failure_message(
		"свой удар не в зоне Триумфа не должен давать ход").is_false()

	# Триумф, но чужой: детерминированная мораль привязана к последнему удару
	# именно этого юнита (T17/D2), иначе один триумфатор кормил бы ходом всех.
	seq._last_strike_unit = bs.defender_units[0]
	seq._last_strike_zone = BattleRules.ZONE_TRIUMPH
	assert_bool(seq.try_morale_extra_turn()).override_failure_message(
		"лишний ход выдан за чужой удар").is_false()

	# Обе половины сошлись: свой юнит и его Триумф.
	seq._last_strike_unit = unit
	assert_bool(seq.try_morale_extra_turn()).override_failure_message(
		"свой Триумф не дал лишний ход").is_true()
	assert_bool(unit.has_moved).override_failure_message(
		"лишний ход не сбросил флаг движения").is_false()
	assert_that(executor.transitions.size()).is_equal(1)
	assert_that(int(executor.transitions[0])).is_equal(
		int(BattleTurnExecutor.State.WAITING_INPUT))


func test_morale_extra_turn_hands_the_turn_to_ai_on_enemy_side() -> void:
	var bs := _state(
		_unit("seq_morale2", 1, BattleState.Side.DEFENDER, Vector2i(4, 4)),
		_unit("seq_dfm6", 2, BattleState.Side.ATTACKER, Vector2i(4, 5))
	)
	var unit: BattleState.BattleUnit = bs.defender_units[0]
	var executor := _executor()
	var seq := _seq(bs, executor)
	bs.active_unit = unit
	bs.is_player_turn = false
	seq._last_strike_unit = unit
	seq._last_strike_zone = BattleRules.ZONE_TRIUMPH

	assert_bool(seq.try_morale_extra_turn()).is_true()
	assert_that(executor.ai_turns).override_failure_message(
		"лишний ход врага не ушёл в ИИ-ход").is_equal(1)
	assert_that(executor.transitions.size()).override_failure_message(
		"вражеский лишний ход ещё и переключил фазу игрока").is_equal(0)


## Ментальный иммунитет: лишний ход — воздействие на разум, поэтому нежить,
## элементаль, иммунный к ментальному и дракон его не получают ни при какой зоне.
func test_morale_extra_turn_skips_mind_immune_units() -> void:
	for tag in ["undead", "elemental", "mind_immune", "dragon"]:
		var bs := _melee_pair("seq_immune_" + tag, "seq_dfm7_" + tag, [tag])
		var unit: BattleState.BattleUnit = bs.attacker_units[0]
		var executor := _executor()
		var seq := _seq(bs, executor)
		bs.active_unit = unit
		bs.is_player_turn = true
		seq._last_strike_unit = unit
		seq._last_strike_zone = BattleRules.ZONE_TRIUMPH
		assert_bool(seq.try_morale_extra_turn()).override_failure_message(
			"тег %s получил лишний ход за моралью" % tag).is_false()
		assert_that(executor.transitions.size()).is_equal(0)


## Соседство смотрит только на живых врагов своей стороны: от него зависит, деградирует
## ли выстрел в драку и есть ли смысл в контратаке.
func test_adjacency_looks_only_at_living_enemies() -> void:
	var probe := BattleState.new()
	var cell := Vector2i(4, 4)
	var neighbour_cell: Vector2i = HexUtils.get_all_neighbors(cell, probe.hex_shift_right)[0]
	var att := _unit("seq_adj1", 1, BattleState.Side.ATTACKER, cell)
	var dfn := _unit("seq_adj2", 2, BattleState.Side.DEFENDER, neighbour_cell)
	var far := _unit("seq_adj3", 3, BattleState.Side.DEFENDER, Vector2i(0, 0))
	var bs := _state(att, dfn)
	bs.defender_units.append(far)
	bs._defender_alive_count = 2
	bs._rebuild_unit_grid()
	var seq := _seq(bs, _executor())

	assert_bool(seq.has_adjacent_enemy(att)).override_failure_message(
		"живой враг вплотную не замечен").is_true()
	assert_bool(seq.has_adjacent_enemy(far)).override_failure_message(
		"дальний враг считается соседним").is_false()
	BattleActionResolver.kill_unit(bs, dfn)
	assert_bool(seq.has_adjacent_enemy(att)).override_failure_message(
		"мёртвый враг дал соседство").is_false()
	assert_bool(seq.has_adjacent_enemy(null)).is_false()


## Соседство обязано смотреть и на «кто в сетке, но не в строю»: персонаж, поваленный
## без сознания, остаётся на клетке (его надо спасать), но соседом для правил боя не
## является. Иначе тело в клетке рядом отменяет выстрел и поднимает контратаку у того,
## кто бить не может.
func test_adjacency_ignors_a_downed_character() -> void:
	var probe := BattleState.new()
	var cell := Vector2i(4, 4)
	var att := _unit("seq_down1", 1, BattleState.Side.ATTACKER, cell)
	var sleeper := _character(
		"seq_down2", 2, BattleState.Side.DEFENDER,
		HexUtils.get_all_neighbors(cell, probe.hex_shift_right)[0]
	)
	var bs := _state(att, sleeper)
	var seq := _seq(bs, _executor())

	assert_bool(seq.has_adjacent_enemy(att)).override_failure_message(
		"живой персонаж-защитник не замечен как сосед").is_true()

	BattleActionResolver.kill_unit(bs, sleeper)
	assert_bool(sleeper.is_downed()).override_failure_message(
		"персонаж не упал без сознания — проверка сетки теряет смысл").is_true()
	assert_bool(seq.has_adjacent_enemy(att)).override_failure_message(
		"лежащий без сознания враг дал соседство").is_false()


## Выстрел по цели, когда вплотную к стрелку стоит другой враг: правило
## `not adjacent_enemy` отдаёт такой удар в ближний бой — сколько бы клеток до цели
## ни было, — и цель получает право на ответный удар. Мутант M3 (убрать соседство из
## условия) зелёный без этой проверки, потому что «в упор» и так не выстрел.
## Дистанцию здесь не проверяют: «бьёт ли вообще в такую клетку» — забота входа
## `BattleTurnExecutor.request_attack` (distance != 1 -> return), машина удара про
## переходы состояний и про то, чем считается удар. Снимать удар с цели в 9 клетках
## тестом нельзя: это зафиксировало бы дыру вместо границы ответственности.
func test_shot_with_another_enemy_adjacent_is_fought_as_melee() -> void:
	var probe := BattleState.new()
	var near := Vector2i(4, 4)
	var att := _unit("seq_shooter", 1, BattleState.Side.ATTACKER, near, ["ranged"])
	var target := _unit("seq_target", 2, BattleState.Side.DEFENDER, Vector2i(0, 9))
	var bodyguard := _unit(
		"seq_guard", 3, BattleState.Side.DEFENDER,
		HexUtils.get_all_neighbors(near, probe.hex_shift_right)[0]
	)
	var bs := _state(att, target)
	bs.defender_units.append(bodyguard)
	bs._defender_alive_count = 2
	bs._rebuild_unit_grid()
	var executor := _executor()
	var seq := _seq(bs, executor)

	seq.start_attack(att, target)

	assert_that(executor.attacks.size()).override_failure_message(
		"удар при соседнем враге не состоялся вовсе").is_equal(1)
	assert_bool(target.is_alive()).is_true()
	assert_bool(seq.can_retaliate()).override_failure_message(
		"выстрел при соседнем враге не стал ближним — контратаки нет").is_true()
