
class_name EconomicTurnProcessor
extends TurnPhaseProcessor

signal production_completed(city_uid: int, chain_id: StringName, outputs: Dictionary)
signal upkeep_failed(building_uid: int, resource_id: StringName)
signal resource_depleted(city_uid: int, resource_id: StringName)

const ArchetypeResolver := preload("res://scripts/demographics/archetype_resolver.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")

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
		"ledger": [],
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
		(report["ledger"] as Array).append_array(city_report.get("ledger", []))
		var auto: Dictionary = city_report.get("auto", {})
		for rid in auto:
			report["auto_yield"][rid] = float(report["auto_yield"].get(rid, 0.0)) + float(auto[rid])
	return report

func _process_city(city: City, _ctx: TurnContext) -> Dictionary:
	var res := city.ensure_resource_ctx()
	var ledger_start := res.get_ledger().size()
	var report := {"uid": city.uid, "chains": 0, "upkeep_ok": 0, "upkeep_failed": 0, "auto": {}}
	var catalog := ArchetypeResolver.load_catalog()

	var auto: Dictionary = {}
	var wood_id: StringName = ResourceType.to_name(ResourceType.ID.WOOD)
	var stone_id: StringName = ResourceType.to_name(ResourceType.ID.STONE)
	auto[wood_id] = res.add(
		wood_id, float(GameNumbers.RESOURCE_AUTO_WOOD) * city.auto_resource_mult, "automatic_wood_yield")
	auto[stone_id] = res.add(
		stone_id, float(GameNumbers.RESOURCE_AUTO_STONE) * city.auto_resource_mult, "automatic_stone_yield")
	report["auto"] = auto
	_process_campaign_buildings(city, res, report, catalog)

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
		var execution := chain.execute_transaction(res, workers, logistics, "building:%d/recipe:%s" % [building.uid, chain.id])
		var outputs: Dictionary = execution.get("outputs", {})
		if outputs.is_empty():
			if execution.get("reason") == "insufficient_capacity":
				for out_id in chain.calculate_output(workers, logistics):
					resource_depleted.emit(city.uid, out_id)
			continue
		report["chains"] += 1
		city.food_supply_this_turn += float(outputs.get(&"food", 0.0)) \
			- float(chain.inputs.get(&"food", 0.0))
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
		if res.spend(effective, "building:%d/upkeep" % building.uid):
			report["upkeep_ok"] += 1
			city.food_supply_this_turn -= float(effective.get(&"food", 0.0))
		else:
			report["upkeep_failed"] += 1
		for rid in effective:
			if res.amount(rid) < float(effective[rid]):
				upkeep_failed.emit(building.uid, rid)

	report["campaign_population"] = _process_campaign_population(city, catalog)
	var ledger := res.get_ledger()
	report["ledger"] = ledger.slice(ledger_start)
	return report

