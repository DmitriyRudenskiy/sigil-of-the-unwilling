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
	# Число камней выводится из площади поля (battle-99-hex-clean-hud), поэтому
	# проверяется свойство, а не удвоенная формула: плотность ≤ 6% поля.
	assert_int(a.obstacles.size() * 100).is_less_equal(BattleState.BW * BattleState.BH * 6) \
			.override_failure_message("камней слишком много для такого поля")
	assert_int(a.obstacles.size()).is_greater(0)
	assert_int(view_a.obstacles_added).is_equal(a.obstacles.size())

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
	# Полоса — центр поля, с отступом минимум в две колонки от каждого края:
	# на узком поле камни не должны вставать в колонки развёртки.
	for cell in a.obstacles:
		assert_int(cell.x).is_between(2, BattleState.BW - 3)
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


# UI-3b: flow держит сцену боя до result_accepted (оверлей «Продолжить»).
# Неинтерактивные клиенты (probe) не могут кликнуть — accept_result() даёт
# программный путь. Без battle_over — не emit (оверлей ещё не показан).
func test_accept_result_emits_only_when_battle_over() -> void:
	var bc = auto_free(BattleController.new())
	bc._state = BattleState.new()
	var got: Array = []
	bc.result_accepted.connect(func(): got.append(true))

	bc.accept_result()
	assert_int(got.size()).is_equal(0)

	bc._state.battle_over = true
	bc.accept_result()
	assert_int(got.size()).is_equal(1)


# UI-3b: повторный accept_result после battle_over — идемпотентный emit
# (flow-подключение CONNECT_ONE_SHOT; повторные emit без слушателей не должны
# падать и не должны дублировать эффект).
func test_accept_result_repeat_does_not_crash() -> void:
	var bc = auto_free(BattleController.new())
	bc._state = BattleState.new()
	bc._state.battle_over = true
	var got: Array = []
	bc.result_accepted.connect(func(): got.append(true))
	bc.accept_result()
	bc.accept_result()
	assert_int(got.size()).is_equal(2)

# ── 5.1: «Автобой» — подтверждение, эмулятор, штатный итог ────────────────────

class StubAutoUI extends BattleUI:
	## Порядок паузы команд: по нему видно, что на время подтверждения и передачи
	## управление действительно снято (`set_controls_enabled` — единственный
	## носитель паузы панели, тем же пользуется пауза настроек).
	var calls: Array[String] = []
	func set_controls_enabled(enabled: bool) -> void:
		calls.append("on" if enabled else "off")

class AutoResult extends RefCounted:
	var fired := 0
	var winner := -1
	var atk := -1
	var def_ := -1
	func take(w: BattleState.Side, a: Array[UnitStack], d: Array[UnitStack]) -> void:
		fired += 1
		winner = w
		atk = a.size()
		def_ = d.size()

func _alive(state: BattleState) -> int:
	return state.get_survivors(BattleState.Side.ATTACKER).size() \
		+ state.get_survivors(BattleState.Side.DEFENDER).size()

func _auto_fixture() -> Dictionary:
	var bc = auto_free(BattleController.new())
	var ui = auto_free(StubAutoUI.new())
	bc._ui = ui
	bc._state = BattleState.new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack("swordsmen", 10)]
	var def_: Array[UnitStack] = [Units.make_fixed_stack("goblins", 10)]
	bc._state.place_army(atk, def_)
	return {"bc": bc, "ui": ui}

## Итог «Автобоя» — вердикт того же состояния после эмулятора: контроллер сам
## ничего не считает, он отдаёт состояние `BattleEmulator.run_auto_battle` и
## сообщает `check_end` со своими же полосками выживших.
func test_auto_battle_reports_emulated_state() -> void:
	var f := _auto_fixture()
	var bc = f["bc"]
	var col := AutoResult.new()
	bc.battle_finished.connect(col.take)
	bc._run_auto_battle()
	assert_int(col.fired).is_equal(1).override_failure_message("бой обязан закончиться одним итогом")
	assert_bool(bc._state.battle_over).is_true()
	assert_int(col.winner).is_equal(bc._state.check_end())
	assert_int(col.atk).is_equal(bc._state.get_survivors(BattleState.Side.ATTACKER).size())
	assert_int(col.def_).is_equal(bc._state.get_survivors(BattleState.Side.DEFENDER).size())

## Пока игрок решает, команды сняты; отказ возвращает их, состояние боя не тронуто.
func test_auto_battle_confirm_blocks_and_restores() -> void:
	var f := _auto_fixture()
	var bc = f["bc"]
	var ui = f["ui"]
	var alive_before: int = _alive(bc._state)
	bc._on_auto_battle()
	assert_that(ui.calls).contains_exactly(["off"]) \
			.override_failure_message("открытие подтверждения обязано снять команды")
	assert_object(bc._auto_confirm).is_not_null()
	bc._auto_confirm.canceled.emit()
	assert_that(ui.calls).contains_exactly(["off", "on"])
	assert_int(_alive(bc._state)).is_equal(alive_before)
	assert_bool(bc._state.battle_over).is_false()
