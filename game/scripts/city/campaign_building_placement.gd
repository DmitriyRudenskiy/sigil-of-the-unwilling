class_name CampaignBuildingPlacement
extends RefCounted

const ArenaRingSystem := preload("res://scripts/city/arena_ring_system.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const MAX_ADJACENCY_MODIFIER_BP := 10000.0

static func city_cells() -> Array[Vector2i]:
	return ArenaRingSystem.cells_in_arena()

static func footprint_cells(anchor: Vector2i, footprint: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var origin := HexUtils.offset_to_cube(anchor, true)
	for offset in footprint:
		if not (offset is Array) or offset.size() != 2:
			return []
		var q := int(offset[0])
		var r := int(offset[1])
		cells.append(HexUtils.cube_to_offset(origin + Vector3i(q, -q - r, r), true))
	return cells

static func explain_placement(
	building: Dictionary,
	anchor: Vector2i,
	terrain_by_cell: Dictionary,
	occupied: Dictionary,
	special_sites: Dictionary = {}
) -> Dictionary:
	var cells := footprint_cells(anchor, building.get("footprint", []))
	var issues: Array[String] = []
	if cells.is_empty():
		issues.append("invalid footprint")
	var city_cells_set := {}
	for cell in city_cells():
		city_cells_set[cell] = true
	var placement: Dictionary = building.get("placement", {})
	var allowed_terrain: Array = placement.get("terrain_tags", [])
	for cell in cells:
		if not city_cells_set.has(cell):
			issues.append("footprint cell %s is outside the 52-cell city" % cell)
		if occupied.has(cell):
			issues.append("footprint cell %s is occupied" % cell)
		if not allowed_terrain.is_empty() and not allowed_terrain.has(String(terrain_by_cell.get(cell, ""))):
			issues.append("footprint cell %s has disallowed terrain '%s'" % [cell, terrain_by_cell.get(cell, "unknown")])
		if bool(placement.get("requires_special_site", false)) and not special_sites.has(anchor):
			issues.append("anchor %s requires a special site" % anchor)
	return {"ok": issues.is_empty(), "anchor": anchor, "cells": cells, "issues": issues}

static func explain_adjacency(
	building: Dictionary,
	anchor: Vector2i,
	neighbors: Array[Dictionary]
) -> Dictionary:
	var candidate := building.duplicate(true)
	candidate["cell"] = anchor
	var instances: Array[Dictionary] = [candidate]
	for neighbor in neighbors:
		instances.append(neighbor)
	return _evaluate_one(candidate, instances)

## Re-evaluating all placements after a build/merge keeps neighbor effects derived, never cached.
static func recompute_adjacency(buildings: Array) -> Array[Dictionary]:
	var ordered: Array[Dictionary] = []
	for building in buildings:
		if building is Dictionary:
			ordered.append(building.duplicate(true))
	ordered.sort_custom(_building_order)
	var results: Array[Dictionary] = []
	for i in range(ordered.size()):
		results.append({
			"building_id": String(ordered[i].get("id", "")),
			"cell": ordered[i].get("cell", Vector2i.ZERO),
			"breakdown": _evaluate_one(ordered[i], ordered),
		})
	return results

static func _evaluate_one(target: Dictionary, instances: Array[Dictionary]) -> Dictionary:
	if String(target.get("state", "active")) != "active":
		return {"effects": {}, "causes": []}
	var effects := {}
	var causes: Array[Dictionary] = []
	var target_roles := _role_set(target.get("roles", []))
	for source in instances:
		if String(source.get("state", "active")) != "active":
			continue
		if source.get("cell", Vector2i.ZERO) == target.get("cell", Vector2i.ZERO) and source.get("id", "") == target.get("id", ""):
			continue
		var source_id := String(source.get("id", ""))
		var source_cell: Vector2i = source.get("cell", Vector2i.ZERO)
		var source_footprint := footprint_cells(source_cell, source.get("footprint", [[0, 0]]))
		if source_footprint.is_empty():
			source_footprint = [source_cell]
		var distance := _footprint_distance(target, source_footprint)
		for rule in source.get("adjacency", []):
			if not (rule is Dictionary) or not target_roles.has(String(rule.get("target_role", ""))):
				continue
			if distance > int(rule.get("radius", 0)):
				continue
			var effect := String(rule.get("effect", ""))
			var value := float(rule.get("value", 0.0))
			effects[effect] = float(effects.get(effect, 0.0)) + value
			causes.append({
				"source_id": source_id,
				"source_cell": source_cell,
				"target_id": String(target.get("id", "")),
				"target_cell": target.get("cell", Vector2i.ZERO),
				"rule_id": String(rule.get("id", "")),
				"effect": effect,
				"value_bp": value,
				"distance": distance,
			})
	for effect in effects:
		effects[effect] = clampf(float(effects[effect]), -MAX_ADJACENCY_MODIFIER_BP, MAX_ADJACENCY_MODIFIER_BP)
	causes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.source_cell.y != b.source_cell.y:
			return a.source_cell.y < b.source_cell.y
		if a.source_cell.x != b.source_cell.x:
			return a.source_cell.x < b.source_cell.x
		if a.source_id != b.source_id:
			return a.source_id < b.source_id
		return a.rule_id < b.rule_id
	)
	return {"effects": effects, "causes": causes}

static func _footprint_distance(target: Dictionary, source_cells: Array[Vector2i]) -> int:
	var target_cells := footprint_cells(
		target.get("cell", Vector2i.ZERO), target.get("footprint", [[0, 0]]))
	if target_cells.is_empty():
		target_cells = [target.get("cell", Vector2i.ZERO)]
	var distance := 2147483647
	for target_cell in target_cells:
		for source_cell in source_cells:
			distance = mini(distance, HexUtils.hex_distance(target_cell, source_cell, true))
	return distance

static func _role_set(roles: Variant) -> Dictionary:
	var out := {}
	if roles is Array:
		for role in roles:
			out[String(role)] = true
	return out

static func _building_order(a: Dictionary, b: Dictionary) -> bool:
	var ac: Vector2i = a.get("cell", Vector2i.ZERO)
	var bc: Vector2i = b.get("cell", Vector2i.ZERO)
	if ac.y != bc.y:
		return ac.y < bc.y
	if ac.x != bc.x:
		return ac.x < bc.x
	return String(a.get("id", "")) < String(b.get("id", ""))
