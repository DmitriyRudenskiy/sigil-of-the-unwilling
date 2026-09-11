extends BaseTest



var _city: City

func before_test() -> void:
	_city = City.new()
	_city.center = Vector2i(10, 10)
	_city.display_name = "Testville"
	_city.food_stockpile = 50.0

	_city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 0.0, &"industry": 0.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}

func test_city_starvation_logic() -> void:

	for i in 10:
		_city.add_migrant(PopUnit.State.WORKER, 1)

	assert_bool(_city.starving).is_false()

	_city.food_stockpile = 10.0
	var report := _city.process_turn(1)

	assert_bool(_city.starving).is_true()
	assert_float(_city.food_stockpile).is_equal(0.0)
	assert_bool(report.get("starving", false)).is_true()

func test_city_population_growth() -> void:
	var initial_pop := _city.pop_capped()
	_city.food_stockpile = 100.0
	_city.process_turn(1)

	assert_int(_city.pop_capped()).is_greater(initial_pop)
