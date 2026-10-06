class_name CampaignBuildingCatalog
extends RefCounted

const SCHEMA_VERSION := 1
const SOURCE_GAMES := ["against_the_storm", "terrascape", "age_of_empires_iv", "sigil_of_the_unwilling"]
const CATALOG_PATH := "res://assets/data/campaign_building_catalog.json"
const STATES := ["active", "inactive", "ruined"]
const REQUIRED_FIELDS := [
	"id", "source_refs", "roles", "footprint", "placement", "costs", "upkeep",
	"jobs", "resident_capacity", "construction_turns", "recipes", "services", "group_affinities", "adjacency", "merge",
	"prerequisites", "training", "defense", "state_effects",
]

## Load the shipped, campaign-authored building catalog.
static func load_catalog(path: String = CATALOG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Campaign building catalog not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open campaign building catalog: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_error("Campaign building catalog must contain a JSON object: %s" % path)
		return {}
	return parsed

## Validate building data and all cross-record/campaign references without mutating it.
## `references` supplies resources, groups, needs, trainable_classes, and terrain_tags as arrays.
static func validate_catalog(catalog: Dictionary, references: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(catalog.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	var raw_buildings: Variant = catalog.get("buildings")
	if not (raw_buildings is Array):
		errors.append("buildings must be an array")
		return errors

	var ids := _to_set(raw_buildings.map(func(b): return String(b.get("id", "")) if b is Dictionary else ""))
	var roles := {}
	for raw in raw_buildings:
		if raw is Dictionary:
			var raw_roles: Variant = raw.get("roles", [])
			if raw_roles is Array:
				for role in raw_roles:
					roles[String(role)] = true

	var resource_ids := _to_set(references.get("resources", []))
	var group_ids := _to_set(references.get("groups", []))
	var need_ids := _to_set(references.get("needs", []))
	var class_ids := _to_set(references.get("trainable_classes", []))
	var terrain_ids := _to_set(references.get("terrain_tags", []))
	var scenario_flags := _to_set(references.get("scenario_flags", []))
	var seen_ids := {}
	for index in range(raw_buildings.size()):
		var building: Variant = raw_buildings[index]
		var path := "buildings[%d]" % index
		if not (building is Dictionary):
			errors.append("%s must be an object" % path)
			continue
		_validate_building(building, path, resource_ids, group_ids, need_ids,
			class_ids, terrain_ids, roles, ids, scenario_flags, seen_ids, errors)
	_validate_merge_graph(raw_buildings, errors)
	return errors

static func check_prerequisites(building: Dictionary, built_ids: Array, scenario_flags: Array,
		admin_capacity: int) -> Dictionary:
	var prerequisites: Dictionary = building.get("prerequisites", {})
	var built := _to_set(built_ids)
	var flags := _to_set(scenario_flags)
	var missing: Array[String] = []
	for id in prerequisites.get("buildings", []):
		if not built.has(String(id)):
			missing.append("building:%s" % id)
	for flag in prerequisites.get("scenario_flags", []):
		if not flags.has(String(flag)):
			missing.append("scenario_flag:%s" % flag)
	var required_capacity := int(prerequisites.get("admin_capacity", 0))
	if admin_capacity < required_capacity:
		missing.append("admin_capacity:%d/%d" % [admin_capacity, required_capacity])
	return {"ok": missing.is_empty(), "missing": missing}

static func _validate_building(
	b: Dictionary, path: String, resources: Dictionary, groups: Dictionary,
	needs: Dictionary, classes: Dictionary, terrains: Dictionary, roles: Dictionary,
	building_ids: Dictionary, scenario_flags: Dictionary, seen_ids: Dictionary, errors: Array[String]
) -> void:
	for field in REQUIRED_FIELDS:
		if not b.has(field):
			errors.append("%s.%s is required" % [path, field])
	var id := String(b.get("id", ""))
	if not id.is_valid_identifier() or id.to_lower() != id:
		errors.append("%s.id must be a lowercase identifier" % path)
	if seen_ids.has(id):
		errors.append("%s.id duplicates %s" % [path, id])
	seen_ids[id] = true

	var source_refs: Variant = b.get("source_refs", [])
	if not (source_refs is Array) or source_refs.is_empty():
		errors.append("%s.source_refs must be a non-empty array" % path)
	else:
		for i in range(source_refs.size()):
			var ref: Variant = source_refs[i]
			var ref_path := "%s.source_refs[%d]" % [path, i]
			if not (ref is Dictionary):
				errors.append("%s must be an object" % ref_path)
				continue
			for field in ["game", "entry", "version", "url"]:
				if String(ref.get(field, "")).strip_edges().is_empty():
					errors.append("%s.%s is required" % [ref_path, field])
			if not SOURCE_GAMES.has(String(ref.get("game", ""))):
				errors.append("%s.game is unsupported" % ref_path)
			var url := String(ref.get("url", ""))
			if not url.begins_with("https://") and not url.begins_with("http://"):
				errors.append("%s.url must be HTTP(S)" % ref_path)

	_validate_string_array(b.get("roles", null), "%s.roles" % path, true, errors)
	var footprint: Variant = b.get("footprint")
	var footprint_cells := {}
	var has_origin := false
	if not (footprint is Array) or footprint.is_empty():
		errors.append("%s.footprint must be a non-empty axial-cell array" % path)
	else:
		for i in range(footprint.size()):
			var cell: Variant = footprint[i]
			if not (cell is Array) or cell.size() != 2 or typeof(cell[0]) != TYPE_INT or typeof(cell[1]) != TYPE_INT:
				errors.append("%s.footprint[%d] must be an integer [q, r] pair" % [path, i])
				continue
			var key := "%d,%d" % [cell[0], cell[1]]
			if footprint_cells.has(key):
				errors.append("%s.footprint contains duplicate cell %s" % [path, key])
			footprint_cells[key] = true
			has_origin = has_origin or key == "0,0"
	if footprint is Array and not has_origin:
		errors.append("%s.footprint must contain anchor [0, 0]" % path)

	var placement: Variant = b.get("placement")
	if not (placement is Dictionary):
		errors.append("%s.placement must be an object" % path)
	else:
		var terrain_tags: Variant = placement.get("terrain_tags", null)
		_validate_string_array(terrain_tags, "%s.placement.terrain_tags" % path, false, errors)
		if terrain_tags is Array:
			for terrain in terrain_tags:
				if not terrains.has(String(terrain)):
					errors.append("%s references unknown terrain tag '%s'" % [path, terrain])
		if typeof(placement.get("requires_special_site")) != TYPE_BOOL:
			errors.append("%s.placement.requires_special_site must be boolean" % path)

	_validate_resource_map(b.get("costs", null), "%s.costs" % path, resources, errors)
	_validate_resource_map(b.get("upkeep", null), "%s.upkeep" % path, resources, errors)
	if typeof(b.get("jobs")) != TYPE_INT or int(b.get("jobs", -1)) < 0:
		errors.append("%s.jobs must be a non-negative integer" % path)
	if typeof(b.get("resident_capacity")) != TYPE_INT or int(b.get("resident_capacity", -1)) < 0:
		errors.append("%s.resident_capacity must be a non-negative integer" % path)
	if typeof(b.get("construction_turns")) != TYPE_INT or int(b.get("construction_turns", -1)) < 0:
		errors.append("%s.construction_turns must be a non-negative integer" % path)

	var recipes: Variant = b.get("recipes")
	if not (recipes is Array):
		errors.append("%s.recipes must be an array" % path)
	else:
		var recipe_ids := {}
		for i in range(recipes.size()):
			var recipe: Variant = recipes[i]
			var recipe_path := "%s.recipes[%d]" % [path, i]
			if not (recipe is Dictionary):
				errors.append("%s must be an object" % recipe_path)
				continue
			var recipe_id := String(recipe.get("id", ""))
			if not recipe_id.is_valid_identifier() or recipe_ids.has(recipe_id):
				errors.append("%s.id must be a unique identifier" % recipe_path)
			recipe_ids[recipe_id] = true
			var workers: Variant = recipe.get("workers")
			if typeof(workers) != TYPE_INT or int(workers) < 0 or int(workers) > int(b.get("jobs", 0)):
				errors.append("%s.workers must be between 0 and building jobs" % recipe_path)
			var inputs := _validate_resource_map(recipe.get("inputs", null), "%s.inputs" % recipe_path, resources, errors)
			var outputs := _validate_resource_map(recipe.get("outputs", null), "%s.outputs" % recipe_path, resources, errors)
			if inputs.is_empty() and outputs.is_empty():
				errors.append("%s must declare inputs or outputs" % recipe_path)

	_validate_capacity_map(b.get("services", null), "%s.services" % path, needs, errors)
	_validate_numeric_map(b.get("group_affinities", null), "%s.group_affinities" % path, groups, errors)

	var adjacency: Variant = b.get("adjacency")
	if not (adjacency is Array):
		errors.append("%s.adjacency must be an array" % path)
	else:
		var seen_adjacency_ids := {}
		for i in range(adjacency.size()):
			var rule: Variant = adjacency[i]
			var rule_path := "%s.adjacency[%d]" % [path, i]
			if not (rule is Dictionary):
				errors.append("%s must be an object" % rule_path)
				continue
			var rule_id := String(rule.get("id", ""))
			if rule_id.is_empty() or String(rule.get("effect", "")).is_empty():
				errors.append("%s.id and effect are required" % rule_path)
			if seen_adjacency_ids.has(rule_id):
				errors.append("%s.id duplicates '%s'" % [rule_path, rule_id])
			seen_adjacency_ids[rule_id] = true
			if not roles.has(String(rule.get("target_role", ""))):
				errors.append("%s references unknown target role '%s'" % [rule_path, rule.get("target_role", "")])
			if typeof(rule.get("radius")) != TYPE_INT or int(rule.get("radius", 0)) < 1:
				errors.append("%s.radius must be a positive integer" % rule_path)
			if not _is_number(rule.get("value")):
				errors.append("%s.value must be numeric" % rule_path)
			elif absf(float(rule.get("value"))) > 10000.0:
				errors.append("%s.value must be within +/-10000 basis points" % rule_path)

	var merge: Variant = b.get("merge")
	if not (merge is Dictionary):
		errors.append("%s.merge must be an object" % path)
	else:
		if not merge.is_empty():
			_validate_merge_components(merge.get("components", null), "%s.merge.components" % path, id, building_ids, errors)
			if typeof(merge.get("max_distance")) != TYPE_INT or int(merge.get("max_distance", 0)) < 1:
				errors.append("%s.merge.max_distance must be a positive integer" % path)
	var prerequisites: Variant = b.get("prerequisites")
	if not (prerequisites is Dictionary):
		errors.append("%s.prerequisites must be an object" % path)
	else:
		_validate_building_refs(prerequisites.get("buildings", []), "%s.prerequisites.buildings" % path, "", building_ids, 0, errors)
		if typeof(prerequisites.get("admin_capacity", 0)) != TYPE_INT or int(prerequisites.get("admin_capacity", 0)) < 0:
			errors.append("%s.prerequisites.admin_capacity must be a non-negative integer" % path)
		var flags: Variant = prerequisites.get("scenario_flags", [])
		_validate_string_array(flags, "%s.prerequisites.scenario_flags" % path, false, errors)
		if flags is Array:
			for flag in flags:
				if not scenario_flags.has(flag):
					errors.append("%s references unknown scenario flag '%s'" % [path, flag])

	var training: Variant = b.get("training")
	if not (training is Array):
		errors.append("%s.training must be an array" % path)
	else:
		for i in range(training.size()):
			var action: Variant = training[i]
			var action_path := "%s.training[%d]" % [path, i]
			if not (action is Dictionary):
				errors.append("%s must be an object" % action_path)
				continue
			var class_id := String(action.get("class_id", ""))
			if not classes.has(class_id):
				errors.append("%s references unapproved class '%s'" % [action_path, class_id])
			_validate_resource_map(action.get("costs", null), "%s.costs" % action_path, resources, errors)

	_validate_state_map(b.get("defense", null), "%s.defense" % path, errors)
	_validate_state_effects(b.get("state_effects", null), "%s.state_effects" % path, errors)

static func _validate_resource_map(value: Variant, path: String, resources: Dictionary, errors: Array[String]) -> Dictionary:
	if not (value is Dictionary):
		errors.append("%s must be an object" % path)
		return {}
	for key in value:
		var amount: Variant = value[key]
		if not resources.has(String(key)):
			errors.append("%s references unregistered resource '%s'" % [path, key])
		if not _is_number(amount) or float(amount) <= 0.0:
			errors.append("%s.%s must be a positive number" % [path, key])
	return value

static func _validate_capacity_map(value: Variant, path: String, allowed: Dictionary, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("%s must be an object" % path)
		return
	for key in value:
		if not allowed.has(String(key)):
			errors.append("%s references unknown service '%s'" % [path, key])
		if typeof(value[key]) != TYPE_INT or int(value[key]) < 0:
			errors.append("%s.%s must be a non-negative integer" % [path, key])

static func _validate_numeric_map(value: Variant, path: String, allowed: Dictionary, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("%s must be an object" % path)
		return
	for key in value:
		if not allowed.has(String(key)):
			errors.append("%s references unknown archetype '%s'" % [path, key])
		if not _is_number(value[key]):
			errors.append("%s.%s must be numeric" % [path, key])

static func _validate_state_map(value: Variant, path: String, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("%s must declare defense by state" % path)
		return
	for state in STATES:
		if not _is_number(value.get(state)):
			errors.append("%s.%s must be numeric" % [path, state])

static func _validate_state_effects(value: Variant, path: String, errors: Array[String]) -> void:
	if not (value is Dictionary):
		errors.append("%s must declare effects by state" % path)
		return
	for state in STATES:
		var effects: Variant = value.get(state)
		if not (effects is Dictionary):
			errors.append("%s.%s must be an object" % [path, state])
			continue
		for effect in effects:
			if String(effect).is_empty() or not _is_number(effects[effect]):
				errors.append("%s.%s values must be numeric named effects" % [path, state])

static func _validate_merge_components(value: Variant, path: String, self_id: String,
		building_ids: Dictionary, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s must be an array" % path)
		return
	if value.size() < 2:
		errors.append("%s needs at least 2 building references" % path)
	for ref in value:
		var ref_id := String(ref)
		if not building_ids.has(ref_id):
			errors.append("%s references unknown building '%s'" % [path, ref_id])
		if ref_id == self_id:
			errors.append("%s cannot reference its own building" % path)

static func _validate_merge_graph(buildings: Array, errors: Array[String]) -> void:
	var graph := {}
	for building in buildings:
		if not (building is Dictionary):
			continue
		var merge: Variant = building.get("merge", {})
		if merge is Dictionary and merge.has("components") and merge.components is Array:
			graph[String(building.get("id", ""))] = merge.components
	var visited := {}
	var visiting := {}
	for result_id in graph:
		_visit_merge_graph(String(result_id), graph, visited, visiting, errors)

static func _visit_merge_graph(id: String, graph: Dictionary, visited: Dictionary,
		visiting: Dictionary, errors: Array[String]) -> void:
	if visited.has(id):
		return
	if visiting.has(id):
		errors.append("merge graph contains a cycle through '%s'" % id)
		return
	visiting[id] = true
	for component in graph.get(id, []):
		var component_id := String(component)
		if graph.has(component_id):
			_visit_merge_graph(component_id, graph, visited, visiting, errors)
	visiting.erase(id)
	visited[id] = true

static func _validate_building_refs(value: Variant, path: String, self_id: String, ids: Dictionary, minimum: int, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s must be an array" % path)
		return
	if value.size() < minimum:
		errors.append("%s needs at least %d building references" % [path, minimum])
	var seen := {}
	for ref in value:
		var ref_id := String(ref)
		if not ids.has(ref_id):
			errors.append("%s references unknown building '%s'" % [path, ref_id])
		if ref_id == self_id:
			errors.append("%s cannot reference its own building" % path)
		if seen.has(ref_id):
			errors.append("%s contains duplicate building '%s'" % [path, ref_id])
		seen[ref_id] = true

static func _validate_string_array(value: Variant, path: String, must_not_be_empty: bool, errors: Array[String]) -> void:
	if not (value is Array):
		errors.append("%s must be an array" % path)
		return
	if must_not_be_empty and value.is_empty():
		errors.append("%s must not be empty" % path)
	var seen := {}
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append("%s entries must be strings" % path)
			continue
		var text := String(item)
		if text.strip_edges().is_empty():
			errors.append("%s entries must be non-empty strings" % path)
		if seen.has(text):
			errors.append("%s contains duplicate '%s'" % [path, text])
		seen[text] = true

static func _to_set(values: Variant) -> Dictionary:
	var out := {}
	if values is Array:
		for value in values:
			out[String(value)] = true
	elif values is Dictionary:
		out = values
	return out

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
