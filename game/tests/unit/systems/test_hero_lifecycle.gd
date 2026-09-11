extends BaseTest






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

var _host: Node = null

func after_test() -> void:
	if _host != null and is_instance_valid(_host):
		_host.free()
	_host = null

func _make_sys(host: Node2D, bc: MockConsumer, ic: MockConsumer, boot: MockBootstrap) -> RefCounted:
	var sys := HeroLifecycleSystem.new()
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
	_host = host
	add_child(host)
	var bc := MockConsumer.new()
	var ic := MockConsumer.new()
	var boot := MockBootstrap.new()
	var sys := _make_sys(host, bc, ic, boot)

	var hero = auto_free( HeroController.new())
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

func test_find_resurrection_city_null_when_already_resurrected() -> void:
	var sys := HeroLifecycleSystem.new()
	var controller := SuccessionController.new()
	var mgr = auto_free( CityManager.new())
	sys.setup(
		null, null, null, mgr, null, null, null,
		null, null, null, controller, null
	)
	var deceased = auto_free( HeroController.new())
	deceased.resurrected_once = true
	assert_that(sys._find_resurrection_city(deceased)).is_null()
	deceased.free()
	mgr.free()

func test_find_resurrection_city_null_when_no_cities() -> void:
	var sys := HeroLifecycleSystem.new()
	var controller := SuccessionController.new()
	var mgr = auto_free( CityManager.new())
	sys.setup(
		null, null, null, mgr, null, null, null,
		null, null, null, controller, null
	)
	var deceased = auto_free( HeroController.new())
	assert_that(sys._find_resurrection_city(deceased)).is_null()
	deceased.free()
	mgr.free()