func _process_campaign_buildings(
	city: City, resources: ResourceContext, report: Dictionary, catalog: Dictionary
) -> void:
	var specialization: Array[Dictionary] = []
	var adjacency_bonus_by_building := {}
	for result in CampaignBuildingPlacement.recompute_adjacency(city.campaign_buildings):
		var effects: Dictionary = result.get("breakdown", {}).get("effects", {})
		if effects.has("output_bp"):
			var cell: Vector2i = result.get("cell", Vector2i.ZERO)
			var key := _campaign_building_key(String(result.get("building_id", "")), cell)
			adjacency_bonus_by_building[key] = int(effects["output_bp"])
	for building in city.campaign_buildings:
		if String(building.get("state", "active")) != "active":
			continue
		var assigned_workers := maxi(0, int(building.get("assigned_workers", 0)))
		var workers_by_group := _assigned_workers_by_group(city, building, catalog)
		var roles: Array = building.get("roles", [])
		var specialization_bp := ArchetypeResolver.specialization_bonus_bp(
			catalog, roles, workers_by_group, int(building.get("jobs", assigned_workers)))
		var cell: Vector2i = building.get("cell", Vector2i.ZERO)
		var adjacency_bp := int(adjacency_bonus_by_building.get(
			_campaign_building_key(String(building.get("id", "")), cell), 0))
		var output_bonus_bp := clampi(specialization_bp + adjacency_bp, -10000, 10000)
		for recipe in building.get("recipes", []):
			if not (recipe is Dictionary):
				continue
			var required_workers := int(recipe.get("workers", 0))
			if required_workers <= 0 or assigned_workers <= 0:
				continue
			var ratio := minf(float(assigned_workers), float(required_workers)) / float(required_workers)
			var inputs := _scaled_campaign_resources(recipe.get("inputs", {}), ratio)
			var base_outputs := _scaled_campaign_resources(recipe.get("outputs", {}), ratio)
			if not _campaign_resources_allowed(inputs) or not _campaign_resources_allowed(base_outputs):
				continue
			var recipe_id := String(recipe.get("id", ""))
			var fixed_outputs := _apply_specialization(building, recipe_id, base_outputs, output_bonus_bp)
			var building_id := String(building.get("id", ""))
			var source := "campaign-building:%s/recipe:%s" % [building_id, recipe_id]
			var result := {"ok": true}
			if not inputs.is_empty() or not fixed_outputs.outputs.is_empty():
				result = resources.transact(inputs, fixed_outputs.outputs, source)
			if not bool(result.get("ok", false)):
				continue
			building["production_remainders"] = fixed_outputs.remainders
			city.food_supply_this_turn += float(fixed_outputs.outputs.get(&"food", 0.0)) \
				- float(inputs.get(&"food", 0.0))
			if not inputs.is_empty() or not fixed_outputs.outputs.is_empty():
				report["chains"] = int(report.get("chains", 0)) + 1
				production_completed.emit(city.uid, StringName("%s:%s" % [building_id, recipe_id]), fixed_outputs.outputs)
			specialization.append({
				"building_uid": int(building.get("uid", -1)), "recipe_id": recipe_id,
				"specialization_bonus_bp": specialization_bp,
				"adjacency_bonus_bp": adjacency_bp,
				"output_bonus_bp": output_bonus_bp,
				"outputs": fixed_outputs.outputs.duplicate(),
			})

		var upkeep := _scaled_campaign_resources(building.get("upkeep", {}), 1.0)
		if upkeep.is_empty() or not _campaign_resources_allowed(upkeep):
			continue
		var upkeep_source := "campaign-building:%s/upkeep" % String(building.get("id", ""))
		if resources.spend(upkeep, upkeep_source):
			city.food_supply_this_turn -= float(upkeep.get(&"food", 0.0))
			report["upkeep_ok"] = int(report.get("upkeep_ok", 0)) + 1
		else:
			report["upkeep_failed"] = int(report.get("upkeep_failed", 0)) + 1
			for resource_id in upkeep:
				if resources.amount(StringName(resource_id)) < float(upkeep[resource_id]):
					upkeep_failed.emit(int(building.get("uid", -1)), StringName(resource_id))
					break
	report["specialization"] = specialization

func _campaign_building_key(building_id: String, cell: Vector2i) -> String:
	return "%s:%d:%d" % [building_id, cell.x, cell.y]

func _assigned_workers_by_group(city: City, building: Dictionary, catalog: Dictionary) -> Dictionary:
	var counts := {}
	var uid := int(building.get("uid", -1))
	for pop in city.pop:
		if pop.state != PopUnit.State.WORKER or pop.assigned_to != uid:
			continue
		var group_id := ArchetypeResolver.group_id_for_identity(
			catalog, pop.ancestry_id, pop.archetype_id)
		if not group_id.is_empty():
			counts[group_id] = int(counts.get(group_id, 0)) + 1
	return counts

func _apply_specialization(
	building: Dictionary, recipe_id: String, base_outputs: Dictionary, bonus_bp: int
) -> Dictionary:
	var old_remainders: Dictionary = building.get("production_remainders", {})
	var remainders: Dictionary = old_remainders.duplicate(true)
	var outputs := {}
	for resource_id in base_outputs:
		var key := "%s/%s" % [recipe_id, String(resource_id)]
		var scaled := float(base_outputs[resource_id]) * (10000.0 + float(bonus_bp)) \
			+ float(remainders.get(key, 0.0))
		var whole: float = floor(scaled / 10000.0)
		if whole > 0.0:
			outputs[StringName(resource_id)] = whole
		remainders[key] = fmod(scaled, 10000.0)
	return {"outputs": outputs, "remainders": remainders}

