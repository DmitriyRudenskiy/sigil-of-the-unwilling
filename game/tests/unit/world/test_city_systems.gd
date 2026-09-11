extends BaseTest
const TestFactories := preload("res://tests/helpers/factories.gd")

func _cell_at_distance(city: City, d: int) -> Vector2i:
	if d <= 0:
		return city.center
	var frontier: Array = [city.center]
	var seen: Dictionary = {city.center: true}
	for _i in 200:
		var next: Array = []
		for cell in frontier:
			for nb in HexUtils.get_all_neighbors(cell):
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

func test_logistics_adjacent_full() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 1)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9).is_true()

func test_logistics_distance_falloff() -> void:
	var city := TestFactories.make_city()
	assert_bool(absf(city.get_logistics_multiplier(_cell_at_distance(city, 2)) - 0.85) < 1e-9).is_true()
	assert_bool(absf(city.get_logistics_multiplier(_cell_at_distance(city, 3)) - 0.7) < 1e-9).is_true()
	assert_bool(absf(city.get_logistics_multiplier(_cell_at_distance(city, 5)) - 0.4) < 1e-9).is_true()

func test_logistics_min_clamp() -> void:
	var city := TestFactories.make_city()
	var m: float = city.get_logistics_multiplier(_cell_at_distance(city, 10))
	assert_that(m).is_equal(GameNumbers.LOGISTICS_MIN_MULT)

func test_logistics_borough_shortens_distance() -> void:
	var city := TestFactories.make_city()
	var far: Vector2i = _cell_at_distance(city, 4)
	var b := Borough.new()
	b.cell = far
	b.level = 1
	b.uid = 900
	city.boroughs.append(b)
	var nb: Vector2i = _cell_at_distance_from(far, city, 1)
	assert_that(HexUtils.hex_distance(nb, city.center) > 1).is_equal(true)
	assert_bool(absf(city.get_logistics_multiplier(nb) - 1.0) < 1e-9).is_true()

func _cell_at_distance_from(from: Vector2i, _city: City, d: int) -> Vector2i:
	var frontier: Array = [from]
	var seen: Dictionary = {from: true}
	for _i in 200:
		var next: Array = []
		for cell in frontier:
			for nb in HexUtils.get_all_neighbors(cell):
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
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9).is_true()

func test_logistics_road_adjacent() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	var road_cell: Vector2i = _cell_at_distance_from(cell, city, 1)
	city.add_road(road_cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.0) < 1e-9).is_true()

func test_logistics_road_cap() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 1)
	city.add_road(cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 1.15) < 1e-9).is_true()

func test_logistics_road_removed() -> void:
	var city := TestFactories.make_city()
	var cell: Vector2i = _cell_at_distance(city, 2)
	city.add_road(cell)
	city.remove_road(cell)
	assert_bool(absf(city.get_logistics_multiplier(cell) - 0.85) < 1e-9).is_true()

func test_zone_can_place_rules() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	var d2: Vector2i = _cell_at_distance(city, 2)
	assert_bool(ZoningSystem.can_place(city, city.center, ZoningSystem.ZoneType.NONE).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, city.center, ZoningSystem.ZoneType.RESIDENTIAL).ok).is_false()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.RESIDENTIAL).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.COMMERCIAL).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.INDUSTRIAL).ok).is_false()
	assert_bool(ZoningSystem.can_place(city, d2, ZoningSystem.ZoneType.INDUSTRIAL).ok).is_true()
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.SPECIAL).ok).is_false()
	city.special_sites[adj] = &"ruins"
	assert_bool(ZoningSystem.can_place(city, adj, ZoningSystem.ZoneType.SPECIAL).ok).is_true()

func test_zone_multiplier_isolated() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	_add_building(city, adj, ZoningSystem.ZoneType.RESIDENTIAL)
	assert_bool(absf(ZoningSystem.zone_multiplier(city, adj, ZoningSystem.ZoneType.RESIDENTIAL) - 1.0) < 1e-9).is_true()

func test_zone_agglomeration_bonus() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	assert_bool(b1 != b2).is_true()
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)
	assert_that(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL)).is_equal(1.0 + GameNumbers.ZONE_AGGLOMERATION_BONUS)
	var c: Vector2i = _cell_at_distance(city, 4)
	var d: Vector2i = _neighbor_of(c, city.center)
	_add_building(city, c, ZoningSystem.ZoneType.RESIDENTIAL)
	_add_building(city, d, ZoningSystem.ZoneType.RESIDENTIAL)
	assert_that(ZoningSystem.adjacent_same_zone_count(city, d, ZoningSystem.ZoneType.RESIDENTIAL)).is_equal(1)
	assert_that(ZoningSystem.zone_multiplier(city, d, ZoningSystem.ZoneType.RESIDENTIAL)).is_equal(1.0)

