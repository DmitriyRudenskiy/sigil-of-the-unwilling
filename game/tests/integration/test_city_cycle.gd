# TASK_14 §8 (8): цикл города — рост → строительство → производство за 10 ходов.
# Интеграция: город с пищевым урожаем строит район и растёт без голода.

extends BaseTest



func _make_city() -> City:
	var c := City.new()
	c.center = Vector2i(10, 10)
	c.display_name = "Cyclonia"
	c.food_stockpile = 100.0
	c.storage[&"industry"] = 10000.0
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 10.0, &"industry": 1.0, &"dust": 0.0, &"science": 0.0, &"influence": 0.0}
	for i in 3:
		c.add_migrant(PopUnit.State.WORKER, 1)
	return c

func test_city_ten_turn_cycle_growth_build_production() -> void:
	var city := _make_city()

	# Строительство: район примыкает к центру
	var built := false
	for nb in HexUtils.get_all_neighbors(city.center, true):
		if city.build_borough(nb):
			built = true
			break
	assert_bool(built).is_true()

	var pop_start := city.pop_capped()
	var industry_start := float(city.storage[&"industry"])
	var starving_seen := false
	var total_births := 0

	for t in 10:
		var report: Dictionary = city.process_turn(t)
		starving_seen = starving_seen or bool(report.get("starving", false))
		total_births += int(report.get("births", 0))

	assert_bool(starving_seen).is_false()
	assert_int(city.pop_capped()).is_greater(pop_start)
	assert_int(total_births).is_greater(0)
	# Производство: индустрия накапливается (урожай 1/ход > 0)
	assert_float(float(city.storage[&"industry"])).is_greater(industry_start)
	# Район сохранён и не голод
	assert_int(city.boroughs.size()).is_equal(1)
	assert_bool(city.starving).is_false()
