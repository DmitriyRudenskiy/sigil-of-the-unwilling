extends "res://tests/gut_base.gd"
const TestFactories := preload("res://tests/helpers/test_factories.gd")
## M3: Город — LogisticsCalculator, ZoningSystem, ScaleShiftManager.
## Чистые RefCounted-модели, город собирается вручную.

## Клетка на гекс-дистанции d от центра (BFS, не зависит от координат).
func _cell_at_distance(city: City, d: int) -> Vector2i:
	if d <= 0:
		return city.center
	var frontier: Array = [city.center]
	var seen: Dictionary = {city.center: true}
	for _i in 200:
		var next: Array = []
		for c in frontier:
			for nb in HexUtils.get_all_neighbors(c):
				if seen.has(nb):
					continue
				seen[nb] = true
				if HexUtils.hex_distance(nb, city.center) == d:
					return nb
				next.append(nb)
		frontier = next
	return Vector2i(-1, -1)


func _neighbor_of(a: Vector2i, exclude: Vector2i) -> Vector2i:
	for nb in HexUtils.get_all_neighbors(a):
		if nb != exclude:
			return nb
	return Vector2i(-1, -1)


func _add_building(city: City, cell: Vector2i, zone: int) -> UniqueBuilding:
	var b := UniqueBuilding.new()
	b.uid = city.buildings.size() + 1
	b.cell = cell
	b.level = 1
	b.zone_type = zone
	city.buildings.append(b)
	return b


# ==================== ЛОГИСТИКА ====================

func test_logistics_adjacent_full() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 1)
	assert_true(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9, "adjacent = 1.0")


func test_logistics_distance_falloff() -> void:
	var city := TestFactories.make_city()
	assert_true(absf(city.get_logistics_multiplier(_cell_at_distance(city, 2)) - 0.85) < 1e-9, "d2 = 0.85")
	assert_true(absf(city.get_logistics_multiplier(_cell_at_distance(city, 3)) - 0.7) < 1e-9, "d3 = 0.7")
	assert_true(absf(city.get_logistics_multiplier(_cell_at_distance(city, 5)) - 0.4) < 1e-9, "d5 = 0.4")


func test_logistics_min_clamp() -> void:
	var city := TestFactories.make_city()
	var m: float = city.get_logistics_multiplier(_cell_at_distance(city, 10))
	assert_eq(m, LogisticsCalculator.MIN_MULT, "far cell clamped to MIN")


func test_logistics_borough_shortens_distance() -> void:
	var city := TestFactories.make_city()
	var far: Vector2i = _cell_at_distance(city, 4)
	# До центра 4 клетки (0.55), но район в 1 клетке от неё → 1.0.
	var b := Borough.new()
	b.cell = far
	b.level = 1
	b.uid = 900
	city.boroughs.append(b)
	var nb: Vector2i = _cell_at_distance_from(far, city, 1)
	assert_eq(HexUtils.hex_distance(nb, city.center) > 1, true, "sanity: nb далеко от центра")
	assert_true(absf(city.get_logistics_multiplier(nb) - 1.0) < 1e-9, "adjacent to borough = 1.0")


func _cell_at_distance_from(from: Vector2i, _city: City, d: int) -> Vector2i:
	var frontier: Array = [from]
	var seen: Dictionary = {from: true}
	for _i in 200:
		var next: Array = []
		for c in frontier:
			for nb in HexUtils.get_all_neighbors(c):
				if seen.has(nb):
					continue
				seen[nb] = true
				if HexUtils.hex_distance(nb, from) == d:
					return nb
				next.append(nb)
		frontier = next
	return Vector2i(-1, -1)


func test_logistics_road_on_cell() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	city.add_road(cell)
	assert_true(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9, "d2 + road = 0.85 + 0.15")


func test_logistics_road_adjacent() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	var road_cell: Vector2i = _cell_at_distance_from(cell, city, 1)
	city.add_road(road_cell)
	assert_true(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9, "adjacent road bonus")


func test_logistics_road_cap() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 1)
	city.add_road(cell)
	assert_true(absf(city.get_logistics_multiplier(cell) - 1.15) < 1e-9, "1.0 + bonus, not capped at 1.0")


func test_logistics_road_removed() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	city.add_road(cell)
	city.remove_road(cell)
	assert_true(absf(city.get_logistics_multiplier(cell) - 0.85) < 1e-9, "back to falloff")


# ==================== ЗОНИРОВАНИЕ ====================

func test_zone_can_place_rules() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	var d2: Vector2i = _cell_at_distance(city, 2)
	# NONE — всегда можно.
	assert_true(ZoningSystem.can_place(city, city.center, ZoningSystem.ZoneType.NONE).ok)
	# Жилое/торговое — нельзя в центре, можно рядом.
	assert_false(ZoningSystem.can_place(city, city.center, ZoningSystem.ZoneType.RESIDENTIAL).ok)
	assert_true(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.RESIDENTIAL).ok)
	assert_true(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.COMMERCIAL).ok)
	# Промышленное — не ближе 2 клеток.
	assert_false(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.INDUSTRIAL).ok)
	assert_true(ZoningSystem.can_place(city, d2, ZoningSystem.ZoneType.INDUSTRIAL).ok)
	# Спец. — только на площадках.
	assert_false(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.SPECIAL).ok)
	city.special_sites[adj] = &"ruins"
	assert_true(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.SPECIAL).ok)


