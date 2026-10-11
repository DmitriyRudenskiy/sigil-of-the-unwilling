extends BaseTest

const ArchetypeResolver := preload("res://scripts/demographics/archetype_resolver.gd")
const CampaignCityBalanceFixture := preload("res://scripts/balance/campaign_city_balance_fixture.gd")
const CampaignCityBalanceScenario := preload("res://scripts/balance/campaign_city_balance_scenario.gd")
const EconomicTurnProcessor := preload("res://scripts/economy/economic_turn_processor.gd")
const GameNumbers := preload("res://scripts/constants/game_numbers.gd")
const MvpSaveSchema := preload("res://scripts/campaign/save/mvp_save_schema.gd")

func test_canonical_campaign_fixture_matches_mvp_inputs() -> void:
	var fixture := CampaignCityBalanceFixture.create()
	var city: City = fixture.city
	var hero: HeroController = fixture.hero
	var manager: CityManager = fixture.city_manager

	assert_that(city.pop.size()).is_equal(20)
	assert_that(int(fixture.housing_capacity)).is_equal(20)
	assert_that(city.resource_ctx.serialize()).is_equal({"food": 30.0, "wood": 20.0, "iron": 10.0})
	assert_that(fixture.party.size()).is_equal(2)
	assert_that(int(fixture.party_members)).is_equal(EconomicTurnProcessor.MVP_PARTY_MEMBERS)
	assert_that(int(fixture.provision_capacity)).is_equal(EconomicTurnProcessor.PROVISION_CAPACITY)
	assert_that(int(fixture.resident_count)).is_equal(20)
	assert_that(fixture.assumptions.party_classes).is_equal(["fighter", "ranger"])
	assert_that(String(fixture.party[0]["class"])).is_equal("fighter")
	assert_that(String(fixture.party[1]["class"])).is_equal("ranger")
	assert_that(hero.hero_class).is_equal("fighter")
	assert_that(hero.current_cell).is_equal(city.center)
	assert_that(int(hero.strategic_resources.get_all().get(&"food", -1))).is_zero()
	assert_bool(manager.is_campaign).is_true()
	assert_that(fixture.city_cells.size()).is_equal(52)
	assert_that(int(city.campaign_buildings.size())).is_equal(2)
	assert_that(int(city.campaign_buildings[0].resident_capacity) \
		+ int(city.campaign_buildings[1].resident_capacity)).is_equal(20)
	assert_that(int(fixture.assumptions.carried_food)).is_zero()
	CampaignCityBalanceFixture.dispose(fixture)

func test_fixture_resident_split_uses_all_canonical_mvp_groups() -> void:
	var fixture := CampaignCityBalanceFixture.create()
	var catalog := ArchetypeResolver.load_catalog()
	var actual := {}
	for resident in fixture.city.pop:
		var group_id := ArchetypeResolver.group_id_for_identity(
			catalog, resident.ancestry_id, resident.archetype_id)
		actual[group_id] = int(actual.get(group_id, 0)) + 1

	assert_that(actual).is_equal(fixture.resident_groups)
	assert_that(actual.values().reduce(func(total: int, count: int) -> int: return total + count, 0)) \
		.is_equal(20)
	CampaignCityBalanceFixture.dispose(fixture)

func test_fixture_does_not_change_legacy_city_factory_start() -> void:
	var before := CampaignCityBalanceFixture.legacy_city_signature()

	assert_that(int(before.workers)).is_equal(GameNumbers.VILLAGE_START_WORKERS)
	assert_that(int(before.followers)).is_equal(GameNumbers.VILLAGE_START_FOLLOWERS)
	assert_that(float(before.food)).is_equal(GameNumbers.VILLAGE_START_FOOD)
	assert_that(float(before.gold)).is_equal(GameNumbers.VILLAGE_START_GOLD)
	assert_that(float(before.industry)).is_equal(GameNumbers.VILLAGE_START_INDUSTRY)
	assert_bool(MvpSaveSchema.SECTIONS.has("is_campaign")).is_false()

