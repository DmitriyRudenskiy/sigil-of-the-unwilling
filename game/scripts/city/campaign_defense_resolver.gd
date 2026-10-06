class_name CampaignDefenseResolver
extends RefCounted

static func explain(buildings: Array) -> Dictionary:
	var contributions: Array[Dictionary] = []
	var total := 0
	for building in buildings:
		if not (building is Dictionary):
			continue
		var roles: Variant = building.get("roles", [])
		if not (roles is Array) or not (roles.has("static_defense") or roles.has("city_defense")):
			continue
		var state := String(building.get("state", "active"))
		var defense: Variant = building.get("defense", {})
		if not (defense is Dictionary):
			continue
		var value := maxi(0, roundi(float(defense.get(state, 0.0))))
		if value <= 0:
			continue
		total += value
		contributions.append({
			"building_uid": int(building.get("uid", -1)),
			"building_id": String(building.get("id", "")),
			"state": state,
			"defense": value,
		})
	return {"strength": total, "contributions": contributions}

static func strength(buildings: Array) -> int:
	return int(explain(buildings).strength)
