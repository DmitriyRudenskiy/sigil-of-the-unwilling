extends BaseTest

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const MVP_CATALOG_PATH := "res://assets/data/mvp_catalog.json"

func _mvp_catalog() -> Dictionary:
	var file := FileAccess.open(MVP_CATALOG_PATH, FileAccess.READ)
	assert_that(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_bool(parsed is Dictionary).is_true()
	return parsed

func _references() -> Dictionary:
	var mvp := _mvp_catalog()
	var groups: Array[String] = []
	var needs: Array[String] = ["community_mediation"]
	var classes: Array[String] = []
	for group in mvp.get("groups", []):
		groups.append(String(group.id))
		var need := String(group.get("signature_need", ""))
		if not need.is_empty() and not needs.has(need):
			needs.append(need)
	for record in mvp.get("classes", []):
		if bool(record.get("hireable", false)):
			classes.append(String(record.id))
	return {
		"resources": ["food", "wood", "iron"],
		"groups": groups,
		"needs": needs,
		"trainable_classes": classes,
		"terrain_tags": [],
		"scenario_flags": [],
	}

func test_shipped_campaign_building_catalog_loads_and_validates() -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	assert_bool(catalog.is_empty()).is_false()
	assert_that(catalog.get("buildings", []).size()).is_equal(98)
	var errors := CampaignBuildingCatalog.validate_catalog(catalog, _references())
	assert_that(errors.is_empty()).override_failure_message("shipped catalog invalid: %s" % [errors])
	assert_bool(_contains_null(catalog)).is_false()

func test_runtime_records_have_only_resolved_sources_and_custom_merge_inputs() -> void:
	var catalog := CampaignBuildingCatalog.load_catalog()
	var reference_rows := {}
	for building in catalog.buildings:
		for source in building.source_refs:
			if source.game == "sigil_of_the_unwilling":
				continue
			reference_rows[source.entry] = true
	assert_bool(reference_rows.has("AOE-C-001")).is_true()
	assert_bool(reference_rows.has("TS-M-001")).is_true()
	assert_bool(reference_rows.has("ATS-STEAM-1.11:board-game-piece")).is_false()
	var fruit_farm := _find_building(catalog, "terrascape_fruit_farm")
	assert_that(fruit_farm.merge.components).contains_exactly(["campaign_farm", "campaign_farm"])
	assert_bool(catalog.get("excluded_confirmed", []).size() > 0).is_true()

func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for building in catalog.get("buildings", []):
		if String(building.get("id", "")) == building_id:
			return building
	return {}

func _contains_null(value: Variant) -> bool:
	if value == null:
		return true
	if value is Dictionary:
		for child in value.values():
			if _contains_null(child):
				return true
	elif value is Array:
		for child in value:
			if _contains_null(child):
				return true
	return false
