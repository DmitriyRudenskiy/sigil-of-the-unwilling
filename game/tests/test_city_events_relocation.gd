extends "res://tests/gut_base.gd"
## Спринт 11: события, перенос города, специализации.

const _City := preload("res://scripts/world/City.gd")
const _UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")
const _PopUnit := preload("res://scripts/world/PopUnit.gd")
const _BuildingDefs := preload("res://scripts/data/BuildingDefs.gd")
const _Market := preload("res://scripts/city/MarketSystem.gd")
const _Events := preload("res://scripts/city/CityEvents.gd")
const _Spec := preload("res://scripts/city/SpecializationSystem.gd")
const _CityProc := preload("res://scripts/city/CityTurnProcessor.gd")


func _city(uid := 1) -> Variant:
	var c := _City.new()
	c.uid = uid
	c.center = Vector2i(0, 0)
	c.stronghold_level = 2
	return c


# --- Специализации ---

func test_specialization_level_gate() -> void:
	var c: Variant = _city()
	assert_eq(c.level, 1)
	assert_false(_Spec.set_specialization(c, &"agrarian"), "level 1 — нельзя")
	assert_eq(c.specialization, &"")
	c.level = 2
	assert_true(_Spec.set_specialization(c, &"agrarian"), "level 2 — можно")
	assert_eq(c.specialization, &"agrarian")
	assert_false(_Spec.set_specialization(c, &"nope"), "неизвестный id")


func test_agrarian_food_yield() -> void:
	var c: Variant = _city()
	c._add_pop(_PopUnit.State.WORKER, 0, Vector2i(1, 0))
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary: return {&"food": 10.0}
	var y: Dictionary = c.get_yield()
	assert_true(absf(float(y[&"food"]) - 10.0) < 1e-9, "base 10, got %s" % y[&"food"])
	c.level = 2
	_Spec.set_specialization(c, &"agrarian")
	y = c.get_yield()
	assert_true(absf(float(y[&"food"]) - 15.0) < 1e-9, "agrarian 15, got %s" % y[&"food"])


func test_merchant_rate() -> void:
	var c: Variant = _city()
	c.prosperity = 0.0
	assert_true(absf(_Market.rate_for(c, &"grain") - 1.5) < 1e-9, "base 1.5")
	c.level = 2
	_Spec.set_specialization(c, &"merchant")
	assert_true(absf(_Market.rate_for(c, &"grain") - 1.875) < 1e-9,
		"merchant 1.875, got %s" % _Market.rate_for(c, &"grain"))


func test_militarist_defense() -> void:
	var c: Variant = _city()
	assert_eq(c.defense_strength(), 0)
	c.level = 2
	_Spec.set_specialization(c, &"militarist")
	assert_eq(c.defense_strength(), 5)


func test_scholar_science_per_turn() -> void:
	var c: Variant = _city(42)
	c.level = 2
	_Spec.set_specialization(c, &"scholar")
	var proc := _CityProc.new()
	proc._process_city(c, 7)
	assert_true(absf(c.resource_ctx.amount(&"science") - 2.0) < 1e-9,
		"science +2, got %s" % c.resource_ctx.amount(&"science"))


# --- Перенос города ---

func test_relocate_ok() -> void:
	var c: Variant = _city()
	var b := _UniqueBuilding.new()
	b.def = _BuildingDefs.walls()
	b.cell = Vector2i(1, 0)
	c.buildings.append(b)
	c._add_pop(_PopUnit.State.WORKER, 0, Vector2i(2, 0))
	c.roads[Vector2i(3, 0)] = true
	var centers: Array = []
	c.relocation_completed.connect(func(nc: Vector2i): centers.append(nc))
	var r: Dictionary = c.relocate(Vector2i(2, 1))
	assert_true(bool(r.ok), "relocate ok: %s" % r.get("reason", ""))
	assert_eq(c.center, Vector2i(2, 1))
	assert_eq(b.cell, Vector2i(3, 1), "здание сдвинуто")
	assert_eq(c.pop[0].tile, Vector2i(4, 1), "тайл рабочего сдвинут")
	assert_true(c.roads.has(Vector2i(5, 1)), "дорога сдвинута")
	assert_eq(centers.size(), 1, "сигнал")
	assert_eq(centers[0], Vector2i(2, 1))
	# Сериализация нового центра.
	var d: Dictionary = c.serialize()
	assert_eq(int(d.center.x), 2)
	assert_eq(int(d.center.y), 1)


