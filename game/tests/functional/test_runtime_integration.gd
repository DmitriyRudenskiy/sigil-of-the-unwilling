extends GdUnitTestSuite

const WORLD_SCENE: String = "res://scenes/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const MAX_SECONDS: float = 4.0

var _nodes: Array[Node] = []

func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

func test_world_boots_with_key_nodes() -> void:
	var world_packed: PackedScene = load(WORLD_SCENE)
	assert_that(world_packed).is_not_null()
	if world_packed == null:
		return

	var world: Node = world_packed.instantiate()
	assert_that(world).is_not_null()
	_nodes.append(world)
	get_tree().root.add_child(world)

	await get_tree().create_timer(MAX_SECONDS).timeout

	var world_node: Node = get_tree().root.get_node_or_null("World")
	assert_that(world_node).is_not_null()
	if world_node == null:
		return

	var wc_script: Script = world_node.get_script()
	assert_that(wc_script).is_not_null()
	if wc_script != null:
		assert_that(wc_script.resource_path).is_equal("res://scripts/world/WorldController.gd")

	var ui: Node = world_node.get_node_or_null("WorldUI")
	assert_that(ui).is_not_null()

	world_node.free()
	await get_tree().process_frame
	await get_tree().process_frame

func test_main_menu_boots() -> void:
	var packed: PackedScene = load(MAIN_MENU_SCENE)
	assert_that(packed).is_not_null()
	if packed == null:
		return

	var menu: Node = packed.instantiate()
	assert_that(menu).is_not_null()
	_nodes.append(menu)
	get_tree().root.add_child(menu)
	await get_tree().create_timer(0.5).timeout

	assert_bool(menu.is_inside_tree()).is_true()
	var script: Script = menu.get_script()
	assert_that(script).is_not_null()
	if script != null:
		assert_that(script.resource_path).is_equal("res://scripts/ui/MainMenu.gd")
