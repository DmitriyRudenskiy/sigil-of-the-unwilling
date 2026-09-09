extends GdUnitTestSuite
const TestFactories := preload("res://tests/helpers/factories.gd")


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
	b.def = BuildingDefs.farm()
	var chain := ProductionChain.new()
	chain.id = &"lumber"
	chain.inputs = {"wood": 2.0}
	chain.outputs = {"planks": 3.0}
	chain.required_workers = 2
	b.production_chain = chain
	city.buildings.append(b)
	WorkerAssignment.assign_all(city)
	return b



func test_phase_id_and_priority() -> void:
	var p := EconomicTurnProcessor.new()
	assert_that(p.get_phase_id()).is_equal(&"economy")
	assert_that(p.get_priority()).is_equal(10)


func test_empty_city_only_auto_yield() -> void:
	var ctx := TurnContext.new()
	ctx.cities.append(TestFactories.make_city())
	var p := EconomicTurnProcessor.new()
	var report: Dictionary = p.process(ctx)
	assert_that(int(report.get("chains_executed", -1))).is_equal(0)
	assert_that(int(report.get("upkeep_failed", -1))).is_equal(0)
	var auto: Dictionary = report.get("auto_yield", {})
	assert_that(float(auto.get(&"wood", -1.0))).is_equal(float(GameNumbers.RESOURCE_AUTO_WOOD))
	assert_that(float(auto.get(&"stone", -1.0))).is_equal(float(GameNumbers.RESOURCE_AUTO_STONE))



func test_chain_produces_with_workers() -> void:
	var city := TestFactories.make_city()
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

	assert_that(int(report.get("chains_executed", -1))).is_equal(1)
	assert_that(events.size()).is_equal(1)
	assert_that(events[0][0]).is_equal(&"lumber")
	assert_that(float((events[0][1] as Dictionary).get("planks", -1.0))).is_equal(3.0)
	assert_that(city.resource_ctx.amount(&"wood")).is_equal(0.0)
	assert_that(city.resource_ctx.amount(&"planks")).is_equal(3.0)


func test_chain_insufficient_workers_no_output() -> void:
	var city := TestFactories.make_city()
	_add_worker(city)  
	_make_lumber_building(city)
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_that(int(report.get("chains_executed", -1))).is_equal(1)
	assert_that(city.resource_ctx.amount(&"planks")).is_equal(1.5)
	assert_that(city.resource_ctx.amount(&"wood")).is_equal(0.0)


func test_chain_no_workers_skipped() -> void:
	var city := TestFactories.make_city()
	_make_lumber_building(city)
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_that(int(report.get("chains_executed", -1))).is_equal(0)
	assert_that(city.resource_ctx.amount(&"planks")).is_equal(0.0)
	assert_that(city.resource_ctx.amount(&"wood")).is_equal(float(GameNumbers.RESOURCE_AUTO_WOOD))


func test_chain_shortage_no_input_deduction() -> void:
	var city := TestFactories.make_city()
	_add_worker(city)
	_add_worker(city)
	var b := _make_lumber_building(city)
	b.production_chain.inputs = {"wood": 5.0}
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_that(int(report.get("chains_executed", -1))).is_equal(0)
	assert_that(city.resource_ctx.amount(&"wood")).is_equal(2.0)



func test_upkeep_paid() -> void:
	var city := TestFactories.make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var b: UniqueBuilding = city.buildings[0]
	b.upkeep = {"stone": 1.0}
	var p := EconomicTurnProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_that(int(report.get("upkeep_ok", -1))).is_equal(1)
	assert_that(int(report.get("upkeep_failed", -1))).is_equal(0)
	assert_that(city.resource_ctx.amount(&"stone")).is_equal(1.0)


func test_upkeep_failed_emits_signal() -> void:
	var city := TestFactories.make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var b: UniqueBuilding = city.buildings[0]
	b.upkeep = {"gold": 10.0}  
	var p := EconomicTurnProcessor.new()
	var failed: Array = []
	p.upkeep_failed.connect(func(buid: int, rid: StringName): failed.append([buid, rid]))
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = p.process(ctx)
	assert_that(int(report.get("upkeep_failed", -1))).is_equal(1)
	assert_that(failed.size()).is_equal(1)
	assert_that(failed[0][1]).is_equal(&"gold")



func test_report_cities_entries() -> void:
	var ctx := TurnContext.new()
	ctx.cities.append(TestFactories.make_city(1))
	ctx.cities.append(TestFactories.make_city(2))
	var p := EconomicTurnProcessor.new()
	var report: Dictionary = p.process(ctx)
	var cities: Array = report.get("cities", [])
	assert_that(cities.size()).is_equal(2)
	assert_that(int((cities[0] as Dictionary).get("uid", -1))).is_equal(1)
	assert_that(int((cities[1] as Dictionary).get("uid", -1))).is_equal(2)


func test_integration_with_scheduler() -> void:
	var sched := TurnScheduler.new()
	sched.register_processor(EconomicTurnProcessor.new())
	var city := TestFactories.make_city()
	_add_worker(city)
	_add_worker(city)
	_make_lumber_building(city)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = sched.execute_turn(ctx)
	var phases: Dictionary = report.get("phases", {})
	assert_bool(phases.has(&"economy")).is_true()
	assert_that(city.resource_ctx.amount(&"planks")).is_equal(3.0)
