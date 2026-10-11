extends BaseTest

const CampaignConstructionProcessor := preload("res://scripts/city/processors/campaign_construction_processor.gd")

class _EconomyProbe extends TurnPhaseProcessor:
	var city: City
	var observed: Dictionary = {}

	func get_phase_id() -> StringName:
		return &"economy_probe"

	func get_priority() -> int:
		return 10

	func process(_ctx: TurnContext) -> Dictionary:
		observed = city.campaign_buildings[0].duplicate(true)
		return {}

func test_progress_advances_once_and_activates_only_at_zero() -> void:
	var city := City.new()
	city.campaign_buildings = [
		{"uid": 1, "id": "two_turn", "state": "inactive", "construction_turns_remaining": 2},
		{"uid": 2, "id": "one_turn", "state": "inactive", "construction_turns_remaining": 1},
		{"uid": 3, "id": "complete", "state": "active", "construction_turns_remaining": 0},
		{"uid": 4, "id": "ruined", "state": "ruined", "construction_turns_remaining": 1},
		{"uid": 5, "id": "legacy", "state": "active"},
	]
	var changed := [0]
	city.buildings_changed.connect(func(): changed[0] += 1)
	var processor := CampaignConstructionProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)

	var first: Dictionary = processor.process(ctx)
	assert_that(processor.get_priority()).is_equal(9)
	assert_that(int(first.advanced)).is_equal(2)
	assert_that(first.completed).contains_exactly([2])
	assert_that(city.campaign_buildings[0].construction_turns_remaining).is_equal(1)
	assert_that(city.campaign_buildings[0].state).is_equal("inactive")
	assert_that(city.campaign_buildings[1].construction_turns_remaining).is_zero()
	assert_that(city.campaign_buildings[1].state).is_equal("active")
	assert_that(city.campaign_buildings[2].state).is_equal("active")
	assert_that(city.campaign_buildings[3].state).is_equal("ruined")
	assert_bool(city.campaign_buildings[4].has("construction_turns_remaining")).is_false()

	var second: Dictionary = processor.process(ctx)
	assert_that(int(second.advanced)).is_equal(1)
	assert_that(second.completed).contains_exactly([1])
	assert_that(city.campaign_buildings[0].state).is_equal("active")
	assert_that(changed[0]).is_equal(2)

func test_completion_happens_before_economy_phase() -> void:
	var city := City.new()
	city.campaign_buildings = [{
		"uid": 7, "id": "farm", "state": "inactive", "construction_turns_remaining": 1,
	}]
	var construction := CampaignConstructionProcessor.new()
	var economy := _EconomyProbe.new()
	economy.city = city
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(economy)
	scheduler.register_processor(construction)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report := scheduler.execute_turn(ctx)
	assert_that(report.phases.keys()).contains_exactly([&"campaign_construction", &"economy_probe"])
	assert_that(economy.observed.state).is_equal("active")
	assert_that(economy.observed.construction_turns_remaining).is_zero()
