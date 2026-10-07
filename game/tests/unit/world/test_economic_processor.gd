extends BaseTest
const TestFactories := preload("res://tests/helpers/factories.gd")
const ArenaRingSystem := preload("res://scripts/city/arena_ring_system.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")

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
	var ledger: Array = report.get("ledger", [])
	assert_bool(ledger.any(func(flow): return flow.source == "building:1/upkeep")).is_true()

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

func test_campaign_building_uses_same_ledger_for_recipe_and_upkeep() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings.append({
		"uid": 41, "id": "market_garden", "state": "active", "assigned_workers": 2,
		"recipes": [{"id": "grow_food", "workers": 2,
			"inputs": {"wood": 1.0}, "outputs": {"food": 3.0}}],
		"upkeep": {"food": 1.0},
	})
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = EconomicTurnProcessor.new().process(ctx)
	assert_that(int(report.chains_executed)).is_equal(1)
	assert_that(int(report.upkeep_ok)).is_equal(1)
	assert_that(city.resource_ctx.amount(&"wood")).is_equal(1.0)
	assert_that(city.resource_ctx.amount(&"food")).is_equal(2.0)
	var sources: Array[String] = []
	for flow in report.ledger:
		sources.append(String(flow.source))
	assert_bool(sources.has("campaign-building:market_garden/recipe:grow_food")).is_true()
	assert_bool(sources.has("campaign-building:market_garden/upkeep")).is_true()

func test_campaign_adjacency_bonus_applies_deterministically_to_production() -> void:
	var city := TestFactories.make_city()
	city.food_demand_this_turn = 0.0
	var center := ArenaRingSystem.center()
	var near := HexUtils.get_neighbor(center, 0, true)
	city.campaign_buildings = [
		{"uid": 1, "id": "campaign_farm", "state": "active", "cell": center,
			"footprint": [[0, 0]], "roles": ["food_production"], "jobs": 2,
			"assigned_workers": 2, "recipes": [{"id": "farm_food", "workers": 2,
				"inputs": {}, "outputs": {"food": 2}}]},
		{"uid": 2, "id": "campaign_sawmill", "state": "active", "cell": near,
			"footprint": [[0, 0]], "roles": ["wood_production"], "jobs": 2,
			"assigned_workers": 0, "adjacency": [{"id": "forest_edge_farm",
				"target_role": "food_production", "radius": 1,
				"effect": "output_bp", "value": 1500}]},
	]
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var processor := EconomicTurnProcessor.new()
	for _turn in range(4):
		processor.process(ctx)
	assert_that(city.resource_ctx.amount(&"food")).is_equal(9.0)

func test_campaign_building_skips_inactive_and_unregistered_resources() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings = [
		{"id": "inactive_farm", "state": "inactive", "assigned_workers": 2,
			"recipes": [{"id": "food", "workers": 2, "inputs": {}, "outputs": {"food": 3.0}}]},
		{"id": "amber_store", "state": "active", "assigned_workers": 2,
			"recipes": [{"id": "amber", "workers": 2, "inputs": {}, "outputs": {"amber": 3.0}}]},
	]
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = EconomicTurnProcessor.new().process(ctx)
	assert_that(int(report.chains_executed)).is_zero()
	assert_that(city.resource_ctx.amount(&"food")).is_zero()
	assert_that(city.resource_ctx.amount(&"amber")).is_zero()

