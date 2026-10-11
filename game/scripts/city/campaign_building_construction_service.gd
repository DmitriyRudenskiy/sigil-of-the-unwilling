class_name CampaignBuildingConstructionService
extends RefCounted

const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CampaignCityProgression := preload("res://scripts/city/campaign_city_progression.gd")

static func request(
	city: City,
	catalog: Dictionary,
	building_id: String,
	anchor: Vector2i,
	terrain_by_cell: Dictionary = {},
	scenario_flags: Array = [],
	admin_capacity: int = 0
) -> Dictionary:
	var check := explain_request(city, catalog, building_id, anchor, terrain_by_cell,
		scenario_flags, admin_capacity)
	if not check.ok:
		return check
	var resources := city.ensure_resource_ctx(Resources.get_campaign_resource_defs(true))
	var costs: Dictionary = check.costs
	var paid := resources.transact(costs, {}, "construction:%s" % building_id) \
		if not costs.is_empty() else {"ok": true, "flow": {}}
	if not paid.ok:
		return {"ok": false, "reason": String(paid.get("reason", "payment_failed")),
			"missing": paid.get("missing", {})}
	var instance: Dictionary = check.building.duplicate(true)
	var uid := city._uid_seq
	for existing in city.campaign_buildings:
		if existing is Dictionary:
			uid = maxi(uid, int(existing.get("uid", -1)) + 1)
	city._uid_seq = uid + 1
	instance["uid"] = uid
	instance["cell"] = anchor
	instance["state"] = "inactive" if int(check.construction_turns) > 0 else "active"
	instance["construction_turns_remaining"] = int(check.construction_turns)
	instance["paid_costs"] = costs.duplicate(true)
	instance["assigned_workers"] = 0
	instance["resident_ids"] = []
	city.campaign_buildings.append(instance)
	city.buildings_changed.emit()
	return {"ok": true, "instance": instance.duplicate(true), "flow": paid.get("flow", {})}

## Validate against a catalog already loaded and structurally validated by the caller.
static func explain_request(
	city: City,
	catalog: Dictionary,
	building_id: String,
	anchor: Vector2i,
	terrain_by_cell: Dictionary = {},
	scenario_flags: Array = [],
	admin_capacity: int = 0
) -> Dictionary:
	if city == null:
		return _failure("no_city")
	var definition := _find_building(catalog, building_id)
	if definition.is_empty():
		return _failure("unknown_building:%s" % building_id)
	var costs: Variant = definition.get("costs", {})
	if not (costs is Dictionary):
		return _failure("invalid_costs")
	for resource_id in costs:
		if not ResourceRegistry.CAMPAIGN_MVP_IDS.has(StringName(resource_id)):
			return _failure("unregistered_resource:%s" % String(resource_id))
		var amount: Variant = costs[resource_id]
		if (typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT) \
				or not is_finite(float(amount)) or float(amount) <= 0.0:
			return _failure("invalid_cost:%s" % String(resource_id))

	var built_ids: Array[String] = []
	for instance in city.campaign_buildings:
		if not (instance is Dictionary):
			continue
		if int(instance.get("construction_turns_remaining", 0)) > 0 \
				or String(instance.get("state", "active")) == "ruined":
			continue
		built_ids.append(String(instance.get("id", "")))
	var prerequisites := CampaignBuildingCatalog.check_prerequisites(
		definition, built_ids, scenario_flags, admin_capacity)
	if not prerequisites.ok:
		return {"ok": false, "reason": "prerequisite_missing", "missing": prerequisites.missing}

	var occupied := _occupied_cells(city)
	var placement := CampaignBuildingPlacement.explain_placement(
		definition, anchor, terrain_by_cell, occupied, city.special_sites, city.center)
	if placement.ok and city.is_buildable_fn.is_valid():
		for cell in placement.cells:
			if not bool(city.is_buildable_fn.call(cell)):
				placement.issues.append("footprint cell %s is not buildable" % cell)
		placement.ok = placement.issues.is_empty()
	if not placement.ok:
		return {"ok": false, "reason": "placement_blocked", "issues": placement.issues,
			"placement": placement}

	var capacity := CampaignCityProgression.construction_check(city, placement.cells)
	if not bool(capacity.get("ok", false)):
		capacity["placement"] = placement
		return capacity

	var missing := {}
	for resource_id in costs:
		var available := _amount(city, StringName(resource_id))
		var shortage := float(costs[resource_id]) - available
		if shortage > 0.0001:
			missing[String(resource_id)] = shortage
	if not missing.is_empty():
		return {"ok": false, "reason": "insufficient_stock", "missing": missing,
			"placement": placement}
	return {"ok": true, "building": definition.duplicate(true), "costs": costs.duplicate(true),
		"construction_turns": int(definition.get("construction_turns", 0)),
		"placement": placement}

static func _occupied_cells(city: City) -> Dictionary:
	var occupied := {}
	for cell in CampaignBuildingPlacement.city_cells(city.center):
		if city.cell_is_built(cell):
			occupied[cell] = true
	for instance in city.campaign_buildings:
		if not (instance is Dictionary):
			continue
		var anchor: Vector2i = instance.get("cell", Vector2i.ZERO)
		var footprint := CampaignBuildingPlacement.footprint_cells(
			anchor, instance.get("footprint", [[0, 0]]))
		if footprint.is_empty():
			footprint = [anchor]
		for cell in footprint:
			occupied[cell] = true
	for pop in city.pop:
		if pop.state == PopUnit.State.WORKER and pop.tile.x >= 0:
			occupied[pop.tile] = true
	return occupied

static func _amount(city: City, resource_id: StringName) -> float:
	if city.resource_ctx != null:
		return city.resource_ctx.amount(resource_id)
	return city.food_stockpile if resource_id == &"food" else 0.0

static func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for building in catalog.get("buildings", []):
		if building is Dictionary and String(building.get("id", "")) == building_id:
			return building
	return {}

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
