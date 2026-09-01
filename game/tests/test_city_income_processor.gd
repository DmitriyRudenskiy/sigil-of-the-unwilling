extends "res://tests/test_base.gd"
## city-in-world: фаза дани городов (CityIncomeProcessor).
## Игровые города платят долю казны; песочница CityArena (owner == &"none")
## пропускается; герой не трогается (внешний эффект — интеграционный слой).

const _CityIncomeProcessor = preload("res://scripts/economy/CityIncomeProcessor.gd")
const _City = preload("res://scripts/world/City.gd")


func _make_city(owner: StringName, gold: float) -> RefCounted:
	var c := _City.new()
	c.display_name = "Тест"
	c.center = Vector2i(5, 5)
	c.owner = owner
	if gold > 0.0:
		c.ensure_resource_ctx().add(&"gold", gold)
	return c


func test_phase_contract() -> void:
	var proc := _CityIncomeProcessor.new()
	assert_eq(proc.get_phase_id(), &"city_income", "phase id")
	assert_eq(proc.get_priority(), 15, "приоритет 15 (после экономики, до демографии)")


func test_player_city_pays_royalty() -> void:
	# gold 10 × ROYALTY_FRACTION 0.25 = 2.5 → floor = 2.
	var proc := _CityIncomeProcessor.new()
	var city := _make_city(&"player", 10.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	var total: Dictionary = report.get("total", {})
	assert_approx(float(total.get(&"gold", 0.0)), 2.0, 0.0001, "дань 2 в total")
	assert_approx(city.resource_ctx.amount(&"gold"), 8.0, 0.0001, "казна −2")
	var per_city: Array = report.get("per_city", [])
	assert_eq(per_city.size(), 1, "один город в отчёте")
	assert_eq(int(per_city[0].get("royalty", 0)), 2, "royalty в записи")


func test_arena_city_skipped() -> void:
	# CityArena: owner == &"none" — фаза его не видит, казна не трогается.
	var proc := _CityIncomeProcessor.new()
	var city := _make_city(&"none", 10.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	assert_true((report.get("total") as Dictionary).is_empty(), "дани нет")
	assert_eq((report.get("per_city") as Array).size(), 0, "город не в отчёте")
	assert_approx(city.resource_ctx.amount(&"gold"), 10.0, 0.0001, "казна цела")


func test_zero_royalty_skipped() -> void:
	# gold 3 × 0.25 = 0.75 → floor = 0: дани нет, казна не трогается.
	var proc := _CityIncomeProcessor.new()
	var city := _make_city(&"player", 3.0)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	assert_true((report.get("total") as Dictionary).is_empty(), "дани нет")
	assert_approx(city.resource_ctx.amount(&"gold"), 3.0, 0.0001, "казна цела")


func test_city_without_resource_ctx_skipped() -> void:
	var proc := _CityIncomeProcessor.new()
	var city := _make_city(&"player", 0.0)  # ensure_resource_ctx не вызывался
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	assert_true((report.get("total") as Dictionary).is_empty(), "без ctx — пропуск")


func test_null_city_in_list_skipped() -> void:
	var proc := _CityIncomeProcessor.new()
	var ctx := TurnContext.new()
	ctx.cities.append(null)
	ctx.cities.append(_make_city(&"player", 10.0))
	var report: Dictionary = proc.process(ctx)
	assert_approx(float((report.get("total") as Dictionary).get(&"gold", 0.0)),
		2.0, 0.0001, "null пропущен, дань с города есть")


func test_null_ctx() -> void:
	var proc := _CityIncomeProcessor.new()
	var report: Dictionary = proc.process(null)
	assert_true((report.get("total") as Dictionary).is_empty(), "total пуст")
	assert_eq((report.get("per_city") as Array).size(), 0, "per_city пусто")