func test_campaign_building_needs_relations_and_fixed_point_specialization() -> void:
	var city := TestFactories.make_city()
	city.food_demand_this_turn = 0.0
	var builder := PopUnit.new()
	builder.state = PopUnit.State.WORKER
	builder.ancestry_id = "gnomes"
	builder.assigned_to = 41
	city.pop.append(builder)
	var crafter := PopUnit.new()
	crafter.state = PopUnit.State.WORKER
	crafter.ancestry_id = "elves"
	crafter.assigned_to = 41
	city.pop.append(crafter)
	city.campaign_buildings.append({
		"uid": 41, "id": "workshop", "state": "active", "assigned_workers": 2,
		"jobs": 2, "roles": ["woodworking"],
		"services": {"education": 1, "treatment": 1, "community_mediation": 1},
		"recipes": [{"id": "half_output", "workers": 2,
			"inputs": {}, "outputs": {"food": 0.5}}],
	})
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var processor := EconomicTurnProcessor.new()
	var first: Dictionary = processor.process(ctx)
	var first_groups: Dictionary = first.cities[0].campaign_population.groups
	assert_that(int(first_groups.engineers_builders.coverage_percent)).is_equal(100)
	assert_that(int(first_groups.weavers_crafters.coverage_percent)).is_equal(100)
	assert_that(int(first_groups.engineers_builders.satisfaction)).is_equal(50)
	assert_that(int(first_groups.weavers_crafters.satisfaction)).is_equal(50)
	var pairs: Array = first.cities[0].campaign_population.workplace_pairs
	assert_that(pairs.size()).is_equal(1)
	assert_bool(bool(pairs[0].mitigated)).is_true()
	assert_that(float(city.resource_ctx.amount(&"food"))).is_zero()
	assert_that(float(city.campaign_buildings[0].production_remainders["half_output/food"])) \
		.is_equal_approx(5500.0, 0.001)
	var second: Dictionary = processor.process(ctx)
	assert_that(int(second.chains_executed)).is_equal(1)
	assert_that(float(city.resource_ctx.amount(&"food"))).is_equal(1.0)
	assert_that(float(city.campaign_buildings[0].production_remainders["half_output/food"])) \
		.is_equal_approx(1000.0, 0.001)

func test_scheduler_ledger_includes_growth_campaign_production_and_upkeep() -> void:
	var city := TestFactories.make_city()
	_add_worker(city)
	city.food_stockpile = 10.0
	city.ensure_resource_ctx().clear_ledger()
	CityGrowthService.process_turn(city, 1)
	var food_after_growth := city.food_stockpile
	city.campaign_buildings.append({
		"uid": 41, "id": "market_garden", "state": "active", "assigned_workers": 2,
		"recipes": [{"id": "grow_food", "workers": 2,
			"inputs": {"wood": 1.0}, "outputs": {"food": 3.0}}],
		"upkeep": {"food": 1.0},
	})
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(EconomicTurnProcessor.new())
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = scheduler.execute_turn(ctx)
	var ledgers: Array = report.ledger
	assert_that(ledgers.size()).is_equal(1)
	var flows: Array = ledgers[0].flows
	var sources: Array[String] = []
	for flow in flows:
		sources.append(String(flow.source))
	assert_bool(sources.has("city:population_food")).is_true()
	assert_bool(sources.has("automatic_wood_yield")).is_true()
	assert_bool(sources.has("campaign-building:market_garden/recipe:grow_food")).is_true()
	assert_bool(sources.has("campaign-building:market_garden/upkeep")).is_true()
	assert_float(city.food_stockpile).is_equal_approx(food_after_growth + 2.0, 0.0001)

func test_in_progress_building_cannot_produce_pay_upkeep_or_supply_services() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings.append({
		"uid": 71, "id": "unfinished_farm", "state": "active",
		"construction_turns_remaining": 1, "assigned_workers": 2,
		"recipes": [{"id": "food", "workers": 2, "inputs": {}, "outputs": {"food": 3.0}}],
		"upkeep": {"wood": 1.0}, "services": {"education": 2},
	})
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = EconomicTurnProcessor.new().process(ctx)
	var city_report: Dictionary = report.cities[0]
	assert_that(int(report.chains_executed)).is_zero()
	assert_that(int(report.upkeep_ok)).is_zero()
	assert_float(city.resource_ctx.amount(&"food")).is_zero()
	assert_bool(city_report.campaign_population.service_capacity.is_empty()).is_true()
	for flow in city_report.ledger:
		assert_bool(String(flow.source).begins_with("campaign-building:")).is_false()

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
