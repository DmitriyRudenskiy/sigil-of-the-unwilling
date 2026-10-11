extends BaseTest

const CampaignCityProgression := preload("res://scripts/city/campaign_city_progression.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const TestFactories := preload("res://tests/helpers/factories.gd")

func _city() -> City:
	var city := TestFactories.make_city()
	city.center = Vector2i(20, 20)
	city.core_cells = HexUtils.core_cells(city.center)
	return city

func test_city_level_cell_limits_are_exact_and_clamped() -> void:
	assert_that(CampaignCityProgression.CELL_LIMITS).is_equal(
		[4, 9, 14, 19, 24, 29, 34, 39, 44, 48, 52])
	assert_that(CampaignCityProgression.cell_limit(0)).is_equal(4)
	assert_that(CampaignCityProgression.cell_limit(12)).is_equal(52)

func test_unique_occupied_cells_include_core_starting_buildings_construction_and_ruins() -> void:
	var city := _city()
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	var legacy := UniqueBuilding.new()
	legacy.cell = cells[4]
	city.buildings.append(legacy)
	city.campaign_buildings.append({"id": "house", "cell": cells[5],
		"footprint": [[0, 0], [1, 0]], "fixture_starting": true})
	var multi_cells := CampaignBuildingPlacement.footprint_cells(cells[5], [[0, 0], [1, 0]])
	city.campaign_buildings.append({"id": "in_progress", "cell": cells[8],
		"footprint": [[0, 0]], "construction_turns_remaining": 2, "state": "inactive"})
	city.campaign_buildings.append({"id": "ruin", "cell": cells[9],
		"footprint": [[0, 0]], "state": "ruined"})
	var occupied := CampaignCityProgression.occupied_cells(city)
	assert_that(occupied.size()).is_equal(4 + 1 + multi_cells.size() + 1 + 1)
	for cell in city.core_cells + [cells[4], cells[8], cells[9]] + multi_cells:
		assert_bool(occupied.has(cell)).is_true()

func test_construction_check_counts_only_new_unique_cells_and_reports_limit() -> void:
	var city := _city()
	city.level = 2
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	var first := CampaignCityProgression.construction_check(city, [cells[4], cells[4]])
	assert_bool(first.ok).is_true()
	assert_that(first.used).is_equal(4)
	assert_that(first.added).is_equal(1)
	assert_that(first.projected).is_equal(5)
	assert_that(first.limit).is_equal(9)
	var too_many := CampaignCityProgression.construction_check(city,
		[cells[4], cells[5], cells[6], cells[7], cells[8], cells[9]])
	assert_bool(too_many.ok).is_false()
	assert_that(too_many.reason).is_equal("city_capacity")
	assert_that(too_many.projected).is_equal(10)
	assert_that(too_many.remaining).is_equal(5)

func test_level_up_requires_current_allowance_and_level_11_is_terminal() -> void:
	var city := TestFactories.make_city()
	var blocked := CampaignCityProgression.level_up_check(city)
	assert_bool(blocked.ok).is_false()
	assert_that(blocked.reason).is_equal("allowance_not_full")
	assert_that(blocked.missing).is_equal(3)
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	city.core_cells = HexUtils.core_cells(city.center)
	city.campaign_buildings.append_array([
		{"id": "starter_a", "cell": cells[4], "footprint": [[0, 0]]},
		{"id": "starter_b", "cell": cells[5], "footprint": [[0, 0]]},
	])
	var upgraded := CampaignCityProgression.try_level_up(city)
	assert_bool(upgraded.ok).is_true()
	assert_that(city.level).is_equal(2)
	assert_that(upgraded.limit).is_equal(9)
	city.level = 11
	var maximum := CampaignCityProgression.try_level_up(city)
	assert_bool(maximum.ok).is_false()
	assert_that(maximum.reason).is_equal("maximum_level")
	assert_that(CampaignCityProgression.cell_limit(city.level)).is_equal(52)

func test_full_52_cell_city_requires_level_11() -> void:
	var city := _city()
	var cells := CampaignBuildingPlacement.city_cells(city.center)
	city.level = 10
	for index in range(4, 48):
		city.campaign_buildings.append({"id": "building_%d" % index,
			"cell": cells[index], "footprint": [[0, 0]]})
	assert_that(CampaignCityProgression.occupied_cells(city).size()).is_equal(48)
	var remaining_cells: Array[Vector2i] = []
	for index in range(48, cells.size()):
		remaining_cells.append(cells[index])
	var level_ten := CampaignCityProgression.construction_check(city, remaining_cells)
	assert_bool(level_ten.ok).is_false()
	assert_that(level_ten.projected).is_equal(52)
	city.level = 11
	var level_eleven := CampaignCityProgression.construction_check(city, remaining_cells)
	assert_bool(level_eleven.ok).is_true()
	assert_that(level_eleven.projected).is_equal(52)
