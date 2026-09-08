extends GdUnitTestSuite

const _WorldController = preload("res://scripts/world/WorldController.gd")
const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _HeroLifecycle = preload("res://scripts/world/HeroLifecycleSystem.gd")

func _make_follower(uid: int, path: StringName) -> Follower:
	var f := _Follower.new()
	f.uid = uid
	f.path = path
	return f

func _make_city(uid: int, name: StringName) -> City:
	var c := _City.new()
	c.uid = uid
	c.display_name = name
	c.owner = &"archivist"
	return c

func _make_wc(cities: Array[City], controller: _Succession) -> WorldController:
	var wc := _WorldController.new()
	wc._rng = RandomNumberGenerator.new()
	var mgr := _CityManager.new()
	for c in cities:
		mgr.register_city(c)
	wc._cities = mgr
	wc._succession = controller
	var sys := _HeroLifecycle.new()
	sys.setup(wc, null, wc._rng, wc._cities, null, null, null, null, null, null, wc._succession, null)
	wc._hero_lifecycle = sys
	return wc


func test_plan_succession_returns_same_path() -> void:
	var h := TestFactories.make_hero(&"archivist")
	h.followers = [_make_follower(1, &"archivist")]

	var mgr := _CityManager.new()
	mgr.register_city(_make_city(2, &"Highhold"))
	var controller := _Succession.new()

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

	var controller := _Succession.new()
	var wc := _make_wc([_make_city(2, &"Highhold")], controller)

	assert_that(wc._plan_succession(h)).is_null()
	h.free()
	(wc.get("_cities")).free()
	wc.free()


func test_plan_succession_null_when_unwired() -> void:
	var wc := _WorldController.new()
	var h := TestFactories.make_hero(&"archivist")
	assert_that(wc._plan_succession(h)).is_null()
	h.free()
	wc.free()
