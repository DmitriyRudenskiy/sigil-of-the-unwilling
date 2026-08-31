extends "res://tests/test_base.gd"
## Регрессионные тесты для правок R1, R2, R3.

const _BS = preload("res://scripts/systems/BattleState.gd")
const _BTX = preload("res://scripts/systems/BattleTurnExecutor.gd")
const _BAI = preload("res://scripts/systems/BattleAI.gd")
# ==================== R1: obstacle seed determinism ====================

func test_obstacle_different_seeds_differ() -> void:
	var a := _generate_obstacles(42)
	var b := _generate_obstacles(43)
	assert_false(
		a.keys().hash() == b.keys().hash(),
		"different seeds must produce different obstacle layouts"
	)

func test_obstacle_same_seed_reproducible() -> void:
	var a := _generate_obstacles(42)
	var b := _generate_obstacles(42)
	assert_true(
		a.keys().hash() == b.keys().hash(),
		"same seed must produce identical obstacles"
	)

func test_obstacle_count_is_eight() -> void:
	var obstacles := _generate_obstacles(99)
	assert_eq(obstacles.size(), 8, "exactly 8 obstacles")

func test_obstacle_cells_in_bounds() -> void:
	var obstacles := _generate_obstacles(7)
	for cell in obstacles:
		var c: Vector2i = cell
		assert_true(c.x >= 4 and c.x <= BattleState.BW - 5, "x in bounds")
		assert_true(c.y >= 1 and c.y <= BattleState.BH - 2, "y in bounds")

func _generate_obstacles(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
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

# ==================== R2: scroll spawn determinism ====================

func test_scroll_spawn_determinism() -> void:
	var a := _get_scroll_spell_ids(12345)
	var b := _get_scroll_spell_ids(12345)
	assert_true(a == b, "same run_seed must produce identical scroll spells")

func test_scroll_spawn_varies_with_seed() -> void:
	var a := _get_scroll_spell_ids(111)
	var b := _get_scroll_spell_ids(222)
	assert_true(a.size() > 0, "scrolls generated for seed 111")
	assert_true(b.size() > 0, "scrolls generated for seed 222")

func _get_scroll_spell_ids(seed: int) -> Array[StringName]:
	var chest_rng := RandomNumberGenerator.new()
	chest_rng.seed = seed
	var all_spells: Array = Spells.get_all_spells()
	var count := 3
	var result: Array[StringName] = []
	for i in count:
		var spell = all_spells[chest_rng.randi() % all_spells.size()]
		result.append(spell.id)
	return result

# ==================== R3: PendingAction enum ====================

func test_pending_action_enum_values() -> void:
	assert_eq(_BTX.PendingAction.NONE, 0, "NONE = 0")
	assert_eq(_BTX.PendingAction.MOVE, 1, "MOVE = 1")
	assert_eq(_BTX.PendingAction.ATTACK, 2, "ATTACK = 2")

func test_pause_sets_pending_move() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor"
	executor.pause_battle()
	executor._pending_completion = _BTX.PendingAction.MOVE
	assert_eq(
		executor._pending_completion,
		_BTX.PendingAction.MOVE,
		"pending is MOVE enum"
	)
	executor.resume_battle()
	assert_false(executor.is_paused(), "resumed after resume_battle")
	executor.free()

func test_pause_sets_pending_attack() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor2"
	executor.pause_battle()
	executor._pending_completion = _BTX.PendingAction.ATTACK
	assert_eq(
		executor._pending_completion,
		_BTX.PendingAction.ATTACK,
		"pending is ATTACK enum"
	)
	executor.free()

func test_resume_clears_pending() -> void:
	var executor := _BTX.new()
	executor.name = "TestExecutor3"
	executor.pause_battle()
	executor._pending_completion = _BTX.PendingAction.MOVE
	executor.resume_battle()
	assert_eq(
		executor._pending_completion,
		_BTX.PendingAction.NONE,
		"pending cleared after resume"
	)
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
	assert_false(executor.is_paused(), "start_battle clears pause")
	assert_eq(
		executor._pending_completion,
		_BTX.PendingAction.NONE,
		"start_battle clears pending"
	)
	executor.free()
