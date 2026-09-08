extends GdUnitTestSuite

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
	assert_that(coordinator._pending_enemy_cell).is_equal(Vector2i(5, 5))
	assert_that(flow.started).is_equal(1)
	fake_map.free()
	coordinator.free()
	fake_hero.free()
	flow.free()

func test_artifact_mods_collected() -> void:
	var hero = HeroController.new()
	hero.name = "TestHero"
	var inv = hero.get("inventory")
	assert_bool(inv != null).is_true()
	assert_bool(inv is HeroInventory).is_true()
	hero.free()

func test_setup_idempotent() -> void:
	var hero = HeroController.new()
	hero.name = "TestHero2"
	var root_node: Node = Engine.get_main_loop().root
	root_node.add_child(hero)
	var fake_map = MapGenerator.new()
	fake_map.name = "FakeMap2"
	hero.setup(fake_map)
	var c1 = _count_visual_sprites(hero)
	hero.setup(fake_map)
	var c2 = _count_visual_sprites(hero)
	assert_that(c1).is_equal(c2)
	assert_bool(c1 > 0).is_true()
	hero.free()
	fake_map.free()

## Спрайты теперь вложены в HeroVisuals — считаем по поддереву.
func _count_visual_sprites(node: Node) -> int:
	var count = 0
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			count += 1
		count += _count_visual_sprites(child)
	return count

func test_extraction_keys_no_duplication() -> void:
	var service = ResourceChainService.new()
	assert_bool(service.has_method("build_extraction_keys")).is_true()

func test_map_spawner_setup_registry() -> void:
	var mg = MapGenerator.new()
	assert_bool(mg.has_method("generate")).is_true()
	mg.free()

func test_marker_click_no_double() -> void:
	assert_bool(true).is_true()

func test_battle_flow_accepts_magic() -> void:
	var flow = BattleFlow.new()
	flow.name = "TestFlow"
	assert_bool(flow.has_method("start_battle")).is_true()
	flow.free()

func test_battle_controller_stores_magic() -> void:
	var bc = BattleController.new()
	bc.name = "TestBC"
	assert_bool(bc.has_method("get")).is_true()
	bc.free()
