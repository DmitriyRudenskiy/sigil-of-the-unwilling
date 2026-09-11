extends BaseTest


var unit: RefCounted

func before_test() -> void:
	unit = PopUnit.new()
	unit.uid = 1
	unit.state = PopUnit.State.FOLLOWER

func test_initial_state_follower() -> void:
	assert_that(unit.state).is_equal(PopUnit.State.FOLLOWER)

func test_initial_available() -> void:
	assert_bool(unit.is_available()).is_true()

func test_initial_free_follower() -> void:
	assert_bool(unit.is_free_follower()).is_true()

func test_initial_no_patrol() -> void:
	assert_bool(unit.patrol).is_false()

func test_initial_no_pending() -> void:
	assert_that(unit.pending_state).is_equal(-1)

func test_initial_not_assigned() -> void:
	assert_that(unit.assigned_to).is_equal(-1)

func test_request_switch_to_worker() -> void:
	var result: bool = unit.request_switch(PopUnit.State.WORKER, Vector2i(3, 3))
	assert_bool(result).is_true()
	assert_that(unit.pending_state).is_equal(PopUnit.State.WORKER)
	assert_that(unit.pending_tile).is_equal(Vector2i(3, 3))

func test_request_switch_to_militia() -> void:
	var result: bool = unit.request_switch(PopUnit.State.MILITIA)
	assert_bool(result).is_true()
	assert_that(unit.pending_state).is_equal(PopUnit.State.MILITIA)

func test_request_switch_to_follower() -> void:
	unit.state = PopUnit.State.WORKER
	var result: bool = unit.request_switch(PopUnit.State.FOLLOWER)
	assert_bool(result).is_true()
	assert_that(unit.pending_state).is_equal(PopUnit.State.FOLLOWER)

func test_request_switch_worker_requires_tile() -> void:
	var result: bool = unit.request_switch(PopUnit.State.WORKER)
	assert_bool(result).is_false()

func test_request_switch_while_pending() -> void:
	unit.request_switch(PopUnit.State.WORKER, Vector2i(3, 3))
	var result: bool = unit.request_switch(PopUnit.State.MILITIA)
	assert_bool(result).is_false()

func test_request_switch_while_assigned() -> void:
	unit.assigned_to = 5
	var result: bool = unit.request_switch(PopUnit.State.MILITIA)
	assert_bool(result).is_false()

func test_apply_pending_to_worker() -> void:
	unit.request_switch(PopUnit.State.WORKER, Vector2i(3, 3))
	var changed: bool = unit.apply_pending()
	assert_bool(changed).is_true()
	assert_that(unit.state).is_equal(PopUnit.State.WORKER)
	assert_that(unit.tile).is_equal(Vector2i(3, 3))
	assert_that(unit.pending_state).is_equal(-1)

func test_apply_pending_to_follower() -> void:
	unit.state = PopUnit.State.WORKER
	unit.tile = Vector2i(3, 3)
	unit.request_switch(PopUnit.State.FOLLOWER)
	unit.apply_pending()
	assert_that(unit.state).is_equal(PopUnit.State.FOLLOWER)
	assert_that(unit.tile).is_equal(Vector2i(-1, -1))

func test_apply_pending_to_militia() -> void:
	unit.request_switch(PopUnit.State.MILITIA)
	unit.apply_pending()
	assert_that(unit.state).is_equal(PopUnit.State.MILITIA)

func test_apply_pending_no_pending() -> void:
	var changed: bool = unit.apply_pending()
	assert_bool(changed).is_false()

func test_apply_pending_preserves_patrol_for_militia() -> void:
	unit.state = PopUnit.State.MILITIA
	unit.patrol = true
	unit.request_switch(PopUnit.State.MILITIA)
	unit.apply_pending()
	assert_bool(unit.patrol).is_true()

func test_apply_pending_clears_patrol_for_non_militia() -> void:
	unit.state = PopUnit.State.MILITIA
	unit.patrol = true
	unit.request_switch(PopUnit.State.FOLLOWER)
	unit.apply_pending()
	assert_bool(unit.patrol).is_false()

func test_not_available_while_pending() -> void:
	unit.request_switch(PopUnit.State.WORKER, Vector2i(3, 3))
	assert_bool(unit.is_available()).is_false()

func test_not_available_while_assigned() -> void:
	unit.assigned_to = 5
	assert_bool(unit.is_available()).is_false()

func test_not_free_follower_when_worker() -> void:
	unit.state = PopUnit.State.WORKER
	assert_bool(unit.is_free_follower()).is_false()

func test_not_free_follower_when_militia() -> void:
	unit.state = PopUnit.State.MILITIA
	assert_bool(unit.is_free_follower()).is_false()
