extends RefCounted
class_name TerrainCostTable

const GRASS := 1.0
const FOREST := 1.25
const MOUNTAIN := 1.25
const SAND := 1.5
const SNOW := 1.5
const SWAMP := 1.75
const WATER := INF

static var _costs: Dictionary = {}
static var _costs_by_id: PackedFloat32Array = PackedFloat32Array()
static var _levitation_costs_by_id: PackedFloat32Array = PackedFloat32Array()

static func ensure() -> void:
	if not _costs.is_empty():
		return
	_costs = {
		"grass": GRASS,
		"forest": FOREST,
		"mountain": MOUNTAIN,
		"sand": SAND,
		"snow": SNOW,
		"swamp": SWAMP,
		"water": WATER,
	}
	_costs_by_id = PackedFloat32Array()
	_levitation_costs_by_id = PackedFloat32Array()
	for i in HexUtils.TERRAIN_NAMES.size():
		var name: String = HexUtils.TERRAIN_NAMES[i]
		_costs_by_id.append(get_cost(name))
		_levitation_costs_by_id.append(get_cost_with_effects(name, true))

static func get_cost(terrain: String) -> float:
	ensure()
	if terrain == "water":
		return WATER
	return _costs.get(terrain, GRASS)

static func get_cost_with_effects(terrain: String, has_levitation: bool) -> float:
	ensure()
	if terrain == "water":
		return GRASS if has_levitation else WATER
	return _costs.get(terrain, GRASS)

static func get_cost_with_effects_by_id(terrain_id: int, has_levitation: bool) -> float:
	ensure()
	if terrain_id < 0 or terrain_id >= _costs_by_id.size():
		return GRASS
	return _levitation_costs_by_id[terrain_id] if has_levitation else _costs_by_id[terrain_id]

static func get_all_terrains() -> Array[String]:
	ensure()
	var r: Array[String] = []
	for k in _costs:
		r.append(k)
	return r
