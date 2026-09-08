class_name CityIncomeProcessor
extends TurnPhaseProcessor


func get_phase_id() -> StringName:
	return &"city_income"


func get_priority() -> int:
	return 15


func process(ctx: TurnContext) -> Dictionary:
	var total := {}
	var per_city: Array = []
	if ctx == null:
		return {"total": total, "per_city": per_city}
	for city in ctx.cities:
		if city == null or city.owner != &"player":
			continue
		if city.resource_ctx == null:
			continue
		var gold: float = city.resource_ctx.amount(&"gold")
		var royalty: int = int(floor(gold * GameNumbers.ROYALTY_FRACTION))
		if royalty <= 0:
			continue
		city.resource_ctx.remove(&"gold", float(royalty))
		per_city.append({"uid": city.uid, "name": city.display_name,
			"royalty": royalty})
		total[&"gold"] = float(int(total.get(&"gold", 0.0)) + royalty)
	return {"total": total, "per_city": per_city}
