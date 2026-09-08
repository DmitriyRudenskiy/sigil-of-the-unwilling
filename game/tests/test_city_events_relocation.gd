extends GdUnitTestSuite

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



func test_specialization_level_gate() -> void:
	var c: Variant = _city()
	assert_that(c.level).is_equal(1)
	assert_bool(_Spec.set_specialization(c, &"agrarian")).is_false()
	assert_that(c.specialization).is_equal(&"")
	c.level = 2
	assert_bool(_Spec.set_specialization(c, &"agrarian")).is_true()
	assert_that(c.specialization).is_equal(&"agrarian")
	assert_bool(_Spec.set_specialization(c, &"nope")).is_false()


func test_agrarian_food_yield() -> void:
	var c: Variant = _city()
	c._add_pop(_PopUnit.State.WORKER, 0, Vector2i(1, 0))
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary: return {&"food": 10.0}
	var y: Dictionary = c.get_yield()
	assert_bool(absf(float(y[&"food"]) - 10.0) < 1e-9).is_true()
	c.level = 2
	_Spec.set_specialization(c, &"agrarian")
	y = c.get_yield()
	assert_bool(absf(float(y[&"food"]) - 15.0) < 1e-9).is_true()


func test_merchant_rate() -> void:
	var c: Variant = _city()
	c.prosperity = 0.0
	assert_bool(absf(_Market.rate_for(c, &"grain") - 1.5) < 1e-9).is_true()
	c.level = 2
	_Spec.set_specialization(c, &"merchant")
	assert_bool(absf(_Market.rate_for(c, &"grain") - 1.875) < 1e-9).is_true()


func test_militarist_defense() -> void:
	var c: Variant = _city()
	assert_that(c.defense_strength()).is_equal(0)
	c.level = 2
	_Spec.set_specialization(c, &"militarist")
	assert_that(c.defense_strength()).is_equal(5)


func test_scholar_science_per_turn() -> void:
	var c: Variant = _city(42)
	c.level = 2
	_Spec.set_specialization(c, &"scholar")
	var proc := _CityProc.new()
	proc._process_city(c, 7)
	assert_bool(absf(c.resource_ctx.amount(&"science") - 2.0) < 1e-9).is_true()



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
	var r: CityCheck = c.relocate(Vector2i(2, 1))
	assert_bool(bool(r.ok)).is_true()
	assert_that(c.center).is_equal(Vector2i(2, 1))
	assert_that(b.cell).is_equal(Vector2i(3, 1))
	assert_that(c.pop[0].tile).is_equal(Vector2i(4, 1))
	assert_bool(c.roads.has(Vector2i(5, 1))).is_true()
	assert_that(centers.size()).is_equal(1)
	assert_that(centers[0]).is_equal(Vector2i(2, 1))
	var d: Dictionary = c.serialize()
	assert_that(int(d.center.x)).is_equal(2)
	assert_that(int(d.center.y)).is_equal(1)


func test_relocate_failures() -> void:
	var c: Variant = _city()
	var b := _UniqueBuilding.new()
	b.def = _BuildingDefs.walls()
	b.cell = Vector2i(1, 0)
	c.buildings.append(b)
	var r: CityCheck = c.relocate(Vector2i(0, 0))
	assert_bool(bool(r.ok)).is_false()
	r = c.relocate(Vector2i(5, 0))
	assert_bool(bool(r.ok)).is_false()
	r = c.relocate(Vector2i(1, 0))
	assert_bool(bool(r.ok)).is_false()
	assert_that(c.center).is_equal(Vector2i(0, 0))



func test_events_deterministic() -> void:
	var c: Variant = _city(51)
	assert_bool(_Events.occurs(c, 9)).is_true()
	assert_bool(_Events.occurs(c, 7)).is_false()
	var c2: Variant = _city(42)
	assert_bool(_Events.occurs(c2, 7)).is_false()


func test_event_harvest_festival() -> void:
	var c: Variant = _city(51)
	c.food_stockpile = 4.0
	var r: Dictionary = _Events.resolve(c, 9)
	assert_bool(bool(r.occurred)).is_true()
	assert_that(r.event_id).is_equal(&"harvest_festival")
	assert_bool(absf(c.food_stockpile - 9.0) < 1e-9).is_true()
	assert_that(c.reputation).is_equal(3)


func test_event_tax_inspector() -> void:
	var c: Variant = _city(2)
	c.storage[&"industry"] = 20.0
	var r: Dictionary = _Events.resolve(c, 1)
	assert_bool(bool(r.occurred)).is_true()
	assert_that(r.event_id).is_equal(&"tax_inspector")
	assert_bool(absf(float(c.storage[&"industry"]) - 15.0) < 1e-9).is_true()


func test_event_plague() -> void:
	var c: Variant = _city(5)
	for i in 3:
		c._add_pop(_PopUnit.State.WORKER, 0)
	var r: Dictionary = _Events.resolve(c, 8)
	assert_bool(bool(r.occurred)).is_true()
	assert_that(r.event_id).is_equal(&"plague_outbreak")
	assert_that(c.pop.size()).is_equal(2)
	assert_that(c.reputation).is_equal(-5)


func test_event_no_no_mutation() -> void:
	var c: Variant = _city(42)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	var r: Dictionary = _Events.resolve(c, 7)
	assert_bool(bool(r.occurred)).is_false()
	assert_bool(absf(c.food_stockpile - 10.0) < 1e-9).is_true()
	assert_that(c.reputation).is_equal(0)


func test_processor_event_signal() -> void:
	var c: Variant = _city(51)
	var events: Array = []
	var proc := _CityProc.new()
	proc.city_event_occurred.connect(
		func(uid: int, id: StringName): events.append([uid, id]))
	var report: Dictionary = proc._process_city(c, 9)
	assert_that(int(report.get("event_occurred", 0))).is_equal(1)
	assert_that(report.get("event", "")).is_equal("harvest_festival")
	assert_that(events.size()).is_equal(1)
	assert_that(events[0][0]).is_equal(51)
	assert_that(events[0][1]).is_equal(&"harvest_festival")
	var report2: Dictionary = proc._process_city(c, 7)
	assert_that(int(report2.get("event_occurred", 0))).is_equal(0)
	assert_that(events.size()).is_equal(1)


func test_relocate_rejects_out_of_bounds_and_other_city() -> void:
	var c: Variant = _city()
	var map_size := Vector2i(30, 30)
	var r: CityCheck = c.relocate(Vector2i(-1, 0), map_size)
	assert_bool(r.ok).is_false()
	assert_that(c.center).is_not_equal(Vector2i(-1, 0))
	r = c.relocate(Vector2i(1, 0), map_size, {Vector2i(1, 0): true})
	assert_bool(r.ok).is_false()
	r = c.relocate(Vector2i(2, 0), map_size)
	assert_bool(r.ok).is_true()
