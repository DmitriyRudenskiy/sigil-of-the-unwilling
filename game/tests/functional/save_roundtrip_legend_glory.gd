extends BaseTest
## save-load-coverage-expansion 3.4: LegendTracker (save_data.legend) и
## GloryTracker (WorldStateDelta.glory_state) переживают save/load.

const _WorldStateDelta = preload("res://scripts/world/world_state_delta.gd")
const _GloryTracker = preload("res://scripts/world/glory_tracker.gd")
const _LegendTracker = preload("res://scripts/world/legend_tracker.gd")
const _Lifecycle = preload("res://scripts/world/hero_lifecycle_system.gd")


func test_glory_roundtrip_through_delta() -> void:
	var glory := _GloryTracker.new()
	glory.add_glory(15.0, 1, &"battle_won")
	glory.add_glory(10.0, 5, &"village_captured")
	var total_before := glory.total
	var window_total_before := glory.glory_last_window(5)

	var delta := _WorldStateDelta.new()
	delta.glory_state = glory.serialize()
	var dict := delta.serialize()

	# load: новый трекер из world-state
	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)
	var glory2 := _GloryTracker.new()
	glory2.deserialize(delta2.glory_state)

	assert_float(glory2.total).is_equal(total_before)
	assert_float(glory2.glory_last_window(5)).is_equal(window_total_before)
	assert_that(glory2._events.size()).is_equal(2)


func test_glory_legacy_save_defaults_empty() -> void:
	var delta := _WorldStateDelta.new()
	var dict := delta.serialize()
	dict.erase("glory_state")  # эмуляция legacy-формата

	var delta2 := _WorldStateDelta.new()
	delta2.deserialize(dict)
	assert_bool(delta2.glory_state.is_empty()).is_true()

	var glory := _GloryTracker.new()
	glory.deserialize(delta2.glory_state)
	assert_float(glory.total).is_equal(0.0)


func test_legend_roundtrip_through_lifecycle() -> void:
	var host := Node2D.new()
	add_child(host)
	auto_free(host)
	var sys := _Lifecycle.new()
	sys.setup(host, null, null, null, null, null, null, null, null, null, null, null)

	# смерть + возрождение + смена поколения
	sys._legend.record_death(&"battle")
	sys._legend.record_resurrection()
	sys._legend.advance_generation("Heir")
	var gen_before := sys._legend.generation_count
	var deaths_before := sys._legend.deaths_by_cause.duplicate()

	var state := sys.get_legend_state()
	assert_bool(state.is_empty() == false).is_true()

	# load: новый lifecycle восстанавливает состояние
	var sys2 := _Lifecycle.new()
	sys2.setup(host, null, null, null, null, null, null, null, null, null, null, null)
	sys2.restore_legend_state(state)

	assert_that(sys2._legend.generation_count).is_equal(gen_before)
	assert_dict(sys2._legend.deaths_by_cause).is_equal(deaths_before)
	assert_that(sys2._legend.resurrection_count).is_equal(1)


func test_legend_restore_ignores_empty() -> void:
	var host := Node2D.new()
	add_child(host)
	auto_free(host)
	var sys := _Lifecycle.new()
	sys.setup(host, null, null, null, null, null, null, null, null, null, null, null)
	sys._legend.record_death(&"plague")

	# Пустой legend (legacy-сейв без поля) не должен стирать состояние.
	sys.restore_legend_state({})
	assert_that(sys._legend.deaths_by_cause.get(&"plague", 0)).is_equal(1)


func test_legend_state_in_save_data() -> void:
	# save_data.legend — то самое поле v4, которое раньше было мёртвым.
	var sd := SaveData.new()
	sd.run_seed = 7
	sd.hero = {"cell": {"x": 1, "y": 1}}
	sd.legend = {"path_id": "warrior", "generation_count": 3}
	var dict := sd.to_dict()
	var sd2 := SaveData.new()
	sd2.from_dict(dict)
	assert_that(int(sd2.legend.get("generation_count", 0))).is_equal(3)
