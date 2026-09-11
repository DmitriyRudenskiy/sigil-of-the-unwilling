extends BaseTest



var cc: Object
var bus: Node

func before_test() -> void:
	cc = CursorControllerAutoload.new()
	bus = GameEventBusAutoload.new()
	cc._connect_context(bus)

func after_test() -> void:
	if cc != null:
		cc.free()
		cc = null
	if bus != null:
		bus.free()
		bus = null

func test_walk_moving_changes_mode() -> void:
	bus.hero_moving_changed.emit(true)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.WALK)

func test_walk_still_changes_mode() -> void:
	bus.hero_moving_changed.emit(false)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.DEFAULT)

func test_resource_extracted_sets_collect() -> void:
	bus.resource_extracted.emit(Vector2i(4, 4), &"silver", 2)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.COLLECT)

func test_collect_timer_returns_to_default() -> void:
	bus.resource_extracted.emit(Vector2i(4, 4), &"silver", 2)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.COLLECT)
	cc._advance_collect(CursorControllerAutoload.COLLECT_HOLD_SECONDS)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.DEFAULT)

func test_collect_partial_delta_stays_collect() -> void:
	bus.resource_extracted.emit(Vector2i(4, 4), &"silver", 2)
	cc._advance_collect(0.3)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.COLLECT)

func test_battle_completed_resets_to_default() -> void:
	bus.battle_completed.emit(BattleState.Side.ATTACKER, Vector2i(3, 3))
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.DEFAULT)

func test_battle_lost_resets_to_default() -> void:
	bus.battle_lost.emit(Vector2i(3, 3))
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.DEFAULT)

func test_set_mode_attack() -> void:
	cc.set_mode(CursorControllerAutoload.Mode.ATTACK)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.ATTACK)

func test_set_mode_same_is_noop() -> void:
	cc.set_mode(CursorControllerAutoload.Mode.WALK)
	cc._change_mode(CursorControllerAutoload.Mode.WALK)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.WALK)

func test_unconfigured_mode_does_not_crash() -> void:
	cc.set_mode(CursorControllerAutoload.Mode.WALK)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.WALK)
	cc.set_mode(CursorControllerAutoload.Mode.ATTACK)
	assert_that(cc.current_mode()).is_equal(CursorControllerAutoload.Mode.ATTACK)
