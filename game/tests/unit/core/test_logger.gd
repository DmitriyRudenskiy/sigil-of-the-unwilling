extends BaseTest



func _visible_tag(t: String) -> String:
	var s: String = t.replace("[color=gray]", "").replace("[/color]", "")
	return s.substr(1, s.length() - 2)

func test_tag_pads_to_width() -> void:
	assert_that(_visible_tag(GameLogger._tag("Battle")).length()).is_equal(GameLogger.TAG_WIDTH)
	assert_that(_visible_tag(GameLogger._tag("")).length()).is_equal(GameLogger.TAG_WIDTH)

func test_tag_wraps_in_gray() -> void:
	var t := GameLogger._tag("Hero")
	if Platform.is_headless():
		assert_bool(not t.begins_with("[color=gray]")).is_true()
		assert_that(_visible_tag(t)).is_equal("Hero".rpad(GameLogger.TAG_WIDTH))
		return
	assert_bool(t.begins_with("[color=gray]")).is_true()
	assert_bool(t.ends_with("[/color]")).is_true()
	assert_that(_visible_tag(t)).is_equal("Hero".rpad(GameLogger.TAG_WIDTH))

func test_long_tag_not_truncated() -> void:
	var t := GameLogger._tag("VeryLongTagName123")
	assert_that(_visible_tag(t)).is_equal("VeryLongTagName123")
	assert_int(_visible_tag(t).length()).is_greater(GameLogger.TAG_WIDTH)

func test_public_methods_smoke() -> void:
	GameLogger.info("info smoke", "Test")
	GameLogger.trace("trace smoke", "Test")
	GameLogger.battle("battle smoke")
	GameLogger.world("world smoke")
	GameLogger.inventory("inventory smoke")
	GameLogger.ui("ui smoke")
	GameLogger.hero("hero smoke")
	GameLogger.warn("warn smoke", "Test")
	assert_error(func(): GameLogger.error("error smoke", "Test")).is_push_error(any_string())