func test_zone_commercial_near_residential() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 1)
	var b: Vector2i = _cell_at_distance_from(a, city, 1)
	_add_building(city, a, ZoningSystem.ZoneType.RESIDENTIAL)
	var c := _add_building(city, b, ZoningSystem.ZoneType.COMMERCIAL)
	assert_that(c.zone_type).is_equal(ZoningSystem.ZoneType.COMMERCIAL)
	assert_that(ZoningSystem.zone_multiplier(city, b, ZoningSystem.ZoneType.COMMERCIAL)).is_equal(1.0 + GameNumbers.ZONE_COMMERCIAL_MARKET)

func test_zone_industrial_road_bonus() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	var road_cell: Vector2i = _cell_at_distance_from(a, city, 1)
	city.add_road(road_cell)
	assert_that(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL)).is_equal(1.0 + GameNumbers.ZONE_INDUSTRIAL_ROAD)

func test_zone_combined_bonuses() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	_add_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_add_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)
	var r := Vector2i(-1, -1)
	for nb in HexUtils.get_all_neighbors(a):
		if nb != b1 and nb != b2:
			r = nb
			break
	assert_bool(r != Vector2i(-1, -1)).is_true()
	city.add_road(r)
	assert_that(ZoningSystem.zone_multiplier(city, a, ZoningSystem.ZoneType.INDUSTRIAL)).is_equal(1.0 + GameNumbers.ZONE_AGGLOMERATION_BONUS + GameNumbers.ZONE_INDUSTRIAL_ROAD)

func test_scale_tiers_by_population() -> void:
	assert_that(ScaleShiftManager.tier_for(0)).is_equal(0)
	assert_that(ScaleShiftManager.tier_for(4)).is_equal(0)
	assert_that(ScaleShiftManager.tier_for(5)).is_equal(1)
	assert_that(ScaleShiftManager.tier_for(14)).is_equal(1)
	assert_that(ScaleShiftManager.tier_for(15)).is_equal(2)
	assert_that(ScaleShiftManager.tier_for(29)).is_equal(2)
	assert_that(ScaleShiftManager.tier_for(30)).is_equal(3)
	assert_that(ScaleShiftManager.tier_for(35)).is_equal(3)

func test_scale_tier_names() -> void:
	assert_that(ScaleShiftManager.tier_name(0)).is_equal("Селение")
	assert_that(ScaleShiftManager.tier_name(1)).is_equal("Деревня")
	assert_that(ScaleShiftManager.tier_name(2)).is_equal("Город")
	assert_that(ScaleShiftManager.tier_name(3)).is_equal("Метрополия")
	assert_that(ScaleShiftManager.tier_name(99)).is_equal("Метрополия")

func test_scale_multipliers() -> void:
	assert_that(ScaleShiftManager.storage_multiplier(0)).is_equal(1.0)
	assert_that(ScaleShiftManager.storage_multiplier(1)).is_equal(1.25)
	assert_that(ScaleShiftManager.storage_multiplier(2)).is_equal(1.5)
	assert_that(ScaleShiftManager.storage_multiplier(3)).is_equal(2.0)
	assert_that(ScaleShiftManager.auto_resource_multiplier(1)).is_equal(1.1)
	assert_that(ScaleShiftManager.auto_resource_multiplier(3)).is_equal(1.4)
	assert_that(ScaleShiftManager.upkeep_multiplier(2)).is_equal(0.9)
	assert_that(ScaleShiftManager.upkeep_multiplier(3)).is_equal(0.85)
	assert_that(ScaleShiftManager.storage_multiplier(99)).is_equal(2.0)

func test_road_add_remove_signal() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)
	var changes: Array = []
	city.buildings_changed.connect(func(): changes.append(1))
	assert_bool(city.has_road(adj)).is_false()
	city.add_road(adj)
	assert_bool(city.has_road(adj)).is_true()
	city.add_road(adj)
	assert_that(changes.size()).is_equal(1)
	city.remove_road(adj)
	assert_bool(city.has_road(adj)).is_false()
	assert_that(changes.size()).is_equal(2)
	city.remove_road(adj)
	assert_that(changes.size()).is_equal(2)