func test_21_day_run_repeats_identical_daily_ledgers_and_state() -> void:
	var first := CampaignCityBalanceScenario.run()
	var second := CampaignCityBalanceScenario.run()

	assert_bool(first.ok).is_true().override_failure_message(str(first.technical_errors))
	assert_bool(second.ok).is_true().override_failure_message(str(second.technical_errors))
	assert_that(first.days_report.size()).is_equal(21)
	assert_that(second.days_report.size()).is_equal(21)
	assert_bool(first.balance_pass).is_true()
	assert_that(first.warnings).is_empty()
	assert_that(first.construction_summary.affordability.attempted).is_equal(15)
	assert_that(first.construction_summary.affordability.affordable).is_equal(15)
	assert_that(first.construction_summary.construction_build_days.campaign_farm).is_equal([1, 6])
	assert_that(first.summary.day21_defense).is_equal(4)
	assert_float(float(first.summary.day21_stocks.food)).is_equal_approx(1.1, 0.0001)
	assert_that(first.summary.day21_group_coverage.size()).is_equal(7)
	for group_state in first.summary.day21_group_coverage.values():
		assert_that(int(group_state.coverage_percent)).is_equal(100)
	assert_that(first.summary.footprint_cells_used).is_equal(17)
	assert_that(first.city_progression.level).is_equal(5)
	assert_that(first.city_progression.occupied_city_cells).is_equal(21)
	assert_that(first.city_progression.cell_limit).is_equal(24)
	assert_that(first.days_report[0].level_up_actions.size()).is_equal(1)
	assert_that(first.days_report[0].level_up_actions[0].to_level).is_equal(2)
	assert_that(first.days_report[1].level_up_actions[0].to_level).is_equal(3)
	assert_that(first.days_report[10].level_up_actions[0].to_level).is_equal(4)
	assert_that(first.days_report[16].level_up_actions[0].to_level).is_equal(5)
	assert_that(first.construction_summary.cumulative_costs).is_equal({
		"food": 17.0, "wood": 59.0, "iron": 20.0,
	})
	var day21_workers := 0
	for building_staff in first.days_report[-1].staffing:
		day21_workers += int(building_staff.assigned_workers)
	assert_that(day21_workers).is_equal(8)
	for day_report in first.days_report:
		for resource in ["food", "wood", "iron"]:
			assert_bool(float(day_report.stocks[resource]) >= 0.0).is_true()
	for milestone in first.milestones:
		assert_bool(milestone.achieved).is_true().override_failure_message(str(milestone))
	assert_that(first.days_report[0].construction.map(func(building: Dictionary) -> String:
		return String(building.id))).is_equal(["campaign_farm", "campaign_barracks"])
	assert_that(int(first.days_report[6].raid[0].day)).is_equal(7)
	for day_index in range(21):
		var first_day: Dictionary = first.days_report[day_index]
		var second_day: Dictionary = second.days_report[day_index]
		assert_that(int(first_day.day)).is_equal(day_index + 1)
		assert_that(first_day.ledger).is_equal(second_day.ledger)
		assert_that(first_day.stocks).is_equal(second_day.stocks)
		assert_that(first_day.staffing).is_equal(second_day.staffing)
		assert_that(first_day.buildings).is_equal(second_day.buildings)
	assert_that(first).is_equal(second)

func test_target_miss_is_a_warning_not_a_technical_failure() -> void:
	var report := CampaignCityBalanceScenario.run({"day21_food_max": 0.0})

	assert_bool(report.ok).is_true()
	assert_bool(report.balance_pass).is_false()
	assert_that(report.technical_errors).is_empty()
	assert_that(report.warnings.size()).is_equal(1)
	assert_that(String(report.warnings[0].code)).is_equal("day21_food")
	assert_float(float(report.warnings[0].expected.max)).is_zero()
	assert_float(float(report.warnings[0].actual)).is_equal_approx(1.1, 0.0001)
