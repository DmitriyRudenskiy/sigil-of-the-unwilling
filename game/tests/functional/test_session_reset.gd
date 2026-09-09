extends GdUnitTestSuite

const City = preload("res://scripts/world/City.gd")
const ArenaClusterSystem = preload("res://scripts/city/ArenaClusterSystem.gd")
const ArenaTurnRunner = preload("res://scripts/city/ArenaTurnRunner.gd")
const ArenaRingSystem = preload("res://scripts/city/ArenaRingSystem.gd")
const BuildingDefs = preload("res://scripts/data/BuildingDefs.gd")
const HexUtils = preload("res://scripts/core/HexUtils.gd")

var city: City

func before_test() -> void:

	ArenaClusterSystem.reset()
	city = ArenaTurnRunner.make_city()

func _place_farm_cluster() -> Array:

	var neighbors: Array = HexUtils.get_all_neighbors(ArenaRingSystem.center())
	var cells: Array = []
	for i in 4:
		var res: CityCheck = ArenaTurnRunner.place_building(
			city, BuildingDefs.farm(), neighbors[i])
		assert_bool(bool(res.ok)).is_true()
		cells.append(neighbors[i])
	return cells

func _place_lone_mine() -> void:
	var farm_cells: Array = []
	for b in city.buildings:
		farm_cells.append(b.cell)
	for c in ArenaRingSystem.cells_in_arena():
		if ArenaRingSystem.ring_of(c) == 2 and c not in farm_cells:
			var res: CityCheck = ArenaTurnRunner.place_building(
				city, BuildingDefs.mine(), c)
			assert_bool(bool(res.ok)).is_true()
			return
	assert_bool(true).is_false()

func test_cluster_from_fresh_city() -> void:
	_place_farm_cluster()
	_place_lone_mine()
	var cl: Array = ArenaClusterSystem.clusters(city)
	assert_int(cl.size()).is_equal(1)
	var cluster: Dictionary = cl[0]
	assert_bool(str(cluster["def_id"]) == "farm").is_true()
	assert_int((cluster["buildings"] as Array).size()).is_equal(4)

func test_second_call_uses_cache() -> void:
	_place_farm_cluster()
	_place_lone_mine()
	var cl1: Array = ArenaClusterSystem.clusters(city)
	var cl2: Array = ArenaClusterSystem.clusters(city)
	assert_int(cl1.size()).is_equal(1)
	assert_int(cl2.size()).is_equal(1)
	assert_bool((cl2[0] as Dictionary).get("cells") == (cl1[0] as Dictionary).get("cells")).is_true()

func test_reset_clears_cache_and_recomputes() -> void:
	_place_farm_cluster()
	_place_lone_mine()
	ArenaClusterSystem.reset()
	var cl: Array = ArenaClusterSystem.clusters(city)
	assert_int(cl.size()).is_equal(1)
	assert_int((cl[0] as Dictionary)["buildings"].size()).is_equal(4)

func test_new_city_after_reset_no_contamination() -> void:
	_place_farm_cluster()
	_place_lone_mine()
	ArenaClusterSystem.reset()
	var city2 := ArenaTurnRunner.make_city()
	assert_int(ArenaClusterSystem.clusters(city2).size()).is_equal(0)

	var cl: Array = ArenaClusterSystem.clusters(city)
	assert_int(cl.size()).is_equal(1)
