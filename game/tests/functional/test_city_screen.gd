extends GdUnitTestSuite

const _City = preload("res://scripts/world/City.gd")
const _CityYieldTable = preload("res://scripts/world/CityYieldTable.gd")

var screen: CityScreen = null
var city: RefCounted = null
var hero: Node2D = null

func _main_root() -> Node:
	return Engine.get_main_loop().root

func before_test() -> void:
	screen = load("res://scenes/ui/CityScreen.tscn").instantiate() as CityScreen
	_main_root().add_child(screen)
	city = _City.new()
	city.display_name = "Тестгород"
	city.center = Vector2i(10, 10)
	city.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return _CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	city.storage[&"industry"] = 30.0
	hero = HeroController.new()
	hero.name = "Hero"
	_main_root().add_child(hero)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(42))

func after_test() -> void:
	if screen != null and is_instance_valid(screen):
		screen.free()
		screen = null
	if hero != null and is_instance_valid(hero):
		hero.free()
		hero = null
	city = null

func test_setup_binds_city_and_hero() -> void:
	assert_that(screen.city).is_equal(city)
	assert_that(screen.hero).is_equal(hero)
	assert_bool(screen.is_open()).is_false()
	screen.open()
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.visible).is_true()
	screen.close()
	assert_bool(screen.is_open()).is_false()
	assert_bool(screen.visible).is_false()

func test_close_button_emits_close_requested() -> void:
	var emitted: Array = [false]
	screen.close_requested.connect(func(): emitted[0] = true)
	var btn := screen.get_node("CityScreenBackground/CityScreenCenter/CityScreenPanel/CityScreenBox/CityScreenButtons/Close") as Button
	assert_that(btn).is_not_null()
	btn.emit_signal("pressed")
	assert_bool(emitted[0]).is_true()

func test_build_farm_success() -> void:
	var r: CityCheck = screen.build_pressed(&"farm")
	assert_bool(bool(r.ok)).is_true()
	assert_that(r.payload.get("building")).is_equal("farm")
	assert_that(int(r.payload.get("level", 0))).is_equal(1)
	assert_that(city.buildings.size()).is_equal(1)
	assert_float(float(r.payload.get("industry_left", -1.0))).is_equal_approx(18.0, 0.0001)
	var cell: Dictionary = r.payload.get("cell", {})
	assert_that(HexUtils.hex_distance(Vector2i(int(cell.x), int(cell.y)), city.center)).is_equal(1)

func test_build_mine_cost() -> void:
	var r: CityCheck = screen.build_pressed(&"mine")
	assert_bool(bool(r.ok)).is_true()
	assert_float(float(r.payload.get("industry_left", -1.0))).is_equal_approx(10.0, 0.0001)

func test_build_fails_without_industry() -> void:
	city.storage[&"industry"] = 5.0
	var r: CityCheck = screen.build_pressed(&"farm")
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).contains("Промышленность")).is_true()
	assert_that(city.buildings.size()).is_equal(0)

func test_build_fails_without_free_cell() -> void:
	city.center = Vector2i(0, 0)
	screen.setup(city, hero, Vector2i(0, 0), TestFactories.seeded(42), Vector2i(1, 1))
	var r: CityCheck = screen.build_pressed(&"farm")
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).contains("клетки")).is_true()

func test_build_unknown_def_fails() -> void:
	var r: CityCheck = screen.build_pressed(&"nope")
	assert_bool(bool(r.ok)).is_false()

func test_hire_moves_follower_to_hero() -> void:
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	var r: CityCheck = screen.hire_pressed()
	assert_bool(bool(r.ok)).is_true()
	var f: Dictionary = r.payload.get("follower", {})
	assert_str(f.get("name", "")).is_not_empty()
	assert_bool(String(f.get("race", "")).length() > 0).is_true()
	assert_that(hero.followers.size()).is_equal(1)
	assert_that(city.count_state(PopUnit.State.FOLLOWER)).is_equal(1)

func test_hire_depletes_then_fails() -> void:
	city.add_migrant(PopUnit.State.FOLLOWER, -1)
	var r1: CityCheck = screen.hire_pressed()
	assert_bool(bool(r1.ok)).is_true()
	var r2: CityCheck = screen.hire_pressed()
	assert_bool(bool(r2.ok)).is_false()
	assert_bool(str(r2.reason).contains("последователей")).is_true()
	assert_that(hero.followers.size()).is_equal(1)

func test_level_up_fresh_village_fails() -> void:
	var r: CityCheck = screen.level_up_pressed()
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).length() > 0).is_true()
	assert_that(city.level).is_equal(1)

func test_level_up_when_conditions_met() -> void:
	city.prosperity = 70.0
	city.storage[&"industry"] = 40.0
	for i in 12:
		city.add_migrant(PopUnit.State.WORKER, -1)
	screen.build_pressed(&"farm")
	screen.build_pressed(&"mine")
	assert_that(city.buildings.size()).is_equal(2)
	var r: CityCheck = screen.level_up_pressed()
	assert_bool(bool(r.ok)).is_true()
	assert_that(int(r.payload.get("level", 0))).is_equal(2)
	assert_that(city.level).is_equal(2)

func test_level_up_max_level_fails() -> void:
	city.level = GameNumbers.CITY_LEVEL_MAX
	var r: CityCheck = screen.level_up_pressed()
	assert_bool(bool(r.ok)).is_false()
	assert_bool(str(r.reason).contains("максимальном")).is_true()
