extends BaseTest

func test_sale_counts_only_a_real_transaction() -> void:
	var city := _city_with_market()
	city.storage[&"wood"] = 5.0
	var pilot := _FakePilot.new(city)
	var role := TraderRole.new()
	var industry_before: float = city.storage[&"industry"]

	assert_bool(role.act(pilot)).is_true()
	var metrics: Dictionary = role.metrics(pilot)
	assert_that(int(metrics.deals)).is_equal(1)
	assert_that(metrics.transactions.size()).is_equal(1)
	assert_that(metrics.transactions[0].resource).is_equal("wood")
	assert_float(float(metrics.transactions[0].stock_before)).is_equal(5.0)
	assert_float(float(metrics.transactions[0].stock_after)).is_equal(0.0)
	assert_float(float(city.storage[&"industry"])).is_greater(industry_before)
	assert_float(float(city.storage[&"wood"])).is_equal(0.0)

	pilot.free()

func test_noop_stock_does_not_count_as_a_deal() -> void:
	var city := _city_with_market()
	city.storage[&"wood"] = GameNumbers.MARKET_MIN_AMOUNT - 0.5
	var pilot := _FakePilot.new(city)
	var role := TraderRole.new()

	assert_bool(role.act(pilot)).is_false()
	var metrics: Dictionary = role.metrics(pilot)
	assert_that(int(metrics.deals)).is_equal(0)
	assert_that(metrics.transactions).is_empty()
	assert_float(float(city.storage[&"wood"])).is_equal(0.5)

	pilot.free()

func test_world_role_trader_completes_a_sale_headlessly() -> void:
	const class_id := "druid"
	const role_id := "trader"
	var seed_value: int = ScenarioTargets.seed_for(class_id, role_id)
	assert_that(ScenarioPilot.prepare_world(seed_value, class_id).get("status")).is_equal("prepared")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	for _i in 20:
		await get_tree().process_frame
		if world.get_hero() != null and world.get_map_gen() != null:
			break
	assert_bool(world.get_hero() != null).is_true()
	var pilot: Node = load("res://scenes/probe/ScenarioPilot.tscn").instantiate()
	get_tree().root.add_child(pilot)
	assert_that(pilot.start_scenario(world, seed_value, role_id, class_id).get("status")).is_equal("scenario_started")
	pilot.max_turns = 60
	for _frame in 30000:
		if pilot.done or not is_instance_valid(pilot._hero):
			break
		await get_tree().process_frame
	assert_bool(pilot.role._deals >= 3).is_true()
	var metrics: Dictionary = pilot.role.metrics(pilot)
	assert_bool(int(metrics.gold_goal) == 1000).is_true()
	assert_bool(metrics.transactions.size() >= 3).is_true()
	assert_bool(bool(metrics.market_available)).is_true()
	assert_bool(pilot.first_building_turn >= 0).is_true()
	assert_bool(metrics.transactions.size() > 0).is_true()
	for transaction in metrics.transactions:
		assert_bool(float(transaction.stock_after) < float(transaction.stock_before)).is_true()
		assert_bool(float(transaction.industry_after) > float(transaction.industry_before)).is_true()
	pilot.queue_free()
	world.queue_free()
	await get_tree().process_frame

func test_fighter_trader_returns_to_market_with_real_cargo() -> void:
	const class_id := "fighter"
	const role_id := "trader"
	var seed_value: int = ScenarioTargets.seed_for(class_id, role_id)
	assert_that(ScenarioPilot.prepare_world(seed_value, class_id).get("status")).is_equal("prepared")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	for _i in 20:
		await get_tree().process_frame
		if world.get_hero() != null and world.get_map_gen() != null:
			break
	var pilot: Node = load("res://scenes/probe/ScenarioPilot.tscn").instantiate()
	get_tree().root.add_child(pilot)
	assert_that(pilot.start_scenario(world, seed_value, role_id, class_id).get("status")).is_equal("scenario_started")
	for _frame in 30000:
		if pilot.role._deals > 0 or pilot.done or not is_instance_valid(pilot._hero):
			break
		await get_tree().process_frame
	var metrics: Dictionary = pilot.role.metrics(pilot)
	assert_bool(pilot.role._deals > 0).is_true()
	assert_bool(bool(metrics.market_available)).is_true()
	assert_bool(pilot.first_building_turn >= 0).is_true()
	assert_bool(metrics.transactions.size() > 0).is_true()
	for transaction in metrics.transactions:
		assert_bool(String(transaction.resource) != "food").is_true()
		assert_bool(float(transaction.stock_after) < float(transaction.stock_before)).is_true()
		assert_bool(float(transaction.industry_after) > float(transaction.industry_before)).is_true()
	pilot.queue_free()
	world.queue_free()
	await get_tree().process_frame

func _city_with_market() -> City:
	var city := City.new()
	city.center = Vector2i.ZERO
	city.storage[&"industry"] = 10.0
	var market := UniqueBuilding.new()
	market.def = BuildingDefs.market()
	city.buildings.append(market)
	return city

class _FakeWorld extends RefCounted:
	func get_endgame_state() -> Dictionary:
		return {"state": "RUNNING"}

class _FakePilot extends Node:
	var _player_city: City
	var _world := _FakeWorld.new()
	var turn := 1
	var commits := 0

	func _init(city: City) -> void:
		_player_city = city

	func _hero_cell() -> Vector2i:
		return _player_city.center

	func _city_center() -> Vector2i:
		return _player_city.center

	func _unload_backpack() -> int:
		return 0

	func _commit(_progress: bool) -> void:
		commits += 1
