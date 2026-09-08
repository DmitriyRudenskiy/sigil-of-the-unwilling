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
