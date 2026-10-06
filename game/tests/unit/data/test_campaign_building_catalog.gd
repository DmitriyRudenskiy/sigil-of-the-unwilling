extends BaseTest

const CampaignBuildingCatalog = preload("res://scripts/data/campaign_building_catalog.gd")

func _references() -> Dictionary:
	return {
		"resources": ["food", "wood", "iron"],
		"groups": ["engineers_builders"],
		"needs": ["education"],
		"trainable_classes": ["fighter"],
		"terrain_tags": ["grass"],
		"scenario_flags": ["founding_open"],
	}

func _building(id: String, role: String = "agriculture") -> Dictionary:
	return {
		"id": id,
		"source_refs": [{
			"game": "terrascape", "entry": id, "version": "1.1.1.2",
			"url": "https://example.org/%s" % id,
		}],
		"roles": [role],
		"footprint": [[0, 0]],
		"placement": {"terrain_tags": ["grass"], "requires_special_site": false},
		"costs": {"wood": 2},
		"upkeep": {},
		"jobs": 2,
		"resident_capacity": 2,
		"construction_turns": 1,
		"recipes": [{"id": "produce_food", "workers": 1, "inputs": {}, "outputs": {"food": 1}}],
		"services": {"education": 1},
		"group_affinities": {"engineers_builders": 10},
		"adjacency": [],
		"merge": {},
		"prerequisites": {"buildings": [], "admin_capacity": 0, "scenario_flags": []},
		"training": [],
		"defense": {"active": 0, "inactive": 0, "ruined": 0},
		"state_effects": {"active": {"production_bp": 10000}, "inactive": {}, "ruined": {}},
	}

func _catalog() -> Dictionary:
	var farm := _building("farm")
	var mill := _building("mill", "milling")
	var bakery := _building("bakery", "food_production")
	bakery.merge = {"components": ["farm", "mill"], "max_distance": 1}
	bakery.prerequisites.buildings = ["farm"]
	bakery.prerequisites.scenario_flags = ["founding_open"]
	bakery.adjacency = [{
		"id": "near_farm", "target_role": "agriculture", "radius": 1,
		"effect": "output_bp", "value": 500,
	}]
	bakery.training = [{"class_id": "fighter", "costs": {"food": 3}}]
	return {"schema_version": 1, "buildings": [farm, mill, bakery]}

func test_valid_catalog_resolves_all_declared_references() -> void:
	var errors := CampaignBuildingCatalog.validate_catalog(_catalog(), _references())
	assert_that(errors.is_empty()).override_failure_message("валидный каталог отклонён: %s" % [errors])

func test_invalid_references_are_reported() -> void:
	var catalog := _catalog()
	var farm: Dictionary = catalog.buildings[0]
	farm.costs["amber"] = 1
	farm.services["resolve"] = 1
	farm.group_affinities["unknown_group"] = 1
	var bakery: Dictionary = catalog.buildings[2]
	bakery.merge.components = ["missing_building"]
	bakery.prerequisites.buildings = ["missing_prerequisite"]
	bakery.prerequisites.scenario_flags = ["unknown_flag"]
	bakery.adjacency[0].target_role = "unknown_role"
	bakery.adjacency[0].value = 10001
	bakery.adjacency.append({
		"id": "near_farm", "target_role": "agriculture", "radius": 1,
		"effect": "output_bp", "value": 500,
	})
	bakery.training[0].class_id = "sorcerer"
	var errors := CampaignBuildingCatalog.validate_catalog(catalog, _references())
	assert_that(_has_error(errors, "unregistered resource 'amber'")).is_true()
	assert_that(_has_error(errors, "unknown service 'resolve'")).is_true()
	assert_that(_has_error(errors, "unknown archetype 'unknown_group'")).is_true()
	assert_that(_has_error(errors, "unknown building 'missing_building'")).is_true()
	assert_that(_has_error(errors, "unknown building 'missing_prerequisite'")).is_true()
	assert_that(_has_error(errors, "unknown target role 'unknown_role'")).is_true()
	assert_that(_has_error(errors, "within +/-10000 basis points")).is_true()
	assert_that(_has_error(errors, "unapproved class 'sorcerer'")).is_true()
	assert_that(_has_error(errors, "unknown scenario flag 'unknown_flag'")).is_true()
	assert_that(_has_error(errors, "id duplicates 'near_farm'")).is_true()

func test_prerequisites_use_buildings_flags_and_admin_capacity_without_deleting_entities() -> void:
	var catalog := _catalog()
	var bakery: Dictionary = catalog.buildings[2]
	bakery.prerequisites.admin_capacity = 2
	var existing_entities := ["farm", "mill", "resident_1", "resident_2"]
	var satisfied := CampaignBuildingCatalog.check_prerequisites(
		bakery, ["farm"], ["founding_open"], 2)
	assert_bool(satisfied.ok).is_true()
	var capacity_lost := CampaignBuildingCatalog.check_prerequisites(
		bakery, ["farm"], ["founding_open"], 1)
	assert_bool(capacity_lost.ok).is_false()
	assert_that(capacity_lost.missing).contains("admin_capacity:1/2")
	assert_that(existing_entities).contains_exactly(["farm", "mill", "resident_1", "resident_2"])

func test_invalid_footprint_and_missing_source_are_reported() -> void:
	var catalog := _catalog()
	var farm: Dictionary = catalog.buildings[0]
	farm.footprint = [[1, 0], [1, 0]]
	farm.roles = "agriculture"
	farm.placement.terrain_tags = "grass"
	farm.source_refs[0].url = "not-a-url"
	var errors := CampaignBuildingCatalog.validate_catalog(catalog, _references())
	assert_that(_has_error(errors, "duplicate cell 1,0")).is_true()
	assert_that(_has_error(errors, "must contain anchor [0, 0]")).is_true()
	assert_that(_has_error(errors, "url must be HTTP(S)")).is_true()
	assert_that(_has_error(errors, "buildings[0].roles must be an array")).is_true()
	assert_that(_has_error(errors, "buildings[0].placement.terrain_tags must be an array")).is_true()

func _has_error(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
