extends BaseTest





var manager: Node = null

func before_test() -> void:
	manager = CityManager.new()

func after_test() -> void:
	if manager != null:
		manager.free()
		manager = null

func test_roundtrip_owner_and_display_name() -> void:
	var c := City.new()
	c.display_name = "Заречье"
	c.center = Vector2i(3, 4)
	c.owner = &"player"
	c.level = 2
	c.storage[&"industry"] = 42.0
	var c2 := City.new()
	c2.deserialize(c.serialize())
	assert_that(c2.owner).is_equal(&"player")
	assert_that(c2.display_name).is_equal("Заречье")
	assert_that(c2.center).is_equal(Vector2i(3, 4))
	assert_that(c2.level).is_equal(2)
	assert_float(float(c2.storage.get(&"industry", 0.0))).is_equal_approx(42.0, 0.0001)

func test_roundtrip_owner_none_default() -> void:
	var c := City.new()
	c.display_name = "Песочница"
	var c2 := City.new()
	c2.deserialize(c.serialize())
	assert_that(c2.owner).is_equal(&"none")
	assert_that(c2.display_name).is_equal("Песочница")

func test_roundtrip_garrison_via_pop() -> void:
	var c := City.new()
	c.display_name = "Крепость"
	for i in 3:
		c.add_migrant(PopUnit.State.MILITIA, -1)
	assert_that(c.garrison_count()).is_equal(3)
	var c2 := City.new()
	c2.deserialize(c.serialize())
	assert_that(c2.garrison_count()).is_equal(3)
	assert_that(c2.pop.size()).is_equal(3)

func test_village_name_deterministic() -> void:
	assert_that(CityFactory.village_name(12345, Vector2i(7, 9))).is_equal(CityFactory.village_name(12345, Vector2i(7, 9)))
	assert_str(CityFactory.village_name(12345, Vector2i(7, 9))).is_not_empty()

func test_village_name_differs_by_seed() -> void:
	assert_bool(CityFactory.village_name(1, Vector2i(5, 5))
		!= CityFactory.village_name(2, Vector2i(5, 5))).is_true()

func test_village_name_spread_across_cells() -> void:
	var names: Dictionary = {}
	for i in 200:
		names[CityFactory.village_name(42, Vector2i(i % 10, i / 10))] = true
	assert_int(names.size()).is_greater(1)

func test_provider_applied_to_later_registered_city() -> void:
	manager.set_tile_yield_provider(func(_cell: Vector2i) -> Dictionary:
		return CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS))
	var capital := City.new()
	capital.display_name = "Столица"
	capital.center = Vector2i(10, 10)
	manager.register_city(capital, true)
	var village := City.new()
	village.display_name = "Дальний Посад"
	village.center = Vector2i(20, 20)
	manager.register_city(village)
	assert_that(capital.tile_yield_fn).is_not_null()
	assert_that(village.tile_yield_fn).is_not_null()
	var y: Dictionary = village.tile_yield_fn.call(Vector2i(21, 20))
	assert_float(float(y.get(&"food", 0.0))).is_equal_approx(3.0, 0.0001)

func test_city_at_finds_registered_city() -> void:
	var v := City.new()
	v.display_name = "Кряж"
	v.center = Vector2i(15, 17)
	manager.register_city(v)
	assert_that(manager.city_at(Vector2i(15, 17))).is_equal(v)
	assert_that(manager.city_at(Vector2i(16, 17))).is_null()

func test_restore_order_capital_then_captured_villages() -> void:
	var seed := 777
	var captured := [Vector2i(20, 20), Vector2i(30, 30)]
	var save_names: Dictionary = {}
	var save_centers: Dictionary = {}

	var m1 = auto_free( CityManager.new())
	var capital := City.new()
	capital.display_name = "Столица"
	capital.center = Vector2i(10, 10)
	capital.owner = &"player"
	m1.register_city(capital, true)
	assert_that(capital.uid).is_equal(0)
	for cell in captured:
		var v := CityFactory.create_village(cell, CityFactory.village_name(seed, cell), seed)
		m1.register_city(v)
		save_names[v.uid] = v.display_name
		save_centers[v.uid] = v.center
	assert_that(m1.cities.size()).is_equal(3)
	assert_that(m1.get_city_by_uid(1).center).is_equal(Vector2i(20, 20))
	assert_that(m1.get_city_by_uid(2).center).is_equal(Vector2i(30, 30))
	m1.free()

	var m2 = auto_free( CityManager.new())
	var cap2 := City.new()
	cap2.display_name = "Столица"
	cap2.center = Vector2i(10, 10)
	m2.register_city(cap2, true)
	for cell in captured:
		var v2 := CityFactory.create_village(cell, CityFactory.village_name(seed, cell), seed)
		m2.register_city(v2)
		assert_that(save_names[v2.uid]).is_equal(v2.display_name)
		assert_that(save_centers[v2.uid]).is_equal(v2.center)
	assert_that(m2.cities.size()).is_equal(3)
	m2.free()
