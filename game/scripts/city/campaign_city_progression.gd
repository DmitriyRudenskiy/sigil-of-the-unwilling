class_name CampaignCityProgression
extends RefCounted

const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")

const CELL_LIMITS: Array[int] = [4, 9, 14, 19, 24, 29, 34, 39, 44, 48, 52]
const MAX_LEVEL := 11

static func cell_limit(level: int) -> int:
	return CELL_LIMITS[clampi(level, 1, MAX_LEVEL) - 1]

static func occupied_cells(city: City) -> Dictionary:
	var occupied := {}
	if city == null:
		return occupied
	var city_cells := CampaignBuildingPlacement.city_cells(city.center)
	var city_cell_set := {}
	for cell in city_cells:
		city_cell_set[cell] = true
		if city.cell_is_built(cell):
			occupied[cell] = true
	for instance in city.campaign_buildings:
		if not (instance is Dictionary):
			continue
		var anchor: Vector2i = instance.get("cell", Vector2i.ZERO)
		var footprint := CampaignBuildingPlacement.footprint_cells(
			anchor, instance.get("footprint", [[0, 0]]))
		if footprint.is_empty():
			footprint = [anchor]
		for cell in footprint:
			if city_cell_set.has(cell):
				occupied[cell] = true
	return occupied

static func construction_check(city: City, cells: Array) -> Dictionary:
	if city == null:
		return {"ok": false, "reason": "no_city"}
	var occupied := occupied_cells(city)
	var added := {}
	for cell in cells:
		if cell is Vector2i and not occupied.has(cell):
			added[cell] = true
	var used := occupied.size()
	var projected := used + added.size()
	var limit := cell_limit(city.level)
	return {
		"ok": projected <= limit,
		"reason": "" if projected <= limit else "city_capacity",
		"level": city.level,
		"used": used,
		"added": added.size(),
		"projected": projected,
		"limit": limit,
		"remaining": maxi(0, limit - used),
	}

static func level_up_check(city: City) -> Dictionary:
	if city == null:
		return {"ok": false, "reason": "no_city"}
	var used := occupied_cells(city).size()
	var limit := cell_limit(city.level)
	if city.level >= MAX_LEVEL:
		return {"ok": false, "reason": "maximum_level", "level": city.level,
			"used": used, "limit": limit, "missing": 0}
	var missing := maxi(0, limit - used)
	return {"ok": missing == 0,
		"reason": "" if missing == 0 else "allowance_not_full",
		"level": city.level, "used": used, "limit": limit, "missing": missing}

static func try_level_up(city: City) -> Dictionary:
	var check := level_up_check(city)
	if not bool(check.get("ok", false)):
		return check
	city.level += 1
	city.boroughs_changed.emit()
	return {"ok": true, "level": city.level, "limit": cell_limit(city.level),
		"used": int(check.used)}
