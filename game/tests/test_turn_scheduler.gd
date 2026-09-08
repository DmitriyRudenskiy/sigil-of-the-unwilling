extends GdUnitTestSuite

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



func test_register_and_get_processors() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_phase(&"a", 10, log)
	sched.register_processor(p)
	assert_that(sched.get_processors().size()).is_equal(1)
	assert_bool(sched.get_processors()[0] == p).is_true()


func test_duplicate_register_ignored() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_phase(&"a", 10, log)
	sched.register_processor(p)
	sched.register_processor(p)
	assert_that(sched.get_processors().size()).is_equal(1)


func test_null_register_ignored() -> void:
	var sched := TurnScheduler.new()
	sched.register_processor(null)
	assert_that(sched.get_processors().size()).is_equal(0)


func test_unregister() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_phase(&"a", 10, log)
	sched.register_processor(p)
	sched.unregister_processor(p)
	assert_that(sched.get_processors().size()).is_equal(0)



func test_phases_run_by_priority() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_phase(&"late", 30, log))
	sched.register_processor(_make_phase(&"early", 10, log))
	sched.register_processor(_make_phase(&"mid", 20, log))

	var ctx := TurnContext.new()
	ctx.month = 3
	sched.execute_turn(ctx)

	assert_that(log.size()).is_equal(3)
	assert_that(log[0]).is_equal(&"early")
	assert_that(log[1]).is_equal(&"mid")
	assert_that(log[2]).is_equal(&"late")


func test_report_contains_all_phases() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_phase(&"e1", 10, log))
	sched.register_processor(_make_phase(&"e2", 20, log))

	var ctx := TurnContext.new()
	var report: Dictionary = sched.execute_turn(ctx)

	assert_that(report.get("turn")).is_equal(1)
	var phases: Dictionary = report.get("phases", {})
	assert_bool(phases.has(&"e1")).is_true()
	assert_bool(phases.has(&"e2")).is_true()
	assert_that(int((phases[&"e1"] as Dictionary).get("turn", -1))).is_equal(1)


func test_turn_counter_increments() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_phase(&"p", 10, log))
	assert_that(sched.get_turn()).is_equal(0)
	sched.execute_turn(TurnContext.new())
	assert_that(sched.get_turn()).is_equal(1)
	sched.execute_turn(TurnContext.new())
	assert_that(sched.get_turn()).is_equal(2)
	assert_that(log.size()).is_equal(2)



func test_season_derived_from_month() -> void:
	var sched := TurnScheduler.new()
	var probe := _ProbePhase.new()
	sched.register_processor(probe)

	var ctx := TurnContext.new()
	ctx.month = 8  
	sched.execute_turn(ctx)
	assert_that(int(probe.captured.get("season", -1))).is_equal(Season.ID.SUMMER)
	assert_that(int(probe.captured.get("turn", -1))).is_equal(1)
	ctx.month = 1  
	sched.execute_turn(ctx)
	assert_that(int(probe.captured.get("season", -1))).is_equal(Season.ID.WINTER)


func test_null_weather_normalized() -> void:
	var sched := TurnScheduler.new()
	var probe := _ProbePhase.new()
	sched.register_processor(probe)

	var ctx := TurnContext.new()
	ctx.weather = -1
	sched.execute_turn(ctx)
	assert_that(int(probe.captured.get("weather", -2))).is_equal(GameNumbers.WEATHER_CLEAR)



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

	assert_that(started.size()).is_equal(1)
	assert_that(started[0]).is_equal(1)
	assert_that(phase_events.size()).is_equal(1)
	assert_that(phase_events[0]).is_equal(&"sig")
	assert_that(completed.size()).is_equal(1)



func test_null_ctx_returns_empty() -> void:
	var sched := TurnScheduler.new()
	var report: Dictionary = {}
	assert_error(func(): report = sched.execute_turn(null)).is_push_error(any_string())
	assert_bool(report.is_empty()).is_true()
	assert_that(sched.get_turn()).is_equal(0)


func test_empty_scheduler_ok() -> void:
	var sched := TurnScheduler.new()
	var captured: Dictionary = {}
	var ctx := TurnContext.new()
	var report: Dictionary = sched.execute_turn(ctx)
	assert_that(report.get("turn")).is_equal(1)
	assert_bool((report.get("phases") as Dictionary).is_empty()).is_true()
	captured["ctx_turn"] = ctx.turn_number
	assert_that(int(captured["ctx_turn"])).is_equal(1)
