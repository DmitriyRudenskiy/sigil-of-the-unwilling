class_name EconomicTurnProcessor
extends TurnPhaseProcessor
## Фаза 1 (M1: Экономика). Исполняется ПОСЛЕ монолита городов
## (City.process_turn) — добавочная: не трогает легасийный
## city.storage, работает через city.resource_ctx.
##
## Порядок внутри фазы:
##  1. Авто-ресурсы — дрова/камень по GameSettings (базовый уклад мира;
##     они — вход для цепочек, поэтому идут ПЕРВЫМИ);
##  2. Цепочки производства зданий (production_chain) — входы списываются
##     из resource_ctx, выходы добавляются туда же;
##  3. Поддержка (upkeep) — списывается ресурс на содержание зданий.
##
## Внешние эффекты (GameEventBus/UI) не вызываются здесь: сигналы
## процессора пробрасывает интеграционный слой (WorldBootstrap).

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

	# 1. Авто-ресурсы (базовый уклад) — вход для цепочек.
	var auto: Dictionary = {}
	auto[&"wood"] = res.add(&"wood", float(GameSettings.RESOURCE_AUTO_WOOD_PER_DAY))
	auto[&"stone"] = res.add(&"stone", float(GameSettings.RESOURCE_AUTO_STONE_PER_DAY))
	report["auto"] = auto

	# 2. Цепочки производства.
	for building in city.buildings:
		if building == null:
			continue
		var chain: ProductionChain = building.get_production_chain()
		if chain == null:
			continue
		var workers: int = city.count_state(PopUnit.State.WORKER)
		var logistics: float = city.get_logistics_multiplier(building.cell)
		var outputs: Dictionary = chain.execute(res, workers, logistics)
		if outputs.is_empty():
			# Цепочка не отработала (нет рабочих или нехватка входов);
			# входы не списаны — execute() атомарен.
			continue
		for out_id in outputs:
			var added: float = res.add(out_id, float(outputs[out_id]))
			if added <= 0.0 and res.get_capacity(out_id) > 0.0:
				resource_depleted.emit(city.uid, out_id)
		report["chains"] += 1
		production_completed.emit(city.uid, chain.id, outputs)

	# 3. Поддержка.
	for building in city.buildings:
		if building == null:
			continue
		var upkeep: Dictionary = building.get_upkeep()
		if upkeep.is_empty():
			continue
		if res.spend(upkeep):
			report["upkeep_ok"] += 1
		else:
			report["upkeep_failed"] += 1
		for rid in upkeep:
			if res.amount(rid) < float(upkeep[rid]):
				upkeep_failed.emit(building.uid, rid)

	return report
