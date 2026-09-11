extends GdUnitTestSuite

const _HeroController = preload("res://scripts/entities/HeroController.gd")

var hero: HeroController

func before_test() -> void:
	hero = _root_hero()

func after_test() -> void:
	if hero != null and is_instance_valid(hero):
		hero.free()
	hero = null

func test_capacity_default_zero() -> void:
	assert_that(hero.strategic_resources.get_all().get(&"oak", -1)).is_equal(0)

func test_add_under_capacity() -> void:
	var added := hero.add_strategic_resource(&"oak", 5)
	assert_that(added).is_equal(5)
	assert_that(hero.strategic_resources.get_all()[&"oak"]).is_equal(5)

func test_add_at_capacity() -> void:
	hero.add_strategic_resource(&"oak", GameNumbers.RESOURCE_CAPACITY)
	assert_that(hero.strategic_resources.get_all()[&"oak"]).is_equal(GameNumbers.RESOURCE_CAPACITY)

func test_add_over_capacity_clamped() -> void:
	var added := hero.add_strategic_resource(&"oak", GameNumbers.RESOURCE_CAPACITY + 10)
	assert_that(added).is_equal(GameNumbers.RESOURCE_CAPACITY)
	assert_that(hero.strategic_resources.get_all()[&"oak"]).is_equal(GameNumbers.RESOURCE_CAPACITY)

func test_add_partial_fill() -> void:
	hero.add_strategic_resource(&"oak", 7)
	var added := hero.add_strategic_resource(&"oak", 6)
	assert_that(added).is_equal(3)
	assert_that(hero.strategic_resources.get_all()[&"oak"]).is_equal(GameNumbers.RESOURCE_CAPACITY)

func test_remove_resource() -> void:
	hero.add_strategic_resource(&"oak", 5)
	var removed := hero.remove_strategic_resource(&"oak", 3)
	assert_that(removed).is_equal(3)
	assert_that(hero.strategic_resources.get_all()[&"oak"]).is_equal(2)

func test_remove_over_amount() -> void:
	hero.add_strategic_resource(&"oak", 3)
	var removed := hero.remove_strategic_resource(&"oak", 10)
	assert_that(removed).is_equal(3)
	assert_that(hero.strategic_resources.get_all()[&"oak"]).is_equal(0)

func test_remove_zero() -> void:
	var removed := hero.remove_strategic_resource(&"oak", 5)
	assert_that(removed).is_equal(0)

func test_auto_wood_per_day() -> void:
	hero.end_turn()
	assert_that(hero.strategic_resources.get_all()[&"wood"]).is_equal(GameNumbers.RESOURCE_AUTO_WOOD)

func test_auto_stone_per_day() -> void:
	hero.end_turn()
	assert_that(hero.strategic_resources.get_all()[&"stone"]).is_equal(GameNumbers.RESOURCE_AUTO_STONE)

func test_auto_capped() -> void:
	hero.add_strategic_resource(&"wood", GameNumbers.RESOURCE_CAPACITY - 1)
	hero.end_turn()
	assert_that(hero.strategic_resources.get_all()[&"wood"]).is_equal(GameNumbers.RESOURCE_CAPACITY)

func _root_hero() -> HeroController:
	if hero != null and is_instance_valid(hero):
		hero.queue_free()
	var h := TestFactories.make_hero()
	h.name = "TestHero"
	var root_node: Node = Engine.get_main_loop().root
	root_node.add_child(h)
	h.strategic_resources.init_from_registry()
	return h