func test_relocate_failures() -> void:
	var c: Variant = _city()
	var b := _UniqueBuilding.new()
	b.def = _BuildingDefs.walls()
	b.cell = Vector2i(1, 0)
	c.buildings.append(b)
	var r: Dictionary = c.relocate(Vector2i(0, 0))
	assert_false(bool(r.ok), "тот же центр")
	r = c.relocate(Vector2i(5, 0))
	assert_false(bool(r.ok), "дальше 3 клеток")
	r = c.relocate(Vector2i(1, 0))
	assert_false(bool(r.ok), "на застройке")
	assert_eq(c.center, Vector2i(0, 0), "центр не тронут")


# --- События ---

func test_events_deterministic() -> void:
	# (51, 9): roll 0.0009 < 0.08 -> harvest_festival; (42, 7): нет.
	var c: Variant = _city(51)
	assert_true(_Events.occurs(c, 9), "51/9 occurs")
	assert_false(_Events.occurs(c, 7), "51/7 no")
	var c2: Variant = _city(42)
	assert_false(_Events.occurs(c2, 7), "42/7 no")


func test_event_harvest_festival() -> void:
	var c: Variant = _city(51)
	c.food_stockpile = 4.0
	var r: Dictionary = _Events.resolve(c, 9)
	assert_true(bool(r.occurred), "occurred")
	assert_eq(r.event_id, &"harvest_festival")
	assert_true(absf(c.food_stockpile - 9.0) < 1e-9, "food 9")
	assert_eq(c.reputation, 3)


func test_event_tax_inspector() -> void:
	var c: Variant = _city(2)
	c.storage[&"industry"] = 20.0
	var r: Dictionary = _Events.resolve(c, 1)
	assert_true(bool(r.occurred), "occurred")
	assert_eq(r.event_id, &"tax_inspector")
	assert_true(absf(float(c.storage[&"industry"]) - 15.0) < 1e-9, "gold 15")


func test_event_plague() -> void:
	var c: Variant = _city(5)
	for i in 3:
		c._add_pop(_PopUnit.State.WORKER, 0)
	var r: Dictionary = _Events.resolve(c, 8)
	assert_true(bool(r.occurred), "occurred")
	assert_eq(r.event_id, &"plague_outbreak")
	assert_eq(c.pop.size(), 2, "потеряли одного")
	assert_eq(c.reputation, -5)


func test_event_no_no_mutation() -> void:
	var c: Variant = _city(42)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	var r: Dictionary = _Events.resolve(c, 7)
	assert_false(bool(r.occurred), "no event")
	assert_true(absf(c.food_stockpile - 10.0) < 1e-9, "food intact")
	assert_eq(c.reputation, 0)


func test_processor_event_signal() -> void:
	var c: Variant = _city(51)
	var events: Array = []
	var proc := _CityProc.new()
	proc.city_event_occurred.connect(
		func(uid: int, id: StringName): events.append([uid, id]))
	var report: Dictionary = proc._process_city(c, 9)
	assert_eq(int(report.get("event_occurred", 0)), 1)
	assert_eq(report.get("event", ""), "harvest_festival")
	assert_eq(events.size(), 1, "один сигнал")
	assert_eq(events[0][0], 51)
	assert_eq(events[0][1], &"harvest_festival")
	# Ход без события — сигнала нет.
	var report2: Dictionary = proc._process_city(c, 7)
	assert_eq(int(report2.get("event_occurred", 0)), 0)
	assert_eq(events.size(), 1, "второго сигнала нет")


func test_relocate_rejects_out_of_bounds_and_other_city() -> void:
	# Аудит #18: вне карты / на клетке другого города — отказ в переносе.
	var c: Variant = _city()
	var map_size := Vector2i(30, 30)
	var r: Dictionary = c.relocate(Vector2i(-1, 0), map_size)
	assert_false(r.ok, "вне карты — отказ")
	assert_ne(c.center, Vector2i(-1, 0), "центр не сдвинулся")
	r = c.relocate(Vector2i(1, 0), map_size, {Vector2i(1, 0): true})
	assert_false(r.ok, "на клетке чужого города — отказ")
	r = c.relocate(Vector2i(2, 0), map_size)
	assert_true(r.ok, "валидная цель — перенос состоялся")
