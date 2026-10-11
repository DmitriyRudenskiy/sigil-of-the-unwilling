extends BaseTest
## T-010: ходовой цикл — каноническая модель времени и фиксированный порядок фаз.
##
## Спецификация (владелец, round 7 §2.2):
##   - порядок фаз фиксирован: city_population → hero_movement → caravans_trade
##     → diplomacy_council → battle_raid_resolution → production
##   - MVP-маска: caravans/diplomacy — каркас (Post-MVP)
##   - ход = сезон, 4 хода = год (WorldClock)
##   - I1 на уровне хода: два прогона конвейера идентичны
##   - драйвер: 1 ход = 1 итерация конвейера (TurnScheduler продвигает WorldClock)


class _PhaseProc extends TurnPhaseProcessor:
	## Фейк-процессор: фаза = его phase_id (для проверки канонического порядка).
	var pid: StringName

	func _init(p_id: StringName) -> void:
		pid = p_id

	func get_phase_id() -> StringName:
		return pid

	func get_phase() -> StringName:
		return pid

	func process(_ctx: TurnContext) -> Dictionary:
		return {"ran": true}


class _PrioProc extends TurnPhaseProcessor:
	## Фейк-процессор: фиксированная фаза, настраиваемый приоритет.
	var pid: StringName
	var prio: int
	var phase: StringName

	func _init(p_id: StringName, p_prio: int, p_phase: StringName) -> void:
		pid = p_id
		prio = p_prio
		phase = p_phase

	func get_phase_id() -> StringName:
		return pid

	func get_phase() -> StringName:
		return phase

	func get_priority() -> int:
		return prio

	func process(_ctx: TurnContext) -> Dictionary:
		return {"ran": true}


class _DeterministicProc extends TurnPhaseProcessor:
	## Детерминированный фейк (I1): значение = f(seed, turn) — без внешнего состояния.
	var seed: int

	func _init(p_seed: int) -> void:
		seed = p_seed

	func get_phase_id() -> StringName:
		return &"det"

	func get_phase() -> StringName:
		return TurnPhase.phase_name(TurnPhase.ID.CITY_POPULATION)

	func process(ctx: TurnContext) -> Dictionary:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + ctx.turn_number
		return {"value": rng.randi_range(0, 1000000)}


func before_test() -> void:
	WorldClock.reset()


func test_canonical_phase_order_enforced() -> void:
	# Регистрация вперемешку → исполнение в каноническом порядке (TurnPhase.PHASE_IDS).
	var sched := TurnScheduler.new()
	var shuffled: Array[StringName] = [
		&"production",
		&"diplomacy_council",
		&"city_population",
		&"battle_raid_resolution",
		&"caravans_trade",
		&"hero_movement",
	]
	for pid in shuffled:
		sched.register_processor(_PhaseProc.new(pid))

	var order: Array = []
	sched.phase_completed.connect(func(pid: StringName, _r: Dictionary) -> void: order.append(pid))
	sched.execute_turn(TurnContext.new())

	assert_array(order).contains_exactly([
		&"city_population",
		&"hero_movement",
		&"caravans_trade",
		&"diplomacy_council",
		&"battle_raid_resolution",
		&"production",
	])


func test_within_phase_priority_then_registration() -> void:
	# Внутри фазы: приоритет, затем порядок регистрации.
	var sched := TurnScheduler.new()
	var phase := TurnPhase.phase_name(TurnPhase.ID.PRODUCTION)
	var late_reg_low_prio := _PrioProc.new(&"a", 5, phase)
	var early_reg_high_prio := _PrioProc.new(&"b", 1, phase)
	var same_prio_first := _PrioProc.new(&"c", 10, phase)
	var same_prio_second := _PrioProc.new(&"d", 10, phase)
	sched.register_processor(late_reg_low_prio)
	sched.register_processor(early_reg_high_prio)
	sched.register_processor(same_prio_first)
	sched.register_processor(same_prio_second)

	var order: Array = []
	sched.phase_completed.connect(func(pid: StringName, _r: Dictionary) -> void: order.append(pid))
	sched.execute_turn(TurnContext.new())

	assert_array(order).contains_exactly([&"b", &"a", &"c", &"d"])


func test_unphased_processor_runs_last() -> void:
	# Legacy-совместимость: процессор без фазы — после production.
	var sched := TurnScheduler.new()
	var legacy := _PrioProc.new(&"legacy", 1, &"unphased")
	var prod := _PrioProc.new(&"prod", 99, TurnPhase.phase_name(TurnPhase.ID.PRODUCTION))
	sched.register_processor(legacy)  # приоритет 1 — но фаза unphased
	sched.register_processor(prod)

	var order: Array = []
	sched.phase_completed.connect(func(pid: StringName, _r: Dictionary) -> void: order.append(pid))
	sched.execute_turn(TurnContext.new())

	assert_array(order).contains_exactly([&"prod", &"legacy"])


