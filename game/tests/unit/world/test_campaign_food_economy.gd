extends BaseTest

const TestFactories := preload("res://tests/helpers/factories.gd")

func _make_campaign_context(
	resident_count: int, city_food: float, hero_cell: Vector2i, carried_food: int
) -> Dictionary:
	var city := TestFactories.make_city()
	city.center = Vector2i(5, 5)
	city.ensure_resource_ctx()
	city.food_stockpile = city_food
	city.resource_ctx.clear_ledger()
	for _i in range(resident_count):
		var resident := PopUnit.new()
		resident.state = PopUnit.State.WORKER
		city.pop.append(resident)

	var hero: HeroController = auto_free(TestFactories.make_hero())
	hero.movement_comp.set_current_cell(hero_cell)
	hero.strategic_resources.set_all({&"food": carried_food})
	var ctx := TurnContext.new()
	ctx.is_campaign = true
	ctx.cities.append(city)
	ctx.heroes.append(hero)
	return {"city": city, "hero": hero, "context": ctx}

func _run_economy_turn(ctx: TurnContext) -> Dictionary:
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(EconomicTurnProcessor.new())
	return scheduler.execute_turn(ctx)

func test_campaign_mode_skips_legacy_city_growth_food_debit() -> void:
	var manager: CityManager = auto_free(CityManager.new())
	var city := TestFactories.make_city()
	manager.register_city(city, true)
	manager.is_campaign = true
	city.food_stockpile = 10.0
	var resident := PopUnit.new()
	resident.state = PopUnit.State.WORKER
	city.pop.append(resident)

	manager.on_turn_ended(1)

	assert_that(city.food_stockpile).is_equal(10.0)

func test_campaign_mode_skips_legacy_capital_inflow() -> void:
	var manager: CityManager = auto_free(CityManager.new())
	var city := TestFactories.make_city()
	manager.register_city(city, true)
	manager.is_campaign = true
	var report: Dictionary = {}
	for _turn in range(GameNumbers.CITY_CYCLE_TURNS):
		report = manager.on_turn_ended(1)

	assert_bool(bool(report.cycle)).is_false()
	assert_that(int(report.arrivals)).is_zero()
	assert_that(city.pop.size()).is_zero()

func test_legacy_mode_keeps_one_food_per_worker_behavior() -> void:
	var manager: CityManager = auto_free(CityManager.new())
	var city := TestFactories.make_city()
	manager.register_city(city, true)
	city.food_stockpile = 2.0
	var resident := PopUnit.new()
	resident.state = PopUnit.State.WORKER
	city.pop.append(resident)

	manager.on_turn_ended(1)

	assert_that(city.food_stockpile).is_equal(1.0)

func test_campaign_residents_consume_point_one_food_each_through_ledger() -> void:
	var fixture := _make_campaign_context(20, 30.0, Vector2i(50, 50), 0)
	var city: City = fixture.city
	var report := _run_economy_turn(fixture.context)
	var economy: Dictionary = report.phases.economy
	var city_report: Dictionary = economy.cities[0]
	var food_report: Dictionary = city_report.campaign_food
	var flows: Array = report.ledger[0].flows

	assert_that(float(food_report.resident_demand)).is_equal(2.0)
	assert_that(float(food_report.resident_consumed)).is_equal(2.0)
	assert_that(economy.auto_yield).is_empty()
	assert_that(city.food_stockpile).is_equal(28.0)
	assert_that(flows.size()).is_equal(1)
	assert_that(String(flows[0].source)).is_equal("campaign:resident_food")
	assert_that(float(flows[0].inputs.food)).is_equal(2.0)

func test_in_city_refills_before_party_rations_and_resident_demand() -> void:
	var fixture := _make_campaign_context(20, 30.0, Vector2i(5, 5), 0)
	var city: City = fixture.city
	var hero: HeroController = fixture.hero
	var report := _run_economy_turn(fixture.context)
	var flows: Array = report.ledger[0].flows
	var party: Dictionary = report.phases.economy.party

	assert_that(float(city.food_stockpile)).is_equal(18.0)
	assert_that(int(hero.strategic_resources.get_all().get(&"food", 0))).is_equal(8)
	assert_that(int(party.resupplied)).is_equal(10)
	assert_that(int(party.consumed)).is_equal(2)
	assert_that(flows.size()).is_equal(2)
	assert_that(String(flows[0].source)).is_equal("campaign:party_resupply")
	assert_that(float(flows[0].inputs.food)).is_equal(10.0)
	assert_that(String(flows[1].source)).is_equal("campaign:resident_food")
	assert_that(float(flows[1].inputs.food)).is_equal(2.0)

