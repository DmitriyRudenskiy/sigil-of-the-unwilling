class_name RaceEconomy
extends RefCounted

## race-economy (Phase 2): 7 расовых экономических профилей.
## Данные: res://assets/data/race_economy.json. Дизайн: doc/races-economy.md.
##
## Хуки (doc §2, §9):
## - production -> ProductionChain.building_eff (специализация расы)
## - synergy    -> logistics_calculator / zone_multiplier
## - conflict   -> AdjacencySystem (моральный штраф соседям)
## - needs      -> happiness_change (дефицит -> -мораль)
##
## Анти-имба: несколько рас в одном здании -> берём МАКСИМУМ building_eff,
## не сумму (best_production_mult).

const DATA_PATH := "res://assets/data/race_economy.json"

static var _cache: Dictionary = {}  # race_id (StringName) -> profile Dictionary


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("RaceEconomy: data not found: %s" % DATA_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	if data is Array:
		for raw in data:
			if raw is Dictionary:
				var id := StringName(raw.get("race_id", ""))
				if id != &"":
					_cache[id] = raw


static func all() -> Dictionary:
	_ensure_loaded()
	return _cache


static func has(race_id: StringName) -> bool:
	_ensure_loaded()
	return _cache.has(race_id)


static func profile(race_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _cache.get(race_id, {})


# --- Специализация (building_eff) ---

## Множитель building_eff для здания; 1.0 = бонуса нет.
static func production_mult(race_id: StringName, building_id: StringName) -> float:
	var prod: Dictionary = profile(race_id).get("production", {})
	return float(prod.get(String(building_id), 1.0))


## Максимум специализации по набору рас (анти-имба: не сумма).
static func best_production_mult(races: Array, building_id: StringName) -> float:
	var best := 1.0
	for r in races:
		best = maxf(best, production_mult(StringName(r), building_id))
	return best


# --- Нужды (мораль) ---

static func needs_primary(race_id: StringName) -> StringName:
	return StringName(_needs(race_id).get("primary", ""))


static func needs_secondary(race_id: StringName) -> StringName:
	return StringName(_needs(race_id).get("secondary", ""))


static func not_needed(race_id: StringName) -> Array:
	return _needs(race_id).get("not_needed", [])


static func _needs(race_id: StringName) -> Dictionary:
	var n: Variant = profile(race_id).get("needs", {})
	return n if n is Dictionary else {}


# --- Аскетизм ---

static func is_ascetic(race_id: StringName) -> bool:
	return bool(profile(race_id).get("ascetic", false))


# --- Синергия / конфликт ---

## Множитель логистики к соседям-партнёрам; 1.0 = нет.
static func synergy_logistics(race_id: StringName, other: StringName) -> float:
	return float(_pair(race_id, "synergy", other, "logistics", 1.0))


## Моральный штраф от соседей-антипат; 0 = нет.
static func conflict_morale(race_id: StringName, other: StringName) -> int:
	return int(_pair(race_id, "conflict", other, "morale", 0))


## Расовая синергия квартала: максимум synergy_logistics между расой здания
## и расами соседей (анти-имба: не сумма). 1.0 = нет синергии.
static func district_synergy_mult(city: City, building: UniqueBuilding) -> float:
	if city == null or building == null:
		return 1.0
	var mine := building.worker_race
	if mine == &"":
		return 1.0
	var best := 1.0
	for nb in HexUtils.get_all_neighbors(building.cell):
		var nb_b := city.get_building_at(nb)
		if nb_b == null or nb_b.worker_race == &"":
			continue
		best = maxf(best, synergy_logistics(mine, nb_b.worker_race))
		best = maxf(best, synergy_logistics(nb_b.worker_race, mine))
	return best


static func _pair(race_id: StringName, key: String, other: StringName,
		val_key: String, defv: float) -> float:
	var list: Variant = profile(race_id).get(key, [])
	if not (list is Array):
		return defv
	for entry in list:
		if entry is Dictionary and StringName(entry.get("with", "")) == other:
			return float(entry.get(val_key, defv))
	return defv


# --- Назначение расы зданиям (Phase 2, вариант A) ---

## Жадное назначение доминирующей расы зданиям города по убыванию
## production_mult. Здание получает ОДНУ расу (лучшую доступную); раса не
## используется чаще, чем её численность в city.race_pop. Buildings без
## работников не получают расу. Пересчитывается каждый тик (идемпотентно).
static func assign_building_races(city: City) -> void:
	var remaining: Dictionary = {}
	for r in city.race_pop:
		remaining[StringName(r)] = int(city.race_pop[r])
	var buildings: Array = city.buildings
	var candidates: Array = []
	for i in buildings.size():
		var b: UniqueBuilding = buildings[i]
		if b == null or b.def == null or b.assigned_workers <= 0:
			continue
		for r in remaining:
			var rn := StringName(r)
			if int(remaining[rn]) <= 0:
				continue
			var mult := production_mult(rn, b.def.id)
			if mult > 1.0:
				candidates.append([mult, i, b, rn])
	candidates.sort_custom(_candidate_less)
	var assigned: Dictionary = {}
	for c in candidates:
		var b: UniqueBuilding = c[2]
		var rn: StringName = c[3]
		if assigned.has(b.uid) or int(remaining[rn]) <= 0:
			continue
		b.worker_race = rn
		remaining[rn] = int(remaining[rn]) - 1
		assigned[b.uid] = true
	for b in buildings:
		if b != null and not assigned.has(b.uid):
			b.worker_race = &""


static func _candidate_less(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] > b[0]  # mult desc
	if a[1] != b[1]:
		return a[1] < b[1]  # index asc
	return String(a[3]) < String(b[3])  # race name asc


static func reset_cache() -> void:
	_cache.clear()
