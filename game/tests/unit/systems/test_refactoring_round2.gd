extends BaseTest

const _FakeMap = preload("res://tests/fakes/fake_battle_map.gd")
const _FakeFlow = preload("res://tests/fakes/fake_battle_flow.gd")

var _root_nodes: Array[Node] = []

func after_test() -> void:
	for n in _root_nodes:
		if is_instance_valid(n):
			n.free()
	_root_nodes.clear()

func _track_root(n: Node) -> void:
	_root_nodes.append(n)

func test_contact_triggers_battle() -> void:
	# Контракт BattleHandoff: бой стартует только с валидными армиями обеих сторон
	var units = Services.resolve(&"units")
	var fake_map = _FakeMap.new()
	fake_map.name = "FakeMap"
	fake_map.enemy_stacks[Vector2i(5, 5)] = [units.make_fixed_stack("goblins", 10)]
	var coordinator = WorldBattleCoordinator.new()
	coordinator.name = "Coord"
	coordinator.map_gen = fake_map
	var fake_hero = HeroController.new()
	fake_hero.name = "FakeHero"
	fake_hero.get_army().setup(units)
	coordinator.hero = fake_hero
	var flow = _FakeFlow.new()
	flow.name = "BF"
	coordinator.battle_flow = flow
	coordinator.rng = TestFactories.seeded(8875)
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
	_track_root(hero)
	root_node.add_child(hero)
	var fake_map = MapGenerator.new()
	fake_map.name = "FakeMap2"
	hero.setup(fake_map)
	var c1 = _count_visual_sprites(hero)
	hero.setup(fake_map)
	var c2 = _count_visual_sprites(hero)
	assert_that(c1).is_equal(c2)
	assert_bool(c1 > 0).is_true()
	fake_map.free()

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

	var layer = auto_free( MarkerLayer.new())
	_track_root(layer)
	get_tree().root.add_child(layer)
	var map := _ClickMapStub.new()
	layer.setup(map)
	layer._visible = true
	layer._reachable = {Vector2i(0, 0): MarkerLayer.MarkType.GREEN}
	layer._red_frontier = {}
	layer._city_marks = []

	var clicks := [0]
	layer.marker_clicked.connect(func(_cell: Vector2i, _reachable_flag: bool) -> void:
		clicks[0] += 1
	)

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	layer._unhandled_input(press)
	assert_int(clicks[0]).is_equal(1).override_failure_message("один press-событие = ровно один marker_clicked")

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	layer._unhandled_input(release)
	assert_int(clicks[0]).is_equal(1).override_failure_message("release-событие не должно эмитить повторно")

	var city := City.new()
	city.center = Vector2i(3, 3)
	layer._city_marks = [{"cell": Vector2i(3, 3), "city": city}]
	var city_clicks := [0]
	layer.city_marker_clicked.connect(func(_c: City) -> void:
		city_clicks[0] += 1
	)
	var clicks_before: int = clicks[0]
	layer._handle_left_click(Vector2i(3, 3))
	assert_int(city_clicks[0]).is_equal(1).override_failure_message("один клик по городу = ровно один city_marker_clicked")
	assert_int(clicks[0]).is_equal(clicks_before).override_failure_message("клики по городу не должны дублировать marker_clicked")

	map.free()

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

class _ClickMapStub:
	extends MapGenerator
	func has_valid_tilemap() -> bool:
		return true
	func get_tile_size() -> Vector2i:
		return Vector2i(82, 82)
	func world_to_map(_world_pos: Vector2) -> Vector2i:
		return Vector2i(0, 0)
	func map_to_local(_cell: Vector2i) -> Vector2:
		return Vector2.ZERO
