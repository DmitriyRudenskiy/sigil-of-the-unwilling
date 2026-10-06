class_name ArchetypeResolver
extends RefCounted

const CATALOG_PATH := "res://assets/data/mvp_catalog.json"

static func load_catalog(path: String = CATALOG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

static func get_group(catalog: Dictionary, group_id: String) -> Dictionary:
	for group in catalog.get("groups", []):
		if group is Dictionary and String(group.get("id", "")) == group_id:
			return group
	return {}

static func group_id_for_identity(
	catalog: Dictionary,
	ancestry_id: String,
	archetype_id: String = ""
) -> String:
	if not archetype_id.is_empty() and not get_group(catalog, archetype_id).is_empty():
		return archetype_id
	for race in catalog.get("races", []):
		if race is Dictionary and String(race.get("id", "")) == ancestry_id:
			var group_id := String(race.get("group", ""))
			return group_id if not get_group(catalog, group_id).is_empty() else ""
	return ""

static func need_coverage_percent(demand: int, supplied: int) -> int:
	if demand <= 0:
		return 100
	return clampi(int(floor(100.0 * float(mini(demand, maxi(supplied, 0))) / float(demand))), 0, 100)

static func resolve_need_turn(
	group: Dictionary,
	current_satisfaction: int,
	unmet_turns: int,
	coverage_percent: int,
	rules: Dictionary = {}
) -> Dictionary:
	var satisfaction := clampi(
		current_satisfaction,
		int(rules.get("satisfaction_min", 0)),
		int(rules.get("satisfaction_max", 100))
	)
	var unmet := maxi(unmet_turns, 0)
	if coverage_percent >= 100:
		satisfaction = mini(
			satisfaction + int(rules.get("satisfied_need_delta", 1)),
			int(rules.get("satisfaction_max", 100))
		)
		unmet = 0
	else:
		unmet += 1
		var period := maxi(int(group.get("unmet_response_period_turns", 1)), 1)
		if unmet % period == 0:
			satisfaction = maxi(
				satisfaction - int(rules.get("unmet_need_delta", 1)),
				int(rules.get("satisfaction_min", 0))
			)
	return {
		"coverage_percent": clampi(coverage_percent, 0, 100),
		"satisfaction": satisfaction,
		"unmet_turns": unmet,
	}

static func specialization_bonus_bp(
	catalog: Dictionary,
	building_roles: Variant,
	workers_by_group: Dictionary,
	jobs: int
) -> int:
	var roles: Array = building_roles if building_roles is Array else [building_roles]
	var matched_workers := 0
	for group in catalog.get("groups", []):
		if not (group is Dictionary):
			continue
		var matches := false
		for role in group.get("preferred_roles", []):
			if roles.has(role):
				matches = true
				break
		if matches:
			matched_workers += maxi(int(workers_by_group.get(String(group.get("id", "")), 0)), 0)
	var rules: Dictionary = catalog.get("archetype_rules", {})
	matched_workers = mini(matched_workers, maxi(jobs, 0))
	return mini(
		matched_workers * int(rules.get("specialization_bonus_per_worker_bp", 1000)),
		int(rules.get("specialization_bonus_cap_bp", 10000))
	)

static func relation_value(catalog: Dictionary, group_a: String, group_b: String) -> int:
	if group_a == group_b:
		return 0
	for relation in catalog.get("group_relations", []):
		if not (relation is Dictionary):
			continue
		var a := String(relation.get("a", ""))
		var b := String(relation.get("b", ""))
		if (a == group_a and b == group_b) or (a == group_b and b == group_a):
			return int(relation.get("value", 0))
	return 0

static func resolve_workplace_relations(
	catalog: Dictionary,
	workers_by_group: Dictionary,
	mediation_capacity: int = 0,
	mediation_groups: Array = []
) -> Dictionary:
	var ids: Array[String] = []
	var deltas := {}
	for group in catalog.get("groups", []):
		if group is Dictionary:
			var id := String(group.get("id", ""))
			if not id.is_empty():
				ids.append(id)
				deltas[id] = 0
	ids.sort()

	var remaining_mediation := maxi(mediation_capacity, 0)
	var rules: Dictionary = catalog.get("archetype_rules", {})
	var pairs: Array[Dictionary] = []
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a := ids[i]
			var b := ids[j]
			if int(workers_by_group.get(a, 0)) <= 0 or int(workers_by_group.get(b, 0)) <= 0:
				continue
			var raw_value := relation_value(catalog, a, b)
			var value := raw_value
			var mitigated := false
			if value < 0 and remaining_mediation > 0 and mediation_groups.has(a) and mediation_groups.has(b):
				value += 1
				remaining_mediation -= 1
				mitigated = true
			pairs.append({"a": a, "b": b, "raw": raw_value, "value": value, "mitigated": mitigated})
			deltas[a] = int(deltas[a]) + value
			deltas[b] = int(deltas[b]) + value

	var min_delta := int(rules.get("relation_delta_min", -2))
	var max_delta := int(rules.get("relation_delta_max", 2))
	for group in catalog.get("groups", []):
		if group is Dictionary:
			var id := String(group.get("id", ""))
			if deltas.has(id):
				deltas[id] = clampi(int(deltas[id]), min_delta, max_delta)
	return {
		"deltas": deltas,
		"pairs": pairs,
		"mediation_capacity_used": maxi(mediation_capacity, 0) - remaining_mediation,
	}
