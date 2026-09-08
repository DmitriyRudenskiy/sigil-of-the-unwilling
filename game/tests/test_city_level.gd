extends GdUnitTestSuite

const _City = preload("res://scripts/world/City.gd")
const _Prosperity = preload("res://scripts/city/ProsperitySystem.gd")
const _CityProc = preload("res://scripts/city/CityTurnProcessor.gd")

var center := Vector2i(5, 5)


func _city() -> Variant:
	var c := _City.new()
	c.uid = 42
	c.center = center
	c.stronghold_level = 1
	return c


func _ring_cell(r: int) -> Vector2i:
	var cell := center
	for _i in r:
		cell = HexUtils.get_all_neighbors(cell)[0]
	return cell


func _add_workers(c: Variant, n: int, food_yield: float) -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": food_yield}
	for i in n:
		c._add_pop(PopUnit.State.WORKER, 0, _ring_cell(1) + Vector2i(i, 0))


func test_prosperity_empty_city() -> void:
	var c: Variant = _city()
	var v: float = _Prosperity.recalculate(c)
	assert_bool(absf(v - 60.0) < 1e-9).is_true()
	assert_that(c.prosperity).is_equal(60.0)


func test_prosperity_starving() -> void:
	var c: Variant = _city()
	_add_workers(c, 2, 0.0)  
	var v: float = _Prosperity.recalculate(c)
	assert_bool(absf(v - 40.0) < 1e-9).is_true()


func test_prosperity_full_city_clamped() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.storage[&"industry"] = 50.0
	c.reputation = 50
	c.add_followers(15)  
	for i in 10:  
		var b := UniqueBuilding.new()
		b.cell = _ring_cell(1) + Vector2i(i, 0)
		c.buildings.append(b)
	c._add_pop(PopUnit.State.WORKER, 0, HexUtils.get_neighbor(center, 5))
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 20.0}
	var v: float = _Prosperity.recalculate(c)
	assert_bool(absf(v - 100.0) < 1e-9).is_true()


func test_gold_bonus() -> void:
	var c: Variant = _city()
	c.prosperity = 100.0
	assert_bool(absf(_Prosperity.gold_bonus(c) - 5.0) < 1e-9).is_true()
	c.prosperity = 40.0
	assert_bool(absf(_Prosperity.gold_bonus(c) - 2.0) < 1e-9).is_true()
	c.prosperity = 0.0
	assert_bool(absf(_Prosperity.gold_bonus(c) - 0.0) < 1e-9).is_true()


func test_reputation_mod_bands() -> void:
	var c: Variant = _city()
	c.prosperity = 60.0
	assert_that(_Prosperity.reputation_mod(c)).is_equal(1)
	c.prosperity = 40.0
	assert_that(_Prosperity.reputation_mod(c)).is_equal(0)
	c.prosperity = 20.0
	assert_that(_Prosperity.reputation_mod(c)).is_equal(-1)


func test_level_up_all_gates_fail() -> void:
	var c: Variant = _city()
	c.prosperity = 50.0  
	c.add_followers(5)  
	var check: Dictionary = _Prosperity.can_level_up(c)
	assert_bool(bool(check.ok)).is_false()
	assert_that(check.reasons.size()).is_equal(3)


func test_level_up_buildings_gate() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.prosperity = 80.0
	c.add_followers(12)
	c.buildings.append(UniqueBuilding.new())
	var check: Dictionary = _Prosperity.can_level_up(c)
	assert_bool(bool(check.ok)).is_false()
	assert_that(check.reasons.size()).is_equal(1)
	c.buildings.append(UniqueBuilding.new())
	check = _Prosperity.can_level_up(c)
	assert_bool(bool(check.ok)).is_true()


func test_level_up_success() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.prosperity = 80.0
	c.add_followers(12)
	c.buildings.append(UniqueBuilding.new())
	c.buildings.append(UniqueBuilding.new())
	assert_bool(_Prosperity.try_level_up(c)).is_true()
	assert_that(c.level).is_equal(2)
	assert_bool(_Prosperity.try_level_up(c)).is_false()


func test_level_max() -> void:
	var c: Variant = _city()
	c.level = 5
	var check: Dictionary = _Prosperity.can_level_up(c)
	assert_bool(bool(check.ok)).is_false()
	assert_that(check.reasons.size()).is_equal(1)


func test_build_radius_by_level() -> void:
	var c: Variant = _city()
	for lvl in [1, 2, 3, 4, 5]:
		c.level = lvl
		var expected: int = [3, 4, 5, 5, 5][lvl - 1]
		assert_that(_Prosperity.build_radius_for_level(lvl)).is_equal(expected)
		assert_that(c.building_max_distance()).is_equal(expected)


func test_ring_of() -> void:
	var c: Variant = _city()
	assert_that(c.ring_of(center)).is_equal(0)
	assert_that(c.ring_of(_ring_cell(1))).is_equal(1)
	assert_that(c.ring_of(_ring_cell(3))).is_equal(3)


func test_ring_build_gate() -> void:
	var c: Variant = _city()
	c.storage[&"industry"] = 1000.0
	var far := _ring_cell(4)
	assert_bool(c.can_build_building(BuildingDefs.market(), far).ok).is_false()
	c.level = 3
	assert_bool(c.can_build_building(BuildingDefs.market(), far).ok).is_true()


func test_build_rejected_on_worker_cell() -> void:
	var c: Variant = _city()
	c.storage[&"industry"] = 100.0
	var cell := _ring_cell(1)
	c._add_pop(PopUnit.State.WORKER, 0, cell)
	var res: Dictionary = c.can_build_building(BuildingDefs.farm(), cell)
	assert_bool(res.ok).is_false()
	assert_that(str(res.reason)).is_equal("Клетка занята рабочим")
	assert_that(c.pop.size()).is_equal(1)
	assert_bool(c.can_build_building(BuildingDefs.farm(), _ring_cell(2)).ok).is_true()


func test_serialize_roundtrip() -> void:
	var c: Variant = _city()
	c.level = 3
	c.prosperity = 77.5
	var restored := _City.new()
	restored.deserialize(c.serialize())
	assert_that(restored.level).is_equal(3)
	assert_bool(absf(restored.prosperity - 77.5) < 1e-9).is_true()


func test_serialize_clamps() -> void:
	var c: Variant = _city()
	var restored := _City.new()
	restored.deserialize({"level": 99, "prosperity": -5.0})
	assert_that(restored.level).is_equal(5)
	assert_bool(absf(restored.prosperity - 0.0) < 1e-9).is_true()


func test_processor_prosperity_and_level_up() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.storage[&"industry"] = 1000.0
	c.add_followers(12)
	for i in 2:
		var b := UniqueBuilding.new()
		b.def = BuildingDefs.farm()
		b.cell = _ring_cell(1) + Vector2i(i + 1, 0)
		c.buildings.append(b)
	_add_workers(c, 2, 20.0)

	var proc := _CityProc.new()
	var got: Array = []
	proc.city_level_up.connect(func(uid: int, lvl: int): got.append([uid, lvl]))
	var gold_before: float = c.storage[&"industry"]
	proc._process_city(c, 7)

	assert_bool(absf(c.prosperity - 74.1) < 1e-6).is_true()
	assert_bool(absf(c.storage[&"industry"] - (gold_before + 3.705)) < 1e-6).is_true()
	assert_that(c.level).is_equal(2)
	assert_that(got.size()).is_equal(1)
	assert_that(got[0][0]).is_equal(c.uid)
	assert_that(got[0][1]).is_equal(2)