func test_away_party_uses_carried_food_without_city_debit() -> void:
	var fixture := _make_campaign_context(0, 30.0, Vector2i(50, 50), 5)
	var city: City = fixture.city
	var hero: HeroController = fixture.hero
	var report := _run_economy_turn(fixture.context)
	var party: Dictionary = report.phases.economy.party

	assert_that(int(hero.strategic_resources.get_all().get(&"food", 0))).is_equal(3)
	assert_that(int(party.resupplied)).is_zero()
	assert_that(int(party.consumed)).is_equal(2)
	assert_that(float(city.food_stockpile)).is_equal(30.0)
	assert_that(report.ledger[0].flows).is_empty()

func test_food_shortages_are_reported_without_negative_stocks() -> void:
	var fixture := _make_campaign_context(20, 0.0, Vector2i(50, 50), 0)
	var city: City = fixture.city
	var report := _run_economy_turn(fixture.context)
	var economy: Dictionary = report.phases.economy
	var city_report: Dictionary = economy.cities[0]
	var food_report: Dictionary = city_report.campaign_food
	var party: Dictionary = economy.party

	assert_that(float(city.food_stockpile)).is_zero()
	assert_that(float(food_report.resident_shortage)).is_equal(2.0)
	assert_that(int(party.shortage)).is_equal(2)
	assert_that(int(fixture.hero.strategic_resources.get_all().get(&"food", 0))).is_zero()
	assert_that(report.ledger[0].flows).is_empty()

func test_campaign_turn_completes_construction_then_produces_consumes_and_reports_needs() -> void:
	var city := TestFactories.make_city()
	city.center = Vector2i(5, 5)
	for index in range(20):
		var resident := PopUnit.new()
		resident.state = PopUnit.State.WORKER if index < 2 else PopUnit.State.FOLLOWER
		resident.ancestry_id = "halflings"
		city.pop.append(resident)
	city.campaign_buildings.append({
		"uid": 41,
		"id": "campaign_farm",
		"cell": city.center,
		"footprint": [[0, 0]],
		"state": "inactive",
		"construction_turns_remaining": 1,
		"jobs": 2,
		"assigned_workers": 0,
		"roles": ["food_production"],
		"recipes": [{"id": "farm_food", "workers": 2, "inputs": {}, "outputs": {"food": 4.0}}],
	})
	var manager: CityManager = auto_free(CityManager.new())
	manager.is_campaign = true
	manager.cities.append(city)
	manager.on_turn_ended(1)

	var context := TurnContext.new()
	context.is_campaign = true
	context.cities.append(city)
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(CampaignConstructionProcessor.new())
	scheduler.register_processor(EconomicTurnProcessor.new())
	var report := scheduler.execute_turn(context)
	var economy: Dictionary = report.phases.economy
	var city_report: Dictionary = economy.cities[0]
	var food_report: Dictionary = city_report.campaign_food
	var food_group: Dictionary = city_report.campaign_population.groups.farmers_brewers

	assert_that(String(report.economy_mode)).is_equal("campaign")
	assert_that(report.phases.keys()).is_equal([&"campaign_construction", &"economy"])
	assert_that(String(city.campaign_buildings[0].state)).is_equal("active")
	assert_that(int(city.campaign_buildings[0].assigned_workers)).is_equal(2)
	assert_that(float(food_report.resident_demand)).is_equal(2.0)
	assert_that(float(food_report.resident_consumed)).is_equal(2.0)
	assert_that(int(food_group.coverage_percent)).is_equal(100)
	assert_that(float(city.food_stockpile) > 0.0).is_true()

func test_campaign_food_ledger_repeats_deterministically() -> void:
	var first := _make_campaign_context(20, 30.0, Vector2i(5, 5), 0)
	var second := _make_campaign_context(20, 30.0, Vector2i(5, 5), 0)
	var first_report := _run_economy_turn(first.context)
	var second_report := _run_economy_turn(second.context)
	var first_result := {
		"flows": first_report.ledger[0].flows,
		"city_food": first.city.food_stockpile,
		"party_food": first.hero.strategic_resources.get_all().get(&"food", 0),
	}
	var second_result := {
		"flows": second_report.ledger[0].flows,
		"city_food": second.city.food_stockpile,
		"party_food": second.hero.strategic_resources.get_all().get(&"food", 0),
	}

	assert_that(JSON.stringify(first_result)).is_equal(JSON.stringify(second_result))
