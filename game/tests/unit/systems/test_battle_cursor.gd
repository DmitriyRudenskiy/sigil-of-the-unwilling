extends BaseTest



func test_cursor_modes_enum() -> void:
	assert_int(BattleView.CursorMode.ATTACK).is_equal(1).override_failure_message("CursorMode.ATTACK should be 1")
	assert_int(BattleView.CursorMode.SPELL).is_equal(2).override_failure_message("CursorMode.SPELL should be 2")
	assert_int(BattleView.CursorMode.RANGED).is_equal(3).override_failure_message("CursorMode.RANGED should be 3")

func test_cursor_overlay_mode() -> void:
	var c := BattleView.CursorOverlay.new()
	c.set_mode(BattleView.CursorMode.ATTACK)
	assert_int(c.mode).is_equal(BattleView.CursorMode.ATTACK).override_failure_message("cursor overlay mode should be ATTACK after set_cursor_mode")

	c.set_mode(BattleView.CursorMode.SPELL)
	assert_int(c.mode).is_equal(BattleView.CursorMode.SPELL).override_failure_message("cursor overlay mode should be SPELL after set_cursor_mode")

	c.set_mode(BattleView.CursorMode.RANGED)
	assert_int(c.mode).is_equal(BattleView.CursorMode.RANGED).override_failure_message("cursor overlay mode should be RANGED after set_cursor_mode")

	c.set_mode(BattleView.CursorMode.DEFAULT)
	assert_int(c.mode).is_equal(BattleView.CursorMode.DEFAULT).override_failure_message("cursor overlay mode should be DEFAULT after set_cursor_mode")

	c.queue_free()

func test_cursor_overlay_visibility() -> void:
	var c := BattleView.CursorOverlay.new()
	c.visible_flag = true
	assert_bool(c.visible_flag).is_true().override_failure_message("cursor should be visible when visible_flag = true")

	c.visible_flag = false
	assert_bool(c.visible_flag).is_false().override_failure_message("cursor should be hidden when visible_flag = false")

	c.queue_free()

func test_view_cursor_methods() -> void:
	var view = auto_free( BattleView.new())
	view.set_cursor_mode(BattleView.CursorMode.ATTACK)
	view.set_cursor_visible(true)

	view._cursor = BattleView.CursorOverlay.new()
	view.set_cursor_mode(BattleView.CursorMode.SPELL)
	assert_int(view._cursor.mode).is_equal(BattleView.CursorMode.SPELL).override_failure_message("view.set_cursor_mode should propagate to overlay")

	view.set_cursor_visible(true)
	assert_bool(view._cursor.visible_flag).is_true().override_failure_message("view.set_cursor_visible should set overlay visible_flag")

	view.clear_cursor()
	assert_int(view._cursor.mode).is_equal(BattleView.CursorMode.DEFAULT).override_failure_message("view.clear_cursor should reset mode to DEFAULT")

	view._cursor.queue_free()
	view.queue_free()

func test_input_setter_propagates() -> void:
	var input = auto_free( BattleInput.new())
	assert_int(input._cursor_mode).is_equal(BattleView.CursorMode.DEFAULT).override_failure_message("input cursor mode should default to DEFAULT")

	input.set_cursor_mode(BattleView.CursorMode.ATTACK)
	assert_int(input._cursor_mode).is_equal(BattleView.CursorMode.ATTACK).override_failure_message("input cursor mode should be ATTACK after set_cursor_mode")

	input.set_cursor_mode(BattleView.CursorMode.SPELL)
	assert_int(input._cursor_mode).is_equal(BattleView.CursorMode.SPELL).override_failure_message("input cursor mode should be SPELL after set_cursor_mode")

	input.set_cursor_mode(BattleView.CursorMode.RANGED)
	assert_int(input._cursor_mode).is_equal(BattleView.CursorMode.RANGED).override_failure_message("input cursor mode should be RANGED after set_cursor_mode")

	input.queue_free()

func test_walk_cursor_mode() -> void:
	assert_int(BattleView.CursorMode.MOVE).is_equal(4).override_failure_message("CursorMode.MOVE should be 4 (added after RANGED=3)")
	assert_bool(BattleView.CursorMode.DEFAULT == 0 and BattleView.CursorMode.ATTACK == 1).is_true().override_failure_message("existing cursor mode values must not change")

	var c := BattleView.CursorOverlay.new()
	c.set_mode(BattleView.CursorMode.MOVE)
	assert_int(c.mode).is_equal(BattleView.CursorMode.MOVE).override_failure_message("cursor overlay should be MOVE after set_mode(MOVE)")
	c.queue_free()

func test_walk_cursor_distinct_from_ranged() -> void:
	assert_int(BattleView.CursorMode.MOVE).is_not_equal(BattleView.CursorMode.RANGED).override_failure_message("MOVE cursor mode must be distinct from RANGED")
	assert_int(BattleView.CursorMode.MOVE).is_not_equal(BattleView.CursorMode.DEFAULT).override_failure_message("MOVE cursor mode must be distinct from DEFAULT")
