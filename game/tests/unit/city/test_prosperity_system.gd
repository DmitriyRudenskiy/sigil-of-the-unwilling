extends BaseTest
## Носитель: scripts/city/prosperity_system.gd (процветание, надбка золота,
## модификатор репутации и переходы уровня города).
## Прежнее имя — `unit/world/test_city_level.gd`; в шаге 3 T-305 файл разделён по
## носителям: кольцевые предельности города (`ring_of`, `building_max_distance`,
## `can_build_building`, `serialize`) ушли в
## `unit/world/test_city_rings_and_serialization.gd`.
## Третий снизу тест считает `CityTurnProcessor` как драйвер: предмет проверки —
## значения процветания, золота и сигнал `city_level_up`, а не работа процессора.

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

func _add_workers(c: Variant, n: int, food_yield: float) -> void:
	c.tile_yield_fn = func(_cell: Vector2i) -> Dictionary:
		return {&"food": food_yield}
	for i in n:
		c._add_pop(PopUnit.State.WORKER, 0, _ring_cell(1) + Vector2i(i, 0))

func test_prosperity_empty_city() -> void:
	var c: Variant = _city()
	var v: float = ProsperitySystem.recalculate(c)
	assert_bool(absf(v - 60.0) < 1e-9).is_true()
	assert_that(c.prosperity).is_equal(60.0)

func test_prosperity_starving() -> void:
	var c: Variant = _city()
	_add_workers(c, 2, 0.0)
	var v: float = ProsperitySystem.recalculate(c)
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
	var v: float = ProsperitySystem.recalculate(c)
	assert_bool(absf(v - 100.0) < 1e-9).is_true()

func test_gold_bonus() -> void:
	var c: Variant = _city()
	c.prosperity = 100.0
	assert_bool(absf(ProsperitySystem.gold_bonus(c) - 5.0) < 1e-9).is_true()
	c.prosperity = 40.0
	assert_bool(absf(ProsperitySystem.gold_bonus(c) - 2.0) < 1e-9).is_true()
	c.prosperity = 0.0
	assert_bool(absf(ProsperitySystem.gold_bonus(c) - 0.0) < 1e-9).is_true()

func test_reputation_mod_bands() -> void:
	var c: Variant = _city()
	c.prosperity = 60.0
	assert_that(ProsperitySystem.reputation_mod(c)).is_equal(1)
	c.prosperity = 40.0
	assert_that(ProsperitySystem.reputation_mod(c)).is_equal(0)
	c.prosperity = 20.0
	assert_that(ProsperitySystem.reputation_mod(c)).is_equal(-1)

func test_level_up_all_gates_fail() -> void:
	var c: Variant = _city()
	c.prosperity = 50.0
	c.add_followers(5)
	var check: Dictionary = ProsperitySystem.can_level_up(c)
	assert_bool(bool(check.ok)).is_false()
	assert_that(check.reasons.size()).is_equal(3)

func test_level_up_buildings_gate() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.prosperity = 80.0
	c.add_followers(12)
	# Ранняя игра: порог зданий — 1 (early-game-foundation)
	var check: Dictionary = ProsperitySystem.can_level_up(c)
	assert_bool(bool(check.ok)).is_false()
	assert_that(check.reasons.size()).is_equal(1)
	c.buildings.append(UniqueBuilding.new())
	check = ProsperitySystem.can_level_up(c)
	assert_bool(bool(check.ok)).is_true()

func test_level_up_success() -> void:
	var c: Variant = _city()
	c.stronghold_level = 2
	c.prosperity = 80.0
	c.add_followers(12)
	c.buildings.append(UniqueBuilding.new())
	c.buildings.append(UniqueBuilding.new())
	assert_bool(ProsperitySystem.try_level_up(c)).is_true()
	assert_that(c.level).is_equal(2)
	# Ранняя игра: дымовая до 11 — уровень 2 не потолок (early-game-foundation)
	c.prosperity = 80.0
	assert_bool(ProsperitySystem.try_level_up(c)).is_true()
	assert_that(c.level).is_equal(3)

func test_level_max() -> void:
	var c: Variant = _city()
	c.level = GameNumbers.CITY_LEVEL_MAX
	c.prosperity = 99.0
	var check: Dictionary = ProsperitySystem.can_level_up(c)
	assert_bool(bool(check.ok)).is_false()
	assert_that(check.reasons.size()).is_equal(1)

func test_build_radius_for_level_is_fixed() -> void:
	# D6: радиус зафиксирован на 3 (кольца 1–3 вокруг ядра, 02g §2.1); зеркало
	# города (city.building_max_distance) проверяется своим носителем.
	for lvl in [1, 2, 3, 4, 5]:
		assert_that(ProsperitySystem.build_radius_for_level(lvl)).is_equal(3)

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

	var proc := CityTurnProcessor.new()
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
