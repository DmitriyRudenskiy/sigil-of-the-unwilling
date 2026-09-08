class_name ArenaClusterSystem
extends RefCounted

const HexUtils := preload("res://scripts/core/HexUtils.gd")
const City := preload("res://scripts/world/City.gd")
const PopUnit := preload("res://scripts/world/PopUnit.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")

# TASK_06: кэш больше не живёт в статическом поле.
# Он привязан к самому городу (city.set_meta / get_meta),
# а версия кэша пересчитывается при каждом обращении,
# поэтому при любом изменении города кэш автоматически становится невалидным.


static func clusters(city: City) -> Array:
	if city == null:
		return []
	var version: int = _city_version(city)
	var cache: Dictionary = city.get_meta(&"arena_clusters_cache", {})
	if int(cache.get(&"version", -1)) == version and cache.has(&"clusters"):
		return cache[&"clusters"]
	var result: Array = _compute_clusters(city)
	city.set_meta(&"arena_clusters_cache", {
		&"version": version,
		&"clusters": result
	})
	return result


static func _compute_clusters(city: City) -> Array:
	var by_def: Dictionary = {}
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		if not by_def.has(b.def.id):
			by_def[b.def.id] = []
		(by_def[b.def.id] as Array).append(b)
	var out: Array = []
	for def_id in by_def:
		var bldgs: Array = by_def[def_id]
		var by_cell: Dictionary = {}
		for b in bldgs:
			by_cell[(b as UniqueBuilding).cell] = b
		var seen: Dictionary = {}
		for b0 in bldgs:
			var start: UniqueBuilding = b0
			if seen.has(start.uid):
				continue
			var comp: Array = []
			var stack: Array = [start]
			seen[start.uid] = true
			while not stack.is_empty():
				var b: UniqueBuilding = stack.pop_back()
				comp.append(b)
				for nb in HexUtils.get_all_neighbors(b.cell):
					var nb_b: UniqueBuilding = by_cell.get(nb)
					if nb_b != null and not seen.has(nb_b.uid):
						seen[nb_b.uid] = true
						stack.append(nb_b)
			if comp.size() >= GameNumbers.ARENA_CLUSTER_MIN:
				var cells: Array[Vector2i] = []
				for b in comp:
					cells.append((b as UniqueBuilding).cell)
				out.append({"def_id": def_id, "cells": cells, "buildings": comp})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = (a["cells"] as Array)[0]
		var cb: Vector2i = (b["cells"] as Array)[0]
		return ca.y * 10000 + ca.x < cb.y * 10000 + cb.x)
	return out


static func cluster_uids(city: City) -> Dictionary:
	if city == null:
		return {}
	var m: Dictionary = {}
	for cl in clusters(city):
		for b in (cl as Dictionary)["buildings"]:
			m[(b as UniqueBuilding).uid] = GameNumbers.ARENA_CLUSTER_MULT
	return m


static func cluster_worker_housing(city: City) -> int:
	if city == null:
		return 0
	return city.free_housing(PopUnit.State.WORKER) \
		+ GameNumbers.ARENA_CLUSTER_HOUSING * (clusters(city) as Array).size()


static func invalidate(_city_uid: int) -> void:
	# TASK_06: старая сигнатура сохранена для совместимости.
	# Теперь кэш привязан к объекту City и сам инвалидируется
	# по версии (uid + def + cell + level + workers),
	# поэтому отдельное удаление по uid не требуется.
	pass


static func invalidate_city(city: City) -> void:
	if city != null and city.has_meta(&"arena_clusters_cache"):
		city.remove_meta(&"arena_clusters_cache")


static func reset() -> void:
	# TASK_06: без статического кэша сбрасывать нечего.
	# Кэш живёт в meta городов и исчезает вместе с ними.
	pass


static func _city_version(city: City) -> int:
	if city == null:
		return -1
	var h: int = 0
	for bld in city.buildings:
		if bld != null:
			h = (h * 131 + int(bld.uid)) & 0x7fffffff
			h = (h * 137 + bld.level) & 0x7fffffff
			h = (h * 139 + bld.assigned_workers) & 0x7fffffff
			if bld.def != null:
				h = (h * 149 + int(bld.def.id.hash())) & 0x7fffffff
			h = (h * 151 + bld.cell.x) & 0x7fffffff
			h = (h * 157 + bld.cell.y) & 0x7fffffff
	return int(city.buildings.size()) * 1_000_003 + h
