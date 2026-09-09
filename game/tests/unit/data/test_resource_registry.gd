extends GdUnitTestSuite

func test_wood_definition() -> void:
	var def := Resources.get_resource(&"wood")
	assert_that(def).is_not_null()
	assert_that(def.display_name).is_equal("Дерево")
	assert_that(def.yield_min).is_equal(2)
	assert_that(def.yield_max).is_equal(2)
	assert_that(def.weight_per_unit).is_equal(0.0)

func test_stone_definition() -> void:
	var def := Resources.get_resource(&"stone")
	assert_that(def).is_not_null()
	assert_that(def.display_name).is_equal("Камень")
	assert_that(def.yield_min).is_equal(2)
	assert_that(def.yield_max).is_equal(2)
	assert_that(def.weight_per_unit).is_equal(0.0)

func test_all_resources_count() -> void:
	var all := Resources.get_all()
	assert_that(all.size()).is_equal(20)

func test_hidden_resources_count() -> void:
	var ids := Resources.get_hidden_resource_ids()
	assert_that(ids.size()).is_equal(11)

func test_oak_definition() -> void:
	var def := Resources.get_resource(&"oak")
	assert_that(def).is_not_null()
	assert_that(def.yield_min).is_equal(3)
	assert_that(def.yield_max).is_equal(5)
	assert_that(def.weight_per_unit).is_equal(2.0)

func test_saltpeter_definition() -> void:
	var def := Resources.get_resource(&"saltpeter")
	assert_that(def).is_not_null()
	assert_that(def.yield_min).is_equal(2)
	assert_that(def.yield_max).is_equal(3)

func test_biome_filter_sand() -> void:
	var sand := Resources.get_by_biome("sand")
	assert_bool(sand.size() >= 3).is_true()

func test_biome_filter_snow() -> void:
	var snow := Resources.get_by_biome("snow")
	assert_bool(snow.size() >= 3).is_true()

func test_biome_filter_swamp() -> void:
	var swamp := Resources.get_by_biome("swamp")
	assert_bool(swamp.size() >= 3).is_true()

func test_biome_filter_grass() -> void:
	var grass := Resources.get_by_biome("grass")
	assert_bool(grass.size() >= 2).is_true()
