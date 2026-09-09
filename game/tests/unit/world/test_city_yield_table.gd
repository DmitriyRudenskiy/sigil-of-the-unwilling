extends GdUnitTestSuite

const _CityYieldTable = preload("res://scripts/world/CityYieldTable.gd")

const FIDSI: Array = [&"food", &"industry", &"dust", &"science", &"influence"]

func test_keys_are_fid_si() -> void:
	for k in _CityYieldTable.KEYS:
		assert_bool(k in FIDSI).is_true()
	assert_that(_CityYieldTable.KEYS.size()).is_equal(5)

func test_water_is_zero() -> void:
	var y := _CityYieldTable.yield_for_terrain(HexUtils.Terrain.WATER)
	for k in _CityYieldTable.KEYS:
		assert_float(y[k]).is_equal_approx(0.0, 0.0001)

func test_unknown_terrain_is_zero() -> void:
	var y := _CityYieldTable.yield_for_terrain(99)
	for k in _CityYieldTable.KEYS:
		assert_float(y[k]).is_equal_approx(0.0, 0.0001)

func test_grass_pinned() -> void:
	var y := _CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	assert_float(y[&"food"]).is_equal_approx(3.0, 0.0001)
	assert_float(y[&"industry"]).is_equal_approx(2.0, 0.0001)
	for k in [&"dust", &"science", &"influence"]:
		assert_float(y[k]).is_equal_approx(0.0, 0.0001)

func test_mountain_pinned() -> void:
	var y := _CityYieldTable.yield_for_terrain(HexUtils.Terrain.MOUNTAIN)
	assert_float(y[&"industry"]).is_equal_approx(3.0, 0.0001)
	assert_float(y[&"dust"]).is_equal_approx(1.0, 0.0001)
	for k in [&"food", &"science", &"influence"]:
		assert_float(y[k]).is_equal_approx(0.0, 0.0001)

func test_all_known_terrains_have_positive_yield() -> void:
	for t in [HexUtils.Terrain.SWAMP, HexUtils.Terrain.SAND, HexUtils.Terrain.GRASS,
			HexUtils.Terrain.FOREST, HexUtils.Terrain.MOUNTAIN, HexUtils.Terrain.SNOW]:
		var y := _CityYieldTable.yield_for_terrain(t)
		var total := 0.0
		for k in _CityYieldTable.KEYS:
			total += float(y[k])
		assert_float(total).is_greater(0.0)
