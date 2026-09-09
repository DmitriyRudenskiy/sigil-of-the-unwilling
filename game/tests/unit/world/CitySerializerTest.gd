extends GdUnitTestSuite

var city: City

func before_test() -> void:
	city = City.new()
	city.uid = 7
	city.center = Vector2i(10, 5)
	city.owner = &"player"
	city.storage[&"industry"] = 100.0

func test_roundtrip_basic_fields() -> void:
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)

	assert_that(c2.center).is_equal(Vector2i(10, 5))
	assert_that(String(c2.owner)).is_equal("player")

func test_roundtrip_storage() -> void:
	city.storage[&"industry"] = 42.5
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_float(c2.storage[&"industry"]).is_equal_approx(42.5, 0.0001)

func test_roundtrip_pop() -> void:
	city.add_followers(3)
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.pop.size()).is_equal(3)

func test_roundtrip_boroughs() -> void:
	var b := Borough.new()
	b.cell = Vector2i(11, 5)
	b.level = 2
	b.uid = 1
	city.boroughs.append(b)
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.boroughs.size()).is_equal(1)
	assert_that(c2.boroughs[0].cell).is_equal(Vector2i(11, 5))
	assert_that(c2.boroughs[0].level).is_equal(2)

func test_roundtrip_buildings() -> void:
	city.storage[&"industry"] = 100.0
	var def := BuildingDefs.market()
	var bld := city.build_building(def, Vector2i(11, 5))
	assert_that(bld).is_not_null()
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.buildings.size()).is_equal(1)
	assert_that(c2.buildings[0].def.id).is_equal(def.id)

func test_json_safe() -> void:

	var s := JSON.stringify(CitySerializer.serialize(city))
	assert_that(s.length() > 0).is_true()
	assert_that(JSON.parse_string(s) is Dictionary).is_true()

func test_empty_deserialize() -> void:

	var c2 := City.new()
	CitySerializer.deserialize(c2, {})
	assert_that(c2.pop.size()).is_zero()
	assert_that(c2.boroughs.size()).is_zero()
	assert_that(c2.buildings.size()).is_zero()

func test_uid_continuity() -> void:

	city.add_followers(2)
	var d := CitySerializer.serialize(city)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	var max_uid := 0
	for u in c2.pop:
		max_uid = maxi(max_uid, u.uid)
	var fresh := c2.add_migrant(PopUnit.State.FOLLOWER, 0)
	assert_that(fresh.uid > max_uid).is_true()

func test_migrate_v1_to_v2() -> void:
	var d: Dictionary = {
		"version": 1,
		"uid": 1,
		"center": {"x": 1, "y": 1},
	}
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.scale_tier).is_equal(0)
	assert_float(c2.auto_resource_mult).is_equal_approx(1.0, 0.0001)
