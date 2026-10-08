extends BaseTest

func test_losing_to_a_target_skips_it_without_counting_a_kill() -> void:
	var role := AdventurerRole.new()
	role.target = ScenarioTargets.role("adventurer")
	var pilot := _Pilot.new()
	var first_enemy := UnitStack.new(null, 1)
	var second_enemy := UnitStack.new(null, 1)
	pilot.enemy_stacks = {Vector2i(15, 0): [first_enemy]}

	assert_that(role.enemy_target(pilot)).is_equal(Vector2i(15, 0))
	pilot.enemy_stacks.erase(Vector2i(15, 0))
	pilot.enemy_stacks[Vector2i(10, 20)] = [first_enemy]
	assert_that(role.enemy_target(pilot)).is_equal(Vector2i(10, 20))
	pilot.enemy_stacks[Vector2i(18, 0)] = [second_enemy]
	role.on_battle_lost(pilot, Vector2i(10, 20))
	assert_that(role.enemy_target(pilot)).is_equal(Vector2i(18, 0))
	assert_that(role._kills).is_equal(0)
	pilot.free()

func test_feasible_selected_target_is_retained_outside_ring() -> void:
	assert_that(ScenarioTargets.seed_for("monk", "adventurer")).is_equal(1397225540)
	var role := AdventurerRole.new()
	role.target = ScenarioTargets.role("adventurer")
	var pilot := _Pilot.new()
	pilot.city_center = Vector2i(10, 10)
	var enemy := UnitStack.new(UnitStats.new("goblins", "Goblins", 0, 0, 8), 39)
	pilot.enemy_stacks = {Vector2i(19, 3): [enemy]}

	assert_that(role._in_ring(Vector2i(19, 3), pilot)).is_true()
	assert_that(role.enemy_target(pilot)).is_equal(Vector2i(19, 3))
	pilot.enemy_stacks.erase(Vector2i(19, 3))
	pilot.enemy_stacks[Vector2i(14, 1)] = [enemy]
	assert_that(role._in_ring(Vector2i(14, 1), pilot)).is_false()
	assert_that(role.enemy_target(pilot)).is_equal(Vector2i(14, 1))

	enemy.count = 200
	assert_that(role.enemy_target(pilot)).is_equal(Vector2i(-1, -1))
	pilot.free()

func test_role_counts_only_authoritative_hero_victory() -> void:
	var city := City.new()
	city.center = Vector2i(10, 10)
	var pilot := ScenarioPilot.new()
	pilot._player_city = city
	pilot._world = _Pilot.new()
	var role := AdventurerRole.new()
	role.target = ScenarioTargets.role("adventurer")
	pilot.role = role
	get_tree().root.add_child(pilot)
	var enemy_cell := Vector2i(10, 25)

	GameEventBus.battle_completed.emit(BattleState.Side.ATTACKER, enemy_cell)
	GameEventBus.battle_lost.emit(enemy_cell)
	assert_that(role._kills).is_equal(0)
	GameEventBus.battle_won.emit(enemy_cell)
	assert_that(role._kills).is_equal(1)
	pilot.queue_free()
	pilot._world.free()
	await get_tree().process_frame

class _Pilot extends Node:
	var enemy_stacks: Dictionary = {}
	var city_center := Vector2i.ZERO
	var hero_cell := Vector2i.ZERO
	var hex_shift_right := true
	var _hero: Node
	func _init() -> void:
		var hero := _Hero.new()
		hero.battle_stack = UnitStack.new(UnitStats.new("hero", "Hero", 0, 5, 10), 1)
		_hero = hero
		add_child(_hero)
	func _hero_cell() -> Vector2i: return hero_cell
	func _city_center() -> Vector2i: return city_center
	func _map(): return self
	func get_map_gen(): return self
	func get_endgame_state() -> Dictionary: return {}

class _Hero extends Node:
	var battle_stack: UnitStack
	func get_hero_battle_stack() -> UnitStack: return battle_stack
	func get_component(_name: String) -> Node: return null
