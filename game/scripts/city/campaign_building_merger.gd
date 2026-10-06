class_name CampaignBuildingMerger
extends RefCounted

const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")

static func merge(
	buildings: Array,
	result_definition: Dictionary,
	component_uids: Array,
	environment: Dictionary = {}
) -> Dictionary:
	var recipe: Variant = result_definition.get("merge", {})
	if not (recipe is Dictionary) or not (recipe.get("components", []) is Array):
		return _failure("merge recipe is missing")
	var expected: Array = recipe.get("components", [])
	if expected.size() < 2 or component_uids.size() != expected.size():
		return _failure("selected components do not match the recipe")
	var selected_uids := {}
	for uid in component_uids:
		if selected_uids.has(uid):
			return _failure("component instance selected more than once")
		selected_uids[uid] = true
	var instances_by_uid := {}
	for building in buildings:
		if building is Dictionary:
			var uid: Variant = building.get("uid", -1)
			if instances_by_uid.has(uid):
				return _failure("duplicate building instance uid %s" % uid)
			instances_by_uid[uid] = building
	var selected: Array[Dictionary] = []
	var actual_counts := {}
	for uid in component_uids:
		if not instances_by_uid.has(uid):
			return _failure("component instance %s does not exist" % uid)
		var instance: Dictionary = instances_by_uid[uid]
		selected.append(instance)
		var id := String(instance.get("id", ""))
		actual_counts[id] = int(actual_counts.get(id, 0)) + 1
	var expected_counts := {}
	for id in expected:
		expected_counts[String(id)] = int(expected_counts.get(String(id), 0)) + 1
	if actual_counts != expected_counts:
		return _failure("selected building types do not match the recipe")
	var max_distance := int(recipe.get("max_distance", 0))
	if max_distance < 1:
		return _failure("merge recipe has no valid max_distance")
	for i in range(selected.size()):
		for j in range(i + 1, selected.size()):
			var a: Vector2i = selected[i].get("cell", Vector2i.ZERO)
			var b: Vector2i = selected[j].get("cell", Vector2i.ZERO)
			if HexUtils.hex_distance(a, b, true) > max_distance:
				return _failure("components exceed merge distance %d" % max_distance)

	var anchor := _anchor_of(selected)
	var workers := 0
	var residents: Array = []
	var resident_set := {}
	var stock := {}
	var production_remainders := {}
	var all_active := true
	var any_ruined := false
	for component in selected:
		workers += int(component.get("assigned_workers", 0))
		if int(component.get("assigned_workers", 0)) < 0:
			return _failure("component has a negative worker assignment")
		var component_state := String(component.get("state", "active"))
		all_active = all_active and component_state == "active"
		any_ruined = any_ruined or component_state == "ruined"
		for resident_id in component.get("resident_ids", []):
			if resident_set.has(resident_id):
				return _failure("resident %s is assigned to multiple components" % resident_id)
			resident_set[resident_id] = true
			residents.append(resident_id)
		for resource_id in component.get("stock", {}):
			var amount := float(component.stock[resource_id])
			if not is_finite(amount) or amount < 0.0:
				return _failure("component stock must be a non-negative finite amount")
			stock[resource_id] = float(stock.get(resource_id, 0.0)) + amount
		for key in component.get("production_remainders", {}):
			var remainder := float(component.production_remainders[key])
			if not is_finite(remainder) or remainder < 0.0:
				return _failure("component production remainder must be non-negative and finite")
			production_remainders[key] = float(production_remainders.get(key, 0.0)) + remainder
	if workers > int(result_definition.get("jobs", 0)):
		return _failure("assigned workers exceed result building jobs")
	if residents.size() > int(result_definition.get("resident_capacity", 0)):
		return _failure("result building cannot house all assigned residents")

	var occupied := {}
	for building in buildings:
		if not (building is Dictionary) or selected_uids.has(building.get("uid", -1)):
			continue
		var cells := CampaignBuildingPlacement.footprint_cells(
			building.get("cell", Vector2i.ZERO), building.get("footprint", [[0, 0]]))
		for cell in cells:
			occupied[cell] = true
	var placement := CampaignBuildingPlacement.explain_placement(
		result_definition, anchor,
		environment.get("terrain_by_cell", {}), occupied,
		environment.get("special_sites", {}))
	if not placement.ok:
		return _failure("result placement blocked: %s" % "; ".join(placement.issues))

	var result_building := result_definition.duplicate(true)
	result_building["uid"] = _next_uid(buildings)
	result_building["cell"] = anchor
	result_building["state"] = "ruined" if any_ruined else ("active" if all_active else "inactive")
	result_building["assigned_workers"] = workers
	result_building["resident_ids"] = residents
	result_building["resident_capacity"] = int(result_definition.get("resident_capacity", 0))
	result_building["stock"] = stock
	result_building["production_remainders"] = production_remainders
	var next_buildings: Array = []
	for building in buildings:
		if not (building is Dictionary) or not selected_uids.has(building.get("uid", -1)):
			next_buildings.append(building.duplicate(true) if building is Dictionary else building)
	next_buildings.append(result_building)
	return {
		"ok": true,
		"buildings": next_buildings,
		"result": result_building,
		"removed_uids": component_uids.duplicate(),
		"placement": placement,
	}

static func _anchor_of(selected: Array[Dictionary]) -> Vector2i:
	var anchor: Vector2i = selected[0].get("cell", Vector2i.ZERO)
	for building in selected:
		var cell: Vector2i = building.get("cell", Vector2i.ZERO)
		if cell.y < anchor.y or (cell.y == anchor.y and cell.x < anchor.x):
			anchor = cell
	return anchor

static func _next_uid(buildings: Array) -> int:
	var next_id := 1
	for building in buildings:
		if building is Dictionary:
			next_id = maxi(next_id, int(building.get("uid", 0)) + 1)
	return next_id

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
