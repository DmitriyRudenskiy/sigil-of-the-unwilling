extends BaseTest
## Носитель: scripts/ui/marker_layer.gd — городские метки на карте мира:
## выставление и замена набора, разрешение клетки в город, клик эмитит
## `city_marker_clicked`. Тесты переехали из `functional/test_city_navigation.gd`
## (шаг 7 T-305, 2026-10-30): маршрутизация клика в роутер ушла в
## `integration/test_event_router.gd`, пара городов бутстрапа — в
## `functional/test_world_bootstrap.gd`, переименованная кнопка выхода — в
## `functional/test_city_screen.gd`.

var holder: Node2D = null

func _main_root() -> Node:
	return Engine.get_main_loop().root

func before_test() -> void:
	holder = Node2D.new()
	holder.name = "CityMarkHolder"
	_main_root().add_child(holder)

func after_test() -> void:
	# super — сброс паузы из BaseTest; прежний файл перекрывал after_test без вызова.
	super.after_test()
	if holder != null and is_instance_valid(holder):
		holder.free()
	holder = null

func _make_two_cities() -> Dictionary:
	var mg = auto_free(MapGenerator.new())
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
