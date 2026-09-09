extends GdUnitTestSuite
const _BuildingDefs = preload("res://scripts/data/BuildingDefs.gd")
const _PopUnit = preload("res://scripts/world/PopUnit.gd")

var city: City

func before_test() -> void:
	city = ArenaTurnRunner.make_city()

func _free_cell(ring: int) -> Vector2i:
	for cell in ArenaRingSystem.cells_in_ring(ring):
		if not city.cell_is_built(cell):
			return cell
	return Vector2i(-1, -1)

func test_arena_cells_unique() -> void:
	var cells: Array = ArenaRingSystem.cells_in_arena()
	var seen: Dictionary = {}
	for cell in cells:
		seen[cell] = true
	assert_that(seen.size()).is_equal(cells.size())
	assert_that(cells.size()).is_equal(91)

func test_center_ring_zero() -> void:
	assert_that(ArenaRingSystem.ring_of(ArenaRingSystem.ARENA_CENTER)).is_equal(0)
	assert_that(city.center).is_equal(ArenaRingSystem.ARENA_CENTER)
	assert_bool(city.center.y % 2 == 0).is_true()

func test_all_cells_within_radius() -> void:
	var ok := true
	for cell in ArenaRingSystem.cells_in_arena():
		if ArenaRingSystem.ring_of(cell) > GameNumbers.ARENA_RADIUS:
			ok = false
	assert_bool(ok).is_true()

func test_ring_colors_distinct() -> void:
	var seen: Array = []
	for r in range(0, GameNumbers.ARENA_RADIUS + 1):
		seen.append(ArenaRingSystem.ring_color(r))
	var ok := true
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			if seen[i] == seen[j]:
				ok = false
	assert_bool(ok).is_true()

func test_start_city() -> void:
	assert_that(city.pop_total()).is_equal(8)
	assert_that(city.count_state(_PopUnit.State.WORKER)).is_equal(4)
	assert_that(city.count_state(_PopUnit.State.FOLLOWER)).is_equal(4)
	assert_bool(city.food_stockpile >= 20.0).is_true()

func test_place_farm() -> void:
	var cell: Vector2i = _free_cell(1)
	assert_bool(cell != Vector2i(-1, -1)).is_true()
	var industry_before: float = float(city.storage.get(&"industry", 0.0))
	var res: CityCheck = ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"farm"), cell)
	assert_bool(bool(res.ok)).is_true()
	assert_bool(city.cell_is_built(cell)).is_true()
	var industry_after: float = float(city.storage.get(&"industry", 0.0))
	assert_bool(industry_after < industry_before).is_true()
	var b: UniqueBuilding = city.get_building_at(cell)
	assert_bool(b.zone_multiplier >= 1.0).is_true()
	assert_bool(is_equal_approx(b.zone_multiplier,
			1.0 + GameNumbers.ring_bonus(&"farm", 1))).is_true()

func test_place_outside_arena() -> void:
	var res: CityCheck = ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"farm"), Vector2i(60, 60))
	assert_bool(bool(res.ok)).is_false()

func test_seating_unique_tiles() -> void:
	var seated: int = ArenaTurnRunner.seat_workers(city)
	assert_bool(seated >= 3).is_true()
	var tiles: Dictionary = {}
	var ok := true
	for u in city.pop:
		if u.state == _PopUnit.State.WORKER and u.tile.x >= 0:
			if tiles.has(u.tile):
				ok = false
			tiles[u.tile] = true
	assert_bool(ok).is_true()

func test_seating_avoids_buildings() -> void:
	var farm: Vector2i = _free_cell(1)
	ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"farm"), farm)
	for u in city.pop:
		if u.state == _PopUnit.State.WORKER and u.tile == farm:
			u.tile = Vector2i(-1, -1)
	ArenaTurnRunner.seat_workers(city)
	var ok := true
	for u in city.pop:
		if u.state == _PopUnit.State.WORKER and u.tile == farm:
			ok = false
	assert_bool(ok).is_true()

func test_hire_worker() -> void:
	var farm: Vector2i = _free_cell(1)
	ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"farm"), farm)
	var hired: int = ArenaTurnRunner.hire_worker(city)
	assert_that(hired).is_equal(1)
	assert_that(city.pop_total()).is_equal(9)

