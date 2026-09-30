extends BaseTest

# city-hex-layout-prototype: ядро города (ромб 2×2), кольца 1–3, кэш тайл→город

const MapRenderer = preload("res://scripts/world/map_renderer.gd")

func _city(center := Vector2i(10, 10)) -> City:
	var c := CityFactory.create_village(center, "Test")
	return c

func test_core_cells_diamond() -> void:
	var center := Vector2i(10, 10)
	var cells: Array[Vector2i] = CityFactory.core_cells_for(center)
	assert_that(cells.size()).is_equal(4)
	assert_bool(cells.has(center))
	assert_bool(cells.has(center + Vector2i(1, 0)))
	assert_bool(cells.has(center + Vector2i(0, 1)))
	assert_bool(cells.has(center + Vector2i(1, 1)))

func test_create_village_fills_core_cells() -> void:
	var c := _city()
	assert_that(c.core_cells.size()).is_equal(4)
	assert_bool(c.core_cells.has(c.center))

func test_building_max_distance_fixed_3() -> void:
	var c := _city()
	c.level = 1
	assert_that(c.building_max_distance()).is_equal(3)
	c.level = 12
	assert_that(c.building_max_distance()).is_equal(3)

func test_core_cells_block_building() -> void:
	var c := _city()
	for cc in c.core_cells:
		assert_bool(c.cell_is_built(cc)).override_failure_message(str(cc))

func test_serializer_migration_without_core_cells() -> void:
	var c := _city()
	var d := CitySerializer.serialize(c)
	d.erase("core_cells")
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.core_cells).is_equal(CityFactory.core_cells_for(c2.center))

func test_serializer_roundtrip_core_cells() -> void:
	var c := _city()
	var d := CitySerializer.serialize(c)
	var c2 := City.new()
	CitySerializer.deserialize(c2, d)
	assert_that(c2.core_cells).is_equal(c.core_cells)

func test_first_free_build_cell_skips_core() -> void:
	var c := _city()
	var cell := CityBuildingService.first_free_build_cell(c, BuildingDefs.market())
	assert_bool(cell != Vector2i(-1, -1))
	assert_bool(not c.core_cells.has(cell)).override_failure_message("предложено ядро: " + str(cell))

func test_first_free_build_cell_no_beyond_ring_3() -> void:
	var c := _city()
	# занять все клетки колец 1–3
	for r in range(1, 4):
		for cell in HexUtils.ring(c.center, r):
			c.buildings.append(_building_at(cell))
	var cell := CityBuildingService.first_free_build_cell(c, BuildingDefs.market())
	assert_that(cell).is_equal(Vector2i(-1, -1))

func test_first_free_build_cell_finds_free_in_ring() -> void:
	# City.new() без village-kit — рабочие не занимают клетки
	var c := City.new()
	c.center = Vector2i(10, 10)
	c.core_cells = CityFactory.core_cells_for(c.center)
	# занять всё кроме одной клетки кольца 1
	var free_cell: Vector2i = Vector2i(-1, -1)
	for r in range(1, 4):
		for cell in HexUtils.ring(c.center, r):
			if cell == c.center + Vector2i(0, -1):
				free_cell = cell
				continue
			c.buildings.append(_building_at(cell))
	var found := CityBuildingService.first_free_build_cell(c, BuildingDefs.market())
	assert_that(found).is_equal(free_cell)

func _building_at(cell: Vector2i) -> UniqueBuilding:
	var b := UniqueBuilding.new()
	b.cell = cell
	b.def = BuildingDefs.market()
	b.level = 1
	return b

func test_rebuild_city_zones_cache() -> void:
	var c := _city(Vector2i(10, 10))
	var renderer := MapRenderer.new(null)
	renderer.rebuild_city_zones([c])
	# ядро — ring 0
	for cc in c.core_cells:
		assert_bool(renderer.city_zones.has(cc)).override_failure_message(str(cc))
		assert_int(int(renderer.city_zones[cc].ring)).is_equal(0)
	# кольцо 1 — ring 1 (кроме занятых ядром)
	var ring1 := HexUtils.ring(c.center, 1)
	var ring1_count := 0
	for cell in ring1:
		if not c.core_cells.has(cell):
			assert_bool(renderer.city_zones.has(cell))
			assert_int(int(renderer.city_zones[cell].ring)).is_equal(1)
			ring1_count += 1
	# (1,1) в аксиальных координатах — расстояние 2, в кольце 1 только (1,0) и (0,1)
	assert_that(ring1_count).is_equal(4)
	# кольцо 3 есть, кольцо 4 нет
	var ring3 := HexUtils.ring(c.center, 3)
	var ring4 := HexUtils.ring(c.center, 4)
	assert_bool(renderer.city_zones.has(ring3[0]))
	assert_bool(not renderer.city_zones.has(ring4[0]))

func test_rebuild_city_zones_replaces() -> void:
	var c1 := _city(Vector2i(10, 10))
	var c2 := _city(Vector2i(30, 30))
	var renderer := MapRenderer.new(null)
	renderer.rebuild_city_zones([c1, c2])
	assert_bool(renderer.city_zones.has(c1.center))
	assert_bool(renderer.city_zones.has(c2.center))
	renderer.rebuild_city_zones([c2])
	assert_bool(not renderer.city_zones.has(c1.center))
	assert_bool(renderer.city_zones.has(c2.center))
