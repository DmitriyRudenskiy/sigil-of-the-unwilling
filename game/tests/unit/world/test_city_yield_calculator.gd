extends BaseTest

var c: City

func before_test() -> void:
	c = City.new()
	c.center = Vector2i(5, 5)
	c.scale_tier = 0
	c.auto_resource_mult = 1.0
	c.upkeep_mult = 1.0
	c.owner = &"player"

func test_empty_city_zero_yield() -> void:
	var y := CityYieldCalculator.new().calculate(c)
	assert_float(y[&"food"]).is_equal_approx(0.0, 0.0001)

func test_worker_on_tile_generates_yield() -> void:
	c.resource_ctx = null
	c.ensure_resource_ctx()
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 1.0}
	var calc := CityYieldCalculator.new()
	for i in 2:
		var u = c.add_migrant(PopUnit.State.WORKER, 0)
		u.tile = HexUtils.get_all_neighbors(c.center)[i % 6]
	var y := calc.calculate(c)
	assert_float(y[&"food"]).is_equal_approx(2.0, 0.0001)

func test_cached_result_no_recalc() -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 1.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	var calc := CityYieldCalculator.new()
	var y1 := calc.calculate(c)
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 999.0}
	var y2 := calc.calculate(c)
	assert_float(y2[&"food"]).is_equal_approx(y1[&"food"], 0.0001)

func test_invalidate_triggers_recalc() -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 1.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	var calc := CityYieldCalculator.new()
	calc.calculate(c)
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 3.0}
	calc.invalidate()
	var y := calc.calculate(c)
	assert_float(y[&"food"]).is_equal_approx(3.0, 0.0001)

func test_agrarian_specialization_multiplier() -> void:

	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 1.0}
	var u = c.add_migrant(PopUnit.State.WORKER, 0)
	u.tile = HexUtils.get_all_neighbors(c.center)[0]
	var calc := CityYieldCalculator.new()
	var base := float(calc.calculate(c)[&"food"])
	c.level = 2
	c.specialization = &"agrarian"
	calc.invalidate()
	var y := float(calc.calculate(c)[&"food"])
	assert_float(y).is_equal_approx(base * SpecializationSystem.FOOD_YIELD_MULT, 0.0001)