func test_ring_yield_bounds() -> void:
	assert_bool(GameNumbers.ring_yield(0).is_empty()).is_true()
	assert_bool(GameNumbers.ring_yield(GameNumbers.ARENA_RADIUS + 1).is_empty()).is_true()
	var y: Dictionary = GameNumbers.ring_yield(1)
	assert_bool(y.has(&"food") and y.has(&"industry")).is_true()
	assert_bool(float(y[&"food"]) > 0.0).is_true()

func test_ring_bonus() -> void:
	assert_that(GameNumbers.ring_bonus(&"nonexistent", 1)).is_equal(0.0)
	for ring in range(1, GameNumbers.ARENA_RADIUS + 1):
		for bid in [&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
				&"trade_post", &"school", &"market", &"shack", &"walls"]:
			var v: float = GameNumbers.ring_bonus(bid, ring)
			assert_bool(v >= 0.0 and v <= 0.6).is_true()
	var any_positive := false
	for ring in range(1, GameNumbers.ARENA_RADIUS + 1):
		for bid in [&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
				&"trade_post", &"school", &"market", &"shack", &"walls"]:
			if GameNumbers.ring_bonus(bid, ring) > 0.0:
				any_positive = true
	assert_bool(any_positive).is_true()

func test_demo_plan_deterministic() -> void:
	var a: Dictionary = ArenaDemoScenario.run_demo_plan(12)
	var b: Dictionary = ArenaDemoScenario.run_demo_plan(12)
	assert_that(float(a["score"])).is_equal(float(b["score"]))
	assert_that(int(a["starve_days"])).is_equal(int(b["starve_days"]))

const _CLUSTER_CELLS: Array = [
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 2),
]

func _place_farm(cell: Vector2i) -> void:
	var res: CityCheck = ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"farm"), cell)
	assert_bool(bool(res.ok)).is_true()

func test_cluster_forms_on_four_connected() -> void:
	for i in 3:
		_place_farm((_CLUSTER_CELLS[i] as Vector2i))
	assert_that(ArenaClusterSystem.clusters(city).size()).is_equal(0)
	_place_farm((_CLUSTER_CELLS[3] as Vector2i))
	var cls: Array = ArenaClusterSystem.clusters(city)
	assert_that(cls.size()).is_equal(1)
	assert_that(((cls[0] as Dictionary)["cells"] as Array).size()).is_equal(4)

func test_disconnected_groups_not_cluster() -> void:
	for cell in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(2, 4), Vector2i(2, 5)]:
		_place_farm(cell as Vector2i)
	assert_that(ArenaClusterSystem.clusters(city).size()).is_equal(0)

func test_cluster_different_types_not_merged() -> void:
	for cell in [Vector2i(4, 1), Vector2i(5, 1)]:
		_place_farm(cell as Vector2i)
	for cell in [Vector2i(6, 1), Vector2i(7, 2)]:
		var res: CityCheck = ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"mill"), cell as Vector2i)
		assert_bool(bool(res.ok)).is_true()
	assert_that(ArenaClusterSystem.clusters(city).size()).is_equal(0)

func test_cluster_multiplier_applied() -> void:
	for cell in _CLUSTER_CELLS:
		_place_farm(cell as Vector2i)
	ArenaRingSystem.apply_ring_multipliers(city)
	for cell in _CLUSTER_CELLS:
		var b: UniqueBuilding = city.get_building_at(cell as Vector2i)
		assert_bool(b != null and b.zone_multiplier >= 1.49).is_true()

func test_cluster_housing_bonus() -> void:
	for cell in _CLUSTER_CELLS:
		_place_farm(cell as Vector2i)
	assert_that(ArenaClusterSystem.cluster_worker_housing(city)).is_equal(city.free_housing(_PopUnit.State.WORKER) + GameNumbers.ARENA_CLUSTER_HOUSING)
	var city2 := ArenaTurnRunner.make_city()
	assert_that(ArenaClusterSystem.cluster_worker_housing(city2)).is_equal(city2.free_housing(_PopUnit.State.WORKER))

