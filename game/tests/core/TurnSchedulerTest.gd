extends GdUnitTestSuite


class _Proc extends TurnPhaseProcessor:
	var id: StringName
	var prio: int
	var calls: Array = []

	func _init(p_id: StringName, p_prio: int) -> void:
		id = p_id
		prio = p_prio

	func get_phase_id() -> StringName:
		return id

	func get_priority() -> int:
		return prio

	func process(ctx: TurnContext) -> Dictionary:
		calls.append(ctx.turn_number)
		return {"phase": String(id)}


# Из test_turn_scheduler (root): общий log исполнения для проверки порядка.
class _LogPhase extends TurnPhaseProcessor:
	var id: StringName = &"log"
	var priority := 100
	var log: Array = []

	func get_phase_id() -> StringName:
		return id

	func get_priority() -> int:
		return priority

	func process(ctx: TurnContext) -> Dictionary:
		log.append(id)
		return {"ran": true, "turn": ctx.turn_number, "month": ctx.month}


# Из test_turn_scheduler (root): захват season/weather из контекста.
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


func _make_log_phase(id: StringName, priority: int, log: Array) -> _LogPhase:
	var p := _LogPhase.new()
	p.id = id
	p.priority = priority
	p.log = log
	return p


func test_processors_sorted_by_priority() -> void:
	var sched := TurnScheduler.new()
	var late := _Proc.new(&"late", 30)
	var early := _Proc.new(&"early", 10)
	var mid := _Proc.new(&"mid", 20)
	sched.register_processor(late)
	sched.register_processor(early)
	sched.register_processor(mid)
	var ids := sched.get_processors()
	assert_array(ids).contains_exactly_in_any_order([early, mid, late])


func test_duplicate_registration_ignored() -> void:
	var sched := TurnScheduler.new()
	var p := _Proc.new(&"p", 10)
	sched.register_processor(p)
	sched.register_processor(p)
	sched.register_processor(null)
	assert_array(sched.get_processors()).has_size(1)


## Из test_turn_scheduler (root): unregister.
func test_unregister_removes_processor() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	var p := _make_log_phase(&"a", 10, log)
	sched.register_processor(p)
	sched.unregister_processor(p)
	assert_array(sched.get_processors()).has_size(0)


## Из test_turn_scheduler (root): порядок исполнения фаз по приоритету (не только порядок в списке).
func test_phases_run_in_priority_order() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_log_phase(&"late", 30, log))
	sched.register_processor(_make_log_phase(&"early", 10, log))
	sched.register_processor(_make_log_phase(&"mid", 20, log))
	sched.execute_turn(TurnContext.new())
	assert_array(log).contains_exactly([&"early", &"mid", &"late"])


## Из test_turn_scheduler (root): season выводится из месяца.
func test_season_derived_from_month() -> void:
	var sched := TurnScheduler.new()
	var probe := _ProbePhase.new()
	sched.register_processor(probe)
	var ctx := TurnContext.new()
	ctx.month = 8
	sched.execute_turn(ctx)
	assert_int(int(probe.captured.get("season", -1))).is_equal(Season.ID.SUMMER)
	ctx.month = 1
	sched.execute_turn(ctx)
	assert_int(int(probe.captured.get("season", -1))).is_equal(Season.ID.WINTER)


## Из test_turn_scheduler (root): null-погода нормализуется в CLEAR.
func test_null_weather_normalized() -> void:
	var sched := TurnScheduler.new()
	var probe := _ProbePhase.new()
	sched.register_processor(probe)
	var ctx := TurnContext.new()
	ctx.weather = -1
	sched.execute_turn(ctx)
	assert_int(int(probe.captured.get("weather", -2))).is_equal(GameNumbers.WEATHER_CLEAR)


## Из test_turn_scheduler (root): сигнал phase_completed.
func test_phase_completed_signal() -> void:
	var sched := TurnScheduler.new()
	var log: Array = []
	sched.register_processor(_make_log_phase(&"sig", 10, log))
	var phase_events: Array = []
	sched.phase_completed.connect(func(pid: StringName, _r: Dictionary): phase_events.append(pid))
	sched.execute_turn(TurnContext.new())
	assert_array(phase_events).contains_exactly([&"sig"])


## Из test_turn_scheduler (root): пустой планировщик корректно отрабатывает ход.
func test_empty_scheduler_ok() -> void:
	var sched := TurnScheduler.new()
	var ctx := TurnContext.new()
	var report := sched.execute_turn(ctx)
	assert_dict(report).contains_key_value("turn", 1)
	assert_dict(report["phases"]).is_empty()
	assert_int(ctx.turn_number).is_equal(1)


func test_execute_turn_runs_phases_and_reports() -> void:
	var sched := TurnScheduler.new()
	var started: Array = []
	var completed: Array = []
	var done: Array = []
	sched.turn_started.connect(func(t: int) -> void: started.append(t))
	sched.turn_completed.connect(func(t: int, r: Dictionary) -> void: done.append([t, r]))
	var p1 := _Proc.new(&"a", 1)
	var p2 := _Proc.new(&"b", 2)
	sched.register_processor(p1)
	sched.register_processor(p2)

	var ctx := TurnContext.new()
	var report := sched.execute_turn(ctx)

	assert_array(started).contains_exactly_in_any_order([1])
	assert_dict(report).contains_key_value("turn", 1)
	assert_dict(report["phases"]).contains_keys([&"a", &"b"])
	assert_dict(report["phases"]).contains_key_value(&"a", {"phase": "a"})
	assert_int(p1.calls[0]).is_equal(1)
	assert_array(done).has_size(1)
	
	assert_array(p1.calls).is_not_empty()


func test_execute_turn_increments_turn_number() -> void:
	var sched := TurnScheduler.new()
	sched.register_processor(_Proc.new(&"a", 1))
	var ctx := TurnContext.new()
	sched.execute_turn(ctx)
	sched.execute_turn(ctx)
	assert_int(sched.get_turn()).is_equal(2)
	assert_int(ctx.turn_number).is_equal(2)


func test_execute_turn_null_ctx_returns_empty() -> void:
	var sched := TurnScheduler.new()
	assert_dict(sched.execute_turn(null)).is_empty()
	assert_int(sched.get_turn()).is_zero()
