extends BaseTest

class _HeroStub extends Node:
	signal hero_moved(cell: Vector2i)
	signal hero_entered_village(cell: Vector2i)
	signal movement_finished(cell: Vector2i)
	var movement = null
	var current_cell: Vector2i = Vector2i.ZERO
	var clicked: Vector2i = Vector2i(-1, -1)

	func on_map_clicked(cell: Vector2i) -> void:
		clicked = cell

class _MapStub extends Node:
	var map_width := 12
	var map_height := 12
	var hex_shift_right := true

	func is_walkable(_cell: Vector2i) -> bool:
		return true

	func apply_fog(_v) -> void:
		pass

var _router: WorldEventRouter
var _hero: _HeroStub
var _map: _MapStub
var _cities: CityManager

func before_test() -> void:
	_router = WorldEventRouter.new()
	add_child(_router)
	_hero = _HeroStub.new()
	_map = _MapStub.new()
	_cities = CityManager.new()
	_router.setup(_hero, _map, null, _cities, null, null, null, null, null, null, null)

func test_hero_moved_emits_router_signal() -> void:
	var got: Array = []
	_router.hero_moved_to.connect(func(c: Vector2i) -> void: got.append(c))
	_hero.hero_moved.emit(Vector2i(3, 3))
	assert_that(got.size()).is_equal(1)
	assert_that(got[0]).is_equal(Vector2i(3, 3))

func test_hero_moved_updates_visibility() -> void:

	var v := VisibilityMap.new()
	_router.visibility = v
	_hero.current_cell = Vector2i(5, 5)
	_hero.hero_moved.emit(Vector2i(5, 5))
	assert_bool(v.is_visible(Vector2i(5, 5))).is_true()

func test_city_marker_clicked_selects_target() -> void:
	var c := City.new()
	c.center = Vector2i(4, 4)
	_cities.cities.append(c)
	_router._on_city_marker_clicked(c)
	assert_that(_hero.clicked).is_equal(Vector2i(4, 4))

func after_test() -> void:
	_router.queue_free()
	_hero.free()
	_map.free()
	if is_instance_valid(_cities):
		_cities.free()
	_cities = null
