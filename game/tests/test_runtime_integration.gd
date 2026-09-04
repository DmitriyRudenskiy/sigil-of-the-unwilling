extends "res://tests/gut_base.gd"
## Runtime-интеграционный тест: загружает World.tscn, даёт MAX_SECONDS на
## _ready(), затем проверяет, что ключевые узлы на месте.

const WORLD_SCENE: String = "res://scenes/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const MAX_SECONDS: float = 4.0


func test_world_boots_with_key_nodes() -> void:
	var world_packed: PackedScene = load(WORLD_SCENE)
	assert_not_null(world_packed, "World.tscn загружается")
	if world_packed == null:
		return

	var world: Node = world_packed.instantiate()
	assert_not_null(world, "World инстанцируется")
	# WorldController._handle_headless_exit() не срабатывает под GUT
	# (Platform.is_gut_run() — авто-quit только для smoke-ранов гейта).
	get_tree().root.add_child(world)

	# Даём сцене время на _ready() и инициализацию.
	await get_tree().create_timer(MAX_SECONDS).timeout

	var world_node: Node = get_tree().root.get_node_or_null("World")
	assert_not_null(world_node, "World node in scene tree")
	if world_node == null:
		return

	var wc_script: Script = world_node.get_script()
	assert_not_null(wc_script, "скрипт на корне World")
	if wc_script != null:
		assert_eq(wc_script.resource_path, "res://scripts/world/WorldController.gd",
			"WorldController на корне World")

	var ui: Node = world_node.get_node_or_null("WorldUIManager")
	assert_not_null(ui, "WorldUIManager найден")

	world_node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_main_menu_boots() -> void:
	var packed: PackedScene = load(MAIN_MENU_SCENE)
	assert_not_null(packed, "MainMenu.tscn загружается")
	if packed == null:
		return

	var menu: Node = packed.instantiate()
	assert_not_null(menu, "MainMenu инстанцируется")
	get_tree().root.add_child(menu)
	await get_tree().create_timer(0.5).timeout

	assert_true(menu.is_inside_tree(), "MainMenu в дереве сцены")
	var script: Script = menu.get_script()
	assert_not_null(script, "скрипт на корне MainMenu")
	if script != null:
		assert_eq(script.resource_path, "res://scripts/ui/MainMenu.gd", "MainMenu.gd на корне")
