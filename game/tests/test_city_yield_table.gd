extends "res://tests/test_base.gd"
## city-in-world: таблица выходов клеток (CityYieldTable).
## Ключи ⊆ FIDSI; вода/неизвестная местность → нули; pin значений grass/mountain.

const _CityYieldTable = preload("res://scripts/world/CityYieldTable.gd")

const FIDSI: Array = [&"food", &"industry", &"dust", &"science", &"influence"]


func test_keys_are_fid_si() -> void:
	# Таблица оперирует только пятью ресурсами (ключи диктируются вызывающим,
	# но сама CityYieldTable их знает — фиксируем набор).
	for k in _CityYieldTable.KEYS:
		assert_true(k in FIDSI, "ключ %s входит в FIDSI" % str(k))
	assert_eq(_CityYieldTable.KEYS.size(), 5, "ровно 5 ресурсов")


func test_water_is_zero() -> void:
	var y := _CityYieldTable.yield_for_terrain(HexUtils.Terrain.WATER)
	for k in _CityYieldTable.KEYS:
		assert_approx(y[k], 0.0, 0.0001, "water %s == 0" % str(k))


func test_unknown_terrain_is_zero() -> void:
	var y := _CityYieldTable.yield_for_terrain(99)
	for k in _CityYieldTable.KEYS:
		assert_approx(y[k], 0.0, 0.0001, "unknown %s == 0" % str(k))


func test_grass_pinned() -> void:
	var y := _CityYieldTable.yield_for_terrain(HexUtils.Terrain.GRASS)
	assert_approx(y[&"food"], 3.0, 0.0001, "grass food 3")
	assert_approx(y[&"industry"], 2.0, 0.0001, "grass industry 2")
	for k in [&"dust", &"science", &"influence"]:
		assert_approx(y[k], 0.0, 0.0001, "grass %s == 0" % str(k))


func test_mountain_pinned() -> void:
	var y := _CityYieldTable.yield_for_terrain(HexUtils.Terrain.MOUNTAIN)
	assert_approx(y[&"industry"], 3.0, 0.0001, "mountain industry 3")
	assert_approx(y[&"dust"], 1.0, 0.0001, "mountain dust 1")
	for k in [&"food", &"science", &"influence"]:
		assert_approx(y[k], 0.0, 0.0001, "mountain %s == 0" % str(k))


func test_all_known_terrains_have_positive_yield() -> void:
	# Любая суша даёт что-то (кроме воды) — город не строится в пустоте.
	for t in [HexUtils.Terrain.SWAMP, HexUtils.Terrain.SAND, HexUtils.Terrain.GRASS,
			HexUtils.Terrain.FOREST, HexUtils.Terrain.MOUNTAIN, HexUtils.Terrain.SNOW]:
		var y := _CityYieldTable.yield_for_terrain(t)
		var total := 0.0
		for k in _CityYieldTable.KEYS:
			total += float(y[k])
		assert_gt(total, 0.0, "terrain %d даёт выход > 0" % t)
