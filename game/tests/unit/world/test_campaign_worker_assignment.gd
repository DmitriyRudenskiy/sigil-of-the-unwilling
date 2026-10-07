extends BaseTest

const TestFactories := preload("res://tests/helpers/factories.gd")

func _add_worker(city: City, assigned_to: int = -1) -> PopUnit:
	var worker := PopUnit.new()
	worker.state = PopUnit.State.WORKER
	worker.assigned_to = assigned_to
	city.pop.append(worker)
	return worker

func _building(uid: int, recipes: Array, jobs: int = 0, state: String = "active") -> Dictionary:
	return {
		"uid": uid,
		"id": "building_%d" % uid,
		"state": state,
		"jobs": jobs,
		"assigned_workers": 0,
		"recipes": recipes,
	}

func _recipe(id: String, output: String, workers: int, amount: float = 1.0) -> Dictionary:
	return {
		"id": id,
		"workers": workers,
		"inputs": {},
		"outputs": {output: amount},
	}

func test_food_then_wood_then_iron_and_uid_tie_break() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings = [
		_building(20, [_recipe("food", "food", 2)]),
		_building(10, [_recipe("food", "food", 2)]),
		_building(30, [_recipe("wood", "wood", 2)]),
		_building(40, [_recipe("iron", "iron", 2)]),
	]
	for _i in range(3):
		_add_worker(city)

	WorkerAssignment.rebalance(city)

	assert_that(int(city.campaign_buildings[1].assigned_workers)).is_equal(2)
	assert_that(int(city.campaign_buildings[0].assigned_workers)).is_equal(1)
	assert_that(int(city.campaign_buildings[2].assigned_workers)).is_zero()
	assert_that(int(city.campaign_buildings[3].assigned_workers)).is_zero()

func test_preserves_valid_assignments_and_caps_staff_by_building_jobs() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings = [
		_building(1, [_recipe("farm", "food", 3)], 1),
		_building(2, [_recipe("sawmill", "wood", 2)], 2),
	]
	_add_worker(city, 1)
	_add_worker(city, 1)
	_add_worker(city)

	WorkerAssignment.rebalance(city)

	assert_that(int(city.campaign_buildings[0].assigned_workers)).is_equal(1)
	assert_that(int(city.campaign_buildings[1].assigned_workers)).is_equal(2)
	assert_that(city.pop[0].assigned_to).is_equal(1)
	assert_that(city.pop[1].assigned_to).is_equal(2)
	assert_that(city.pop[2].assigned_to).is_equal(2)

func test_inactive_constructing_ruined_and_recipe_less_buildings_release_workers() -> void:
	var city := TestFactories.make_city()
	var inactive := _building(1, [_recipe("food", "food", 1)], 1, "inactive")
	var constructing := _building(2, [_recipe("food", "food", 1)], 1, "active")
	constructing.construction_turns_remaining = 2
	var ruined := _building(3, [_recipe("food", "food", 1)], 1, "ruined")
	var no_recipe := _building(4, [], 1)
	city.campaign_buildings = [inactive, constructing, ruined, no_recipe]
	for uid in range(1, 5):
		_add_worker(city, uid)

	WorkerAssignment.rebalance(city)

	for building in city.campaign_buildings:
		assert_that(int(building.assigned_workers)).is_zero()
	for worker in city.pop:
		assert_that(worker.assigned_to).is_equal(-1)

func test_partial_staffing_is_shared_across_recipes_in_stable_priority_order() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings = [_building(7, [
		_recipe("wood_recipe", "wood", 2, 2.0),
		_recipe("food_recipe", "food", 2, 2.0),
	], 4)]
	for _i in range(3):
		_add_worker(city)

	WorkerAssignment.rebalance(city)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = EconomicTurnProcessor.new().process(ctx)
	var recipe_flows := {}
	for flow in report.ledger:
		if String(flow.source).begins_with("campaign-building:building_7/recipe:"):
			recipe_flows[String(flow.source)] = flow.outputs

	assert_that(int(city.campaign_buildings[0].assigned_workers)).is_equal(3)
	assert_that(float(recipe_flows["campaign-building:building_7/recipe:food_recipe"].food)).is_equal(2.0)
	assert_that(float(recipe_flows["campaign-building:building_7/recipe:wood_recipe"].wood)).is_equal(1.0)

func test_recipe_id_breaks_equal_priority_ties() -> void:
	var city := TestFactories.make_city()
	city.campaign_buildings = [_building(8, [
		_recipe("z_food", "food", 1, 9.0),
		_recipe("a_food", "food", 1, 2.0),
	], 2)]
	_add_worker(city)

	WorkerAssignment.rebalance(city)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = EconomicTurnProcessor.new().process(ctx)
	var recipe_sources: Array[String] = []
	for flow in report.ledger:
		if String(flow.source).begins_with("campaign-building:building_8/recipe:"):
			recipe_sources.append(String(flow.source))

	assert_that(recipe_sources).is_equal(["campaign-building:building_8/recipe:a_food"])