func test_cell_features_deterministic() -> void:
	var city2 := ArenaTurnRunner.make_city()
	var count := 0
	for cell in ArenaRingSystem.cells_in_arena():
		var f1: StringName = ArenaRingSystem.cell_feature(city, cell as Vector2i)
		var f2: StringName = ArenaRingSystem.cell_feature(city2, cell as Vector2i)
		assert_that(f1).is_equal(f2)
		if f1 != &"":
			count += 1
		assert_bool(f1 == &"" or f1 == &"quarry" or f1 == &"spring"
				 or f1 == &"river" or f1 == &"ruins").is_true()
	assert_bool(count >= 5).is_true()

func test_cell_features_rings_only() -> void:
	for cell in ArenaRingSystem.cells_in_ring(0):
		assert_that(ArenaRingSystem.cell_feature(city, cell as Vector2i)).is_equal(&"")
	for cell in ArenaRingSystem.cells_in_ring(1):
		assert_that(ArenaRingSystem.cell_feature(city, cell as Vector2i)).is_equal(&"")
	for cell in ArenaRingSystem.cells_in_ring(5):
		assert_that(ArenaRingSystem.cell_feature(city, cell as Vector2i)).is_equal(&"")

func test_feature_mults() -> void:
	var quarry := Vector2i(2, 4)
	var spring := Vector2i(2, 5)
	var river := Vector2i(2, 2)
	assert_that(ArenaRingSystem.cell_feature(city, quarry)).is_equal(&"quarry")
	assert_that(ArenaRingSystem.cell_feature(city, spring)).is_equal(&"spring")
	assert_that(ArenaRingSystem.cell_feature(city, river)).is_equal(&"river")
	assert_that(ArenaRingSystem.feature_mult(city, &"mine", quarry)).is_equal(GameNumbers.ARENA_FEATURE_QUARRY)
	assert_that(ArenaRingSystem.feature_mult(city, &"farm", quarry)).is_equal(1.0)
	assert_that(ArenaRingSystem.feature_mult(city, &"farm", spring)).is_equal(GameNumbers.ARENA_FEATURE_SPRING)
	assert_that(ArenaRingSystem.feature_mult(city, &"mine", spring)).is_equal(1.0)
	assert_that(ArenaRingSystem.feature_mult(city, &"tavern", river)).is_equal(GameNumbers.ARENA_FEATURE_RIVER)

func test_ruins_gold_bonus() -> void:
	var cell := Vector2i(2, 3)
	assert_that(ArenaRingSystem.cell_feature(city, cell)).is_equal(&"ruins")
	var gold_before: float = float(city.storage.get(&"gold", 0.0))
	var res: CityCheck = ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"shack"), cell)
	assert_bool(bool(res.ok)).is_true()
	assert_that(float(res.payload.get("ruins_gold", 0.0))).is_equal(GameNumbers.ARENA_FEATURE_RUINS_GOLD)
	var gold_after: float = float(city.storage.get(&"gold", 0.0))
	assert_that(gold_after).is_equal(gold_before + GameNumbers.ARENA_FEATURE_RUINS_GOLD)

func test_storm_periodicity() -> void:
	assert_bool(ArenaStorm.is_storm_turn(6)).is_true()
	assert_bool(ArenaStorm.is_storm_turn(12)).is_true()
	assert_bool(ArenaStorm.is_storm_turn(5)).is_false()
	assert_bool(ArenaStorm.is_storm_turn(1)).is_false()
	assert_bool(ArenaStorm.is_storm_turn(0)).is_false()

func test_storm_food_and_production() -> void:
	var cell := Vector2i(-1, -1)
	for cand in ArenaRingSystem.cells_in_ring(3):
		if ArenaRingSystem.cell_feature(city, cand) == &"":
			cell = cand
			break
	assert_bool(cell != Vector2i(-1, -1)).is_true()
	_place_farm(cell)
	var rep: Dictionary = ArenaTurnRunner.run_turn(city, 6)
	assert_bool(bool(rep.get("storm", false))).is_true()
	assert_that(float(rep.get("storm_food", 0.0))).is_equal(GameNumbers.ARENA_STORM_FOOD)
	var b: UniqueBuilding = city.get_building_at(cell)
	assert_bool(b != null and absf(b.zone_multiplier - GameNumbers.ARENA_STORM_PROD_MULT) < 0.001).is_true()

