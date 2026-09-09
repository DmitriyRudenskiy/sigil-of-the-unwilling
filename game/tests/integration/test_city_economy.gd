extends GdUnitTestSuite

const City = preload("res://scripts/world/City.gd")
const PopUnit = preload("res://scripts/world/PopUnit.gd")

var _city: City

func before_test() -> void:
	_city = City.new()
	_city.center = Vector2i(10, 10)
	_city.display_name = "Testville"
	_city.food_stockpile = 50.0
	# Город без тайлов: доход 0, только потребление
	_city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 0.0, &"industry": 0.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}


func test_city_starvation_logic() -> void:
	# 10 рабочих съедают 10 еды за ход (FOOD_PER_WORKER = 1.0)
	for i in 10:
		_city.add_migrant(PopUnit.State.WORKER, 1)

	assert_bool(_city.starving).is_false()

	_city.food_stockpile = 10.0
	var report := _city.process_turn(1)

	# Еда должна закончиться, город должен голодать
	assert_bool(_city.starving).is_true()
	assert_float(_city.food_stockpile).is_equal(0.0)
	assert_bool(report.get("starving", false)).is_true()


func test_city_population_growth() -> void:
	var initial_pop := _city.pop_capped()
	_city.food_stockpile = 100.0
	_city.process_turn(1)

	# При избытке еды и месте в жилье, население должно вырасти
	assert_int(_city.pop_capped()).is_greater(initial_pop)
