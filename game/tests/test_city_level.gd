extends "res://tests/test_base.gd"
## Спринт 9: процветание, уровень города, кольца застройки.

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
	# 50 база + 10 еда (0 >= 0). Нет золота/зданий/населения/репутации.
	assert_true(absf(v - 60.0) < 1e-9, "empty city = 60, got %s" % v)
	assert_eq(c.prosperity, 60.0, "written to city")


func test_prosperity_starving() -> void:
	var c: Variant = _city()
	_add_workers(c, 2, 0.0)  # расход 2.0, добычи нет
	var v: float = _Prosperity.recalculate(c)
	# 50 - 10 (голод)
	assert_true(absf(v - 40.0) < 1e-9, "starving = 40, got %s" % v)


func test_prosperity_full_city_clamped() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.storage[&"industry"] = 50.0
	c.reputation = 50
	c.add_followers(15)  # 15/20 = 0.75 >= POP_RATIO
	for i in 10:  # 10 зданий = 20 (кап бонуса)
		var b := UniqueBuilding.new()
		b.cell = _ring_cell(1) + Vector2i(i, 0)
		c.buildings.append(b)
	# Тайл рабочего — в другом секторе, не занят зданием (иначе yield = 0).
	c._add_pop(PopUnit.State.WORKER, 0, HexUtils.get_neighbor(center, 5))
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": 20.0}
	var v: float = _Prosperity.recalculate(c)
	# 50 + 10 + 10 + 20 + 10 + 5 = 105 -> 100
	assert_true(absf(v - 100.0) < 1e-9, "clamped to 100, got %s" % v)


func test_gold_bonus() -> void:
	var c: Variant = _city()
	c.prosperity = 100.0
	assert_true(absf(_Prosperity.gold_bonus(c) - 5.0) < 1e-9, "100 -> 5.0")
	c.prosperity = 40.0
	assert_true(absf(_Prosperity.gold_bonus(c) - 2.0) < 1e-9, "40 -> 2.0")
	c.prosperity = 0.0
	assert_true(absf(_Prosperity.gold_bonus(c) - 0.0) < 1e-9, "0 -> 0.0")


func test_reputation_mod_bands() -> void:
	var c: Variant = _city()
	c.prosperity = 60.0
	assert_eq(_Prosperity.reputation_mod(c), 1, ">= 60 -> +1")
	c.prosperity = 40.0
	assert_eq(_Prosperity.reputation_mod(c), 0, "middle -> 0")
	c.prosperity = 20.0
	assert_eq(_Prosperity.reputation_mod(c), -1, "<= 20 -> -1")


func test_level_up_all_gates_fail() -> void:
	var c: Variant = _city()
	c.prosperity = 50.0  # < 60
	c.add_followers(5)  # 5 < 12
	var check: Dictionary = _Prosperity.can_level_up(c)
	assert_false(bool(check.ok), "not allowed")
	assert_eq(check.reasons.size(), 3, "3 reasons: prosperity/pop/buildings")


func test_level_up_buildings_gate() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.prosperity = 80.0
	c.add_followers(12)
	c.buildings.append(UniqueBuilding.new())
	var check: Dictionary = _Prosperity.can_level_up(c)
	assert_false(bool(check.ok), "1 building < 2")
	assert_eq(check.reasons.size(), 1, "only buildings missing")
	c.buildings.append(UniqueBuilding.new())
	check = _Prosperity.can_level_up(c)
	assert_true(bool(check.ok), "2 buildings -> ok")


func test_level_up_success() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.prosperity = 80.0
	c.add_followers(12)
	c.buildings.append(UniqueBuilding.new())
	c.buildings.append(UniqueBuilding.new())
	assert_true(_Prosperity.try_level_up(c), "level up")
	assert_eq(c.level, 2, "level 2")
	assert_false(_Prosperity.try_level_up(c), "no double level-up")


func test_level_max() -> void:
	var c: Variant = _city()
	c.level = 5
	var check: Dictionary = _Prosperity.can_level_up(c)
	assert_false(bool(check.ok), "max level")
	assert_eq(check.reasons.size(), 1, "one reason")


func test_build_radius_by_level() -> void:
	var c: Variant = _city()
	for lvl in [1, 2, 3, 4, 5]:
		c.level = lvl
		var expected: int = [3, 4, 5, 5, 5][lvl - 1]
		assert_eq(_Prosperity.build_radius_for_level(lvl), expected, "L%d radius" % lvl)
		assert_eq(c.building_max_distance(), expected, "city sees radius")


func test_ring_of() -> void:
	var c: Variant = _city()
	assert_eq(c.ring_of(center), 0, "center = ring 0")
	assert_eq(c.ring_of(_ring_cell(1)), 1, "neighbor = ring 1")
	assert_eq(c.ring_of(_ring_cell(3)), 3, "far = ring 3")


func test_ring_build_gate() -> void:
	var c: Variant = _city()
	c.storage[&"industry"] = 1000.0
	var far := _ring_cell(4)
	assert_false(c.can_build_building(BuildingDefs.market(), far).ok,
		"level 1: ring 4 rejected")
	c.level = 3
	assert_true(c.can_build_building(BuildingDefs.market(), far).ok,
		"level 3: ring 4 allowed")


func test_serialize_roundtrip() -> void:
	var c: Variant = _city()
	c.level = 3
	c.prosperity = 77.5
	var restored := _City.new()
	restored.deserialize(c.serialize())
	assert_eq(restored.level, 3, "level restored")
	assert_true(absf(restored.prosperity - 77.5) < 1e-9, "prosperity restored")


func test_serialize_clamps() -> void:
	var c: Variant = _city()
	var restored := _City.new()
	restored.deserialize({"level": 99, "prosperity": -5.0})
	assert_eq(restored.level, 5, "level clamped to max")
	assert_true(absf(restored.prosperity - 0.0) < 1e-9, "prosperity clamped to 0")


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

	# Репутация (шаг 6): +1 за избыток еды. Процветание (шаг 9):
	# 50 + 10 (еда) + 10 (золото) + 4 (2 здания) + 0.1 (репутация 1) = 74.1.
	assert_true(absf(c.prosperity - 74.1) < 1e-6, "prosperity 74.1, got %s" % c.prosperity)
	# Бонус к золоту: 74.1 * 0.05 = 3.705.
	assert_true(absf(c.storage[&"industry"] - (gold_before + 3.705)) < 1e-6,
		"gold bonus 3.705")
	# Уровень: 74.1 >= 60, 14 >= 12, 2 >= 2 -> уровень 2.
	assert_eq(c.level, 2, "leveled up to 2")
	assert_eq(got.size(), 1, "signal emitted once")
	assert_eq(got[0][0], c.uid, "signal city uid")
	assert_eq(got[0][1], 2, "signal new level")
