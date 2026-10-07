class_name CampaignTrainingService
extends RefCounted

const MvpSaveSchema := preload("res://scripts/campaign/save/mvp_save_schema.gd")
const CatalogPath := "res://assets/data/mvp_catalog.json"
const PARTY_CAPACITY := 5

static func available_training_actions(
	state: Dictionary,
	building_catalog: Dictionary,
	scenario_flags: Array = [],
	admin_capacity: int = 0
) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not MvpSaveSchema.validate(state).is_empty() or state.party.size() >= PARTY_CAPACITY:
		return options
	var catalog := _load_catalog()
	var built_ids: Array[String] = []
	for instance in state.city.get("campaign_buildings", []):
		if not (instance is Dictionary) or int(instance.get("construction_turns_remaining", 0)) > 0 \
				or String(instance.get("state", "active")) == "ruined":
			continue
		built_ids.append(String(instance.get("id", "")))
	for instance in state.city.get("campaign_buildings", []):
		if not (instance is Dictionary) or String(instance.get("state", "active")) != "active" \
				or int(instance.get("construction_turns_remaining", 0)) > 0:
			continue
		var definition := _find_building(building_catalog, String(instance.get("id", "")))
		if definition.is_empty():
			continue
		if not CampaignBuildingCatalog.check_prerequisites(
				definition, built_ids, scenario_flags, admin_capacity).ok:
			continue
		for action in definition.get("training", []):
			if not (action is Dictionary):
				continue
			var class_id := String(action.get("class_id", ""))
			if _approved_class(catalog, class_id).is_empty():
				continue
			var costs: Variant = action.get("costs", {})
			if not (costs is Dictionary):
				continue
			var valid_costs := true
			for resource_id in costs:
				if not ResourceRegistry.CAMPAIGN_MVP_IDS.has(StringName(resource_id)):
					valid_costs = false
					break
			if valid_costs:
				options.append({"building_uid": int(instance.get("uid", -1)),
					"building_id": String(instance.get("id", "")),
					"class_id": class_id, "costs": costs.duplicate(true)})
	return options

