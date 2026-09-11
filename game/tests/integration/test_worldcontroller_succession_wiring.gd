extends BaseTest







func _make_follower(uid: int, path: StringName) -> Follower:
	var f := Follower.new()
	f.uid = uid
	f.path = path
	return f

func _make_city(uid: int, name: StringName) -> City:
	var c := City.new()
	c.uid = uid
	c.display_name = name
	c.owner = &"archivist"
	return c

func _make_wc(cities: Array[City], controller: SuccessionController) -> WorldController:
	var wc = auto_free( WorldController.new())
	wc._rng = TestFactories.seeded(7827)
	var mgr = auto_free( CityManager.new())
	for city in cities:
		mgr.register_city(city)
	wc._cities = mgr
	wc._succession = controller
	var sys := HeroLifecycleSystem.new()
	sys.setup(wc, null, wc._rng, wc._cities, null, null, null, null, null, null, wc._succession, null)
	wc._hero_lifecycle = sys
	return wc

func test_plan_succession_returns_same_path() -> void:
	var h := TestFactories.make_hero(&"archivist")
	h.followers = [_make_follower(1, &"archivist")]

	var mgr = auto_free( CityManager.new())
	mgr.register_city(_make_city(2, &"Highhold"))
	var controller := SuccessionController.new()

	var wc := _make_wc([_make_city(2, &"Highhold")], controller)

	var succ := wc._plan_succession(h)
	assert_that(succ).is_not_null()
	assert_that(succ.path_id).is_equal(&"archivist")
	assert_that(mgr.cities.size()).is_equal(1)
	h.free(); succ.free()
	mgr.free()
	(wc.get("_cities")).free()
	wc.free()

func test_plan_succession_null_when_no_follower() -> void:
	var h := TestFactories.make_hero(&"archivist")
	h.followers = [_make_follower(5, &"warrior")]

	var controller := SuccessionController.new()
	var wc := _make_wc([_make_city(2, &"Highhold")], controller)

	assert_that(wc._plan_succession(h)).is_null()
	h.free()
	(wc.get("_cities")).free()
	wc.free()

func test_plan_succession_null_when_unwired() -> void:
	var wc = auto_free( WorldController.new())
	var h := TestFactories.make_hero(&"archivist")
	assert_that(wc._plan_succession(h)).is_null()
	h.free()
	wc.free()
