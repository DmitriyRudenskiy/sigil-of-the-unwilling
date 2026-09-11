# TASK_14 §8 (3): HeroLifecycleSystem — воскресение.
# Интеграционный сценарий: смерть героя → выбор воскресения в городе
# → восстаёт тот же герой (не дубль), кандидат наследника освобождён.

extends GdUnitTestSuite

const _HeroLifecycle = preload("res://scripts/world/HeroLifecycleSystem.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const CityManager = preload("res://scripts/world/CityManager.gd")

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


class MockSuccession extends RefCounted:
	var last_created: HeroController = null
	var resurrect_calls := 0
	func default_resurrection_cost() -> Dictionary:
		return {"industry": 500.0, "gold": 100.0}
	func resurrect_hero(city: City, cost: Dictionary = {}) -> bool:
		resurrect_calls += 1
		return true
	func on_hero_died(deceased, rng, city_list, mgr) -> HeroController:
		last_created = HeroController.new()
		return last_created

func _make_system(host: Node2D, mgr: CityManager, succ: MockSuccession) -> RefCounted:
	var sys := _HeroLifecycle.new()
	sys.setup(
		host, null, TestFactories.seeded(7), mgr, null, null, null,
		MockConsumer.new(), MockConsumer.new(), MockBootstrap.new(), succ, null
	)
	return sys

func _hero_children(host: Node2D) -> int:
	var n := 0
	for c in host.get_children():
		if c is _Hero:
			n += 1
	return n

var _host: Node = null
var _mgr: Node = null

func after_test() -> void:
	if _host != null and is_instance_valid(_host):
		_host.free()
	_host = null
	if _mgr != null and is_instance_valid(_mgr):
		_mgr.free()
	_mgr = null

func _free_tree(host: Node, mgr: Node) -> void:
	host.free()  # каскадом: герой, death_seq
	mgr.free()
	_host = null
	_mgr = null

func test_resurrection_revives_same_hero_without_duplicate() -> void:
	var host := MockHost.new()
	_host = host
	add_child(host)
	var city := TestFactories.make_city_with_temple()
	city.owner = &"player"
	city.storage[&"gold"] = 1000.0
	var mgr := CityManager.new()
	_mgr = mgr
	add_child(mgr)
	mgr.cities.append(city)
	var succ := MockSuccession.new()
	var sys := _make_system(host, mgr, succ)

	var hero := TestFactories.make_hero()
	host.add_child(hero)
	host.set_hero(hero)

	sys.on_hero_died(&"battle")
	assert_bool(sys.is_death_sequence_open()).is_true()
	assert_that(host.get_hero()).is_null()

	sys._death_seq.resurrection_chosen.emit()

	assert_that(host.get_hero()).is_equal(hero)
	assert_that(hero.get_parent()).is_equal(host)
	assert_bool(hero.resurrected_once).is_true()
	assert_that(succ.resurrect_calls).is_equal(1)
	# Кандидат-наследник освобождён — нет второго героя в мире
	assert_bool(is_instance_valid(succ.last_created)).is_false()
	assert_that(_hero_children(host)).is_equal(1)
	_free_tree(host, mgr)

func test_second_death_cannot_resurrect() -> void:
	var host := MockHost.new()
	_host = host
	add_child(host)
	var city := TestFactories.make_city_with_temple()
	city.owner = &"player"
	city.storage[&"gold"] = 1000.0
	var mgr := CityManager.new()
	_mgr = mgr
	add_child(mgr)
	mgr.cities.append(city)
	var succ := MockSuccession.new()
	var sys := _make_system(host, mgr, succ)

	var hero := TestFactories.make_hero()
	host.add_child(hero)
	host.set_hero(hero)

	sys.on_hero_died(&"battle")
	sys._death_seq.resurrection_chosen.emit()
	assert_bool(hero.resurrected_once).is_true()

	# Вторая смерть: воскресение недоступно, герой удаляется
	sys.on_hero_died(&"battle")
	assert_that(sys._resurrection_city).is_null()
	assert_that(host.get_hero()).is_null()
	hero.free()  # орфаны: герой-Node2D с дочерними нодами после второй смерти
	# Кандидат наследника: в игре его закрывает меню смерти (принять/рестарт),
	# в тесте меню нет — освобождаем явно, иначе орфаны
	if is_instance_valid(succ.last_created):
		succ.last_created.free()
	_free_tree(host, mgr)
