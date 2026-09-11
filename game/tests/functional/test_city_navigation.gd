extends BaseTest







var holder: Node2D = null

func _main_root() -> Node:
	return Engine.get_main_loop().root

func before_test() -> void:
	holder = Node2D.new()
	holder.name = "NavTestHolder"
	_main_root().add_child(holder)

func after_test() -> void:
	if holder != null and is_instance_valid(holder):
		holder.free()
	holder = null

func _make_two_cities() -> Dictionary:
	var mg = auto_free( MapGenerator.new())
	mg.name = "MapGenerator"
	mg.seed_value = 42
	holder.add_child(mg)
	assert_bool(mg.has_valid_tilemap()).is_true()
	var R = WorldBootstrap.BootstrapResult.new()
	R.map_gen = mg
	WorldBootstrap._create_cities(holder, R)
	var capital: City = R.cities.capital
	var second: City = null
	for city in R.cities.cities:
		if city != capital:
			second = city
	return {"mg": mg, "cities": R.cities, "capital": capital, "second": second}

func test_bootstrap_creates_two_cities() -> void:
	var w: Dictionary = _make_two_cities()
	var cities = w.cities
	assert_that(cities.cities.size()).is_equal(2)
	var capital: City = w.capital
	assert_that(capital).is_not_null()
	assert_bool(capital.is_capital).is_true()
	assert_that(capital.display_name).is_equal("Перворечье")
	var capitals := 0
	for city in cities.cities:
		if city.is_capital:
			capitals += 1
	assert_that(capitals).is_equal(1)
	var second: City = w.second
	assert_that(second).is_not_null()
	assert_bool(second.is_capital).is_false()
	assert_that(second.display_name).is_equal("Город 2")
	assert_that(second.owner).is_equal(&"player")
	var d := HexUtils.hex_distance(capital.center, second.center)
	assert_int(d).is_greater(8)
	assert_int(d).is_less(25)
	assert_bool(w.mg.is_walkable(second.center)).is_true()
	assert_bool(w.mg.is_walkable(capital.center)).is_true()

func test_city_markers_shown_and_resolved() -> void:
	var w: Dictionary = _make_two_cities()
	var mg = w.mg
	var ml = auto_free( MarkerLayer.new())
	ml.name = "MarkerLayer"
	holder.add_child(ml)
	ml.setup(mg)
	ml.set_city_markers(w.cities.cities)
	assert_that(ml._city_marks.size()).is_equal(2)
	assert_that(ml.city_at_cell(w.second.center)).is_equal(w.second)
	assert_that(ml.city_at_cell(w.capital.center)).is_equal(w.capital)
	assert_that(ml.city_at_cell(Vector2i(0, 0))).is_null()

func test_city_marker_click_emits_city_and_consumes_input() -> void:
	var w: Dictionary = _make_two_cities()
	var ml = auto_free( MarkerLayer.new())
	ml.name = "MarkerLayer"
	holder.add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers(w.cities.cities)
	var clicked: Array = [null]
	ml.city_marker_clicked.connect(func(c: City) -> void: clicked[0] = c)
	ml._handle_left_click(w.second.center)
	assert_that(clicked[0]).is_equal(w.second)

func test_set_city_markers_empty_and_replaces() -> void:
	var w: Dictionary = _make_two_cities()
	var ml = auto_free( MarkerLayer.new())
	ml.name = "MarkerLayer"
	holder.add_child(ml)
	ml.setup(w.mg)
	ml.set_city_markers([])
	assert_that(ml._city_marks.size()).is_equal(0)
	ml.set_city_markers(w.cities.cities)
	assert_that(ml._city_marks.size()).is_equal(2)
	ml.set_city_markers([w.capital])
	assert_that(ml._city_marks.size()).is_equal(1)
	assert_that(ml.city_at_cell(w.second.center)).is_equal(null)

func test_exit_button_renamed_and_closes() -> void:
	var city := City.new()
	city.display_name = "Перворечье"
	city.center = Vector2i(10, 10)
	city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	var hero = HeroController.new()
	hero.name = "Hero"
	holder.add_child(hero)
	var screen = load("res://scenes/ui/CityScreen.tscn").instantiate() as CityScreen
	holder.add_child(screen)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(42))
	var btn := screen.get_node("CityScreenBackground/CityScreenCenter/CityScreenPanel/CityScreenBox/CityScreenButtons/Close") as Button
	assert_that(btn).is_not_null()
	assert_bool(btn.text.contains("Выход из города")).is_true()
	var closed: Array = [false]
	screen.close_requested.connect(func() -> void: closed[0] = true)
	btn.emit_signal("pressed")
	assert_bool(closed[0]).is_true()
	if is_instance_valid(screen):
		screen.free()
	if is_instance_valid(hero):
		hero.free()

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

func _make_router(mg: MapGenerator, cities: CityManager, hero: NavMockHero) -> WorldEventRouter:
	var r = auto_free( WorldEventRouter.new())
	r.name = "EventRouter"
	_main_root().add_child(r)
	r.setup(hero, mg, null, cities, null, null, null, null, null, null, null, null)
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
