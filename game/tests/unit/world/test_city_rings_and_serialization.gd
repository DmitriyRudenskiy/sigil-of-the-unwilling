extends BaseTest
## Носитель: scripts/world/city.gd — предельности застройки города (кольца, допуск
## стройки на клетке, расстояние застройки) и сериализация состояния города.
## Прежнее имя — `unit/world/test_city_level.gd`; в шаге 3 T-305 файл разделён по
## носителям: процветание, золото, репутационная надбка и переходы уровня ушли в
## `unit/city/test_prosperity_system.gd`.

var center := Vector2i(5, 5)

func _city() -> Variant:
	var c := City.new()
	c.uid = 42
	c.center = center
	c.stronghold_level = 1
	return c

func _ring_cell(r: int) -> Vector2i:
	# D6: ядро = ромб 4 клетки — идём на восток от восточного края ядра
	var cell := center + Vector2i(1, 0)
	for _i in r:
		cell = HexUtils.get_all_neighbors(cell)[0]
	return cell

func test_ring_of() -> void:
	var c: Variant = _city()
	assert_that(c.ring_of(center)).is_equal(0)
	assert_that(c.ring_of(_ring_cell(1))).is_equal(1)
	assert_that(c.ring_of(_ring_cell(3))).is_equal(3)

func test_building_max_distance_is_fixed_ring_three() -> void:
	# city-hex-layout: building_max_distance — фикс 3 (кольца 1–3 вокруг ядра),
	# уровень города радиус не меняет (02g §2.1).
	var c: Variant = _city()
	for lvl in [1, 3, 12]:
		c.level = lvl
		assert_that(c.building_max_distance()).is_equal(3)

func test_ring_build_gate() -> void:
	# city-hex-layout: радиус фикс 3 — кольцо 4 никогда недоступно, кольцо 3 всегда
	var c: Variant = _city()
	c.storage[&"industry"] = 1000.0
	var far := _ring_cell(4)
	assert_bool(c.can_build_building(BuildingDefs.market(), far).ok).is_false()
	c.level = 3
	assert_bool(c.can_build_building(BuildingDefs.market(), far).ok).is_false()
	var near := _ring_cell(3)
	assert_bool(c.can_build_building(BuildingDefs.market(), near).ok).is_true()

func test_build_rejected_on_worker_cell() -> void:
	var c: Variant = _city()
	c.storage[&"industry"] = 100.0
	var cell := _ring_cell(1)
	c._add_pop(PopUnit.State.WORKER, 0, cell)
	var res: CityCheck = c.can_build_building(BuildingDefs.farm(), cell)
	assert_bool(res.ok).is_false()
	assert_that(str(res.reason)).is_equal("Клетка занята рабочим")
	assert_that(c.pop.size()).is_equal(1)
	assert_bool(c.can_build_building(BuildingDefs.farm(), _ring_cell(2)).ok).is_true()

func test_serialize_roundtrip() -> void:
	var c: Variant = _city()
	c.level = 3
	c.prosperity = 77.5
	var restored := City.new()
	restored.deserialize(c.serialize())
	assert_that(restored.level).is_equal(3)
	assert_bool(absf(restored.prosperity - 77.5) < 1e-9).is_true()

func test_serialize_clamps() -> void:
	var restored := City.new()
	restored.deserialize({"level": 99, "prosperity": -5.0})
	assert_that(restored.level).is_equal(GameNumbers.CITY_LEVEL_MAX)
	assert_bool(absf(restored.prosperity - 0.0) < 1e-9).is_true()