func test_scheduler_advances_world_clock() -> void:
	# Драйвер: 1 ход = 1 итерация конвейера; счётчик — WorldClock.
	var sched := TurnScheduler.new()
	sched.register_processor(_PhaseProc.new(&"city_population"))
	assert_int(WorldClock.get_turn()).is_zero()

	var ctx := TurnContext.new()
	var report: Dictionary = sched.execute_turn(ctx)
	assert_int(WorldClock.get_turn()).is_equal(1)
	assert_int(sched.get_turn()).is_equal(1)
	assert_int(ctx.turn_number).is_equal(1)
	assert_dict(report).contains_key_value("turn", 1)

	sched.execute_turn(ctx)
	assert_int(WorldClock.get_turn()).is_equal(2)
	assert_int(ctx.turn_number).is_equal(2)


func test_clock_year_and_season_cycle() -> void:
	# Ход = сезон, 4 хода = год: ход 1 = SPRING года 1.
	assert_int(WorldClock.get_turn()).is_zero()
	assert_int(WorldClock.year()).is_zero()
	assert_int(WorldClock.season()).is_equal(Season.ID.SPRING)

	var expected_seasons: Array[int] = [
		Season.ID.SPRING, Season.ID.SUMMER, Season.ID.AUTUMN, Season.ID.WINTER,
	]
	for i in 4:
		var turn: int = WorldClock.advance_turn()
		assert_int(turn).is_equal(i + 1)
		assert_int(WorldClock.season()).is_equal(expected_seasons[i])
		assert_int(WorldClock.year()).is_equal(1)

	# Ход 5 = SPRING года 2.
	WorldClock.advance_turn()
	assert_int(WorldClock.get_turn()).is_equal(5)
	assert_int(WorldClock.season()).is_equal(Season.ID.SPRING)
	assert_int(WorldClock.year()).is_equal(2)


func test_clock_serialize_restore_roundtrip() -> void:
	# T-110: сериализация — только базовое состояние; season/year — производные.
	for i in 7:
		WorldClock.advance_turn()
	var data: Dictionary = WorldClock.serialize()
	assert_dict(data).contains_key_value("turn", 7)

	WorldClock.reset()
	assert_int(WorldClock.get_turn()).is_zero()
	WorldClock.restore(data)
	assert_int(WorldClock.get_turn()).is_equal(7)
	assert_int(WorldClock.season()).is_equal(Season.ID.AUTUMN)  # (7-1) % 4
	assert_int(WorldClock.year()).is_equal(2)

	# Legacy-сейв без секции T-010 → валидная загрузка (ход 0).
	WorldClock.restore({})
	assert_int(WorldClock.get_turn()).is_zero()
	assert_int(WorldClock.year()).is_zero()


func test_clock_set_turn_clamps_negative() -> void:
	WorldClock.set_turn(-5)
	assert_int(WorldClock.get_turn()).is_zero()


func test_worldseasons_delegates_to_worldclock() -> void:
	# Единственный источник числа хода: WorldSeasons делегирует в WorldClock.
	WorldSeasons.advance_turn()
	assert_int(WorldClock.get_turn()).is_equal(1)
	assert_int(WorldSeasons.get_turns()).is_equal(1)

	WorldSeasons.set_turns(47)
	assert_int(WorldClock.get_turn()).is_equal(47)

	WorldSeasons.reset()
	assert_int(WorldClock.get_turn()).is_zero()
	assert_int(WorldSeasons.get_turns()).is_zero()


func test_skeleton_phases_present_and_inert() -> void:
	# MVP-маска: караваны и дипломатия/Совет — каркас в конвейере, состояние не меняют.
	var sched := TurnScheduler.new()
	sched.register_processor(CaravansTradePhase.new())
	sched.register_processor(DiplomacyCouncilPhase.new())

	var report: Dictionary = sched.execute_turn(TurnContext.new())
	assert_dict(report["phases"]).contains_key_value(
		&"caravans_trade", {"skeleton": true, "post_mvp": true})
	assert_dict(report["phases"]).contains_key_value(
		&"diplomacy_council", {"skeleton": true, "post_mvp": true})

	assert_bool(TurnPhase.is_skeleton(&"caravans_trade")).is_true()
	assert_bool(TurnPhase.is_skeleton(&"diplomacy_council")).is_true()
	assert_bool(TurnPhase.is_skeleton(&"production")).is_false()


func test_i1_pipeline_determinism_at_turn_level() -> void:
	# I1 (уровень хода): два прогона конвейера с тем же состоянием → идентичные отчёты.
	var ctx_a := TurnContext.new()
	var ctx_b := TurnContext.new()
	var report_a: Array = []
	var report_b: Array = []

	var sched_a := TurnScheduler.new()
	sched_a.register_processor(_DeterministicProc.new(42))
	sched_a.register_processor(_PhaseProc.new(&"production"))
	for i in 10:
		report_a.append(sched_a.execute_turn(ctx_a))

	WorldClock.reset()  # статический час: второй прогон с того же начального состояния

	var sched_b := TurnScheduler.new()
	sched_b.register_processor(_DeterministicProc.new(42))
	sched_b.register_processor(_PhaseProc.new(&"production"))
	for i in 10:
		report_b.append(sched_b.execute_turn(ctx_b))

	assert_int(report_a.size()).is_equal(10)
	for i in 10:
		assert_that(report_a[i]).is_equal(report_b[i])  # I1: ход i идентичен в обоих прогонах
