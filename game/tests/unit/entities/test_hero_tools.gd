extends BaseTest


func test_starts_with_empty_slots() -> void:
	var t := HeroTools.new()
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS)
	assert_bool(t.has_tool(ToolType.ID.SHOVEL)).is_false()

func test_add_and_has_tool() -> void:
	var t := HeroTools.new()
	assert_bool(t.add_tool(ToolType.ID.SHOVEL)).is_true()
	assert_bool(t.has_tool(ToolType.ID.SHOVEL)).is_true()
	assert_int(t.get_tool_count(ToolType.ID.SHOVEL)).is_equal(1)
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS - 1)

func test_add_stackable_merges_into_one_slot() -> void:
	var t := HeroTools.new()
	assert_bool(t.add_tool(ToolType.ID.NET, 2)).is_true()
	assert_bool(t.add_tool(ToolType.ID.NET, 3)).is_true()
	assert_int(t.get_tool_count(ToolType.ID.NET)).is_equal(5)
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS - 1)

func test_add_normal_tool_takes_second_slot() -> void:
	var t := HeroTools.new()
	t.add_tool(ToolType.ID.SHOVEL)
	t.add_tool(ToolType.ID.SHOVEL)
	assert_int(t.get_tool_count(ToolType.ID.SHOVEL)).is_equal(2)
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS - 2)

func test_add_rejects_bad_quantity() -> void:
	var t := HeroTools.new()
	assert_bool(t.add_tool(ToolType.ID.SHOVEL, 0)).is_false()
	assert_bool(t.add_tool(ToolType.ID.SHOVEL, -1)).is_false()
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS)

func test_add_full_returns_false() -> void:
	var t := HeroTools.new()
	for i in HeroTools.MAX_SLOTS:
		assert_bool(t.add_tool(ToolType.ID.CART)).is_true()
	assert_bool(t.add_tool(ToolType.ID.SHOVEL)).is_false()

func test_remove_tool_partial_and_full() -> void:
	var t := HeroTools.new()
	t.add_tool(ToolType.ID.PICKAXE, 4)
	assert_bool(t.remove_tool(ToolType.ID.PICKAXE, 2)).is_true()
	assert_int(t.get_tool_count(ToolType.ID.PICKAXE)).is_equal(2)
	assert_bool(t.remove_tool(ToolType.ID.PICKAXE, 2)).is_true()
	assert_int(t.get_tool_count(ToolType.ID.PICKAXE)).is_equal(0)

func test_remove_across_multiple_slots() -> void:
	var t := HeroTools.new()
	t.add_tool(ToolType.ID.CART, 2)
	t.add_tool(ToolType.ID.CART, 3)
	assert_bool(t.remove_tool(ToolType.ID.CART, 4)).is_true()
	assert_int(t.get_tool_count(ToolType.ID.CART)).is_equal(1)

func test_remove_insufficient_returns_false() -> void:
	var t := HeroTools.new()
	t.add_tool(ToolType.ID.SHOVEL)
	assert_bool(t.remove_tool(ToolType.ID.SHOVEL, 2)).is_false()
	assert_bool(t.remove_tool(ToolType.ID.PICKAXE, 1)).is_false()

func test_clear_emits_and_empties() -> void:
	var t := HeroTools.new()
	var holder := {"n": 0}
	t.tools_changed.connect(func(): holder["n"] += 1)
	t.add_tool(ToolType.ID.SHOVEL)
	t.clear()
	assert_int(holder["n"]).is_equal(2)
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS)

func test_serialize_deserialize_roundtrip() -> void:
	var t := HeroTools.new()
	t.add_tool(ToolType.ID.SHOVEL, 2)
	t.add_tool(ToolType.ID.NET)
	var data: Array = t.serialize()
	assert_int(data.size()).is_equal(HeroTools.MAX_SLOTS)

	var t2 := HeroTools.new()
	t2.deserialize(data)
	assert_int(t2.get_tool_count(ToolType.ID.SHOVEL)).is_equal(2)
	assert_bool(t2.has_tool(ToolType.ID.NET)).is_true()

func test_deserialize_short_array_pads_empty() -> void:
	var t := HeroTools.new()
	t.deserialize([{"id": "shovel", "quantity": 1}])
	assert_int(t.get_empty_slots()).is_equal(HeroTools.MAX_SLOTS - 1)
	assert_bool(t.has_tool(ToolType.ID.SHOVEL)).is_true()

func test_deserialize_unknown_tool_name() -> void:
	var t := HeroTools.new()
	t.deserialize([{"id": "not_a_tool", "quantity": 1}])
	assert_bool(t.has_tool(ToolType.ID.SHOVEL)).is_false()
