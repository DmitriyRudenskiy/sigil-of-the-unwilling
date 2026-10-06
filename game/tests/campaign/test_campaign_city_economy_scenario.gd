extends BaseTest

const CityTurnProcessor := preload("res://scripts/city/city_turn_processor.gd")
const CampaignBuildingMerger := preload("res://scripts/city/campaign_building_merger.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CampaignTrainingService := preload("res://scripts/campaign/campaign_training_service.gd")
const EconomicTurnProcessor := preload("res://scripts/economy/economic_turn_processor.gd")
const CityGrowthService := preload("res://scripts/world/city_growth_service.gd")
const TurnScheduler := preload("res://scripts/core/turn_scheduler.gd")

var _city_turn_processor
var _economic_processor

func before_test() -> void:
	_city_turn_processor = CityTurnProcessor.new()
	_economic_processor = EconomicTurnProcessor.new()
const ArenaRingSystem := preload("res://scripts/city/arena_ring_system.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")

func _building_catalog() -> Dictionary:
	return {"schema_version": 1, "buildings": [{
		"id": "barracks",
		"training": [{"class_id": "fighter", "costs": {"food": 2.0, "iron": 1.0}}],
		"prerequisites": {"buildings": [], "scenario_flags": [], "admin_capacity": 0},
	}]}

func _state(city: City) -> Dictionary:
	return {
		"campaign": {"turn": 1, "seed": 123, "phase": "city"},
		"resources": city.resource_ctx.serialize(),
		"population": {"count": 2, "housing": 2}, "party": [],
		"city": {"buildings": {}, "districts": [],
			"campaign_buildings": city.campaign_buildings.duplicate(true)},
		"map": {"region": "R01", "fog": {}, "nodes": {}},
		"prestige": {"ledger": []}, "sign": {"id": "R1", "progress": 0},
	}

func _make_city(uid: int) -> City:
	var city := TestFactories.make_city(uid)
	city.center = ArenaRingSystem.center()
	city.ensure_resource_ctx(Resources.get_campaign_resource_defs(true)).setup(
		Resources.get_campaign_resource_defs(true), true)
	city.resource_ctx.deserialize({"food": 5.0, "wood": 10.0, "iron": 5.0})
	var center := ArenaRingSystem.center()
	var near := HexUtils.get_neighbor(center, 0, true)
	city.campaign_buildings.append_array([
		{"uid": 1, "id": "farm", "cell": center, "footprint": [[0, 0]],
			"state": "active", "assigned_workers": 1, "resident_ids": ["r1"],
			"resident_capacity": 1, "stock": {"wood": 1.0}},
		{"uid": 2, "id": "mill", "cell": near, "footprint": [[0, 0]],
			"state": "active", "assigned_workers": 1, "resident_ids": ["r2"],
			"resident_capacity": 1, "stock": {"food": 1.0}},
		{"uid": 10, "id": "barracks", "cell": HexUtils.get_neighbor(center, 2, true),
			"footprint": [[0, 0]], "state": "active", "assigned_workers": 0},
		{"uid": 11, "id": "field", "cell": HexUtils.get_neighbor(center, 3, true),
			"footprint": [[0, 0]], "state": "active", "assigned_workers": 0,
			"roles": ["agriculture"], "adjacency": [{"id": "near_field",
				"target_role": "food_production", "effect": "food_output_bp",
				"value": 500.0, "radius": 1}]},
		{"uid": 12, "id": "watchtower", "cell": HexUtils.get_neighbor(center, 4, true),
			"footprint": [[0, 0]], "state": "active", "roles": ["static_defense"],
			"defense": {"active": 4, "inactive": 0, "ruined": 0}},
	])
	var merged := CampaignBuildingMerger.merge(city.campaign_buildings, {
		"id": "bakery", "jobs": 2, "resident_capacity": 2,
		"footprint": [[0, 0]], "placement": {"terrain_tags": [], "requires_special_site": false},
		"roles": ["food_production"], "services": {"food": 1.0},
		"recipes": [{"id": "bake", "workers": 2,
			"inputs": {"wood": 1.0}, "outputs": {"food": 2.0}}],
		"upkeep": {"wood": 0.5},
		"merge": {"components": ["farm", "mill"], "max_distance": 1},
	}, [1, 2])
	assert_bool(merged.ok).is_true()
	city.campaign_buildings.clear()
	for building in merged.buildings:
		city.campaign_buildings.append(building)
	var bakery_uid := int(merged.result.uid)
	var engineer := city.add_migrant(PopUnit.State.WORKER, 0)
	engineer.ancestry_id = "gnomes"
	engineer.archetype_id = "engineers_builders"
	engineer.assigned_to = bakery_uid
	engineer.tile = HexUtils.get_neighbor(center, 1, true)
	var farmer := city.add_migrant(PopUnit.State.WORKER, 0)
	farmer.ancestry_id = "halflings"
	farmer.archetype_id = "farmers_brewers"
	farmer.assigned_to = bakery_uid
	farmer.tile = HexUtils.get_neighbor(center, 5, true)
	city.resource_ctx.clear_ledger()
	return city

func _run_scenario() -> Dictionary:
	var city := _make_city(6)
	CityGrowthService.process_turn(city, 1)
	var state := _state(city)
	var trained := CampaignTrainingService.train(
		state, _building_catalog(), 10, "fighter",
		{"id": "guard_1", "name": "Guard", "race": "humans",
			"stats": {"str": 13, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}},
		[], 0, CampaignTrainingService.PARTY_CAPACITY, city.resource_ctx)
	assert_bool(trained.ok).is_true()
	var context := TurnContext.new()
	context.cities.append(city)
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(_city_turn_processor)
	scheduler.register_processor(_economic_processor)
	var turn_report: Dictionary = scheduler.execute_turn(context)
	var city_report: Dictionary = turn_report.phases.city
	var economy_report: Dictionary = turn_report.phases.economy
	var adjacency := CampaignBuildingPlacement.recompute_adjacency(city.campaign_buildings)
	return {
		"uid": city.uid,
		"raid": city_report.cities[0],
		"economy": economy_report,
		"adjacency": adjacency,
		"group_state": economy_report.cities[0].campaign_population.groups.duplicate(true),
		"party": state.party.duplicate(true),
		"food": city.food_stockpile,
		"ledger": turn_report.ledger[0].flows,
	}

func test_campaign_turn_with_merge_training_and_pressure_raid_is_reproducible() -> void:
	var first := _run_scenario()
	var second := _run_scenario()
	assert_bool(first.is_empty()).is_false()
	assert_that(first).is_equal(second)
	assert_that(first.raid.raid_occurred).is_equal(1)
	assert_that(first.raid.raid_repelled).is_false()
	assert_that(first.party.size()).is_equal(1)
	assert_that(first.party[0]["class"]).is_equal("fighter")
	assert_that(first.group_state.engineers_builders.relation_delta).is_equal(1)
	assert_that(first.group_state.farmers_brewers.relation_delta).is_equal(1)
	assert_that(first.economy.cities[0].specialization[0].specialization_bonus_bp).is_equal(1000)
	var bakery_adjacency := {}
	for entry in first.adjacency:
		if String(entry.building_id) == "bakery":
			bakery_adjacency = entry.breakdown
	assert_float(float(bakery_adjacency.effects.food_output_bp)).is_equal_approx(500.0, 0.0001)
	assert_bool(first.ledger.any(func(flow: Dictionary) -> bool:
		return String(flow.source) == "training:guard_1/class:fighter"
	)).is_true()
	assert_bool(first.ledger.any(func(flow: Dictionary) -> bool:
		return String(flow.source) == "campaign-building:bakery/recipe:bake"
	)).is_true()
	assert_bool(first.ledger.any(func(flow: Dictionary) -> bool:
		return String(flow.source) == "raid:pillage"
	)).is_true()
