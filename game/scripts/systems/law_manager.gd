class_name LawManager
extends RefCounted

## Law system (dynamic-world-crisis-system — Laws task).
## Three branches (Order, Faith, Survival), each a tree: a law's `requires`
## names its prerequisite ("" = root of the branch). Laws are unlocked via event
## choices (the `unlock_law` effect) and, while active, contribute passive
## gameplay modifiers (merged by key).
##
## Standalone RefCounted so the core logic is testable without a scene tree.
## `to_dict`/`from_dict` make save/load trivial.

signal law_unlocked(law_id: String)

enum Branch {
	ORDER,     # Порядок: налоги, стража, дисциплина
	FAITH,     # Вера: храмы, ритуалы, мораль
	SURVIVAL   # Выживание: продовольствие, оборона, медицина
}


class Law:
	var id: String
	var name: String
	var description: String
	var branch: Branch = Branch.ORDER
	var tier: int = 1
	var requires: String = ""   # prerequisite law id ("" = root of branch)
	var passive_effects: Dictionary = {}  # ongoing gameplay modifiers, e.g. {"production": 0.1, "morale": 5}

	func _init(data: Dictionary = {}):
		if data.has("id"): id = str(data["id"])
		if data.has("name"): name = str(data["name"])
		if data.has("description"): description = str(data["description"])
		if data.has("branch"): branch = int(data["branch"])
		if data.has("tier"): tier = int(data["tier"])
		if data.has("requires"): requires = str(data["requires"])
		if data.has("passive_effects"): passive_effects = data["passive_effects"]


# Catalog: law id -> Law
var laws: Dictionary = {}
# Unlocked law ids (in unlock order)
var active_laws: Array[String] = []

## Load the law catalog from an array of law dicts.
func load_catalog(entries: Array) -> void:
	laws.clear()
	for e in entries:
		var law := Law.new(e)
		laws[law.id] = law

## Default catalog: 3 branches, 2 laws each, forming simple trees.
func load_default_catalog() -> void:
	load_catalog([
		{"id": "order_tax_code", "name": "Tax Code", "branch": Branch.ORDER, "tier": 1, "requires": "",
		 "passive_effects": {"production": 0.1, "happiness": -5}},
		{"id": "order_standing_guard", "name": "Standing Guard", "branch": Branch.ORDER, "tier": 2, "requires": "order_tax_code",
		 "passive_effects": {"defense": 10, "food": -3}},
		{"id": "faith_temple", "name": "Temple", "branch": Branch.FAITH, "tier": 1, "requires": "",
		 "passive_effects": {"morale": 8, "production": -0.05}},
		{"id": "faith_relic_pilgrimage", "name": "Relic Pilgrimage", "branch": Branch.FAITH, "tier": 2, "requires": "faith_temple",
		 "passive_effects": {"happiness": 10, "morale": 5}},
		{"id": "survival_granary", "name": "Granary", "branch": Branch.SURVIVAL, "tier": 1, "requires": "",
		 "passive_effects": {"food": 10, "production": -0.05}},
		{"id": "survival_field_hospital", "name": "Field Hospital", "branch": Branch.SURVIVAL, "tier": 2, "requires": "survival_granary",
		 "passive_effects": {"healing": 0.2, "food": -5}},
	])

## Unlock a law. Returns true if newly unlocked, false if invalid or already active.
## Enforces the tree: prerequisite must already be active.
func unlock_law(law_id: String) -> bool:
	if not laws.has(law_id):
		return false
	if is_law_active(law_id):
		return false
	var law: Law = laws[law_id]
	if law.requires != "" and not is_law_active(law.requires):
		return false
	active_laws.append(law_id)
	law_unlocked.emit(law_id)
	return true

func is_law_active(law_id: String) -> bool:
	return active_laws.has(law_id)

func get_active_laws() -> Array[Law]:
	var result: Array[Law] = []
	for id in active_laws:
		if laws.has(id):
			result.append(laws[id])
	return result

func get_laws_by_branch(branch: Branch) -> Array[Law]:
	var result: Array[Law] = []
	for id in laws:
		var law: Law = laws[id]
		if law.branch == branch:
			result.append(law)
	return result

## Merged passive effects of all active laws (summed per key).
func get_passive_effects() -> Dictionary:
	var merged: Dictionary = {}
	for id in active_laws:
		if not laws.has(id):
			continue
		var law: Law = laws[id]
		for key in law.passive_effects:
			merged[key] = float(merged.get(key, 0.0)) + float(law.passive_effects[key])
	return merged

func to_dict() -> Dictionary:
	return {"active_laws": active_laws.duplicate()}

func from_dict(data: Dictionary) -> void:
	active_laws.clear()
	var raw = data.get("active_laws", [])
	if raw is Array:
		for id in raw:
			if laws.has(id) and not active_laws.has(id):
				active_laws.append(id)
