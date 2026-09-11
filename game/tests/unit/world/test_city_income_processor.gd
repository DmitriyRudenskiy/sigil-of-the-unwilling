extends BaseTest



func _make_city(owner: StringName, gold: float) -> RefCounted:
	var c := City.new()
	c.display_name = "Тест"
	c.center = Vector2i(5, 5)
	c.owner = owner
	if gold > 0.0:
		c.ensure_resource_ctx().add(&"gold", gold)
	return c

func test_phase_contract() -> void:
	var proc := CityIncomeProcessor.new()
	assert_that(proc.get_phase_id()).is_equal(&"city_income")
	assert_that(proc.get_priority()).is_equal(15)

func test_player_city_pays_royalty() -> void:
	var proc := CityIncomeProcessor.new()
	var city := _make_city(&"player", 10.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	var total: Dictionary = report.get("total", {})
	assert_float(float(total.get(&"gold", 0.0))).is_equal_approx(2.0, 0.0001)
	assert_float(city.resource_ctx.amount(&"gold")).is_equal_approx(8.0, 0.0001)
	var per_city: Array = report.get("per_city", [])
	assert_that(per_city.size()).is_equal(1)
	assert_that(int(per_city[0].get("royalty", 0))).is_equal(2)

func test_arena_city_skipped() -> void:
	var proc := CityIncomeProcessor.new()
	var city := _make_city(&"none", 10.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	assert_bool((report.get("total") as Dictionary).is_empty()).is_true()
	assert_that((report.get("per_city") as Array).size()).is_equal(0)
	assert_float(city.resource_ctx.amount(&"gold")).is_equal_approx(10.0, 0.0001)

func test_zero_royalty_skipped() -> void:
	var proc := CityIncomeProcessor.new()
	var city := _make_city(&"player", 3.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	assert_bool((report.get("total") as Dictionary).is_empty()).is_true()
	assert_float(city.resource_ctx.amount(&"gold")).is_equal_approx(3.0, 0.0001)

func test_city_without_resource_ctx_skipped() -> void:
	var proc := CityIncomeProcessor.new()
	var city := _make_city(&"player", 0.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	assert_bool((report.get("total") as Dictionary).is_empty()).is_true()

func test_null_city_in_list_skipped() -> void:
	var proc := CityIncomeProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(null)
	ctx.cities.append(_make_city(&"player", 10.0))
	var report: Dictionary = proc.process(ctx)
	assert_float(float((report.get("total") as Dictionary).get(&"gold", 0.0))).is_equal_approx(2.0, 0.0001)

func test_null_ctx() -> void:
	var proc := CityIncomeProcessor.new()
	var report: Dictionary = proc.process(null)
	assert_bool((report.get("total") as Dictionary).is_empty()).is_true()
	assert_that((report.get("per_city") as Array).size()).is_equal(0)
