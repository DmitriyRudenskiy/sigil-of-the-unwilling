extends "res://tests/test_base.gd"
## Семантика отступления в BattleTurnExecutor:
##  1) RETREAT в WAITING_INPUT — немедленное отступление;
##  2) RETREAT, отправленный до начала хода игрока (ранний запрос),
##     становится в очередь и исполняется при входе в WAITING_INPUT
##     (с любого пути входа — обычный ход и мораль проходят через
##     _transition_to);
##  3) force_retreat — аварийный выход из зависшего боя (например,
##     после скрипт-ошибки, рванувшей стейт-машину).
##
## Примечание: лямбды GDScript захватывают локальные переменные ПО ЗНАЧЕНИЮ,
## поэтому для захвата событий end_battle используется массив (его объект
## виден из замыкания), а не int-счётчик.

const _Executor = preload("res://systems/BattleTurnExecutor.gd")


func _make_executor() -> Dictionary:
	var bs: BattleState = BattleState.new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack("swordsmen", 40))
	atk.append(Units.make_fixed_stack("archers", 20))
	var def: Array[UnitStack] = []
	def.append(Units.make_fixed_stack("goblins", 50))
	bs.place_army(atk, def)
	var ex := _Executor.new()
	ex.name = "TestRetreatExec"
	ex.setup(bs, BattleAI.new(), {})
	return {"executor": ex, "state": bs}


func _survivor_total(a: Array) -> int:
	var total := 0
	for s in a:
		total += s.count
	return total

# 1) Немедленное отступление в WAITING_INPUT.
func test_immediate_retreat_at_waiting_input() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	ex._state = BattleTurnExecutor.State.WAITING_INPUT
	ex.request_retreat()

	assert_eq(ex.get_current_state(), BattleTurnExecutor.State.BATTLE_OVER,
		"state is BATTLE_OVER after immediate retreat")
	assert_true(bs.battle_over, "battle_over set")
	assert_eq(end_events.size(), 1, "end_battle emitted once")
	if end_events.size() == 1:
		assert_eq(end_events[0][0], BattleState.Side.DEFENDER, "winner = DEFENDER (retreat)")
		# 40 + 20 = 60 → 50% = 30
		assert_eq(_survivor_total(end_events[0][1]), 30, "attacker survives with 50% stacks")
		ex.free()

# 2) Ранний RETREAT: очередь + исполнение при входе в WAITING_INPUT.
func test_early_retreat_queued_until_waiting_input() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	# Ход ещё не начался (TURN_START — задержка перед WAITING_INPUT / AI).
	ex._state = BattleTurnExecutor.State.TURN_START
	ex.request_retreat()

	assert_eq(ex.get_current_state(), BattleTurnExecutor.State.TURN_START,
		"queued retreat does not end battle immediately")
	assert_false(bs.battle_over, "battle not over while queued")
	assert_eq(end_events.size(), 0, "no end_battle while queued")

	# Игрок доходит до своего ввода — очередь исполняется.
	ex._transition_to(BattleTurnExecutor.State.WAITING_INPUT)

	assert_eq(ex.get_current_state(), BattleTurnExecutor.State.BATTLE_OVER,
		"queued retreat fires on WAITING_INPUT entry")
	assert_true(bs.battle_over, "battle over after queued retreat fired")
	assert_eq(end_events.size(), 1, "end_battle emitted once")
	if end_events.size() == 1:
		assert_eq(_survivor_total(end_events[0][1]), 30, "50% stacks survive")
		ex.free()

# 3) Очередное отступление не срабатывает на других переходах,
#    но исполняется при следующем входе в WAITING_INPUT.
func test_queued_retreat_ignores_other_transitions() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]

	ex._state = BattleTurnExecutor.State.TURN_START
	ex.request_retreat()

	ex._transition_to(BattleTurnExecutor.State.AI_ANIMATING)
	assert_false(bs.battle_over, "no retreat during AI transition")
	assert_eq(ex.get_current_state(), BattleTurnExecutor.State.AI_ANIMATING,
		"state stays AI_ANIMATING")

	ex._transition_to(BattleTurnExecutor.State.WAITING_INPUT)
	assert_true(bs.battle_over, "retreat fires on next WAITING_INPUT")
	ex.free()

# 4) force_retreat — аварийный выход из зависшего боя (AI_THINKING).
func test_force_retreat_from_stuck_ai_turn() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	# Симуляция зависшего боя: стейт-машина застряла в AI_THINKING,
	# до WAITING_INPUT не доходит (например, скрипт-ошибка рванула ход).
	ex._state = BattleTurnExecutor.State.AI_THINKING
	ex.force_retreat()

	assert_eq(ex.get_current_state(), BattleTurnExecutor.State.BATTLE_OVER,
		"force_retreat ends stuck battle")
	assert_true(bs.battle_over, "battle_over set")
	assert_eq(end_events.size(), 1, "end_battle emitted")
	if end_events.size() == 1:
		assert_eq(end_events[0][0], BattleState.Side.DEFENDER, "forced retreat = player retreat")
		assert_eq(_survivor_total(end_events[0][1]), 30, "50% stacks survive forced retreat")
		ex.free()

# 5) force_retreat после уже завершённого боя — no-op (один end_battle).
func test_force_retreat_noop_after_battle_over() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]

	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	ex._state = BattleTurnExecutor.State.WAITING_INPUT
	ex.request_retreat()
	assert_eq(end_events.size(), 1, "first end_battle emitted")

	ex.force_retreat()
	assert_eq(end_events.size(), 1, "force_retreat is no-op after battle over")
	ex.free()

## 6) Регрессия E2E-зависания: бой уже окончен по боевому стейту
##    (последний удар убил последнего юнита, battle_over=true), но
##    end_battle НЕ испущен — executor завис в анимации (completion
##    колбэк не пришёл). force_retreat обязан развязать именно это
##    состояние: guard по battle_over здесь недопустим.
func test_force_retreat_on_over_state_without_end_emitted() -> void:
	var ctx: Dictionary = _make_executor()
	var ex: Node = ctx["executor"]
	var bs: BattleState = ctx["state"]
	var end_events: Array = []
	ex.end_battle.connect(func(w, a, d): end_events.append([w, a, d]))

	bs.force_end(BattleState.Side.DEFENDER)
	ex._state = BattleTurnExecutor.State.AI_ANIMATING

	ex.force_retreat()

	assert_eq(ex.get_current_state(), BattleTurnExecutor.State.BATTLE_OVER,
		"force_retreat un-sticks the battle")
	assert_eq(end_events.size(), 1, "end_battle emitted exactly once")
	if end_events.size() == 1:
		assert_eq(end_events[0][0], BattleState.Side.DEFENDER, "winner stays DEFENDER")

	# Повторный force_retreat после развязки — no-op.
	ex.force_retreat()
	assert_eq(end_events.size(), 1, "second force_retreat is no-op")
	ex.free()
