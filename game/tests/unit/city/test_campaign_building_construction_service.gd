extends BaseTest

const ConstructionService := preload("res://scripts/city/campaign_building_construction_service.gd")
const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const TestFactories := preload("res://tests/helpers/factories.gd")

func _city() -> City:
	var city := TestFactories.make_city()
	city.center = Vector2i(20, 20)
	city.level = 11
	city.core_cells = HexUtils.core_cells(city.center)
	city.resource_ctx = ResourceContext.new()
	city.resource_ctx.setup(Resources.get_campaign_resource_defs(true), true)
	city.resource_ctx.add(&"wood", 20.0)
	city.resource_ctx.add(&"iron", 10.0)
	return city

func test_preview_validates_site_relative_to_actual_city_center() -> void:
	var city := _city()
	var catalog := CampaignBuildingCatalog.load_catalog()
	var site := HexUtils.cells_in_core_ring(city.center, 1)[0]
	var result := ConstructionService.explain_request(
		city, catalog, "campaign_farm", site)
	assert_bool(result.ok).is_true()
	assert_that(result.placement.cells).is_equal([site])
	assert_bool(ConstructionService.explain_request(
		city, catalog, "campaign_farm", Vector2i(5, 4)).ok).is_false()
	assert_that(city.campaign_buildings).is_empty()
	assert_that(city.resource_ctx.get_ledger()).is_empty()
	assert_float(city.resource_ctx.amount(&"wood")).is_equal_approx(20.0, 0.0001)

func test_preview_rejects_unknown_prerequisite_shortage_and_occupied_site_without_writes() -> void:
	var city := _city()
	var catalog := CampaignBuildingCatalog.load_catalog()
	var site := HexUtils.cells_in_core_ring(city.center, 1)[0]
	var farm := _find_building(catalog, "campaign_farm")
	farm.prerequisites.buildings = ["campaign_sawmill"]
	var prerequisite := ConstructionService.explain_request(city, catalog, "campaign_farm", site)
	assert_bool(prerequisite.ok).is_false()
	assert_that(prerequisite.reason).is_equal("prerequisite_missing")

	farm.prerequisites.buildings = []
	city.resource_ctx.deserialize({"food": 0.0, "wood": 0.0, "iron": 0.0})
	var shortage := ConstructionService.explain_request(city, catalog, "campaign_farm", site)
	assert_bool(shortage.ok).is_false()
	assert_that(shortage.reason).is_equal("insufficient_stock")
	assert_float(float(shortage.missing.wood)).is_equal_approx(4.0, 0.0001)

	city.resource_ctx.add(&"wood", 20.0)
	var legacy := UniqueBuilding.new()
	legacy.cell = site
	city.buildings.append(legacy)
	var occupied := ConstructionService.explain_request(city, catalog, "campaign_farm", site)
	assert_bool(occupied.ok).is_false()
	assert_that(occupied.reason).is_equal("placement_blocked")
	assert_that(city.campaign_buildings).is_empty()
	assert_float(city.resource_ctx.amount(&"wood")).is_equal_approx(20.0, 0.0001)
	assert_that(city.resource_ctx.get_ledger()).is_empty()

func test_request_spends_once_and_persists_in_progress_instance() -> void:
	var city := _city()
	var catalog := CampaignBuildingCatalog.load_catalog()
	var site := HexUtils.cells_in_core_ring(city.center, 1)[0]
	var result := ConstructionService.request(city, catalog, "campaign_farm", site)
	assert_bool(result.ok).is_true()
	assert_that(result.instance.uid).is_equal(0)
	assert_that(result.instance.cell).is_equal(site)
	assert_that(result.instance.state).is_equal("inactive")
	assert_that(result.instance.construction_turns_remaining).is_equal(1)
	assert_that(result.instance.paid_costs).is_equal({"wood": 4.0})
	assert_float(city.resource_ctx.amount(&"wood")).is_equal_approx(16.0, 0.0001)
	assert_that(result.flow.source).is_equal("construction:campaign_farm")
	assert_that(city.resource_ctx.get_ledger().size()).is_equal(1)

	var duplicate := ConstructionService.request(city, catalog, "campaign_farm", site)
	assert_bool(duplicate.ok).is_false()
	assert_that(duplicate.reason).is_equal("placement_blocked")
	assert_that(city.campaign_buildings.size()).is_equal(1)
	assert_float(city.resource_ctx.amount(&"wood")).is_equal_approx(16.0, 0.0001)
	assert_that(city.resource_ctx.get_ledger().size()).is_equal(1)

func test_zero_turn_request_is_active_immediately() -> void:
	var city := _city()
	var catalog := CampaignBuildingCatalog.load_catalog()
	_find_building(catalog, "campaign_farm")["construction_turns"] = 0
	var site := HexUtils.cells_in_core_ring(city.center, 1)[0]
	var result := ConstructionService.request(city, catalog, "campaign_farm", site)
	assert_bool(result.ok).is_true()
	assert_that(result.instance.state).is_equal("active")
	assert_that(result.instance.construction_turns_remaining).is_zero()

func test_level_one_capacity_rejects_before_resource_transaction() -> void:
	var city := _city()
	city.level = 1
	city.core_cells.clear()
	var catalog := CampaignBuildingCatalog.load_catalog()
	var sites := HexUtils.cells_in_core_ring(city.center, 1)
	for index in range(3):
		var result := ConstructionService.request(city, catalog, "campaign_farm", sites[index])
		assert_bool(result.ok).is_true()
	var ledger_before: Array = city.resource_ctx.get_ledger().duplicate(true)
	var buildings_before := city.campaign_buildings.size()
	var stock_before := city.resource_ctx.amount(&"wood")
	var blocked := ConstructionService.request(city, catalog, "campaign_farm", sites[3])
	assert_bool(blocked.ok).is_false()
	assert_that(blocked.reason).is_equal("city_capacity")
	assert_that(blocked.level).is_equal(1)
	assert_that(blocked.used).is_equal(4)
	assert_that(blocked.limit).is_equal(4)
	assert_that(city.campaign_buildings.size()).is_equal(buildings_before)
	assert_float(city.resource_ctx.amount(&"wood")).is_equal_approx(stock_before, 0.0001)
	assert_that(city.resource_ctx.get_ledger()).is_equal(ledger_before)

func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for building in catalog.get("buildings", []):
		if building is Dictionary and String(building.get("id", "")) == building_id:
			return building
	return {}
