class_name CityIncomeProcessor
extends TurnPhaseProcessor
## city-in-world: фаза дани городов. Исполняется ПОСЛЕ экономики (10), чтобы
## налог начислялся по золоту, уже произведённом за ход; ДО демографии (20).
##
## Правило: каждый город с owner == &"player" платит долю казны
## (resource_ctx gold × CityBalance.ROYALTY_FRACTION). Сам процессор НЕ
## трогает героя — внешний эффект (hero.add_strategic_resource) делает
## интеграционный слой (WorldEventRouter._grant_city_income по отчёту фазы).
##
## Песочница CityArena: у города арены owner == &"none" → фаза его пропускает.


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
		var royalty: int = int(floor(gold * CityBalance.ROYALTY_FRACTION))
		if royalty <= 0:
			continue
		city.resource_ctx.remove(&"gold", float(royalty))
		per_city.append({"uid": city.uid, "name": city.display_name,
			"royalty": royalty})
		total[&"gold"] = float(int(total.get(&"gold", 0.0)) + royalty)
	return {"total": total, "per_city": per_city}
