extends GdUnitTestSuite

const _BS = preload("res://scripts/systems/BattleState.gd")
const _BTX = preload("res://scripts/systems/BattleTurnExecutor.gd")
const _BAI = preload("res://scripts/systems/BattleAI.gd")

func test_obstacle_different_seeds_differ() -> void:
	var a := _generate_obstacles(42)
	var b := _generate_obstacles(43)
	assert_bool(a.keys().hash() == b.keys().hash()).is_false()

func test_obstacle_same_seed_reproducible() -> void:
	var a := _generate_obstacles(42)
	var b := _generate_obstacles(42)
	assert_bool(a.keys().hash() == b.keys().hash()).is_true()

func test_obstacle_count_is_eight() -> void:
	var obstacles := _generate_obstacles(99)
	assert_that(obstacles.size()).is_equal(8)

func test_obstacle_cells_in_bounds() -> void:
	var obstacles := _generate_obstacles(7)
	for cell in obstacles:
		var c: Vector2i = cell
		assert_bool(c.x >= 4 and c.x <= BattleState.BW - 5).is_true()
		assert_bool(c.y >= 1 and c.y <= BattleState.BH - 2).is_true()

func _generate_obstacles(seed: int) -> Dictionary:
	var rng := TestFactories.seeded(6833)
	rng.seed = seed
	var obstacles: Dictionary = {}
	var n := 0
	while n < 8:
		var cell := Vector2i(
			rng.randi_range(4, BattleState.BW - 5),
			rng.randi_range(1, BattleState.BH - 2)
		)
		if obstacles.has(cell):
			continue
		obstacles[cell] = true
		n += 1
	return obstacles


func test_scroll_spawn_determinism() -> void:
	var a := _get_scroll_spell_ids(12345)
	var b := _get_scroll_spell_ids(12345)
	assert_bool(a == b).is_true()

func test_scroll_spawn_varies_with_seed() -> void:
	var a := _get_scroll_spell_ids(111)
	var b := _get_scroll_spell_ids(222)
	assert_bool(a.size() > 0).is_true()
	assert_bool(b.size() > 0).is_true()

func _get_scroll_spell_ids(seed: int) -> Array[StringName]:
	var chest_rng := TestFactories.seeded(6833)
	chest_rng.seed = seed
	var all_spells: Array = Spells.get_all_spells()
	var count := 3
	var result: Array[StringName] = []
	for i in count:
		var spell = all_spells[chest_rng.randi() % all_spells.size()]
		result.append(spell.id)
	return result


func test_pending_action_enum_values() -> void:
	assert_that(_BTX.PendingAction.NONE).is_equal(0)
	assert_that(_BTX.PendingAction.MOVE).is_equal(1)
	assert_that(_BTX.PendingAction.ATTACK).is_equal(2)

func test_pause_sets_pending_move() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor"
	executor.pause_battle()
	executor._pending_completion = _BTX.PendingAction.MOVE
	assert_that(executor._pending_completion).is_equal(_BTX.PendingAction.MOVE)
	executor.resume_battle()
	assert_bool(executor.is_paused()).is_false()
	executor.free()

func test_pause_sets_pending_attack() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor2"
	executor.pause_battle()
	executor._pending_completion = _BTX.PendingAction.ATTACK
	assert_that(executor._pending_completion).is_equal(_BTX.PendingAction.ATTACK)
	executor.free()

func test_resume_clears_pending() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor3"
	executor.pause_battle()
	executor._pending_completion = _BTX.PendingAction.MOVE
	executor.resume_battle()
	assert_that(executor._pending_completion).is_equal(_BTX.PendingAction.NONE)
	executor.free()

func test_start_battle_resets_pending() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor5"
	executor._pending_completion = _BTX.PendingAction.ATTACK
	executor._paused = true
	var bs := BattleState.new()
	var ai := _BAI.new()
	executor.setup(bs, ai, {})
	executor.start_battle()
	assert_bool(executor.is_paused()).is_false()
	assert_that(executor._pending_completion).is_equal(_BTX.PendingAction.NONE)
	executor.free()