func _process_campaign_population(city: City, catalog: Dictionary) -> Dictionary:
	var population_by_group := {}
	for pop in city.pop:
		var group_id := ArchetypeResolver.group_id_for_identity(
			catalog, pop.ancestry_id, pop.archetype_id)
		if not group_id.is_empty():
			population_by_group[group_id] = int(population_by_group.get(group_id, 0)) + 1

	var service_capacity := {}
	var relation_deltas := {}
	var workplace_pairs: Array[Dictionary] = []
	var workers_by_group_total := {}
	for building in city.campaign_buildings:
		if String(building.get("state", "active")) != "active":
			continue
		var services: Dictionary = building.get("services", {})
		for need_id in services:
			service_capacity[String(need_id)] = float(service_capacity.get(String(need_id), 0.0)) \
				+ maxf(float(services[need_id]), 0.0)
		var workers := _assigned_workers_by_group(city, building, catalog)
		for group_id in workers:
			workers_by_group_total[group_id] = int(workers_by_group_total.get(group_id, 0)) \
				+ int(workers[group_id])
		var mediation_id := String(catalog.get("archetype_rules", {}).get(
			"relation_mediation_service_id", "community_mediation"))
		var mediation_capacity := int(floor(float(services.get(mediation_id, 0.0))))
		var present_groups: Array = workers.keys()
		var relation_result := ArchetypeResolver.resolve_workplace_relations(
			catalog, workers, mediation_capacity, present_groups)
		for group_id in relation_result.deltas:
			relation_deltas[group_id] = int(relation_deltas.get(group_id, 0)) \
				+ int(relation_result.deltas[group_id])
		for pair in relation_result.pairs:
			var row: Dictionary = pair.duplicate(true)
			row["building_uid"] = int(building.get("uid", -1))
			workplace_pairs.append(row)

	var demand_by_need := {}
	for group in catalog.get("groups", []):
		if not (group is Dictionary):
			continue
		var group_id := String(group.get("id", ""))
		var need_id := String(group.get("signature_need", ""))
		if need_id != "food":
			demand_by_need[need_id] = int(demand_by_need.get(need_id, 0)) \
				+ int(population_by_group.get(group_id, 0))

	var states: Dictionary = city.campaign_group_state.duplicate(true)
	var group_report := {}
	var rules: Dictionary = catalog.get("archetype_rules", {})
	for group in catalog.get("groups", []):
		if not (group is Dictionary):
			continue
		var group_id := String(group.get("id", ""))
		var residents := int(population_by_group.get(group_id, 0))
		if residents <= 0:
			continue
		var need_id := String(group.get("signature_need", ""))
		var demand: int
		var supplied: int
		if need_id == "food":
			demand = int(round(city.food_demand_this_turn * 1000.0))
			supplied = int(round(maxf(city.food_supply_this_turn, 0.0) * 1000.0))
		else:
			demand = int(demand_by_need.get(need_id, 0))
			supplied = int(floor(float(service_capacity.get(need_id, 0.0)) * 1000.0))
		var coverage := ArchetypeResolver.need_coverage_percent(demand, supplied)
		var state: Dictionary = states.get(group_id, {})
		var resolved := ArchetypeResolver.resolve_need_turn(
			group, int(state.get("satisfaction", rules.get("initial_satisfaction", 50))),
			int(state.get("unmet_turns", 0)), coverage, rules)
		var relation_delta := clampi(int(relation_deltas.get(group_id, 0)),
			int(rules.get("relation_delta_min", -2)), int(rules.get("relation_delta_max", 2)))
		resolved["satisfaction"] = clampi(
			int(resolved.satisfaction) + relation_delta,
			int(rules.get("satisfaction_min", 0)), int(rules.get("satisfaction_max", 100)))
		states[group_id] = {
			"satisfaction": int(resolved.satisfaction), "unmet_turns": int(resolved.unmet_turns),
		}
		group_report[group_id] = {
			"residents": residents, "need": need_id, "coverage_percent": coverage,
			"satisfaction": int(resolved.satisfaction), "unmet_turns": int(resolved.unmet_turns),
			"relation_delta": relation_delta,
		}
	city.campaign_group_state = states
	return {
		"groups": group_report,
		"workers_by_group": workers_by_group_total,
		"workplace_pairs": workplace_pairs,
		"service_capacity": service_capacity,
	}

func _scaled_campaign_resources(values: Variant, ratio: float) -> Dictionary:
	var scaled := {}
	if not (values is Dictionary):
		return scaled
	for resource_id in values:
		scaled[StringName(resource_id)] = float(values[resource_id]) * ratio
	return scaled

func _campaign_resources_allowed(values: Dictionary) -> bool:
	for resource_id in values:
		if not ResourceRegistry.CAMPAIGN_MVP_IDS.has(StringName(resource_id)):
			return false
	return true
