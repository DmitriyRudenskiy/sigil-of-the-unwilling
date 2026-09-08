class_name BuildingDefs
extends RefCounted

const SITE_RUINS := &"ruins"
const SITE_SHRINE := &"shrine"
const SITE_MEADOW := &"meadow"

const DATA_PATH := "res://assets/data/buildings.json"
const PopUnit := preload("res://scripts/world/PopUnit.gd")

static var _raw_cache: Array = []


static func _ensure_loaded() -> void:
	if not _raw_cache.is_empty():
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var text: String = ""
	if file != null:
		text = file.get_as_text()
		file.close()
	var data: Variant = JSON.parse_string(text)
	if data is Array:
		_raw_cache = data


static func _build_def(raw: Dictionary) -> UniqueBuilding.Def:
	var d := _mk(
		StringName(raw.get("id", "")),
		String(raw.get("display_name", "")),
		bool(raw.get("requires_site", false)),
		_levels(raw.get("levels", []))
	)
	var housing_raw: Variant = raw.get("housing", {})
	if housing_raw is Dictionary:
		for k in housing_raw:
			d.housing[_state(String(k))] = int(housing_raw[k])
	var chain_raw: Variant = raw.get("production_chain", {})
	if chain_raw is Dictionary and not chain_raw.is_empty():
		d.production_chain = _chain_from_dict(chain_raw)
	var upkeep_raw: Variant = raw.get("default_upkeep", {})
	for k in upkeep_raw:
		d.default_upkeep[StringName(k)] = float(upkeep_raw[k])
	return d


static func _levels(raw_levels: Array) -> Array:
	var out: Array = []
	for r in raw_levels:
		if r is Dictionary:
			out.append(_req(
				float(r.get("industry", 0.0)),
				int(r.get("followers", 0)),
				StringName(r.get("special_resource", "")),
				float(r.get("special_amount", 0.0))
			))
	return out


static func _state(name: String) -> int:
	return PopUnit.State[StringName(name)]


static func _chain_from_dict(raw: Dictionary) -> ProductionChain:
	return _chain(
		StringName(raw.get("id", "")),
		int(raw.get("workers", 1)),
		raw.get("inputs", {}),
		raw.get("outputs", {})
	)



static func all() -> Array[UniqueBuilding.Def]:
	_ensure_loaded()
	var out: Array[UniqueBuilding.Def] = []
	for raw in _raw_cache:
		if raw is Dictionary:
			out.append(_build_def(raw))
	return out


static func def_by_id(id: StringName) -> UniqueBuilding.Def:
	_ensure_loaded()
	for raw in _raw_cache:
		if raw is Dictionary and String(raw.get("id", "")) == String(id):
			return _build_def(raw)
	return null


static func great_temple() -> UniqueBuilding.Def:
	return def_by_id(&"great_temple")

static func market() -> UniqueBuilding.Def:
	return def_by_id(&"market")

static func barracks() -> UniqueBuilding.Def:
	return def_by_id(&"barracks")

static func ancient_vault() -> UniqueBuilding.Def:
	return def_by_id(&"ancient_vault")

static func walls() -> UniqueBuilding.Def:
	return def_by_id(&"walls")

static func farm() -> UniqueBuilding.Def:
	return def_by_id(&"farm")

static func mill() -> UniqueBuilding.Def:
	return def_by_id(&"mill")

static func bakery() -> UniqueBuilding.Def:
	return def_by_id(&"bakery")

static func mine() -> UniqueBuilding.Def:
	return def_by_id(&"mine")

static func smithy() -> UniqueBuilding.Def:
	return def_by_id(&"smithy")

static func school() -> UniqueBuilding.Def:
	return def_by_id(&"school")

static func tavern() -> UniqueBuilding.Def:
	return def_by_id(&"tavern")

static func trade_post() -> UniqueBuilding.Def:
	return def_by_id(&"trade_post")

static func shack() -> UniqueBuilding.Def:
	return def_by_id(&"shack")

static func manor() -> UniqueBuilding.Def:
	return def_by_id(&"manor")


static func _mk(
	id: StringName, display_name: String, requires_site: bool, levels: Array
) -> UniqueBuilding.Def:
	var d := UniqueBuilding.Def.new()
	d.id = id
	d.display_name = display_name
	d.requires_site = requires_site
	d.levels = levels
	return d


static func _chain(
	id: StringName, workers: int,
	inputs: Dictionary = {}, outputs: Dictionary = {}
) -> ProductionChain:
	var c := ProductionChain.new()
	c.id = id
	c.required_workers = workers
	for k in inputs:
		c.inputs[StringName(k)] = float(inputs[k])
	for k in outputs:
		c.outputs[StringName(k)] = float(outputs[k])
	return c


static func _req(
	industry: float, followers := 0, res := &"", amount := 0.0
) -> UniqueBuilding.LevelReq:
	var r := UniqueBuilding.LevelReq.new()
	r.industry = industry
	r.followers = followers
	r.special_resource = res
	r.special_amount = amount
	return r
