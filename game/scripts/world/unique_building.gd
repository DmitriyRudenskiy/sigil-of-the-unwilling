class_name UniqueBuilding
extends RefCounted

class Def extends RefCounted:
	var id: StringName = &""
	var display_name := ""
	var levels: Array = []
	var requires_site := false
	var housing: Dictionary = {}
	var production_chain: ProductionChain = null
	var default_upkeep: Dictionary = {}
	var default_zone := 0
	# Ранняя игра: дымовая (tech tree) — мин. уровень города (early-game-foundation)
	var min_city_level := 1
	# Военная цепочка: unit_key, costs: Array[Dictionary], tiers: Array[int]
	var military_chain: Dictionary = {}

class LevelReq extends RefCounted:
	var industry := 0.0
	var special_resource: StringName = &""
	var special_amount := 0.0
	var followers := 0

var def: Def = null
var cell := Vector2i(-1, -1)
var level := 0
var uid := 0
var assigned_followers := 0
var assigned_workers := 0
var zone_type: int = 0
var production_chain: ProductionChain = null
var upkeep: Dictionary = {}
var zone_multiplier: float = 1.0

func get_zone_type() -> int:
	return zone_type

func get_production_chain() -> ProductionChain:
	return production_chain

func get_upkeep() -> Dictionary:
	return upkeep

func next_level_req() -> LevelReq:
	if def == null or level >= GameNumbers.BUILDING_MAX_LEVEL:
		return null
	if level >= def.levels.size():
		return null
	return def.levels[level]

func serialize() -> Dictionary:
	var d := {
		"def_id": String(def.id) if def != null else "",
		"cell": SerializationUtils.vec2i_to_dict(cell),
		"level": level,
		"uid": uid,
		"assigned_followers": assigned_followers,
		"assigned_workers": assigned_workers,
		"zone_type": zone_type,
		"upkeep": {},
		"zone_multiplier": zone_multiplier,
	}
	var upkeep_str: Dictionary = {}
	for k in upkeep:
		upkeep_str[String(k)] = float(upkeep[k])
	d["upkeep"] = upkeep_str
	if production_chain != null:
		d["chain"] = production_chain.to_dict()
	return d

static func deserialize(data: Dictionary, def_: UniqueBuilding.Def) -> UniqueBuilding:
	var b := UniqueBuilding.new()
	b.def = def_
	var c: Dictionary = data.get("cell", {})
	b.cell = SerializationUtils.vec2i_from_dict(c, Vector2i(-1, -1))
	b.level = int(data.get("level", 0))
	b.uid = int(data.get("uid", 0))
	b.assigned_followers = int(data.get("assigned_followers", 0))
	b.assigned_workers = int(data.get("assigned_workers", 0))
	b.zone_type = int(data.get("zone_type", 0))
	b.zone_multiplier = float(data.get("zone_multiplier", 1.0))
	var raw_upkeep: Dictionary = data.get("upkeep", {})
	for k in raw_upkeep:
		b.upkeep[StringName(k)] = float(raw_upkeep[k])
	var raw_chain: Dictionary = data.get("chain", {})
	if not raw_chain.is_empty():
		b.production_chain = ProductionChain.from_dict(raw_chain)
	return b
