extends GdUnitTestSuite

var c: City

func before_test() -> void:
	c = City.new()
	c.center = Vector2i(5, 5)
	c.scale_tier = 0
	c.auto_resource_mult = 1.0
	c.upkeep_mult = 1.0
	c.owner = &"player"

func test_food_consumption_zero() -> void:
	assert_float(CityGrowthService.food_consumption(c)).is_equal_approx(0.0, 0.0001)

func test_food_consumption_worker() -> void:
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	assert_float(CityGrowthService.food_consumption(c)).is_equal_approx(GameNumbers.FOOD_PER_WORKER, 0.0001)

func test_food_consumption_militia() -> void:
	var u = c.add_migrant(PopUnit.State.MILITIA, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	assert_float(CityGrowthService.food_consumption(c)).is_equal_approx(GameNumbers.FOOD_PER_MILITIA, 0.0001)

func test_net_food_positive() -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 10.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	var nf := CityGrowthService.net_food(c)
	assert_that(nf > 0.0).is_true()

func test_net_food_negative() -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 0.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	var nf := CityGrowthService.net_food(c)
	assert_that(nf < 0.0).is_true()

func test_growth_threshold_positive() -> void:
	assert_that(CityGrowthService.growth_threshold(c) > 0.0).is_true()

func test_growth_threshold_monotonic() -> void:
	c.add_followers(10)
	var t1 := CityGrowthService.growth_threshold(c)
	c.add_followers(10)
	var t2 := CityGrowthService.growth_threshold(c)
	assert_that(t2 > t1).is_true()

func test_process_turn_returns_report() -> void:
	var report := CityGrowthService.process_turn(c, 0)
	assert_that(report.has("births")).is_true()
	assert_that(report.has("starving")).is_true()
	assert_that(report.has("net_food")).is_true()

func test_process_turn_birth_with_surplus() -> void:

	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 100.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	c.food_stockpile = 500.0
	var pop_before := c.pop.size()
	var report := CityGrowthService.process_turn(c, 1)
	assert_that(int(report.get("births", 0)) >= 1).is_true()
	assert_that(c.pop.size() > pop_before).is_true()

func test_starvation_flag() -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 0.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	CityGrowthService.process_turn(c, 0)
	assert_that(c.starving).is_true()
