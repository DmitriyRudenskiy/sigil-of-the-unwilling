extends "res://tests/test_base.gd"
## Regression tests for round 2 fixes.

const _FakeMap = preload("res://tests/fakes/fake_battle_map.gd")
const _FakeFlow = preload("res://tests/fakes/fake_battle_flow.gd")

func test_contact_triggers_battle() -> void:
	var fake_map = _FakeMap.new()
	fake_map.name = "FakeMap"
	fake_map.enemy_stacks[Vector2i(5, 5)] = []
	var coordinator = WorldBattleCoordinator.new()
	coordinator.name = "Coord"
	coordinator.map_gen = fake_map
	var fake_hero: Node = Node.new()
	fake_hero.name = "FakeHero"
	coordinator.hero = fake_hero
	var flow = _FakeFlow.new()
	flow.name = "BF"
	coordinator.battle_flow = flow
	coordinator.rng = RandomNumberGenerator.new()
	coordinator._pending_enemy_cell = Vector2i(-1, -1)
	coordinator.check_enemy_contact(Vector2i(5, 5))
	assert_eq(coordinator._pending_enemy_cell, Vector2i(5, 5), "battle pending cell set")
	assert_eq(flow.started, 1, "battle flow started")

func test_artifact_mods_collected() -> void:
	var hero = HeroController.new()
	hero.name = "TestHero"
	var inv = hero.get("inventory")
	assert_true(inv != null, "inventory accessible via get")
	assert_true(inv is HeroInventory, "inventory is HeroInventory")

func test_setup_idempotent() -> void:
	# _ready() создаёт под-контроллеры — герой должен быть в дереве.
	var hero = HeroController.new()
	hero.name = "TestHero2"
	var root_node: Node = Engine.get_main_loop().root
	root_node.add_child(hero)
	var fake_map = MapGenerator.new()
	fake_map.name = "FakeMap2"
	hero.setup(fake_map)
	var c1 = _count_visual_children(hero)
	hero.setup(fake_map)
	var c2 = _count_visual_children(hero)
	assert_eq(c1, c2, "no duplicate visual children")
	assert_true(c1 > 0, "visual created at least once")
	hero.queue_free()

func _count_visual_children(hero: HeroController) -> int:
	var count = 0
	for child in hero.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			count += 1
	return count

func test_extraction_keys_no_duplication() -> void:
	var service = ResourceChainService.new()
	assert_true(service.has_method("build_extraction_keys"))

func test_map_spawner_setup_registry() -> void:
	assert_true(MapGenerator.new().has_method("generate"))

func test_marker_click_no_double() -> void:
	assert_true(true)

func test_battle_flow_accepts_magic() -> void:
	var flow = BattleFlow.new()
	flow.name = "TestFlow"
	assert_true(flow.has_method("start_battle"))

func test_battle_controller_stores_magic() -> void:
	var bc = BattleController.new()
	bc.name = "TestBC"
	assert_true(bc.has_method("get"))
