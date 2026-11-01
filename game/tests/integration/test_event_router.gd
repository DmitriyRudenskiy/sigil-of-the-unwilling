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

func test_campaign_mode_is_passed_to_scheduler_from_city_manager() -> void:
	var city := City.new()
	city.center = Vector2i(5, 5)
	city.ensure_resource_ctx()
	city.food_stockpile = 10.0
	city.resource_ctx.clear_ledger()
	var resident := PopUnit.new()
	resident.state = PopUnit.State.WORKER
	city.pop.append(resident)
	_cities.cities.append(city)
	_cities.is_campaign = true
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(EconomicTurnProcessor.new())
	_router.turn_scheduler = scheduler

	_router._run_turn_scheduler(1)

	assert_float(city.food_stockpile).is_equal_approx(9.9, 0.0001)
	assert_that(String(city.resource_ctx.get_ledger()[0].source)).is_equal("campaign:resident_food")

class NavMockMovement extends Node:
	signal reach_preview_changed(path: Array)
	signal reach_preview_cleared()

class NavMockHero extends Node:
	signal hero_moved(cell: Vector2i)
	signal hero_entered_village(cell: Vector2i)
	var current_cell := Vector2i(-1, -1)
	var clicked: Array = []
	var movement: NavMockMovement
	func _init_moved() -> void:
		movement = NavMockMovement.new()
		movement.name = "MockMovement"
		add_child(movement)
	func on_map_clicked(cell: Vector2i) -> void:
		clicked.append(cell)

# Прежний дом — functional/test_city_navigation.gd (шаг 7 T-305, 2026-10-30):
# здесь предмет — выбор цели в WorldEventRouter, поэтому карта настоящая.
func _make_two_cities() -> Dictionary:
	var h := Node2D.new()
	h.name = "RouterCitiesHolder"
	_main_root().add_child(h)
	auto_free(h)
	var mg: MapGenerator = MapGenerator.new()
	mg.name = "MapGenerator"
	mg.seed_value = 42
	h.add_child(mg)
	assert_bool(mg.has_valid_tilemap()).is_true()
	var R = WorldBootstrap.BootstrapResult.new()
	R.map_gen = mg
	WorldBootstrap._create_cities(h, R)
	var capital: City = R.cities.capital
	var second: City = null
	for city in R.cities.cities:
		if city != capital:
			second = city
	return {"mg": mg, "cities": R.cities, "capital": capital, "second": second, "holder": h}

func _main_root() -> Node:
	return Engine.get_main_loop().root

func _make_router(mg: MapGenerator, cities: CityManager, hero: NavMockHero) -> WorldEventRouter:
	var r = auto_free(WorldEventRouter.new())
	r.name = "EventRouter"
	_main_root().add_child(r)
	r.setup(hero, mg, null, cities, null, null, null, null, null, null, null)
	return r

func test_city_marker_click_routes_path_to_city() -> void:
	var w := _make_two_cities()
	var hero := NavMockHero.new()
	hero.current_cell = Vector2i(0, 0)
	hero._init_moved()
	var router := _make_router(w.mg, w.cities, hero)
	var ml = auto_free( MarkerLayer.new())
	ml.name = "MarkerLayer"
	_main_root().add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers(w.cities.cities)
	ml.city_marker_clicked.connect(router._on_city_marker_clicked)
	ml.city_marker_clicked.emit(w.second)
	assert_that(hero.clicked.size()).is_equal(1)
	var target: Vector2i = hero.clicked[0]
	assert_bool(w.mg.is_walkable(target)).is_true()
	assert_bool(target != hero.current_cell).is_true()
	router.free()
	ml.free()
	hero.free()

func test_city_marker_click_to_unwalkable_center_uses_nearby() -> void:
	var w := _make_two_cities()
	var capital: City = w.capital
	w.mg.model.set_terrain(capital.center, HexUtils.Terrain.MOUNTAIN)
	var hero := NavMockHero.new()
	hero.current_cell = Vector2i(0, 0)
	hero._init_moved()
	var router := _make_router(w.mg, w.cities, hero)
	var ml = auto_free( MarkerLayer.new())
	ml.name = "MarkerLayer"
	_main_root().add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers(w.cities.cities)
	ml.city_marker_clicked.connect(router._on_city_marker_clicked)
	ml.city_marker_clicked.emit(capital)
	assert_that(hero.clicked.size()).is_equal(1)
	assert_bool(w.mg.is_walkable(hero.clicked[0])).is_true()
	router.free()
	ml.free()
	hero.free()


func after_test() -> void:
	_router.queue_free()
	_hero.free()
	_map.free()
	if is_instance_valid(_cities):
		_cities.free()
	_cities = null
