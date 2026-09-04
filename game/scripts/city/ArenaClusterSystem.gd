class_name ArenaClusterSystem
extends RefCounted
## Механика кластеров ×4 (M3): связные группы из CLUSTER_MIN зданий одного
## типа дают CLUSTER_MULT к производству каждого + CLUSTER_HOUSING слотов
## рабочих. Связность — hex-соседство (get_all_neighbors). Перенос из
## CityArenaModel + кэш по версии города.

const ArenaBalance := preload("res://scripts/city/ArenaBalance.gd")
const HexUtils := preload("res://scripts/core/HexUtils.gd")
const City := preload("res://scripts/world/City.gd")
const PopUnit := preload("res://scripts/world/PopUnit.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")

## Кэш результатов: city_uid -> {"ver": int, "cl": Array}. Версия =
## размер buildings + хэш uid зданий; пересчёт при любом изменении
## состава (постройка/снос/пересборка). Сбрасывается invalidate().
static var _cache: Dictionary = {}


## Связные группы ≥CLUSTER_MIN зданий одного типа (hex-соседство).
## Возвращает [ {"def_id", "cells": Array[Vector2i], "buildings"} ] в
## детерминированном порядке (по первой клетке кластера: y, затем x).
static func clusters(city: City) -> Array:
	if city == null:
		return []
	var ver: int = _city_version(city)
	var entry: Dictionary = _cache.get(city.uid, {})
	if int(entry.get("ver", -1)) == ver and entry.has("cl"):
		return entry["cl"]
	var result: Array = _compute_clusters(city)
	_cache[city.uid] = {"ver": ver, "cl": result}
	return result


## ponytail: кэш держится бесконечно (одна запись на uid города); демо-планы
## создают много городов → рост памяти. Потолок: LRU-ёмкость (напр. 32 записи)
## или очистка по таймеру, если станет заметно в профайлере.
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
			if comp.size() >= ArenaBalance.CLUSTER_MIN:
				var cells: Array[Vector2i] = []
				for b in comp:
					cells.append((b as UniqueBuilding).cell)
				out.append({"def_id": def_id, "cells": cells, "buildings": comp})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = (a["cells"] as Array)[0]
		var cb: Vector2i = (b["cells"] as Array)[0]
		return ca.y * 10000 + ca.x < cb.y * 10000 + cb.x)
	return out


## uid здания -> множитель кластера (отсутствует = вне кластера).
static func cluster_uids(city: City) -> Dictionary:
	if city == null:
		return {}
	var m: Dictionary = {}
	for cl in clusters(city):
		for b in (cl as Dictionary)["buildings"]:
			m[(b as UniqueBuilding).uid] = ArenaBalance.CLUSTER_MULT
	return m


## Свободные слоты рабочих с учётом бонуса кластеров (+CLUSTER_HOUSING
## на каждый кластер).
static func cluster_worker_housing(city: City) -> int:
	return city.free_housing(PopUnit.State.WORKER) \
		+ ArenaBalance.CLUSTER_HOUSING * (clusters(city) as Array).size()


## Сброс кэша для города (вызывать при изменении buildings).
static func invalidate(city_uid: int) -> void:
	_cache.erase(city_uid)


## ponytail: хэш uid — быстрая, но теоретически коллизируемая оценка; для
## 100% детерминизма кэша нужен полный построчный хэш buildings (дороже).
static func _city_version(city: City) -> int:
	if city == null:
		return -1
	var h: int = 0
	for bld in city.buildings:
		if bld != null:
			h = (h * 131 + int(bld.uid)) & 0x7fffffff
	return int(city.buildings.size()) * 1_000_003 + h