func test_storm_mitigated_by_walls() -> void:
	var cell: Vector2i = _free_cell(1)
	var res: CityCheck = ArenaTurnRunner.place_building(city, _BuildingDefs.def_by_id(&"walls"), cell)
	assert_bool(bool(res.ok)).is_true()
	var b: UniqueBuilding = city.get_building_at(cell)
	assert_bool(b != null).is_true()
	b.level = 2
	assert_that(ArenaStorm.storm_production_mult(city, 6)).is_equal(GameNumbers.ARENA_STORM_MITIG_MULT)
	assert_that(ArenaStorm.storm_food_penalty(city, 6)).is_equal(GameNumbers.ARENA_STORM_MITIG_FOOD)

func test_storm_absent_turn() -> void:
	var rep: Dictionary = ArenaTurnRunner.run_turn(city, 5)
	assert_bool(bool(rep.get("storm", false))).is_false()
	assert_that(float(rep.get("storm_food", 0.0))).is_equal(0.0)

func test_demo_plan_forms_farm_cluster() -> void:
	var r: Dictionary = ArenaDemoScenario.run_demo_plan(48)
	var cls: Array = ArenaClusterSystem.clusters(r["city"])
	assert_bool(cls.size() >= 1).is_true()
	var last: Dictionary = r["last"]
	assert_bool(last.has("storm") and last.has("clusters")).is_true()

func test_balance_yield_table_shape() -> void:
	assert_that(GameNumbers.RING_YIELD.size()).is_equal(6)
	for r in range(6):
		var row: Array = GameNumbers.RING_YIELD[r]
		assert_that(row.size()).is_equal(5)
		for i in range(5):
			assert_bool(float(row[i]) >= 0.0).is_true()

func test_balance_yield_within_bounds() -> void:
	var bounds: Array = [[0.0, 8.0], [0.0, 6.0], [0.0, 2.0], [0.0, 2.0], [0.0, 2.0]]
	for r in range(1, 6):
		var row: Array = GameNumbers.RING_YIELD[r]
		for i in range(5):
			assert_bool(float(row[i]) <= float(bounds[i][1])).is_true()

func test_balance_bonus_within_bounds() -> void:
	var buildings: Array[StringName] = [
		&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
		&"trade_post", &"school", &"market", &"shack", &"walls",
	]
	for bid in buildings:
		assert_bool(GameNumbers.RING_BONUS.has(bid)).is_true()
		var row: Dictionary = GameNumbers.RING_BONUS[bid]
		for ring in range(1, 6):
			var v: float = float(row.get(ring, 0.0))
			assert_bool(v >= 0.0 and v <= 0.6).is_true()

func test_balance_mechanics_constants_present() -> void:
	assert_that(GameNumbers.ARENA_CLUSTER_MIN).is_equal(4)
	assert_float(GameNumbers.ARENA_CLUSTER_MULT).is_greater(1.0)
	assert_int(GameNumbers.ARENA_CLUSTER_HOUSING).is_greater(0)
	assert_int(GameNumbers.ARENA_STORM_PERIOD).is_greater(0)
	assert_bool(GameNumbers.ARENA_STORM_PROD_MULT < 1.0).is_true()
	assert_bool(GameNumbers.ARENA_STORM_MITIG_MULT > GameNumbers.ARENA_STORM_PROD_MULT).is_true()
	assert_float(GameNumbers.ARENA_STORM_FOOD).is_greater(0.0)
	assert_bool(GameNumbers.ARENA_STORM_MITIG_FOOD <= GameNumbers.ARENA_STORM_FOOD).is_true()
	assert_float(GameNumbers.ARENA_FEATURE_QUARRY).is_greater(1.0)
	assert_float(GameNumbers.ARENA_FEATURE_SPRING).is_greater(1.0)
	assert_float(GameNumbers.ARENA_FEATURE_RIVER).is_greater(1.0)
	assert_float(GameNumbers.ARENA_FEATURE_RUINS_GOLD).is_greater(0.0)
	assert_bool(GameNumbers.ARENA_FEATURE_CHANCE > 0.0 and GameNumbers.ARENA_FEATURE_CHANCE < 1.0).is_true()
