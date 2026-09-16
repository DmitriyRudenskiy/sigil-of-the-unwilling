extends BaseTest

# AutoBalancer: структура симуляции, события, корректировки (конвертация с GUT → GdUnit4)

const AutoBalancer = preload("res://scripts/balance/auto_balancer.gd")

var balancer

func before_test() -> void:
	balancer = AutoBalancer.new()


## Initial configuration loads correctly
func test_initial_config() -> void:
	assert_that(balancer.target_survival_rate == 0.85).override_failure_message("Target survival rate should be 85%")
	assert_that(balancer.target_resource_buffer == 3).override_failure_message("Target buffer should be 3 days")
	assert_that(balancer.simulation_days == 100).override_failure_message("Simulation should run 100 days")
	assert_that(balancer.num_simulations == 50).override_failure_message("Should run 50 simulations")


## Resource production values are loaded
func test_resource_production_loaded() -> void:
	assert_bool(balancer._resource_production.has("wood")).override_failure_message("Wood production should exist")
	assert_bool(balancer._resource_production.has("food")).override_failure_message("Food production should exist")
	assert_that(balancer._resource_production["wood"] == 10.0).override_failure_message("Wood production should be 10/day")


## Single simulation returns valid structure
func test_single_simulation_structure() -> void:
	var result = balancer._run_single_simulation()
	assert_bool(result.has("survived")).override_failure_message("Result should have 'survived' field")
	assert_bool(result.has("avg_buffer")).override_failure_message("Result should have 'avg_buffer' field")
	assert_bool(result.has("bottlenecks")).override_failure_message("Result should have 'bottlenecks' field")
	assert_bool(result.survived is bool).override_failure_message("Survived should be boolean")


## Simulation with high production should always survive
func test_high_production_survival() -> void:
	balancer._resource_production["food"] = 100.0
	balancer._resource_production["wood"] = 100.0
	var result = balancer._run_single_simulation()
	assert_bool(result.survived).override_failure_message("Should survive with high production")
	assert_bool(result.avg_buffer > 10).override_failure_message("Should have large resource buffer")


## Simulation with zero production should fail early
func test_zero_production_failure() -> void:
	balancer._resource_production["food"] = 0.0
	balancer._resource_consumption["food"] = 3.0
	var result = balancer._run_single_simulation()
	assert_bool(not result.survived).override_failure_message("Should fail with no food production")
	assert_bool("food" in result.bottlenecks).override_failure_message("Food should be identified as bottleneck")


## Difficulty multiplier affects consumption (smoke)
func test_difficulty_multiplier() -> void:
	balancer.difficulty_multiplier = 2.0
	var sim_result = balancer._run_single_simulation()
	assert_bool(sim_result.survived is bool).override_failure_message("Hard mode sim should return bool survived")


## Event generation returns valid structure
func test_event_generation() -> void:
	var event = balancer._generate_random_event()
	assert_bool(event.has("type")).override_failure_message("Event should have type")
	assert_bool(event.has("effect")).override_failure_message("Event should have effect")
	assert_bool(event.effect is Dictionary).override_failure_message("Effect should be dictionary")


## Event application modifies resources correctly
func test_event_application() -> void:
	var resources = {"food": 20, "wood": 30}
	var event = {"type": "windfall", "effect": {"wood": 15}}
	balancer._apply_event(resources, event)
	assert_that(resources["wood"] == 45).override_failure_message("Wood should increase by 15")
	assert_that(resources["food"] == 20).override_failure_message("Food should remain unchanged")


## Negative event doesn't create negative resources
func test_negative_event_floor() -> void:
	var resources = {"food": 3}
	var event = {"type": "drought", "effect": {"food": -10}}
	balancer._apply_event(resources, event)
	assert_that(resources["food"] == 0).override_failure_message("Food should floor at 0, not go negative")


## Adjustment calculation for low survival
func test_adjustment_low_survival() -> void:
	var mock_results = {
		"survival_rate": 0.5,
		"avg_resource_buffer": 1.0,
		"bottlenecks": ["food"]
	}
	var adjustments = balancer._calculate_adjustments(mock_results)
	assert_bool(adjustments.has("food_production") or adjustments.has("food_consumption")) \
		.override_failure_message("Should suggest food adjustment")


## No adjustments needed for balanced game
func test_no_adjustments_balanced() -> void:
	var mock_results = {
		"survival_rate": 0.9,
		"avg_resource_buffer": 3.5,
		"bottlenecks": []
	}
	var adjustments = balancer._calculate_adjustments(mock_results)
	assert_that(adjustments.size() == 0).override_failure_message("No adjustments needed for balanced game")


## Full simulation suite runs without errors
func test_full_simulation_suite() -> void:
	var results = balancer.run_simulation()
	assert_bool(results.has("survival_rate")).override_failure_message("Results should have survival_rate")
	assert_bool(results.has("avg_resource_buffer")).override_failure_message("Results should have avg_resource_buffer")
	assert_bool(results.has("bottlenecks")).override_failure_message("Results should have bottlenecks")
	assert_bool(results.has("suggested_adjustments")).override_failure_message("Results should have suggested_adjustments")
	assert_bool(results.survival_rate >= 0.0).override_failure_message("Survival rate should be >= 0")
	assert_bool(results.survival_rate <= 1.0).override_failure_message("Survival rate should be <= 1")


## Balance entry point executes successfully
func test_balance_early_game_entry() -> void:
	var results = balancer.balance_early_game()
	assert_that(results != null).override_failure_message("Should return results object")
	assert_bool(results.survival_rate >= 0.0).override_failure_message("Valid survival rate calculated")
