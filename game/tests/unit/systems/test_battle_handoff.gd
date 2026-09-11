extends GdUnitTestSuite

const _BattleHandoff = preload("res://scripts/systems/BattleHandoff.gd")
const _Coordinator = preload("res://scripts/world/WorldBattleCoordinator.gd")
const _FakeMap = preload("res://tests/fakes/fake_battle_map.gd")
const _FakeFlow = preload("res://tests/fakes/fake_battle_flow.gd")

var _units: Node
var _nodes_to_free: Array = []


func before_test() -> void:
	_units = Services.resolve(&"units")


func after_test() -> void:
	for n in _nodes_to_free:
		if is_instance_valid(n):
			n.free()
	_nodes_to_free = []


func _armed_hero(tag: String) -> HeroController:
	var hero := TestFactories.make_hero()
	hero.name = "HandoffHero_%s" % tag
	hero.get_army().setup(_units)
	add_child(hero)
	_nodes_to_free.append(hero)
	return hero


# ── BattleHandoff: сбор данных ──

func test_collect_valid_handoff() -> void:
	var hero := _armed_hero("v1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_bool(handoff.is_valid).is_true()
	assert_that(handoff.validation_errors.size()).is_equal(0)
	# MAX_HERO_ARMY_SIZE = 7 — девятый стек отрезается в get_army_for_battle()
	assert_that(handoff.hero_army.size()).is_equal(GameNumbers.MAX_HERO_ARMY_SIZE)
	assert_that(handoff.enemy_army.size()).is_equal(1)
	assert_that(handoff.enemy_cell).is_equal(Vector2i(5, 5))
	assert_bool(handoff.roles_swapped).is_false()


func test_collect_null_hero_invalid() -> void:
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(null, enemy, Vector2i(5, 5), null, null, false)

	assert_bool(handoff.is_valid).is_false()
	assert_bool(handoff.validation_errors.has("hero_army_empty")).is_true()


func test_collect_null_rng_falls_back_to_randi() -> void:
	var hero := _armed_hero("r1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_bool(handoff.is_valid).is_true()
	assert_that(typeof(handoff.obstacle_seed) == TYPE_INT).is_true()
	assert_bool(handoff.obstacle_seed >= 0).is_true()


func test_collect_empty_enemy_army_invalid() -> void:
	var hero := _armed_hero("e1")
	var handoff := _BattleHandoff.collect(hero, [], Vector2i(5, 5), null, null, false)

	assert_bool(handoff.is_valid).is_false()
	assert_bool(handoff.validation_errors.has("enemy_army_empty")).is_true()


func test_collect_dead_stack_in_enemy_army_invalid() -> void:
	var hero := _armed_hero("d1")
	var dead_stack: UnitStack = _units.make_fixed_stack("goblins", 0)
	var handoff := _BattleHandoff.collect(hero, [dead_stack], Vector2i(5, 5), null, null, false)

	assert_bool(handoff.is_valid).is_false()
	assert_bool(handoff.validation_errors.has("enemy_army_has_dead_stack")).is_true()


func test_collect_gathers_hero_bonus() -> void:
	var hero := _armed_hero("b1")
	hero.stats = {"attack": 7, "defense": 3, "spell_power": 5, "knowledge": 2}
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_that(handoff.hero_bonus.get("attack", 0)).is_equal(7)
	assert_that(handoff.hero_bonus.get("defense", 0)).is_equal(3)
	assert_that(handoff.hero_bonus.get("spell_power", 0)).is_equal(5)
	assert_that(handoff.hero_bonus.get("knowledge", 0)).is_equal(2)


func test_collect_gathers_artifact_mods() -> void:
	var hero := _armed_hero("a1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_bool(handoff.hero_artifact_mods is Dictionary).is_true()
	assert_bool(handoff.hero_artifact_mods.has("attack")).is_true()


func test_collect_gathers_magic() -> void:
	var hero := _armed_hero("m1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_that(handoff.hero_magic).is_not_null()


func test_collect_null_spawner_empty_enemy_bonus() -> void:
	var hero := _armed_hero("s1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_that(handoff.enemy_bonus.size()).is_equal(0)


func test_collect_obstacle_seed_from_rng() -> void:
	var hero := _armed_hero("r1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var h1 := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, TestFactories.seeded(42), false)
	var h2 := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, TestFactories.seeded(42), false)

	assert_that(h1.obstacle_seed).is_equal(h2.obstacle_seed)


# ── BattleHandoff: роли ──

func test_roles_not_swapped() -> void:
	var hero := _armed_hero("n1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_bool(handoff.roles_swapped).is_false()
	assert_that(handoff.get_attacker_army()).is_equal(handoff.hero_army)
	assert_that(handoff.get_defender_army()).is_equal(handoff.enemy_army)
	assert_that(handoff.get_attacker_bonus()).is_equal(handoff.hero_bonus)
	assert_that(handoff.get_defender_bonus()).is_equal(handoff.enemy_bonus)
	assert_that(handoff.get_attacker_artifact_mods()).is_equal(handoff.hero_artifact_mods)
	assert_bool(handoff.get_defender_artifact_mods().is_empty()).is_true()


func test_roles_swapped() -> void:
	var hero := _armed_hero("n2")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, true)

	assert_bool(handoff.roles_swapped).is_true()
	assert_that(handoff.get_attacker_army()).is_equal(handoff.enemy_army)
	assert_that(handoff.get_defender_army()).is_equal(handoff.hero_army)
	assert_that(handoff.get_attacker_bonus()).is_equal(handoff.enemy_bonus)
	assert_that(handoff.get_defender_bonus()).is_equal(handoff.hero_bonus)
	assert_bool(handoff.get_attacker_artifact_mods().is_empty()).is_true()
	assert_that(handoff.get_defender_artifact_mods()).is_equal(handoff.hero_artifact_mods)


func test_hero_won_normal() -> void:
	var hero := _armed_hero("w1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	assert_bool(handoff.hero_won(BattleState.Side.ATTACKER)).is_true()
	assert_bool(handoff.hero_won(BattleState.Side.DEFENDER)).is_false()


func test_hero_won_swapped() -> void:
	var hero := _armed_hero("w2")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, true)

	assert_bool(handoff.hero_won(BattleState.Side.DEFENDER)).is_true()
	assert_bool(handoff.hero_won(BattleState.Side.ATTACKER)).is_false()


func test_extract_hero_survivors_normal() -> void:
	var hero := _armed_hero("x1")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, false)

	var atk: Array[UnitStack] = [_units.make_fixed_stack("swordsmen", 5)]
	var def: Array[UnitStack] = []
	var survivors := handoff.extract_hero_survivors(atk, def)
	assert_that(survivors).is_equal(atk)


func test_extract_hero_survivors_swapped() -> void:
	var hero := _armed_hero("x2")
	var enemy: Array = [_units.make_fixed_stack("goblins", 10)]
	var handoff := _BattleHandoff.collect(hero, enemy, Vector2i(5, 5), null, null, true)

	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = [_units.make_fixed_stack("swordsmen", 5)]
	var survivors := handoff.extract_hero_survivors(atk, def)
	assert_that(survivors).is_equal(def)


# ── BattleHandoff: не-массивные данные ──

func test_collect_non_array_enemy_army() -> void:
	var hero := _armed_hero("j1")
	var handoff := _BattleHandoff.collect(hero, "not_an_array", Vector2i(5, 5), null, null, false)

	assert_bool(handoff.is_valid).is_false()
	assert_bool(handoff.validation_errors.has("enemy_army_empty")).is_true()


func test_collect_mixed_array_filters_non_stacks() -> void:
	var hero := _armed_hero("j2")
	var valid_stack: UnitStack = _units.make_fixed_stack("goblins", 10)
	var mixed: Array = [valid_stack, "junk", 42, null]
	var handoff := _BattleHandoff.collect(hero, mixed, Vector2i(5, 5), null, null, false)

	assert_that(handoff.enemy_army.size()).is_equal(1)
	assert_bool(handoff.is_valid).is_true()


# ── Интеграция с координатором ──

func test_coordinator_contact_triggers_battle_via_handoff() -> void:
	var fake_map = _FakeMap.new()
	fake_map.name = "FakeMap"
	fake_map.enemy_stacks[Vector2i(5, 5)] = [_units.make_fixed_stack("goblins", 10)]

	var coordinator = _Coordinator.new()
	coordinator.name = "Coord"
	coordinator.map_gen = fake_map
	coordinator.hero = _armed_hero("c1")

	var flow = _FakeFlow.new()
	flow.name = "BF"
	coordinator.battle_flow = flow
	coordinator.rng = TestFactories.seeded(8875)

	coordinator.check_enemy_contact(Vector2i(5, 5))

	assert_that(coordinator.get_pending_enemy_cell()).is_equal(Vector2i(5, 5))
	assert_that(flow.started).is_equal(1)
	assert_bool(flow.last_enemy_army.size() >= 1).is_true()

	fake_map.free()
	coordinator.free()
	flow.free()


func test_coordinator_null_hero_no_battle() -> void:
	var fake_map = _FakeMap.new()
	fake_map.name = "FakeMap2"
	fake_map.enemy_stacks[Vector2i(5, 5)] = [_units.make_fixed_stack("goblins", 10)]

	var coordinator = _Coordinator.new()
	coordinator.name = "Coord2"
	coordinator.map_gen = fake_map
	coordinator.hero = null

	var flow = _FakeFlow.new()
	flow.name = "BF2"
	coordinator.battle_flow = flow
	coordinator.rng = TestFactories.seeded(1)

	coordinator.check_enemy_contact(Vector2i(5, 5))

	assert_that(coordinator.get_pending_enemy_cell()).is_equal(Vector2i(-1, -1))
	assert_that(flow.started).is_equal(0)

	fake_map.free()
	coordinator.free()
	flow.free()


func test_coordinator_empty_enemy_army_no_battle() -> void:
	var fake_map = _FakeMap.new()
	fake_map.name = "FakeMap3"
	fake_map.enemy_stacks[Vector2i(5, 5)] = []

	var coordinator = _Coordinator.new()
	coordinator.name = "Coord3"
	coordinator.map_gen = fake_map
	coordinator.hero = _armed_hero("c3")

	var flow = _FakeFlow.new()
	flow.name = "BF3"
	coordinator.battle_flow = flow
	coordinator.rng = TestFactories.seeded(1)

	coordinator.check_enemy_contact(Vector2i(5, 5))

	assert_that(flow.started).is_equal(0)

	fake_map.free()
	coordinator.free()
	flow.free()
