# FILE: res://scripts/data/TerrainResourceManager.gd  (ПОЛНАЯ ЗАМЕНА)
extends Node
class_name TerrainResourceManager

const HexUtils = preload("res://scripts/core/HexUtils.gd")
const GameLogger = preload("res://scripts/core/GameLogger.gd")
const ResourceType = preload("res://scripts/data/ResourceType.gd")

const TERRAIN_RESOURCE_MAP: Dictionary = {
	HexUtils.Terrain.FOREST: ResourceType.ID.WOOD,
	HexUtils.Terrain.MOUNTAIN: ResourceType.ID.STONE,
}
const HARVEST_AMOUNT := 2
signal terrain_harvested(cell: Vector2i, res_id: StringName, amount: int)
signal terrain_exhausted(cell: Vector2i, res_id: StringName)

var cells: Dictionary = {}   # cell -> {"res": int(ResourceType.ID), "exhausted": bool}
var density: float = 1.0
var _world_delta: Variant = null

func attach_delta(delta: Variant) -> void:
	_world_delta = delta

func _ready() -> void:
	pass

func generate(map_data: Dictionary, density: float = -1.0) -> void:
	cells.clear()
	if density < 0.0:
		density = self.density
	elif density >= 0.0:
		self.density = density
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(map_data.get("seed", 0))
	var terrain_map: Dictionary = map_data.get("terrain", {})
	var width: int = map_data.get("width", 0)
	var height: int = map_data.get("height", 0)
	if width == 0 or height == 0:
		return
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if not terrain_map.has(cell):
				continue
			var terrain_id: int = int(terrain_map[cell])
			var res_id: Variant = TERRAIN_RESOURCE_MAP.get(terrain_id)
			if res_id == null:
				continue
			if rng.randf() <= density:
				cells[cell] = {"res": int(res_id), "exhausted": false}

func is_harvestable(cell: Vector2i) -> bool:
	var c: Variant = cells.get(cell, null)
	return c != null and not c.get("exhausted", false)

func res_id_at(cell: Vector2i) -> Variant:
	var c: Variant = cells.get(cell, null)
	if c == null:
		return null
	return ResourceType.to_name(int(c["res"]))

func harvest(cell: Vector2i) -> Dictionary:
	var c = cells.get(cell, null)
	if c == null or c.get("exhausted", false):
		return {"res_id": null, "amount": 0}
	var res_id: StringName = ResourceType.to_name(int(c["res"]))
	c["exhausted"] = true
	if _world_delta != null and _world_delta.has_method("add_terrain_exhausted"):
		_world_delta.add_terrain_exhausted(cell)
	terrain_harvested.emit(cell, res_id, HARVEST_AMOUNT)
	terrain_exhausted.emit(cell, res_id)
	GameLogger.world("Terrain resource harvested at %s: %s" % [cell, res_id])
	return {"res_id": res_id, "amount": HARVEST_AMOUNT}

func mark_exhausted(cells_list: Array) -> void:
	for cell in cells_list:
		if cell is Vector2i and cells.has(cell):
			cells[cell]["exhausted"] = true

func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for cell in cells:
		var c: Dictionary = cells[cell]
		if c.get("exhausted", false):
			out[str(cell)] = c["res"]
	return out

func restore_from_dict(data: Dictionary) -> void:
	for key in data:
		var cell := _parse_cell(str(key))
		if cell is Vector2i and cells.has(cell):
			cells[cell]["exhausted"] = true

func _parse_cell(s: String) -> Vector2i:
	var inner := s.trim_prefix("(").trim_suffix(")")
	var parts: Array = inner.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

func is_exhausted(cell: Vector2i) -> bool:
	var c: Variant = cells.get(cell, null)
	return c != null and c.get("exhausted", false)
