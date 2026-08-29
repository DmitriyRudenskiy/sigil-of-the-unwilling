extends "res://tests/test_base.gd"
## M1: Экономика — ResourceContext.
##
## Лимиты, добавление/снятие, spend/can_afford, сериализация,
## авто-создание неизвестных id, сигналы.

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
	assert_eq(rc.get_capacity(&"wood"), 100.0, "wood cap 100")
	assert_eq(rc.get_capacity(&"stone"), INF, "stone cap INF (default)")


func test_add_and_get() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood")])
	var added: float = rc.add(&"wood", 5.0)
	assert_eq(added, 5.0, "added 5")
	assert_eq(rc.amount(&"wood"), 5.0, "get 5")
	assert_true(rc.has(&"wood"), "has wood")
	assert_false(rc.has(&"stone"), "no stone")


func test_add_clamped_to_capacity() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 10.0)])
	var added1: float = rc.add(&"wood", 7.0)
	var added2: float = rc.add(&"wood", 7.0)
	assert_eq(added1, 7.0, "first add full")
	assert_eq(added2, 3.0, "second add clamped to 3")
	assert_eq(rc.amount(&"wood"), 10.0, "at capacity")


func test_capacity_reached_signal() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 5.0)])
	var reached: Array = []
	rc.capacity_reached.connect(func(id: StringName): reached.append(id))
	rc.add(&"wood", 6.0)
	assert_eq(reached.size(), 1, "signal fired")
	assert_eq(reached[0], &"wood", "signal payload")


func test_resource_changed_signal() -> void:
	var rc := ResourceContext.new()
	var events: Array = []
	rc.resource_changed.connect(func(id: StringName, old_v: float, new_v: float):
		events.append([id, old_v, new_v]))
	rc.add(&"wood", 3.0)
	rc.remove(&"wood", 1.0)
	assert_eq(events.size(), 2, "two changes")
	assert_eq(events[0][1], 0.0, "old 0")
	assert_eq(events[0][2], 3.0, "new 3")
	assert_eq(events[1][2], 2.0, "new 2 after remove")


func test_remove_clamped_to_zero() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 4.0)
	var removed: float = rc.remove(&"wood", 99.0)
	assert_eq(removed, 4.0, "removed only what exists")
	assert_eq(rc.amount(&"wood"), 0.0, "emptied")


func test_unknown_id_auto_inf_capacity() -> void:
	var rc := ResourceContext.new()
	var added: float = rc.add(&"mystery", 123.0)
	assert_eq(added, 123.0, "unknown id unlimited")
	assert_eq(rc.get_capacity(&"mystery"), INF, "auto INF cap")


func test_can_afford_and_spend() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 10.0)
	rc.add(&"stone", 4.0)
	var cost := {"wood": 5.0, "stone": 4.0}
	assert_true(rc.can_afford(cost), "afford")
	assert_true(rc.spend(cost), "spent")
	assert_eq(rc.amount(&"wood"), 5.0, "wood left")
	assert_eq(rc.amount(&"stone"), 0.0, "stone left 0")


func test_spend_fails_without_mutation() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 2.0)
	var cost := {"wood": 5.0, "stone": 1.0}
	assert_false(rc.can_afford(cost), "not afford")
	assert_false(rc.spend(cost), "spend rejected")
	assert_eq(rc.amount(&"wood"), 2.0, "wood untouched (atomic)")
	assert_eq(rc.amount(&"stone"), 0.0, "stone untouched")


func test_empty() -> void:
	var rc := ResourceContext.new()
	assert_true(rc.is_empty(), "fresh is empty")
	rc.add(&"wood", 1.0)
	rc.remove(&"wood", 1.0)
	assert_true(rc.is_empty(), "back to empty after drain")


func test_serialize_deserialize_roundtrip() -> void:
	var rc := ResourceContext.new()
	rc.setup([_make_def(&"wood", 100.0)])
	rc.add(&"wood", 42.5)
	rc.add(&"stone", 7.0)

	var data: Dictionary = rc.serialize()
	assert_eq(float(data.get("wood", -1.0)), 42.5, "serialized wood")

	var rc2 := ResourceContext.new()
	rc2.deserialize(data)
	assert_eq(rc2.amount(&"wood"), 42.5, "restored wood")
	assert_eq(rc2.amount(&"stone"), 7.0, "restored stone")


func test_set_capacity_trims() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 50.0)
	rc.set_capacity(&"wood", 30.0)
	assert_eq(rc.amount(&"wood"), 30.0, "trimmed to new cap")
