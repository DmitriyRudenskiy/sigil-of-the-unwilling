extends GdUnitTestSuite

const _HeroLifecycle = preload("res://scripts/world/HeroLifecycleSystem.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")

class MockHost extends Node2D:
	var _hero: Node = null
	func get_hero() -> Node:
		return _hero
	func set_hero(h: Node) -> void:
		_hero = h

class MockConsumer extends RefCounted:
	var hero: Node = null
	var _hero: Node = null

class MockBootstrap extends RefCounted:
	var enemy_proc = null
	var input_controller = null
	var shortcuts = null
	func _init() -> void:
		enemy_proc = MockConsumer.new()
		input_controller = MockConsumer.new()
		shortcuts = MockConsumer.new()

func _make_sys(host: Node2D, bc: MockConsumer, ic: MockConsumer, boot: MockBootstrap) -> RefCounted:
	var sys := _HeroLifecycle.new()
	sys.setup(
		host,
		null,
		null,
		null,
		null,
		null,
		null,
		bc,
		ic,
		boot,
		null,
		null
	)
	return sys

func test_install_hero_rewires_all_consumers() -> void:
	var host := MockHost.new()
	add_child(host)
	var bc := MockConsumer.new()
	var ic := MockConsumer.new()
	var boot := MockBootstrap.new()
	var sys := _make_sys(host, bc, ic, boot)

	var hero := _Hero.new()
	hero.path_id = &"archivist"
	sys._install_hero(hero)

	assert_that(host.get_hero()).is_equal(hero)
	assert_that(hero.get_parent()).is_equal(host)
	assert_that(bc.hero).is_equal(hero)
	assert_that(ic.hero).is_equal(hero)
	assert_that(boot.enemy_proc._hero).is_equal(hero)
	assert_that(boot.input_controller.hero).is_equal(hero)
	assert_that(boot.shortcuts._hero).is_equal(hero)

	hero.free()
	host.free()

func test_find_resurrection_city_null_when_already_resurrected() -> void:
	var sys := _HeroLifecycle.new()
	var controller := _Succession.new()
	var mgr := _CityManager.new()
	sys.setup(
		null, null, null, mgr, null, null, null,
		null, null, null, controller, null
	)
	var deceased := _Hero.new()
	deceased.resurrected_once = true
	assert_that(sys._find_resurrection_city(deceased)).is_null()
	deceased.free()
	mgr.free()

func test_find_resurrection_city_null_when_no_cities() -> void:
	var sys := _HeroLifecycle.new()
	var controller := _Succession.new()
	var mgr := _CityManager.new()
	sys.setup(
		null, null, null, mgr, null, null, null,
		null, null, null, controller, null
	)
	var deceased := _Hero.new()
	assert_that(sys._find_resurrection_city(deceased)).is_null()
	deceased.free()
	mgr.free()
