extends BaseTest

const BalanceProbe := preload("res://scripts/probe/balance_probe.gd")

func test_probe_avoids_reengaging_an_enemy_after_losing() -> void:
	var probe := BalanceProbe.new()
	var city := City.new()
	city.center = Vector2i(10, 10)
	var map := _FakeMap.new()
	map.enemy_stacks = {Vector2i(10, 10): [], Vector2i(12, 10): []}
	var world := _FakeWorld.new()
	world.map = map
	probe._player_city = city
	probe._world = world

	assert_that(probe._nearest_city_threat()).is_equal(Vector2i(10, 10))
	probe._on_battle_lost(Vector2i(10, 10))
	assert_that(probe._nearest_city_threat()).is_equal(Vector2i(12, 10))
	assert_that(probe.losses).is_equal(1)
	probe.free()
	world.free()

func test_walk_to_retries_after_turn_refreshes_movement_points() -> void:
	var probe := BalanceProbe.new()
	var movement := _FakeMovement.new()
	var hero := _FakeHero.new()
	hero.movement = movement
	var world := _FakeMovementWorld.new(movement)
	probe._hero = hero
	probe._world = world
	probe.turn = 1

	assert_bool(probe._walk_to(Vector2i(5, 5))).is_true()
	assert_that(movement.move_attempts).is_equal(2)
	assert_that(world.turns).is_equal(1)

	probe.free()
	hero.free()
	movement.free()
	world.free()

class _FakeMap:
	var enemy_stacks: Dictionary = {}

class _FakeMovement extends Node:
	var current_cell := Vector2i.ZERO
	var movement_points := 0.0
	var moving := false
	var move_attempts := 0
	var controller := _FakeMoveController.new()

	func _init() -> void:
		add_child(controller)

	func is_moving() -> bool:
		return moving

	func get_current_cell() -> Vector2i:
		return current_cell

	func get_move_points() -> float:
		return movement_points

	func get_controller() -> Node:
		return controller

	func move_to_cell(_cell: Vector2i) -> bool:
		move_attempts += 1
		if movement_points <= 0.0:
			return false
		moving = true
		return true

class _FakeMoveController extends Node:
	var problem := "insufficient_mp"

	func reach_problem(_cell: Vector2i) -> String:
		return problem

class _FakeHero extends Node:
	var movement: Node
	func get_component(_name: String) -> Node: return movement

class _FakeMovementWorld extends Node:
	var movement: _FakeMovement
	var turns := 0

	func _init(p_movement: _FakeMovement) -> void:
		movement = p_movement

	func do_end_turn() -> void:
		turns += 1
		movement.movement_points = 10.0
		movement.controller.problem = ""

	func is_terminal() -> bool:
		return false

class _FakeWorld extends Node:
	var map: _FakeMap
	func get_map_gen(): return map

func test_balance_report_embeds_cached_campaign_city_metrics() -> void:
	var probe := BalanceProbe.new()
	var report := probe.report()
	var city_report: Dictionary = report.campaign_city

	assert_bool(city_report.ok).is_true()
	assert_bool(city_report.balance_pass).is_true()
	assert_that(city_report.construction_summary.affordability.attempted).is_equal(15)
	assert_that(city_report.construction_summary.affordability.affordable).is_equal(15)
	assert_that(city_report.summary.day21_group_coverage.size()).is_equal(7)
	assert_float(float(city_report.summary.day21_stocks.food)).is_equal_approx(1.1, 0.0001)
	assert_that(probe.report()).is_equal(report)
	probe.free()
