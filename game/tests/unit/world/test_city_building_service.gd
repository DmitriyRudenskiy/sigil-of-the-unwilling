extends GdUnitTestSuite

var c: City

func before_test() -> void:
	c = City.new()
	c.center = Vector2i(5, 5)
	c.scale_tier = 0
	c.auto_resource_mult = 1.0
	c.upkeep_mult = 1.0
	c.owner = &"player"
	c.add_followers(5)
	c.storage[&"industry"] = 100.0

func test_borough_adjacent_ok() -> void:
	var cell := c.center + Vector2i(1, 0)
	var res := CityBuildingService.build_borough(c, cell)
	assert_that(res.ok).is_true()
	assert_that(c.boroughs.size()).is_equal(1)

func test_borough_consume_industry() -> void:
	var cell := c.center + Vector2i(1, 0)
	var before := float(c.storage.get(&"industry", 0.0))
	var res := CityBuildingService.build_borough(c, cell)
	assert_that(res.ok).is_true()
	assert_that(c.boroughs.size()).is_equal(1)
	assert_that(float(c.storage[&"industry"]) < before).is_true()

func test_borough_limit() -> void:

	var res1 := CityBuildingService.build_borough(c, c.center + Vector2i(1, 0))
	assert_that(res1.ok).is_true()
	var res2 := CityBuildingService.build_borough(c, c.center + Vector2i(0, 1))
	assert_that(res2.ok).is_true()
	var res3 := CityBuildingService.build_borough(c, c.center + Vector2i(1, 1))
	assert_that(res3.ok).is_false()

func test_building_requires_adjacency() -> void:
	var far := c.center + Vector2i(10, 10)
	var res := CityBuildingService.build_building(c, BuildingDefs.market(), far)
	assert_that(res.bld == null).is_true()

func test_building_occupied_cell() -> void:
	var cell := c.center
	var res := CityBuildingService.build_building(c, BuildingDefs.market(), cell)
	assert_that(res.bld == null).is_true()

func test_build_market_success() -> void:
	var cell := c.center + Vector2i(1, 0)
	var res := CityBuildingService.build_building(c, BuildingDefs.market(), cell)
	assert_that(res.bld).is_not_null()
	assert_that(res.bld.level).is_equal(1)
	assert_that(c.buildings.size()).is_equal(1)

func test_upgrade_market() -> void:
	var cell := c.center + Vector2i(1, 0)
	var res := CityBuildingService.build_building(c, BuildingDefs.market(), cell)
	var bld: UniqueBuilding = res.bld
	c.storage[&"industry"] = 1000.0
	c.storage[&"gold"] = 40.0
	var up := CityBuildingService.perform_upgrade(c, bld)
	assert_that(up.ok).is_true()
	assert_that(bld.level).is_equal(2)

func test_upgrade_max_level_fails() -> void:

	c.add_followers(20)
	c.storage[&"industry"] = 2000.0
	c.storage[&"gold"] = 500.0
	var cell := c.center + Vector2i(1, 0)
	var res := CityBuildingService.build_building(c, BuildingDefs.market(), cell)
	var bld: UniqueBuilding = res.bld
	assert_that(CityBuildingService.perform_upgrade(c, bld).ok).is_true()
	assert_that(CityBuildingService.perform_upgrade(c, bld).ok).is_true()
	var up := CityBuildingService.perform_upgrade(c, bld)
	assert_that(up.ok).is_false()
	assert_that(bld.level).is_equal(3)
