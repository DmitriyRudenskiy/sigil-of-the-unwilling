extends BaseTest

const CampaignBuildingPlacement = preload("res://scripts/city/campaign_building_placement.gd")
const HexUtils = preload("res://scripts/core/hex_utils.gd")
const ArenaRingSystem = preload("res://scripts/city/arena_ring_system.gd")

func _building(id: String, roles: Array, cell: Vector2i, adjacency: Array = [], footprint: Array = [[0, 0]]) -> Dictionary:
	return {"id": id, "roles": roles, "cell": cell, "footprint": footprint, "adjacency": adjacency}

func test_city_layout_is_52_cells_and_placement_respects_terrain_and_occupancy() -> void:
	var cells := CampaignBuildingPlacement.city_cells()
	assert_that(cells.size()).is_equal(52)
	var anchor := ArenaRingSystem.center()
	var building := {
		"footprint": [[0, 0]],
		"placement": {"terrain_tags": ["grass"], "requires_special_site": false},
	}
	var legal := CampaignBuildingPlacement.explain_placement(building, anchor, {anchor: "grass"}, {})
	assert_bool(legal.ok).is_true()
	assert_that(legal.cells).is_equal([anchor])
	var wrong_terrain := CampaignBuildingPlacement.explain_placement(building, anchor, {anchor: "sand"}, {})
	assert_bool(wrong_terrain.ok).is_false()
	assert_that(wrong_terrain.issues.size()).is_equal(1)
	var occupied := CampaignBuildingPlacement.explain_placement(building, anchor, {anchor: "grass"}, {anchor: "farm"})
	assert_bool(occupied.ok).is_false()
	assert_that(occupied.issues[0]).contains("occupied")

func test_multicell_footprint_and_special_site_constraints() -> void:
	var anchor := ArenaRingSystem.center()
	var building := {
		"footprint": [[0, 0], [1, 0]],
		"placement": {"terrain_tags": [], "requires_special_site": true},
	}
	var cells := CampaignBuildingPlacement.footprint_cells(anchor, building.footprint)
	assert_that(cells.size()).is_equal(2)
	var sites := {cells[0]: "spring", cells[1]: "spring"}
	var legal := CampaignBuildingPlacement.explain_placement(building, anchor, {}, {}, sites)
	assert_bool(legal.ok).is_true()
	var blocked := CampaignBuildingPlacement.explain_placement(building, anchor, {}, {}, {cells[1]: "spring"})
	assert_bool(blocked.ok).is_false()
	assert_that(blocked.issues[0]).contains("anchor")

func test_footprint_cannot_extend_outside_the_52_cell_city() -> void:
	var cells := CampaignBuildingPlacement.city_cells()
	var city_set := {}
	for cell in cells:
		city_set[cell] = true
	var anchor := cells[0]
	var invalid_footprint: Array = [[0, 0]]
	for q in range(-4, 5):
		for r in range(-4, 5):
			var candidate := [[0, 0], [q, r]]
			var placement := CampaignBuildingPlacement.footprint_cells(anchor, candidate)
			if placement.size() == 2 and not city_set.has(placement[1]):
				invalid_footprint = candidate
				break
		if invalid_footprint.size() == 2:
			break
	var result := CampaignBuildingPlacement.explain_placement({
		"footprint": invalid_footprint,
		"placement": {"terrain_tags": [], "requires_special_site": false},
	}, anchor, {}, {})
	assert_bool(result.ok).is_false()
	assert_bool(_has_issue(result.issues, "outside the 52-cell city")).is_true()

func test_adjacency_uses_hex_radius_and_exposes_causes() -> void:
	var center := ArenaRingSystem.center()
	var near := HexUtils.get_neighbor(center, 0, true)
	var far := HexUtils.get_neighbor(near, 0, true)
	var workshop := _building("workshop", ["crafting"], center)
	var adjacency := [{"id": "crafting_near_farm", "target_role": "crafting", "radius": 1,
		"effect": "output_bp", "value": 500}]
	var farm := _building("farm", ["agriculture"], near, adjacency)
	var nearby := CampaignBuildingPlacement.explain_adjacency(workshop, center, [farm])
	assert_that(float(nearby.effects.output_bp)).is_equal(500.0)
	assert_that(nearby.causes.size()).is_equal(1)
	assert_that(nearby.causes[0].source_id).is_equal("farm")
	var distant_farm := _building("farm", ["agriculture"], far, adjacency)
	var distant := CampaignBuildingPlacement.explain_adjacency(workshop, center, [distant_farm])
	assert_bool(distant.effects.is_empty()).is_true()

func test_adjacency_stacking_is_bounded_and_recomputed_deterministically() -> void:
	var center := ArenaRingSystem.center()
	var target := _building("workshop", ["crafting"], center)
	var rule := [{"id": "farm_bonus", "target_role": "crafting", "radius": 1,
		"effect": "output_bp", "value": 7000}]
	var farms := [
		_building("farm_b", ["agriculture"], HexUtils.get_neighbor(center, 0, true), rule),
		_building("farm_a", ["agriculture"], HexUtils.get_neighbor(center, 1, true), rule),
	]
	var initial := CampaignBuildingPlacement.recompute_adjacency([target] + farms)
	var target_result: Dictionary = _find_building_result(initial, "workshop")
	assert_that(float(target_result.breakdown.effects.output_bp)).is_equal(10000.0)
	assert_that(target_result.breakdown.causes.size()).is_equal(2)
	var repeated := CampaignBuildingPlacement.recompute_adjacency(farms + [target])
	assert_that(repeated).is_equal(initial)
	var without_one := CampaignBuildingPlacement.recompute_adjacency([target, farms[0]])
	assert_that(float(_find_building_result(without_one, "workshop").breakdown.effects.output_bp)).is_equal(7000.0)

func test_inactive_or_ruined_buildings_do_not_supply_adjacency_effects() -> void:
	var center := ArenaRingSystem.center()
	var target := _building("workshop", ["crafting"], center)
	var rule := [{"id": "farm_bonus", "target_role": "crafting", "radius": 1,
		"effect": "output_bp", "value": 1500}]
	var source := _building("farm", ["agriculture"], HexUtils.get_neighbor(center, 0, true), rule)
	source["state"] = "inactive"
	var no_active_source := CampaignBuildingPlacement.explain_adjacency(target, center, [source])
	assert_bool(no_active_source.effects.is_empty()).is_true()
	source["state"] = "active"
	target["state"] = "ruined"
	var no_active_target := CampaignBuildingPlacement.explain_adjacency(target, center, [source])
	assert_bool(no_active_target.effects.is_empty()).is_true()

func _find_building_result(results: Array[Dictionary], id: String) -> Dictionary:
	for result in results:
		if result.building_id == id:
			return result
	return {}

func _has_issue(issues: Array, fragment: String) -> bool:
	for issue in issues:
		if String(issue).contains(fragment):
			return true
	return false
