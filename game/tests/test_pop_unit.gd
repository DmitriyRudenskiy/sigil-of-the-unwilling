extends "res://tests/gut_base.gd"
## Тесты PopUnit: состояния, переключение, доступность.

const _PopUnit = preload("res://scripts/world/PopUnit.gd")

var unit: RefCounted

func before_each() -> void:
	unit = _PopUnit.new()
	unit.uid = 1
	unit.state = _PopUnit.State.FOLLOWER

# ==================== НАЧАЛЬНОЕ СОСТОЯНИЕ ====================

func test_initial_state_follower() -> void:
	assert_eq(unit.state, _PopUnit.State.FOLLOWER, "initially follower")

func test_initial_available() -> void:
	assert_true(unit.is_available(), "available initially")

func test_initial_free_follower() -> void:
	assert_true(unit.is_free_follower(), "free follower initially")

func test_initial_no_patrol() -> void:
	assert_false(unit.patrol, "no patrol initially")

func test_initial_no_pending() -> void:
	assert_eq(unit.pending_state, -1, "no pending initially")

func test_initial_not_assigned() -> void:
	assert_eq(unit.assigned_to, -1, "not assigned initially")

# ==================== ПЕРЕКЛЮЧЕНИЕ ====================

func test_request_switch_to_worker() -> void:
	var result: bool = unit.request_switch(_PopUnit.State.WORKER, Vector2i(3, 3))
	assert_true(result, "switch requested")
	assert_eq(unit.pending_state, _PopUnit.State.WORKER, "pending is worker")
	assert_eq(unit.pending_tile, Vector2i(3, 3), "pending tile set")

func test_request_switch_to_militia() -> void:
	var result: bool = unit.request_switch(_PopUnit.State.MILITIA)
	assert_true(result, "switch to militia")
	assert_eq(unit.pending_state, _PopUnit.State.MILITIA, "pending is militia")

func test_request_switch_to_follower() -> void:
	unit.state = _PopUnit.State.WORKER
	var result: bool = unit.request_switch(_PopUnit.State.FOLLOWER)
	assert_true(result, "switch to follower")
	assert_eq(unit.pending_state, _PopUnit.State.FOLLOWER, "pending is follower")

func test_request_switch_worker_requires_tile() -> void:
	var result: bool = unit.request_switch(_PopUnit.State.WORKER)
	assert_false(result, "worker requires tile")

func test_request_switch_while_pending() -> void:
	unit.request_switch(_PopUnit.State.WORKER, Vector2i(3, 3))
	var result: bool = unit.request_switch(_PopUnit.State.MILITIA)
	assert_false(result, "cannot switch while pending")

func test_request_switch_while_assigned() -> void:
	unit.assigned_to = 5
	var result: bool = unit.request_switch(_PopUnit.State.MILITIA)
	assert_false(result, "cannot switch while assigned")

# ==================== ПРИМЕНЕНИЕ ====================

func test_apply_pending_to_worker() -> void:
	unit.request_switch(_PopUnit.State.WORKER, Vector2i(3, 3))
	var changed: bool = unit.apply_pending()
	assert_true(changed, "state changed")
	assert_eq(unit.state, _PopUnit.State.WORKER, "now worker")
	assert_eq(unit.tile, Vector2i(3, 3), "tile set")
	assert_eq(unit.pending_state, -1, "pending cleared")

func test_apply_pending_to_follower() -> void:
	unit.state = _PopUnit.State.WORKER
	unit.tile = Vector2i(3, 3)
	unit.request_switch(_PopUnit.State.FOLLOWER)
	unit.apply_pending()
	assert_eq(unit.state, _PopUnit.State.FOLLOWER, "now follower")
	assert_eq(unit.tile, Vector2i(-1, -1), "tile cleared")

func test_apply_pending_to_militia() -> void:
	unit.request_switch(_PopUnit.State.MILITIA)
	unit.apply_pending()
	assert_eq(unit.state, _PopUnit.State.MILITIA, "now militia")

func test_apply_pending_no_pending() -> void:
	var changed: bool = unit.apply_pending()
	assert_false(changed, "no change without pending")

func test_apply_pending_preserves_patrol_for_militia() -> void:
	unit.state = _PopUnit.State.MILITIA
	unit.patrol = true
	unit.request_switch(_PopUnit.State.MILITIA)
	unit.apply_pending()
	assert_true(unit.patrol, "patrol preserved")

func test_apply_pending_clears_patrol_for_non_militia() -> void:
	unit.state = _PopUnit.State.MILITIA
	unit.patrol = true
	unit.request_switch(_PopUnit.State.FOLLOWER)
	unit.apply_pending()
	assert_false(unit.patrol, "patrol cleared for follower")

# ==================== ДОСТУПНОСТЬ ====================

func test_not_available_while_pending() -> void:
	unit.request_switch(_PopUnit.State.WORKER, Vector2i(3, 3))
	assert_false(unit.is_available(), "not available while pending")

func test_not_available_while_assigned() -> void:
	unit.assigned_to = 5
	assert_false(unit.is_available(), "not available while assigned")

func test_not_free_follower_when_worker() -> void:
	unit.state = _PopUnit.State.WORKER
	assert_false(unit.is_free_follower(), "worker is not free follower")

func test_not_free_follower_when_militia() -> void:
	unit.state = _PopUnit.State.MILITIA
	assert_false(unit.is_free_follower(), "militia is not free follower")
