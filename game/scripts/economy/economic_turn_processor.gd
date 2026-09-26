
class_name EconomicTurnProcessor
extends TurnPhaseProcessor

signal production_completed(city_uid: int, chain_id: StringName, outputs: Dictionary)
signal upkeep_failed(building_uid: int, resource_id: StringName)
signal resource_depleted(city_uid: int, resource_id: StringName)

func get_phase_id() -> StringName:
	return &"economy"

func get_priority() -> int:
	return 10

func process(ctx: TurnContext) -> Dictionary:
	var report := {
		"chains_executed": 0,
		"upkeep_ok": 0,
		"upkeep_failed": 0,
		"auto_yield": {},
		"cities": [],
	}
	if ctx == null:
		return report

	for city in ctx.cities:
		var city_report: Dictionary = _process_city(city, ctx)
		report["chains_executed"] += int(city_report.get("chains", 0))
		report["upkeep_ok"] += int(city_report.get("upkeep_ok", 0))
		report["upkeep_failed"] += int(city_report.get("upkeep_failed", 0))
		(report["cities"] as Array).append(city_report)
		var auto: Dictionary = city_report.get("auto", {})
		for rid in auto:
			report["auto_yield"][rid] = float(report["auto_yield"].get(rid, 0.0)) + float(auto[rid])
	return report

func _process_city(city: City, _ctx: TurnContext) -> Dictionary:
	var res := city.ensure_resource_ctx()
	var report := {"uid": city.uid, "chains": 0, "upkeep_ok": 0, "upkeep_failed": 0, "auto": {}}

	var auto: Dictionary = {}
	var wood_id: StringName = ResourceType.to_name(ResourceType.ID.WOOD)
	var stone_id: StringName = ResourceType.to_name(ResourceType.ID.STONE)
	auto[wood_id] = res.add(
		wood_id, float(GameNumbers.RESOURCE_AUTO_WOOD) * city.auto_resource_mult)
	auto[stone_id] = res.add(
		stone_id, float(GameNumbers.RESOURCE_AUTO_STONE) * city.auto_resource_mult)
	report["auto"] = auto

	for building in city.buildings:
		if building == null:
			continue
		var chain: ProductionChain = building.get_production_chain()
		if chain == null:
			continue
		var workers: int = building.assigned_workers
		# Ранняя игра: сезонный цикл масштабирует производство (early-game-foundation)
		var logistics: float = city.get_logistics_multiplier(building.cell) \
			* building.zone_multiplier \
			* AdjacencySystem.building_output_mult(city, building) \
			* WorldSeasons.production_mult()
		var outputs: Dictionary = chain.execute(res, workers, logistics)
		if outputs.is_empty():
			continue
		for out_id in outputs:
			var added: float = res.add(out_id, float(outputs[out_id]))
			if added <= 0.0 and res.get_capacity(out_id) > 0.0:
				resource_depleted.emit(city.uid, out_id)
		report["chains"] += 1
		production_completed.emit(city.uid, chain.id, outputs)

	for building in city.buildings:
		if building == null:
			continue
		var upkeep: Dictionary = building.get_upkeep()
		if upkeep.is_empty():
			continue
		var effective: Dictionary = {}
		for rid in upkeep:
			effective[rid] = float(upkeep[rid]) * city.upkeep_mult
		if res.spend(effective):
			report["upkeep_ok"] += 1
		else:
			report["upkeep_failed"] += 1
		for rid in effective:
			if res.amount(rid) < float(effective[rid]):
				upkeep_failed.emit(building.uid, rid)

	return report
