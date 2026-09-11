# TASK_18 B2.4: BattleController — препятствия, мана, делегирование в executor.
extends BaseTest


class StubView extends BattleView:
	var obstacles_added: int = 0
	func add_obstacle(_cell: Vector2i, _emoji: String) -> void:
		obstacles_added += 1


class StubExecutor extends BattleTurnExecutor:
	var move_requests: Array = []
	func request_move(unit: BattleState.BattleUnit, target: Vector2i) -> void:
		move_requests.append([unit, target])


func test_place_obstacles_deterministic() -> void:
	var a = auto_free(BattleController.new())
	var view_a := StubView.new()
	a._view = view_a
	a._obstacle_seed = 42
	a._place_obstacles()
	assert_int(a.obstacles.size()).is_equal(8)
	assert_int(view_a.obstacles_added).is_equal(8)

	var b = auto_free(BattleController.new())
	var view_b := StubView.new()
	b._view = view_b
	b._obstacle_seed = 42
	b._place_obstacles()
	assert_that(b.obstacles.keys()).is_equal(a.obstacles.keys()) \
			.override_failure_message("same seed must give same obstacles")
	view_a.free()
	view_b.free()

func test_place_obstacles_within_bounds() -> void:
	var a = auto_free(BattleController.new())
	var view_a := StubView.new()
	a._view = view_a
	a._obstacle_seed = 7
	a._place_obstacles()
	for cell in a.obstacles:
		assert_int(cell.x).is_between(4, BattleState.BW - 5)
		assert_int(cell.y).is_between(1, BattleState.BH - 2)
	view_a.free()

func test_spell_fail_refunds_mana() -> void:
	var bc = auto_free(BattleController.new())
	var magic := HeroMagic.new()
	magic.mana_max = 20
	magic.mana_current = 20
	magic.spend_mana(3)
	assert_int(magic.mana_current).is_equal(17)
	bc._hero_magic = magic
	bc._last_spell_cost = 3
	bc._on_spell_cast_failed("no target")
	assert_int(magic.mana_current).is_equal(20)
	assert_int(bc._last_spell_cost).is_equal(0)

func test_spell_fail_without_magic_no_crash() -> void:
	var bc = auto_free(BattleController.new())
	bc._hero_magic = null
	bc._last_spell_cost = 5
	bc._on_spell_cast_failed("whatever")  # просто не падает; без магии возврата нет
	assert_int(bc._last_spell_cost).is_equal(5)

func test_move_request_delegated_to_executor() -> void:
	var bc = auto_free(BattleController.new())
	var exec := StubExecutor.new()
	bc._executor = exec
	var unit = BattleState.BattleUnit.new()
	bc._on_move_requested(unit, Vector2i(1, 2))
	assert_int(exec.move_requests.size()).is_equal(1)
	assert_that(exec.move_requests[0][1]).is_equal(Vector2i(1, 2))
	exec.free()

func test_battle_finished_signal() -> void:
	var bc = auto_free(BattleController.new())
	var got: Array = []
	bc.battle_finished.connect(func(winner, atk, def): got.append([winner, atk, def]))
	bc.battle_finished.emit(BattleState.Side.ATTACKER, [], [])
	assert_int(got.size()).is_equal(1)
	assert_that(got[0][0]).is_equal(BattleState.Side.ATTACKER)
