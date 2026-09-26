## Auto-Balancer for Early Game Resources and Buildings
## This system automatically calibrates resource production, building costs, and consumption rates
## to ensure a smooth early-game experience. It uses simulation-based tuning to find optimal values.

extends RefCounted
const GameLogger := preload("res://scripts/core/GameLogger.gd")
class_name AutoBalancer

# Configuration
@export var target_survival_rate: float = 0.85  # 85% of simulations should survive 10 days
@export var target_resource_buffer: int = 3  # Days of consumption buffer
@export var simulation_days: int = 100
@export var num_simulations: int = 50

# Difficulty multipliers
var difficulty_multiplier: float = 1.0  # 0.5 (easy) to 2.0 (hard)

# Resource data cache
var _resource_production: Dictionary = {}
var _resource_consumption: Dictionary = {}
var _building_costs: Dictionary = {}

func _init():
	_load_current_config()

## Load current game configuration
func _load_current_config():
	# TODO: Load from ResourceManager, BuildingManager, etc.
	# Placeholder values for simulation
	_resource_production = {
		"wood": 10.0,
		"food": 8.0,
		"stone": 5.0
	}
	_resource_consumption = {
		"food": 3.0,
		"wood": 1.0
	}
	_building_costs = {
		"farm": {"wood": 20, "stone": 5},
		"mine": {"wood": 30, "stone": 10}
	}

## Run full simulation suite
func run_simulation() -> Dictionary:
	var results = {
		"survival_rate": 0.0,
		"avg_resource_buffer": 0.0,
		"bottlenecks": [],
		"suggested_adjustments": {}
	}
	
	var survived_count = 0
	var total_buffer = 0
	
	for i in range(num_simulations):
		var sim_result = _run_single_simulation()
		if sim_result.survived:
			survived_count += 1
		total_buffer += sim_result.avg_buffer
		
		# Track bottlenecks
		for resource in sim_result.bottlenecks:
			if resource not in results.bottlenecks:
				results.bottlenecks.append(resource)
	
	results.survival_rate = float(survived_count) / num_simulations
	results.avg_resource_buffer = total_buffer / num_simulations
	
	# Calculate suggested adjustments
	results.suggested_adjustments = _calculate_adjustments(results)
	
	return results

## Run a single simulation
func _run_single_simulation() -> Dictionary:
	var resources = {
		"wood": 50,  # Starting resources
		"food": 30,
		"stone": 20
	}
	
	var daily_production = _resource_production.duplicate()
	var daily_consumption = _resource_consumption.duplicate()
	
	# Apply difficulty multiplier
	for res in daily_consumption:
		daily_consumption[res] *= difficulty_multiplier
	
	var survived = true
	var buffers = []
	var bottlenecks = []
	
	for day in range(simulation_days):
		# Production phase
		for res in daily_production:
			resources[res] = resources.get(res, 0) + daily_production[res]
		
		# Consumption phase
		for res in daily_consumption:
			resources[res] = resources.get(res, 0) - daily_consumption[res]
			if resources[res] < 0:
				resources[res] = 0
				if day < 10:  # Early game failure
					survived = false
					break
			
			# Track buffer
			if daily_consumption[res] > 0:
				var buffer = resources[res] / daily_consumption[res]
				buffers.append(buffer)
				if buffer < 1.0 and res not in bottlenecks:
					bottlenecks.append(res)
		
		if not survived:
			break
		
		# Simulate random events (10% chance per day)
		if randf() < 0.1:
			var event = _generate_random_event()
			_apply_event(resources, event)
	
	return {
		"survived": survived,
		"avg_buffer": buffers.reduce(func(a, b): return a + b, 0) / max(1, buffers.size()),
		"bottlenecks": bottlenecks
	}

## Generate random event for simulation
func _generate_random_event() -> Dictionary:
	var events = [
		{"type": "drought", "effect": {"food": -5}},
		{"type": "windfall", "effect": {"wood": 15}},
		{"type": "plague", "effect": {"food": -10}},
		{"type": "discovery", "effect": {"stone": 10}}
	]
	return events[randi() % events.size()]

## Apply event effects to resources
func _apply_event(resources: Dictionary, event: Dictionary):
	for res in event.effect:
		resources[res] = resources.get(res, 0) + event.effect[res]
		if resources[res] < 0:
			resources[res] = 0

## Calculate balance adjustments based on simulation results
func _calculate_adjustments(results: Dictionary) -> Dictionary:
	var adjustments = {}
	
	# If survival rate too low, increase production or decrease consumption
	if results.survival_rate < target_survival_rate:
		for bottleneck in results.bottlenecks:
			if bottleneck in _resource_production:
				# Increase production by 10-20%
				var increase = randf_range(0.1, 0.2)
				adjustments[bottleneck + "_production"] = _resource_production[bottleneck] * (1 + increase)
			
			if bottleneck in _resource_consumption:
				# Decrease consumption by 5-15%
				var decrease = randf_range(0.05, 0.15)
				adjustments[bottleneck + "_consumption"] = _resource_consumption[bottleneck] * (1 - decrease)
	
	# If buffer too high, slightly increase consumption (challenge)
	elif results.avg_resource_buffer > target_resource_buffer * 2:
		for res in _resource_consumption:
			var increase = randf_range(0.05, 0.1)
			adjustments[res + "_consumption"] = _resource_consumption[res] * (1 + increase)
	
	return adjustments

## Apply calculated corrections to game config
func apply_corrections(adjustments: Dictionary):
	# TODO: Write adjustments back to config files
	GameLogger.info("Applying balance corrections:", "Balance")
	for key in adjustments:
		GameLogger.info("  %s: %.2f" % [key, adjustments[key]], "Balance")
	
	# In production, this would update:
	# - game/data/config/resources.json
	# - game/data/config/buildings.json
	# - ResourceManager defaults

## Main entry point for auto-balancing
func balance_early_game():
	GameLogger.info("Starting auto-balance simulation...", "Balance")
	var results = run_simulation()
	
	GameLogger.info("Survival rate: %.1f%%" % (results.survival_rate * 100), "Balance")
	GameLogger.info("Average resource buffer: %.1f days" % results.avg_resource_buffer, "Balance")
	GameLogger.info("Bottlenecks: %s" % str(results.bottlenecks), "Balance")
	
	if results.suggested_adjustments.size() > 0:
		GameLogger.info("Suggested adjustments:", "Balance")
		apply_corrections(results.suggested_adjustments)
	else:
		GameLogger.info("Game balance is within acceptable parameters.", "Balance")
	
	return results
