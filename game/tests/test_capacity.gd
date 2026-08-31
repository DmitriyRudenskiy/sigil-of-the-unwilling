extends "res://tests/test_base.gd"
## Resource capacity and basic resource tests.

const _HeroController = preload("res://scripts/entities/HeroController.gd")


var hero: HeroController


func before_each() -> void:
	hero = _make_hero()


func test_capacity_default_zero() -> void:
	assert_eq(hero.strategic_resources.get_all().get(&"oak", -1), 0, "default 0")


func test_add_under_capacity() -> void:
	var added := hero.add_strategic_resource(&"oak", 5)
	assert_eq(added, 5, "added 5")
	assert_eq(hero.strategic_resources.get_all()[&"oak"], 5, "is 5")


func test_add_at_capacity() -> void:
	hero.add_strategic_resource(&"oak", GameSettings.RESOURCE_CAPACITY)
	assert_eq(hero.strategic_resources.get_all()[&"oak"], GameSettings.RESOURCE_CAPACITY, "at cap")


func test_add_over_capacity_clamped() -> void:
	var added := hero.add_strategic_resource(&"oak", GameSettings.RESOURCE_CAPACITY + 10)
	assert_eq(added, GameSettings.RESOURCE_CAPACITY, "clamped to cap")
	assert_eq(hero.strategic_resources.get_all()[&"oak"], GameSettings.RESOURCE_CAPACITY, "at cap")


func test_add_partial_fill() -> void:
	hero.add_strategic_resource(&"oak", 7)
	var added := hero.add_strategic_resource(&"oak", 6)
	assert_eq(added, 3, "partial fill")
	assert_eq(hero.strategic_resources.get_all()[&"oak"], GameSettings.RESOURCE_CAPACITY, "at cap")


func test_remove_resource() -> void:
	hero.add_strategic_resource(&"oak", 5)
	var removed := hero.remove_strategic_resource(&"oak", 3)
	assert_eq(removed, 3, "removed 3")
	assert_eq(hero.strategic_resources.get_all()[&"oak"], 2, "is 2")


func test_remove_over_amount() -> void:
	hero.add_strategic_resource(&"oak", 3)
	var removed := hero.remove_strategic_resource(&"oak", 10)
	assert_eq(removed, 3, "removed 3 only")
	assert_eq(hero.strategic_resources.get_all()[&"oak"], 0, "is 0")


func test_remove_zero() -> void:
	var removed := hero.remove_strategic_resource(&"oak", 5)
	assert_eq(removed, 0, "nothing to remove")


func test_auto_wood_per_day() -> void:
	hero.end_turn()
	assert_eq(hero.strategic_resources.get_all()[&"wood"], GameSettings.RESOURCE_AUTO_WOOD_PER_DAY, "auto wood")


func test_auto_stone_per_day() -> void:
	hero.end_turn()
	assert_eq(hero.strategic_resources.get_all()[&"stone"], GameSettings.RESOURCE_AUTO_STONE_PER_DAY, "auto stone")


func test_auto_capped() -> void:
	hero.add_strategic_resource(&"wood", GameSettings.RESOURCE_CAPACITY - 1)
	hero.end_turn()
	assert_eq(hero.strategic_resources.get_all()[&"wood"], GameSettings.RESOURCE_CAPACITY, "capped auto")


func _make_hero() -> HeroController:
	# Предыдущий герой из теста освобождается (добавлен в дерево для _ready())
	if hero != null and is_instance_valid(hero):
		hero.queue_free()
	var h := _HeroController.new()
	h.name = "TestHero"
	# _ready() создаёт resources/movement/army — нужен живой узел в дереве
	var root_node: Node = Engine.get_main_loop().root
	root_node.add_child(h)
	# Инициализация стратегических ресурсов из реестра (все id = 0)
	h.strategic_resources.init_from_registry()
	return h
