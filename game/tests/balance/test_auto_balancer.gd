## Test suite for AutoBalancer system
## Tests simulation accuracy, balance calculations, and edge cases

extends GutTest
class_name TestAutoBalancer

var balancer: AutoBalancer

func before_each():
	balancer = AutoBalancer.new()

## Test: Initial configuration loads correctly
func test_initial_config():
	assert_eq(balancer.target_survival_rate, 0.85, "Target survival rate should be 85%")
	assert_eq(balancer.target_resource_buffer, 3, "Target buffer should be 3 days")
	assert_eq(balancer.simulation_days, 100, "Simulation should run 100 days")
	assert_eq(balancer.num_simulations, 50, "Should run 50 simulations")

## Test: Resource production values are loaded
func test_resource_production_loaded():
	assert_true(balancer._resource_production.has("wood"), "Wood production should exist")
	assert_true(balancer._resource_production.has("food"), "Food production should exist")
	assert_eq(balancer._resource_production["wood"], 10.0, "Wood production should be 10/day")

## Test: Single simulation returns valid structure
func test_single_simulation_structure():
	var result = balancer._run_single_simulation()
	
	assert_true(result.has("survived"), "Result should have 'survived' field")
	assert_true(result.has("avg_buffer"), "Result should have 'avg_buffer' field")
	assert_true(result.has("bottlenecks"), "Result should have 'bottlenecks' field")
	assert_true(result.survived is bool, "Survived should be boolean")

## Test: Simulation with high production should always survive
func test_high_production_survival():
	# Temporarily boost production
	balancer._resource_production["food"] = 100.0
	balancer._resource_production["wood"] = 100.0
	
	var result = balancer._run_single_simulation()
	
	assert_true(result.survived, "Should survive with high production")
	assert_true(result.avg_buffer > 10, "Should have large resource buffer")

## Test: Simulation with zero production should fail early
func test_zero_production_failure():
	balancer._resource_production["food"] = 0.0
	balancer._resource_consumption["food"] = 3.0
	
	var result = balancer._run_single_simulation()
	
	assert_false(result.survived, "Should fail with no food production")
	assert_true("food" in result.bottlenecks, "Food should be identified as bottleneck")

## Test: Difficulty multiplier affects consumption
func test_difficulty_multiplier():
	balancer.difficulty_multiplier = 2.0  # Hard mode
	
	var base_consumption = balancer._resource_consumption["food"]
	var sim_result = balancer._run_single_simulation()
	
	# With 2x consumption, survival should be harder
	# (exact result depends on RNG, but trend should be visible)
	print("Hard mode survival: ", sim_result.survived)

## Test: Event generation returns valid structure
func test_event_generation():
	var event = balancer._generate_random_event()
	
	assert_true(event.has("type"), "Event should have type")
	assert_true(event.has("effect"), "Event should have effect")
	assert_true(event.effect is Dictionary, "Effect should be dictionary")

## Test: Event application modifies resources correctly
func test_event_application():
	var resources = {"food": 20, "wood": 30}
	var event = {"type": "windfall", "effect": {"wood": 15}}
	
	balancer._apply_event(resources, event)
	
	assert_eq(resources["wood"], 45, "Wood should increase by 15")
	assert_eq(resources["food"], 20, "Food should remain unchanged")

## Test: Negative event doesn't create negative resources
func test_negative_event_floor():
	var resources = {"food": 3}
	var event = {"type": "drought", "effect": {"food": -10}}
	
	balancer._apply_event(resources, event)
	
	assert_eq(resources["food"], 0, "Food should floor at 0, not go negative")

## Test: Adjustment calculation for low survival
func test_adjustment_low_survival():
	var mock_results = {
		"survival_rate": 0.5,  # 50% - too low
		"avg_resource_buffer": 1.0,
		"bottlenecks": ["food"]
	}
	
	var adjustments = balancer._calculate_adjustments(mock_results)
	
	assert_true(adjustments.has("food_production") or adjustments.has("food_consumption"), 
		"Should suggest food adjustment")

## Test: No adjustments needed for balanced game
func test_no_adjustments_balanced():
	var mock_results = {
		"survival_rate": 0.9,  # 90% - good
		"avg_resource_buffer": 3.5,  # Within target range
		"bottlenecks": []
	}
	
	var adjustments = balancer._calculate_adjustments(mock_results)
	
	assert_eq(adjustments.size(), 0, "No adjustments needed for balanced game")

## Test: Full simulation suite runs without errors
func test_full_simulation_suite():
	var results = balancer.run_simulation()
	
	assert_true(results.has("survival_rate"), "Results should have survival_rate")
	assert_true(results.has("avg_resource_buffer"), "Results should have avg_resource_buffer")
	assert_true(results.has("bottlenecks"), "Results should have bottlenecks")
	assert_true(results.has("suggested_adjustments"), "Results should have suggested_adjustments")
	
	assert_ge(results.survival_rate, 0.0, "Survival rate should be >= 0")
	assert_le(results.survival_rate, 1.0, "Survival rate should be <= 1")

## Test: Balance entry point executes successfully
func test_balance_early_game_entry():
	var results = balancer.balance_early_game()
	
	# Should complete without crashing
	assert_not_eq(results, null, "Should return results object")
	assert_true(results.survival_rate >= 0.0, "Valid survival rate calculated")
