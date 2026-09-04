extends "res://tests/gut_base.gd"
## M1: Экономика — ProductionChain.
##
## Формула выхода, списание входов, атомарность при нехватке,
## логистика, сериализация.

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
	assert_eq(float(out.get("planks", -1.0)), 3.0, "full output")


func test_calculate_output_worker_ratio() -> void:
	var chain := _make_chain()
	# 1 из 2 рабочих = 50%.
	var out: Dictionary = chain.calculate_output(1, 1.0)
	assert_eq(float(out.get("planks", -1.0)), 1.5, "half output")


func test_calculate_output_capped_at_full() -> void:
	var chain := _make_chain()
	# Больше требуемых рабочих — не усиливает.
	var out: Dictionary = chain.calculate_output(10, 1.0)
	assert_eq(float(out.get("planks", -1.0)), 3.0, "capped")


func test_calculate_output_zero_workers() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(0, 1.0)
	assert_true(out.is_empty(), "no workers -> no output")


func test_calculate_output_logistics() -> void:
	var chain := _make_chain()
	var out: Dictionary = chain.calculate_output(2, 0.5)
	assert_eq(float(out.get("planks", -1.0)), 1.5, "logistics halves")


func test_building_eff_multiplier() -> void:
	var chain := _make_chain()
	chain.building_eff = 2.0
	var out: Dictionary = chain.calculate_output(2, 1.0)
	assert_eq(float(out.get("planks", -1.0)), 6.0, "eff doubles")


func test_can_produce_requires_workers_and_inputs() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 2.0)
	var chain := _make_chain()
	assert_false(chain.can_produce(rc, 0), "no workers -> false")
	rc.add(&"wood", 0.0)
	assert_true(chain.can_produce(rc, 2), "with workers+input -> true")
	rc.remove(&"wood", 1.0)
	assert_false(chain.can_produce(rc, 2), "insufficient input -> false")


func test_execute_deducts_inputs() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 10.0)
	var chain := _make_chain()
	var out: Dictionary = chain.execute(rc, 2, 1.0)
	assert_eq(float(out.get("planks", -1.0)), 3.0, "produced")
	assert_eq(rc.amount(&"wood"), 8.0, "inputs deducted")


func test_execute_atomic_on_shortage() -> void:
	var rc := ResourceContext.new()
	rc.add(&"wood", 1.0)  # нужно 2
	var chain := _make_chain()
	var out: Dictionary = chain.execute(rc, 2, 1.0)
	assert_true(out.is_empty(), "no output")
	assert_eq(rc.amount(&"wood"), 1.0, "inputs NOT deducted")


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
	assert_eq(float(out.get("ale", -1.0)), 2.0, "ale")
	assert_eq(float(out.get("hops_waste", -1.0)), 0.5, "waste")
	assert_eq(rc.amount(&"wood"), 9.0, "wood deducted")
	assert_eq(rc.amount(&"water"), 8.0, "water deducted")


func test_serialize_roundtrip() -> void:
	var chain := _make_chain()
	var data: Dictionary = chain.to_dict()
	var restored := ProductionChain.from_dict(data)
	assert_eq(restored.id, &"lumber", "id")
	assert_eq(restored.required_workers, 2, "workers")
	assert_eq(float(restored.inputs.get(&"wood", -1.0)), 2.0, "input")
	assert_eq(float(restored.outputs.get(&"planks", -1.0)), 3.0, "output")
	# Поведение восстановленной цепи идентично.
	var rc := ResourceContext.new()
	rc.add(&"wood", 5.0)
	assert_eq(float(restored.execute(rc, 2, 1.0).get("planks", -1.0)), 3.0, "restored works")
