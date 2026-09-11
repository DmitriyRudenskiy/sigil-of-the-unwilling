extends BaseTest

func _make_chain() -> ProductionChain:
	var chain := ProductionChain.new()
	chain.id = &"lumber"
	chain.inputs = {"wood": 2.0}
	chain.outputs = {"planks": 3.0}
	chain.required_workers = 2
	chain.building_eff = 1.0
	return chain

func test_calculate_output_full_staff() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(2, 1.0)
	assert_that(float(out.get("planks", -1.0))).is_equal(3.0)

func test_calculate_output_worker_ratio() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(1, 1.0)
	assert_that(float(out.get("planks", -1.0))).is_equal(1.5)

func test_calculate_output_capped_at_full() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(10, 1.0)
	assert_that(float(out.get("planks", -1.0))).is_equal(3.0)

func test_calculate_output_zero_workers() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(0, 1.0)
	assert_bool(out.is_empty()).is_true()

func test_calculate_output_logistics() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(2, 0.5)
	assert_that(float(out.get("planks", -1.0))).is_equal(1.5)

func test_building_eff_multiplier() -> void:
	var chain := _make_chain()
	chain.building_eff = 2.0
	var out: Dictionary = chain.calculate_output(2, 1.0)
	assert_that(float(out.get("planks", -1.0))).is_equal(6.0)

func test_can_produce_requires_workers_and_inputs() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 2.0)
	var chain := _make_chain()
	assert_bool(chain.can_produce(rc, 0)).is_false()
	rc.add(&"wood", 0.0)
	assert_bool(chain.can_produce(rc, 2)).is_true()
	rc.remove(&"wood", 1.0)
	assert_bool(chain.can_produce(rc, 2)).is_false()

func test_execute_deducts_inputs() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 10.0)
	var chain := _make_chain()
	var out: Dictionary = chain.execute(rc, 2, 1.0)
	assert_that(float(out.get("planks", -1.0))).is_equal(3.0)
	assert_that(rc.amount(&"wood")).is_equal(8.0)

func test_execute_atomic_on_shortage() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 1.0)
	var chain := _make_chain()
	var out: Dictionary = chain.execute(rc, 2, 1.0)
	assert_bool(out.is_empty()).is_true()
	assert_that(rc.amount(&"wood")).is_equal(1.0)

func test_execute_multiple_outputs() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 10.0)
	rc.add(&"water", 10.0)
	var chain := ProductionChain.new()
	chain.id = &"brewery"
	chain.inputs = {"wood": 1.0, "water": 2.0}
	chain.outputs = {"ale": 2.0, "hops_waste": 0.5}
	chain.required_workers = 1
	var out: Dictionary = chain.execute(rc, 1, 1.0)
	assert_that(float(out.get("ale", -1.0))).is_equal(2.0)
	assert_that(float(out.get("hops_waste", -1.0))).is_equal(0.5)
	assert_that(rc.amount(&"wood")).is_equal(9.0)
	assert_that(rc.amount(&"water")).is_equal(8.0)

func test_serialize_roundtrip() -> void:
	var chain := _make_chain()
	var data: Dictionary = chain.to_dict()
	var restored := ProductionChain.from_dict(data)
	assert_that(restored.id).is_equal(&"lumber")
	assert_that(restored.required_workers).is_equal(2)
	assert_that(float(restored.inputs.get(&"wood", -1.0))).is_equal(2.0)
	assert_that(float(restored.outputs.get(&"planks", -1.0))).is_equal(3.0)
	var rc := ResourceContext.new()
	rc.add(&"wood", 5.0)
	assert_that(float(restored.execute(rc, 2, 1.0).get("planks", -1.0))).is_equal(3.0)