func test_zone_multiplier_isolated() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	_add_building(city, adj, ZoningSystem.ZoneType.RESIDENTIAL)
	assert_true(absf(ZoningSystem.zone_multiplier(city, adj, ZoningSystem.ZoneType.RESIDENTIAL) - 1.0) < 1e-9)


func test_zone_agglomeration_bonus() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	assert_true(b1 != b2, "two distinct neighbors")
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)
	assert_eq(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL),
		1.0 + ZoningSystem.AGGLOMERATION_BONUS, "2 same-zone neighbors")
	# Один сосед той же зоны — бонуса ещё нет (порог 2).
	var c: Vector2i = _cell_at_distance(city, 4)  # далеко от промышленного кластера
	var d: Vector2i = _neighbor_of(c, city.center)
	_add_building(city, c, ZoningSystem.ZoneType.RESIDENTIAL)
	_add_building(city, d, ZoningSystem.ZoneType.RESIDENTIAL)
	assert_eq(ZoningSystem.adjacent_same_zone_count(city, d, ZoningSystem.ZoneType.RESIDENTIAL), 1,
		"single neighbor only")
	assert_eq(ZoningSystem.zone_multiplier(city, d, ZoningSystem.ZoneType.RESIDENTIAL), 1.0,
		"below agglomeration threshold")


func test_zone_commercial_near_residential() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 1)
	var b: Vector2i = _cell_at_distance_from(a, city, 1)
	_add_building(city, a, ZoningSystem.ZoneType.RESIDENTIAL)
	var c := _add_building(city, b, ZoningSystem.ZoneType.COMMERCIAL)
	assert_eq(c.zone_type, ZoningSystem.ZoneType.COMMERCIAL, "sanity")
	assert_eq(ZoningSystem.zone_multiplier(city, b, ZoningSystem.ZoneType.COMMERCIAL),
		1.0 + ZoningSystem.COMMERCIAL_MARKET_BONUS, "market bonus")


func test_zone_industrial_road_bonus() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	var road_cell: Vector2i = _cell_at_distance_from(a, city, 1)
	city.add_road(road_cell)
	assert_eq(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL),
		1.0 + ZoningSystem.INDUSTRIAL_ROAD_BONUS, "road bonus")


func test_zone_combined_bonuses() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)
	# Дорога на клетке, соседней с a (не b1/b2, чтобы не мешать).
	var r := Vector2i(-1, -1)
	for nb in HexUtils.get_all_neighbors(a):
		if nb != b1 and nb != b2:
			r = nb
			break
	assert_true(r != Vector2i(-1, -1), "free neighbor found")
	city.add_road(r)
	# a: агромерация (b1, b2) + дорога рядом = оба бонуса.
	assert_eq(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL),
		1.0 + ZoningSystem.AGGLOMERATION_BONUS + ZoningSystem.INDUSTRIAL_ROAD_BONUS, "a: both")


# ==================== МАСШТАБ ====================

func test_scale_tiers_by_population() -> void:
	assert_eq(ScaleShiftManager.tier_for(0), 0)
	assert_eq(ScaleShiftManager.tier_for(4), 0)
	assert_eq(ScaleShiftManager.tier_for(5), 1)
	assert_eq(ScaleShiftManager.tier_for(14), 1)
	assert_eq(ScaleShiftManager.tier_for(15), 2)
	assert_eq(ScaleShiftManager.tier_for(29), 2)
	assert_eq(ScaleShiftManager.tier_for(30), 3)
	assert_eq(ScaleShiftManager.tier_for(35), 3)


func test_scale_tier_names() -> void:
	assert_eq(ScaleShiftManager.tier_name(0), "Селение")
	assert_eq(ScaleShiftManager.tier_name(1), "Деревня")
	assert_eq(ScaleShiftManager.tier_name(2), "Город")
	assert_eq(ScaleShiftManager.tier_name(3), "Метрополия")
	assert_eq(ScaleShiftManager.tier_name(99), "Метрополия", "clamp high")


func test_scale_multipliers() -> void:
	assert_eq(ScaleShiftManager.storage_multiplier(0), 1.0)
	assert_eq(ScaleShiftManager.storage_multiplier(1), 1.25)
	assert_eq(ScaleShiftManager.storage_multiplier(2), 1.5)
	assert_eq(ScaleShiftManager.storage_multiplier(3), 2.0)
	assert_eq(ScaleShiftManager.auto_resource_multiplier(1), 1.1)
	assert_eq(ScaleShiftManager.auto_resource_multiplier(3), 1.4)
	assert_eq(ScaleShiftManager.upkeep_multiplier(2), 0.9)
	assert_eq(ScaleShiftManager.upkeep_multiplier(3), 0.85)
	assert_eq(ScaleShiftManager.storage_multiplier(99), 2.0, "clamp high")


# ==================== CITY-ПОЛЯ (ДОРОГИ) ====================

func test_road_add_remove_signal() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	var changes: Array = []
	city.buildings_changed.connect(func(): changes.append(1))
	assert_false(city.has_road(adj))
	city.add_road(adj)
	assert_true(city.has_road(adj))
	city.add_road(adj)  # повтор — без сигнала
	assert_eq(changes.size(), 1, "one signal for add")
	city.remove_road(adj)
	assert_false(city.has_road(adj))
	assert_eq(changes.size(), 2, "one signal for remove")
	city.remove_road(adj)  # повтор — без сигнала
	assert_eq(changes.size(), 2, "no signal for missing")