static func train(
	state: Dictionary,
	building_catalog: Dictionary,
	building_uid: int,
	class_id: String,
	trainee: Dictionary,
	scenario_flags: Array = [],
	admin_capacity: int = 0,
	party_capacity: int = PARTY_CAPACITY,
	resource_context: ResourceContext = null
) -> Dictionary:
	var schema_error := MvpSaveSchema.validate(state)
	if not schema_error.is_empty():
		return _failure("invalid_campaign_state: %s" % schema_error)
	var catalog := _load_catalog()
	var approved_class := _approved_class(catalog, class_id)
	if approved_class.is_empty():
		return _failure("unsupported_class:%s" % class_id)
	var race := _first_tier_race(catalog, String(trainee.get("race", "")))
	if race.is_empty():
		return _failure("unsupported_race:%s" % String(trainee.get("race", "")))
	var stats: Variant = trainee.get("stats", {})
	if not (stats is Dictionary):
		return _failure("invalid_stats")
	var gate_result := _check_class_gate(approved_class, stats)
	if not gate_result.ok:
		return _failure(String(gate_result.reason))
	var trainee_id := String(trainee.get("id", "")).strip_edges()
	if trainee_id.is_empty():
		return _failure("trainee_id_required")
	var party: Array = state.get("party", [])
	for member in party:
		if member is Dictionary and String(member.get("id", "")) == trainee_id:
			return _failure("duplicate_party_member:%s" % trainee_id)
	if party.size() >= mini(PARTY_CAPACITY, maxi(party_capacity, 0)):
		return _failure("party_capacity_reached")

	var city: Dictionary = state.get("city", {})
	var instances: Array = city.get("campaign_buildings", [])
	var instance: Dictionary = {}
	for candidate in instances:
		if candidate is Dictionary and int(candidate.get("uid", -1)) == building_uid:
			instance = candidate
			break
	if instance.is_empty() or String(instance.get("state", "active")) != "active" \
			or int(instance.get("construction_turns_remaining", 0)) > 0:
		return _failure("training_building_unavailable")
	var definition := _find_building(building_catalog, String(instance.get("id", "")))
	if definition.is_empty():
		return _failure("unknown_building:%s" % String(instance.get("id", "")))
	var action := _find_training_action(definition, class_id)
	if action.is_empty():
		return _failure("class_not_trained_here:%s" % class_id)
	var built_ids: Array[String] = []
	for built in instances:
		if not (built is Dictionary) or int(built.get("construction_turns_remaining", 0)) > 0 \
				or String(built.get("state", "active")) == "ruined":
			continue
		built_ids.append(String(built.get("id", "")))
	var prerequisite_check := CampaignBuildingCatalog.check_prerequisites(
		definition, built_ids, scenario_flags, admin_capacity)
	if not prerequisite_check.ok:
		return {"ok": false, "reason": "prerequisite_missing", "missing": prerequisite_check.missing}

	var costs: Variant = action.get("costs", {})
	if not (costs is Dictionary):
		return _failure("invalid_training_costs")
	for resource_id in costs:
		if not ResourceRegistry.CAMPAIGN_MVP_IDS.has(StringName(resource_id)):
			return _failure("unregistered_training_resource:%s" % String(resource_id))
		var amount: Variant = costs[resource_id]
		if (typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT) \
				or not is_finite(float(amount)) or float(amount) <= 0.0:
			return _failure("invalid_training_cost:%s" % String(resource_id))
	for resource_id in state.resources:
		if not ResourceRegistry.CAMPAIGN_MVP_IDS.has(StringName(resource_id)):
			return _failure("unregistered_campaign_resource:%s" % String(resource_id))

	var resources := resource_context
	if resources == null:
		resources = ResourceContext.new()
		resources.setup(Resources.get_campaign_resource_defs(true), true)
		resources.deserialize(state.resources)
	elif resources.serialize() != state.resources:
		return _failure("campaign_resource_state_mismatch")
	var paid := resources.transact(costs, {}, "training:%s/class:%s" % [trainee_id, class_id]) \
		if not costs.is_empty() else {"ok": true}
	if not paid.ok:
		return {"ok": false, "reason": String(paid.get("reason", "payment_failed")),
			"missing": paid.get("missing", {})}

	var member := trainee.duplicate(true)
	member["class"] = class_id
	member["race"] = String(race.id)
	member["level"] = maxi(1, int(member.get("level", 1)))
	member["xp"] = maxi(0, int(member.get("xp", 0)))
	member["stats"] = stats.duplicate(true)
	member["luck"] = int(member.get("luck", 0))
	party.append(member)
	state["party"] = party
	state["resources"] = resources.serialize()
	return {"ok": true, "member": member, "flow": paid.get("flow", {})}

static func _load_catalog() -> Dictionary:
	if not FileAccess.file_exists(CatalogPath):
		return {}
	var file := FileAccess.open(CatalogPath, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

static func _approved_class(catalog: Dictionary, class_id: String) -> Dictionary:
	for class_record in catalog.get("classes", []):
		if class_record is Dictionary and String(class_record.get("id", "")) == class_id \
				and bool(class_record.get("hireable", false)):
			return class_record
	return {}

static func _first_tier_race(catalog: Dictionary, race_id: String) -> Dictionary:
	for race in catalog.get("races", []):
		if race is Dictionary and String(race.get("id", "")) == race_id \
				and bool(race.get("first_tier", false)):
			return race
	return {}

static func _check_class_gate(class_record: Dictionary, stats: Dictionary) -> Dictionary:
	var gate: Dictionary = class_record.get("gate", {})
	var requirements: Array = gate.get("reqs", [])
	var mode := String(gate.get("mode", "all"))
	var met := 0
	var failures: Array[String] = []
	for requirement in requirements:
		if not (requirement is Array) or requirement.size() != 2:
			return {"ok": false, "reason": "invalid_class_gate"}
		var ability := String(requirement[0]).to_lower()
		var needed := int(requirement[1])
		var actual := int(stats.get(ability, -1))
		if actual >= needed:
			met += 1
		else:
			failures.append("%s:%d<%d" % [ability, actual, needed])
	var ok := met > 0 if mode == "any" else failures.is_empty()
	return {"ok": ok, "reason": "class_gate:%s" % ",".join(failures)}

static func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for building in catalog.get("buildings", []):
		if building is Dictionary and String(building.get("id", "")) == building_id:
			return building
	return {}

static func _find_training_action(definition: Dictionary, class_id: String) -> Dictionary:
	for action in definition.get("training", []):
		if action is Dictionary and String(action.get("class_id", "")) == class_id:
			return action
	return {}

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
