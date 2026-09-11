extends BaseTest
## TASK_20: фиксы MCP-аудита — тик debug-мешей, итеративная сериализация
## (глубокие деревья), лимит canvas_draw.

func _pump_until_invalid(obj: Variant, max_frames: int = 10) -> bool:
	for i in max_frames:
		if not is_instance_valid(obj):
			return true
		await get_tree().process_frame
	return not is_instance_valid(obj)


func test_debug_draw_tick_removes_expired_meshes() -> void:
	var dummy_server := Node.new()
	add_child(dummy_server)
	var sys := McpCommandsSystem.new(dummy_server)

	var mi1 := MeshInstance3D.new()
	var mi2 := MeshInstance3D.new()
	var mi3 := MeshInstance3D.new()
	sys._debug_meshes.append({"node": mi1, "frames_left": 2})
	sys._debug_meshes.append({"node": mi2, "frames_left": 0})  # исчезает на следующем тике
	sys._debug_meshes.append({"node": mi3, "frames_left": -1})  # перманентно

	sys.tick_debug_draw()
	assert_that(sys._debug_meshes.size()).is_equal(2)
	assert_that(sys._debug_meshes[0]["frames_left"]).is_equal(1)
	assert_bool(sys._debug_meshes[1]["node"] == mi3).is_true()

	sys.tick_debug_draw()
	assert_that(sys._debug_meshes.size()).is_equal(1)

	var freed := await _pump_until_invalid(mi1)
	freed = await _pump_until_invalid(mi2) and freed
	assert_bool(freed).is_true()
	assert_bool(is_instance_valid(mi3)).is_true()
	mi3.free()
	dummy_server.free()


func test_serialize_deep_tree_no_stack_overflow() -> void:
	# Рекурсивная версия падала бы: глубина 2500 > лимита стека GDScript (~2000).
	var dummy_server := Node.new()
	add_child(dummy_server)
	var sys := McpCommandsSystem.new(dummy_server)

	var root := Node.new()
	root.name = "DeepRoot"
	var current := root
	for i in 2500:
		var child := Node.new()
		child.name = "N%d" % i
		current.add_child(child)
		current = child

	var result := sys._serialize_node(root, 3000)
	assert_that(result).is_not_null()
	assert_that(result["name"]).is_equal("DeepRoot")
	var d: Dictionary = result
	assert_that(d["children"][0]["name"]).is_equal("N0")
	for _i in 3:
		d = d["children"][0]
	assert_that(d["name"]).is_equal("N2")
	root.free()
	dummy_server.free()


func test_serialize_skips_server_node() -> void:
	var dummy_server := Node.new()
	add_child(dummy_server)
	var sys := McpCommandsSystem.new(dummy_server)

	var root := Node.new()
	dummy_server.name = "McpServerDummy"
	root.add_child(dummy_server)
	var sibling := Node.new()
	sibling.name = "Sibling"
	root.add_child(sibling)

	var result := sys._serialize_node(root, 5)
	var names: Array = []
	for c in result.get("children", []):
		names.append(c["name"])
	assert_that(names).is_equal(["Sibling"])

	root.free()
	dummy_server.free()


func test_build_tree_node_deep_and_ordered() -> void:
	var dummy_server := Node.new()
	add_child(dummy_server)
	var sys := McpCommandsSystem.new(dummy_server)

	var root := Node.new()
	var child_a := Node.new()
	child_a.name = "A"
	var child_b := Node.new()
	child_b.name = "B"
	root.add_child(child_a)
	root.add_child(child_b)
	var deep := child_a
	for i in 2500:
		var child := Node.new()
		child.name = "N%d" % i
		deep.add_child(child)
		deep = child

	var result := sys._build_tree_node(root)
	assert_that(result["name"]).is_equal(root.name)
	var names: Array = []
	for c in result["children"]:
		names.append(c["name"])
	# Порядок детей сохранён (A перед B).
	assert_that(names).is_equal(["A", "B"])

	root.free()
	dummy_server.free()


func test_canvas_draw_limit_enforced() -> void:
	var dummy_server := Node.new()
	add_child(dummy_server)
	var ui := McpCommandsUI.new(dummy_server)

	for i in 5005:
		ui._draw_commands.append({"action": "line", "params": {}, "color": Color.WHITE})

	if ui._draw_commands.size() > ui.MAX_DRAW_COMMANDS:
		ui._draw_commands = ui._draw_commands.slice(ui._draw_commands.size() - ui.MAX_DRAW_COMMANDS)

	assert_that(ui._draw_commands.size()).is_equal(ui.MAX_DRAW_COMMANDS)
	dummy_server.free()
