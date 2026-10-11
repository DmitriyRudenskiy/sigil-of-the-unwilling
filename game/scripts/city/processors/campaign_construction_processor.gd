class_name CampaignConstructionProcessor
extends TurnPhaseProcessor

func get_phase_id() -> StringName:
	return &"campaign_construction"

func get_priority() -> int:
	return 9

func process(ctx: TurnContext) -> Dictionary:
	var report := {"advanced": 0, "completed": [], "cities": []}
	if ctx == null:
		return report
	for city in ctx.cities:
		if city == null:
			continue
		var city_report := {"uid": city.uid, "advanced": 0, "completed": []}
		for index in range(city.campaign_buildings.size()):
			var instance: Dictionary = city.campaign_buildings[index]
			var remaining := int(instance.get("construction_turns_remaining", 0))
			if remaining <= 0 or String(instance.get("state", "active")) == "ruined":
				continue
			remaining -= 1
			instance["construction_turns_remaining"] = remaining
			if remaining == 0:
				instance["state"] = "active"
				(city_report["completed"] as Array).append(int(instance.get("uid", -1)))
			city.campaign_buildings[index] = instance
			city_report["advanced"] = int(city_report["advanced"]) + 1
		if int(city_report["advanced"]) > 0:
			city.buildings_changed.emit()
		(report["completed"] as Array).append_array(city_report["completed"])
		report["advanced"] = int(report["advanced"]) + int(city_report["advanced"])
		(report["cities"] as Array).append(city_report)
	return report
