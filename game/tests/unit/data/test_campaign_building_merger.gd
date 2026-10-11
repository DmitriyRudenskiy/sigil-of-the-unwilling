extends BaseTest

const CampaignBuildingMerger = preload("res://scripts/city/campaign_building_merger.gd")
const CampaignBuildingCatalog = preload("res://scripts/data/campaign_building_catalog.gd")
const HexUtils = preload("res://scripts/core/hex_utils.gd")
const ArenaRingSystem = preload("res://scripts/city/arena_ring_system.gd")

func _result_definition(components: Array = ["farm", "mill"], max_distance: int = 1) -> Dictionary:
	return {
		"id": "bakery", "jobs": 4, "resident_capacity": 3,
		"footprint": [[0, 0]], "placement": {"terrain_tags": [], "requires_special_site": false},
		"roles": ["food_production"], "services": {"education": 1},
		"merge": {"components": components, "max_distance": max_distance},
	}

func _components() -> Array:
	var center := ArenaRingSystem.center()
	return [
		{"uid": 1, "id": "farm", "cell": center, "footprint": [[0, 0]], "state": "active",
			"assigned_workers": 1, "resident_ids": ["r1"], "resident_capacity": 2, "stock": {"wood": 2.0},
			"production_remainders": {"r/food": 5500.0}},
		{"uid": 2, "id": "mill", "cell": HexUtils.get_neighbor(center, 0, true), "footprint": [[0, 0]], "state": "inactive",
			"assigned_workers": 1, "resident_ids": ["r2"], "resident_capacity": 2, "stock": {"wood": 1.0, "iron": 1.0},
			"production_remainders": {"r/food": 5500.0}},
	]

func test_valid_merge_transfers_state_without_copying_capacity_or_stock() -> void:
	var before := _components()
	var merged := CampaignBuildingMerger.merge(before, _result_definition(), [1, 2])
	assert_bool(merged.ok).is_true()
	assert_that(merged.buildings.size()).is_equal(1)
	var result: Dictionary = merged.result
	assert_that(result.id).is_equal("bakery")
	assert_that(result.state).is_equal("inactive")
	assert_that(result.assigned_workers).is_equal(2)
	assert_that(result.resident_capacity).is_equal(3)
	assert_that(result.resident_ids).contains_exactly(["r1", "r2"])
	assert_that(float(result.stock.wood)).is_equal(3.0)
	assert_that(float(result.stock.iron)).is_equal(1.0)
	assert_that(float(result.production_remainders["r/food"])).is_equal(11000.0)
	assert_that(before[0].resident_capacity + before[1].resident_capacity).is_equal(4)
	assert_that(result.resident_capacity).is_not_equal(4)

func test_invalid_merge_is_atomic_for_missing_components_and_distance() -> void:
	var before := _components()
	var missing := CampaignBuildingMerger.merge(before, _result_definition(), [1, 99])
	assert_bool(missing.ok).is_false()
	assert_that(missing.reason).contains("does not exist")
	assert_that(before.size()).is_equal(2)
	var far_buildings := _components()
	far_buildings[1].cell = HexUtils.get_neighbor(HexUtils.get_neighbor(ArenaRingSystem.center(), 0, true), 0, true)
	var too_far := CampaignBuildingMerger.merge(far_buildings, _result_definition(), [1, 2])
	assert_bool(too_far.ok).is_false()
	assert_that(too_far.reason).contains("exceed merge distance")
	assert_that(far_buildings.size()).is_equal(2)

func test_merge_rejects_worker_or_resident_loss() -> void:
	var workers := _components()
	workers[1].assigned_workers = 4
	var no_job_room := CampaignBuildingMerger.merge(workers, _result_definition(), [1, 2])
	assert_bool(no_job_room.ok).is_false()
	assert_that(no_job_room.reason).contains("workers exceed")
	var residents := _components()
	var small_house := _result_definition()
	small_house.resident_capacity = 1
	var no_house_room := CampaignBuildingMerger.merge(residents, small_house, [1, 2])
	assert_bool(no_house_room.ok).is_false()
	assert_that(no_house_room.reason).contains("cannot house")
	assert_that(residents.size()).is_equal(2)

func test_catalog_rejects_merge_graph_cycles_and_allows_repeated_component_types() -> void:
	var catalog := {
		"schema_version": 1,
		"buildings": [
			{"id": "farm", "merge": {"components": ["bakery", "farm"], "max_distance": 1}},
			{"id": "mill", "merge": {}},
			{"id": "bakery", "merge": {"components": ["farm", "farm"], "max_distance": 1}},
		],
	}
	var errors := CampaignBuildingCatalog.validate_catalog(catalog, {})
	assert_bool(_has_error(errors, "merge graph contains a cycle")).is_true()
	assert_bool(_has_error(errors, "contains duplicate building")).is_false()

func _has_error(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
