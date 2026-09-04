extends "res://tests/gut_base.gd"
## M0: Ядро — TurnScheduler / TurnContext / TurnPhaseProcessor.
##
## Проверяем: порядок фаз по приоритету, отчёт хода, сигналы,
## повторная регистрация, null-контекст, пересчёт сезона из месяца.

class _FakePhase extends TurnPhaseProcessor:
	var id: StringName = &"fake"
	var priority := 100
	var log: Array = []

	func get_phase_id() -> StringName:
		return id

	func get_priority() -> int:
		return priority

	func process(ctx: TurnContext) -> Dictionary:
		log.append(id)
		return {"ran": true, "turn": ctx.turn_number, "month": ctx.month}


class _ProbePhase extends TurnPhaseProcessor:
	## Ловит поля ctx в dict (для проверки пересчёта сезона/погоды).
	var captured: Dictionary = {}

	func get_phase_id() -> StringName:
		return &"probe"

	func get_priority() -> int:
		return 10

	func process(ctx: TurnContext) -> Dictionary:
		captured["season"] = ctx.season
		captured["weather"] = ctx.weather
		captured["turn"] = ctx.turn_number
		return {}


func _make_phase(id: StringName, priority: int, log: Array) -> _FakePhase:
	var p := _FakePhase.new()
	p.id = id
	p.priority = priority
	p.log = log
	return p


# ==================== РЕГИСТРАЦИЯ ====================

func test_register_and_get_processors() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_phase(&"a", 10, log)
	sched.register_processor(p)
	assert_eq(sched.get_processors().size(), 1, "one processor registered")
	assert_true(sched.get_processors()[0] == p, "same instance stored")


func test_duplicate_register_ignored() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_phase(&"a", 10, log)
	sched.register_processor(p)
	sched.register_processor(p)
	assert_eq(sched.get_processors().size(), 1, "duplicate not added")


func test_null_register_ignored() -> void:
	var sched := TurnScheduler.new()
	sched.register_processor(null)
	assert_eq(sched.get_processors().size(), 0, "null not added")


func test_unregister() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_phase(&"a", 10, log)
	sched.register_processor(p)
	sched.unregister_processor(p)
	assert_eq(sched.get_processors().size(), 0, "unregistered")


# ==================== ПОРЯДОК ИСПОЛНЕНИЯ ====================

func test_phases_run_by_priority() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	# Регистрируем в «перемешанном» порядке — исполнять должны по приоритету.
	sched.register_processor(_make_phase(&"late", 30, log))
	sched.register_processor(_make_phase(&"early", 10, log))
	sched.register_processor(_make_phase(&"mid", 20, log))

	var ctx := TurnContext.new()
	ctx.month = 3
	sched.execute_turn(ctx)

	assert_eq(log.size(), 3, "all phases ran")
	assert_eq(log[0], &"early", "priority 10 first")
	assert_eq(log[1], &"mid", "priority 20 second")
	assert_eq(log[2], &"late", "priority 30 third")


func test_report_contains_all_phases() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_phase(&"e1", 10, log))
	sched.register_processor(_make_phase(&"e2", 20, log))

	var ctx := TurnContext.new()
	var report: Dictionary = sched.execute_turn(ctx)

	assert_eq(report.get("turn"), 1, "report turn = 1")
	var phases: Dictionary = report.get("phases", {})
	assert_true(phases.has(&"e1"), "phase e1 in report")
	assert_true(phases.has(&"e2"), "phase e2 in report")
	assert_eq(int((phases[&"e1"] as Dictionary).get("turn", -1)), 1, "ctx turn passed to phase")


func test_turn_counter_increments() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_phase(&"p", 10, log))
	assert_eq(sched.get_turn(), 0, "turn 0 before execute")
	sched.execute_turn(TurnContext.new())
	assert_eq(sched.get_turn(), 1, "turn 1 after first execute")
	sched.execute_turn(TurnContext.new())
	assert_eq(sched.get_turn(), 2, "turn 2 after second execute")
	assert_eq(log.size(), 2, "phase logged both turns")


# ==================== КОНТЕКСТ И СЕЗОН ====================

func test_season_derived_from_month() -> void:
	var sched := TurnScheduler.new()
	var probe := _ProbePhase.new()
	sched.register_processor(probe)

	var ctx := TurnContext.new()
	ctx.month = 8  # лето
	sched.execute_turn(ctx)
	assert_eq(int(probe.captured.get("season", -1)), Season.ID.SUMMER, "month 8 -> SUMMER")
	assert_eq(int(probe.captured.get("turn", -1)), 1, "ctx turn set on first execute")
	ctx.month = 1  # зима
	sched.execute_turn(ctx)
	assert_eq(int(probe.captured.get("season", -1)), Season.ID.WINTER, "month 1 -> WINTER")


func test_null_weather_normalized() -> void:
	var sched := TurnScheduler.new()
	var probe := _ProbePhase.new()
	sched.register_processor(probe)

	var ctx := TurnContext.new()
	ctx.weather = -1
	sched.execute_turn(ctx)
	assert_eq(int(probe.captured.get("weather", -2)), GameSettings.WEATHER_CLEAR, "negative weather -> CLEAR")


# ==================== СИГНАЛЫ ====================

func test_signals_emitted() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_phase(&"sig", 10, log))

	var started: Array = []
	var completed: Array = []
	var phase_events: Array = []
	sched.turn_started.connect(func(t: int): started.append(t))
	sched.phase_completed.connect(func(pid: StringName, _r: Dictionary): phase_events.append(pid))
	sched.turn_completed.connect(func(t: int, _r: Dictionary): completed.append(t))

	sched.execute_turn(TurnContext.new())

	assert_eq(started.size(), 1, "turn_started emitted once")
	assert_eq(started[0], 1, "turn_started payload")
	assert_eq(phase_events.size(), 1, "phase_completed emitted once")
	assert_eq(phase_events[0], &"sig", "phase_completed payload")
	assert_eq(completed.size(), 1, "turn_completed emitted once")


# ==================== ДЕГЕНЕРАТИВНЫЕ СЛУЧАИ ====================

func test_null_ctx_returns_empty() -> void:
	var sched := TurnScheduler.new()
	var report: Dictionary = sched.execute_turn(null)
	assert_push_error("ctx == null")  # ожидаемый push_error из execute_turn(null)
	assert_true(report.is_empty(), "empty report on null ctx")
	assert_eq(sched.get_turn(), 0, "turn not advanced on null ctx")


func test_empty_scheduler_ok() -> void:
	var sched := TurnScheduler.new()
	var captured: Dictionary = {}
	var ctx := TurnContext.new()
	var report: Dictionary = sched.execute_turn(ctx)
	assert_eq(report.get("turn"), 1, "turn advanced even with no phases")
	assert_true((report.get("phases") as Dictionary).is_empty(), "no phases in report")
	captured["ctx_turn"] = ctx.turn_number
	assert_eq(int(captured["ctx_turn"]), 1, "ctx turn set")
