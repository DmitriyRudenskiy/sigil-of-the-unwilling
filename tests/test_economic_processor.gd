extends "res://tests/test_base.gd"
## M1: Экономика — EconomicTurnProcessor.
##
## Цепочки зданий, поддержка (upkeep), авто-ресурсы, отчёт фазы.
## Город собирается вручную (City — чистый RefCounted).

func _make_city(uid: int = 1) -> City:
	var city := City.new()
	city.uid = uid
	city.display_name = "TestTown %d" % uid
	city.center = Vector2i(5, 5)
	return city


func _add_worker(city: City, tile: Vector2i = Vector2i(6, 5)) -> PopUnit:
	var u := PopUnit.new()
	u.state = PopUnit.State.WORKER
	u.tile = tile
	u.born_turn = 0
	city.pop.append(u)
	return u


func _make_lumber_building(city: City) -> UniqueBuilding:
	var b := UniqueBuilding.new()
	b.uid = city.buildings.size() + 1
	b.cell = Vector2i(6, 5)
	b.level = 1
	var chain := ProductionChain.new()
	chain.id = &"lumber"
	chain.inputs = {"wood": 2.0}
	chain.outputs = {"planks": 3.0}
	chain.required_workers = 2
	b.production_chain = chain
	city.buildings.append(b)
	return b


# ==================== БАЗА ====================

func test_phase_id_and_priority() -> void:
	var p := EconomicTurnProcessor.new()
	assert_eq(p.get_phase_id(), &"economy", "phase id")
	assert_eq(p.get_priority(), 10, "priority 10 (раньше всех)")


func test_empty_city_only_auto_yield() -> void:
	var ctx := TurnContext.new()
	ctx.cities.append(_make_city())
	var p := EconomicTurnProcessor.new()
	var report: Dictionary = p.process(ctx)
	assert_eq(int(report.get("chains_executed", -1)), 0, "no chains")
	assert_eq(int(report.get("upkeep_failed", -1)), 0, "no upkeep failures")
	var auto: Dictionary = report.get("auto_yield", {})
	assert_eq(float(auto.get(&"wood", -1.0)), float(GameSettings.RESOURCE_AUTO_WOOD_PER_DAY), "auto wood")
	assert_eq(float(auto.get(&"stone", -1.0)), float(GameSettings.RESOURCE_AUTO_STONE_PER_DAY), "auto stone")


# ==================== ЦЕПОЧКИ ====================

func test_chain_produces_with_workers() -> void:
	var city := _make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var events: Array = []
	var p := EconomicTurnProcessor.new()
	p.production_completed.connect(func(_c: int, id: StringName, out: Dictionary):
		events.append([id, out]))

	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)

	assert_eq(int(report.get("chains_executed", -1)), 1, "chain ran")
	assert_eq(events.size(), 1, "event emitted")
	assert_eq(events[0][0], &"lumber", "chain id in event")
	assert_eq(float((events[0][1] as Dictionary).get("planks", -1.0)), 3.0, "planks output")
	# Входы: авто-дрова 2 + старт 0 — цепочка взяла 2, осталось 0.
	assert_eq(city.resource_ctx.amount(&"wood"), 0.0, "wood consumed (auto 2 - chain 2)")
	assert_eq(city.resource_ctx.amount(&"planks"), 3.0, "planks in ctx")


func test_chain_insufficient_workers_no_output() -> void:
	var city := _make_city()
	_add_worker(city)  # только 1 из 2
	_make_lumber_building(city)
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	# Цепочка отработала (есть рабочие), но на 50% мощности: входы 2, выход 1.5.
	assert_eq(int(report.get("chains_executed", -1)), 1, "chain ran at 50%")
	assert_eq(city.resource_ctx.amount(&"planks"), 1.5, "half output")
	assert_eq(city.resource_ctx.amount(&"wood"), 0.0, "inputs still fully deducted")


func test_chain_no_workers_skipped() -> void:
	var city := _make_city()
	_make_lumber_building(city)
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_eq(int(report.get("chains_executed", -1)), 0, "skipped without workers")
	assert_eq(city.resource_ctx.amount(&"planks"), 0.0, "no output")
	# Авто-дрова остались (цепочка не трогала).
	assert_eq(city.resource_ctx.amount(&"wood"), float(GameSettings.RESOURCE_AUTO_WOOD_PER_DAY), "wood untouched")


func test_chain_shortage_no_input_deduction() -> void:
	var city := _make_city()
	_add_worker(city)
	_add_worker(city)
	var b := _make_lumber_building(city)
	# Нужен wood 2, но авто-дрова дадут только 2 — хватит ровно.
	# Усложним: входы 5, авто 2 → нехватка → цепочка не отработала.
	b.production_chain.inputs = {"wood": 5.0}
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_eq(int(report.get("chains_executed", -1)), 0, "skipped on shortage")
	assert_eq(city.resource_ctx.amount(&"wood"), 2.0, "inputs untouched (atomic)")


# ==================== ПОДДЕРЖКА ====================

func test_upkeep_paid() -> void:
	var city := _make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var b: UniqueBuilding = city.buildings[0]
	b.upkeep = {"stone": 1.0}
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_eq(int(report.get("upkeep_ok", -1)), 1, "upkeep paid")
	assert_eq(int(report.get("upkeep_failed", -1)), 0, "no failures")
	assert_eq(city.resource_ctx.amount(&"stone"), 1.0, "stone 2(auto) - 1(upkeep)")


func test_upkeep_failed_emits_signal() -> void:
	var city := _make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var b: UniqueBuilding = city.buildings[0]
	b.upkeep = {"gold": 10.0}  # золота нет вовсе
	var p := EconomicTurnProcessor.new()
	var failed: Array = []
	p.upkeep_failed.connect(func(buid: int, rid: StringName): failed.append([buid, rid]))
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_eq(int(report.get("upkeep_failed", -1)), 1, "failed in report")
	assert_eq(failed.size(), 1, "signal emitted")
	assert_eq(failed[0][1], &"gold", "short resource in signal")


# ==================== ОТЧЁТ ====================

func test_report_cities_entries() -> void:
	var ctx := TurnContext.new()
	ctx.cities.append(_make_city(1))
	ctx.cities.append(_make_city(2))
	var p := EconomicTurnProcessor.new()
	var report: Dictionary = p.process(ctx)
	var cities: Array = report.get("cities", [])
	assert_eq(cities.size(), 2, "per-city entries")
	assert_eq(int((cities[0] as Dictionary).get("uid", -1)), 1, "city 1 uid")
	assert_eq(int((cities[1] as Dictionary).get("uid", -1)), 2, "city 2 uid")


func test_integration_with_scheduler() -> void:
	## Энд-ту-энд: планировщик + процессор в одном прогоне.
	var sched := TurnScheduler.new()
	sched.register_processor(EconomicTurnProcessor.new())
	var city := _make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = sched.execute_turn(ctx)
	var phases: Dictionary = report.get("phases", {})
	assert_true(phases.has(&"economy"), "economy phase in report")
	assert_eq(city.resource_ctx.amount(&"planks"), 3.0, "produced through scheduler")
