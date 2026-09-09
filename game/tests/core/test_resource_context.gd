extends GdUnitTestSuite

func _make_def(id: StringName, cap: float = -1.0) -> ResourceDef:
	var d := ResourceDef.new()
	d.id = id
	d.display_name = String(id)
	if cap >= 0.0:
		d.capacity = cap
	return d


func test_setup_applies_capacity() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 100.0), _make_def(&"stone")])
	assert_that(rc.get_capacity(&"wood")).is_equal(100.0)
	assert_that(rc.get_capacity(&"stone")).is_equal(INF)


func test_add_and_get() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood")])
	var added: float = rc.add(&"wood", 5.0)
	assert_that(added).is_equal(5.0)
	assert_that(rc.amount(&"wood")).is_equal(5.0)
	assert_bool(rc.has(&"wood")).is_true()
	assert_bool(rc.has(&"stone")).is_false()


func test_add_clamped_to_capacity() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 10.0)])
	var added1: float = rc.add(&"wood", 7.0)
	var added2: float = rc.add(&"wood", 7.0)
	assert_that(added1).is_equal(7.0)
	assert_that(added2).is_equal(3.0)
	assert_that(rc.amount(&"wood")).is_equal(10.0)


func test_capacity_reached_signal() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 5.0)])
	var reached: Array = []
	rc.capacity_reached.connect(func(id: StringName): reached.append(id))
	rc.add(&"wood", 6.0)
	assert_that(reached.size()).is_equal(1)
	assert_that(reached[0]).is_equal(&"wood")


func test_resource_changed_signal() -> void:
	var rc := ResourceContext.new()
	var events: Array = []
	rc.resource_changed.connect(func(id: StringName, old_v: float, new_v: float):
		events.append([id, old_v, new_v]))
	rc.add(&"wood", 3.0)
	rc.remove(&"wood", 1.0)
	assert_that(events.size()).is_equal(2)
	assert_that(events[0][1]).is_equal(0.0)
	assert_that(events[0][2]).is_equal(3.0)
	assert_that(events[1][2]).is_equal(2.0)


func test_remove_clamped_to_zero() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 4.0)
	var removed: float = rc.remove(&"wood", 99.0)
	assert_that(removed).is_equal(4.0)
	assert_that(rc.amount(&"wood")).is_equal(0.0)


func test_unknown_id_auto_inf_capacity() -> void:
	var rc := ResourceContext.new()
	var added: float = rc.add(&"mystery", 123.0)
	assert_that(added).is_equal(123.0)
	assert_that(rc.get_capacity(&"mystery")).is_equal(INF)


func test_can_afford_and_spend() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 10.0)
	rc.add(&"stone", 4.0)
	var cost := {"wood": 5.0, "stone": 4.0}
	assert_bool(rc.can_afford(cost)).is_true()
	assert_bool(rc.spend(cost)).is_true()
	assert_that(rc.amount(&"wood")).is_equal(5.0)
	assert_that(rc.amount(&"stone")).is_equal(0.0)


func test_spend_fails_without_mutation() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 2.0)
	var cost := {"wood": 5.0, "stone": 1.0}
	assert_bool(rc.can_afford(cost)).is_false()
	assert_bool(rc.spend(cost)).is_false()
	assert_that(rc.amount(&"wood")).is_equal(2.0)
	assert_that(rc.amount(&"stone")).is_equal(0.0)


func test_empty() -> void:
	var rc := ResourceContext.new()
	assert_bool(rc.is_empty()).is_true()
	rc.add(&"wood", 1.0)
	rc.remove(&"wood", 1.0)
	assert_bool(rc.is_empty()).is_true()


func test_serialize_deserialize_roundtrip() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 100.0)])
	rc.add(&"wood", 42.5)
	rc.add(&"stone", 7.0)

	var data: Dictionary = rc.serialize()
	assert_that(float(data.get("wood", -1.0))).is_equal(42.5)

	var rc2 := ResourceContext.new()
	rc2.deserialize(data)
	assert_that(rc2.amount(&"wood")).is_equal(42.5)
	assert_that(rc2.amount(&"stone")).is_equal(7.0)


func test_set_capacity_trims() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 50.0)
	rc.set_capacity(&"wood", 30.0)
	assert_that(rc.amount(&"wood")).is_equal(30.0)
