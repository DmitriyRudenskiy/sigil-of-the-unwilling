extends "res://tests/gut_base.gd"
## succession-sigil: WorldController wiring — hero_died → SuccessionController.
## Проверяем _plan_succession (выбор преемника из мира) без полного
## перепричинения (оно лезет в дерево сцены / battle_coordinator).

const _WorldController = preload("res://scripts/world/WorldController.gd")
const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _HeroLifecycle = preload("res://scripts/world/HeroLifecycleSystem.gd")

func _make_follower(uid: int, path: StringName) -> Follower:
	var f := _Follower.new()
	f.uid = uid
	f.path = path
	return f

func _make_hero(path := &"archivist") -> HeroController:
	var h := _Hero.new()
	h.path_id = path
	return h

func _make_city(uid: int, name: StringName) -> City:
	var c := _City.new()
	c.uid = uid
	c.display_name = name
	c.owner = &"archivist"
	return c

## Собрать WorldController с подставленными _rng / _cities / _succession.
func _make_wc(cities: Array[City], controller: _Succession) -> WorldController:
	var wc := _WorldController.new()
	wc._rng = RandomNumberGenerator.new()
	var mgr := _CityManager.new()
	for c in cities:
		mgr.register_city(c)
	wc._cities = mgr
	wc._succession = controller
	# succession-sigil: делегация _plan_succession → HeroLifecycleSystem.
	var sys := _HeroLifecycle.new()
	sys.setup(wc, null, wc._rng, wc._cities, null, null, null, null, null, null, wc._succession, null)
	wc._hero_lifecycle = sys
	return wc


func test_plan_succession_returns_same_path() -> void:
	var h := _make_hero(&"archivist")
	h.followers = [_make_follower(1, &"archivist")]

	var mgr := _CityManager.new()
	mgr.register_city(_make_city(2, &"Highhold"))
	var controller := _Succession.new()

	var wc := _make_wc([_make_city(2, &"Highhold")], controller)

	var succ := wc._plan_succession(h)
	assert_not_null(succ, "successor chosen from world cities")
	assert_eq(succ.path_id, &"archivist", "successor shares the deceased path")
	assert_eq(mgr.cities.size(), 1, "world cities untouched by selection")
	h.free(); succ.free()
	(wc.get("_cities")).free()
	wc.free()


func test_plan_succession_null_when_no_follower() -> void:
	var h := _make_hero(&"archivist")
	h.followers = [_make_follower(5, &"warrior")]  # другой путь

	var controller := _Succession.new()
	var wc := _make_wc([_make_city(2, &"Highhold")], controller)

	assert_null(wc._plan_succession(h), "no same-path follower → null (run ends)")
	h.free()
	(wc.get("_cities")).free()
	wc.free()


func test_plan_succession_null_when_unwired() -> void:
	## Без подставленных зависимостей — не падает, возвращает null.
	var wc := _WorldController.new()
	var h := _make_hero(&"archivist")
	assert_null(wc._plan_succession(h),
		"no _succession/_cities wired → null")
	h.free()
	wc.free()
