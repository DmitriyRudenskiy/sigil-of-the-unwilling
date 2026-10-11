class_name CampaignCityBalanceScenario
extends RefCounted

const CampaignCityBalanceFixture := preload("res://scripts/balance/campaign_city_balance_fixture.gd")
const CampaignBuildingCatalog := preload("res://scripts/data/campaign_building_catalog.gd")
const CampaignBuildingPlacement := preload("res://scripts/city/campaign_building_placement.gd")
const CampaignBuildingConstructionService := preload("res://scripts/city/campaign_building_construction_service.gd")
const CampaignCityProgression := preload("res://scripts/city/campaign_city_progression.gd")
const CampaignDefenseResolver := preload("res://scripts/city/campaign_defense_resolver.gd")
const GameNumbers := preload("res://scripts/constants/game_numbers.gd")
const MVP_RESOURCES := [&"food", &"wood", &"iron"]
const DAYS := 21
const RAID_DAY := 7
const RAID_STRENGTH := 6
const RAID_FOOD_FRACTION := GameNumbers.RAID_PILLAGE_FRACTION
const CONSTRUCTION_ITINERARY := [
	{"day": 1, "id": "campaign_farm"},
	{"day": 1, "id": "campaign_barracks"},
	{"day": 2, "id": "campaign_sawmill"},
	{"day": 4, "id": "campaign_iron_mine"},
	{"day": 6, "id": "campaign_farm"},
	{"day": 9, "id": "aoe4_palisade"},
	{"day": 10, "id": "terrascape_herb_garden"},
	{"day": 11, "id": "terrascape_lotus_basin"},
	{"day": 12, "id": "terrascape_kenbet"},
	{"day": 13, "id": "terrascape_kenbet"},
	{"day": 15, "id": "terrascape_university"},
	{"day": 16, "id": "terrascape_sanctuary"},
	{"day": 17, "id": "terrascape_henge"},
	{"day": 19, "id": "terrascape_kenbet"},
	{"day": 20, "id": "terrascape_great_plaza"},
]
const LEVEL_UP_ITINERARY := [
	{"day": 1, "timing": "before_construction", "level": 1},
	{"day": 2, "timing": "after_construction", "level": 2},
	{"day": 11, "timing": "after_construction", "level": 3},
	{"day": 17, "timing": "after_construction", "level": 4},
]

class FixedRaidInput extends TurnPhaseProcessor:
	const CampaignDefenseResolver := preload("res://scripts/city/campaign_defense_resolver.gd")
	const GameNumbers := preload("res://scripts/constants/game_numbers.gd")
	const RAID_DAY := 7
	const RAID_STRENGTH := 6
	const RAID_FOOD_FRACTION := GameNumbers.RAID_PILLAGE_FRACTION

	func get_phase_id() -> StringName:
		return &"balance_raid_input"

	func get_priority() -> int:
		return 8

	func process(ctx: TurnContext) -> Dictionary:
		var events: Array[Dictionary] = []
		if ctx == null or ctx.turn_number != RAID_DAY:
			return {"events": events}
		for city in ctx.cities:
			if city == null:
				continue
			var defense := CampaignDefenseResolver.strength(city.campaign_buildings)
			var stock_before := city.resource_ctx.amount(&"food")
			var repelled := defense >= RAID_STRENGTH
			var loss := 0.0
			if not repelled:
				loss = city.resource_ctx.remove(&"food", stock_before * RAID_FOOD_FRACTION,
					"campaign:balance_raid:pillage")
			events.append({
				"day": ctx.turn_number,
				"strength": RAID_STRENGTH,
				"defense": defense,
				"repelled": repelled,
				"food_before": stock_before,
				"food_lost": loss,
				"food_after": city.resource_ctx.amount(&"food"),
			})
		return {"events": events}

static func run(targets: Dictionary = {}) -> Dictionary:
	var fixture := CampaignCityBalanceFixture.create()
	var city: City = fixture.city
	var city_manager: CityManager = fixture.city_manager
	var hero: HeroController = fixture.hero
	var catalog := CampaignBuildingCatalog.load_catalog()
	var scheduler := TurnScheduler.new()
	scheduler.register_processor(FixedRaidInput.new())
	scheduler.register_processor(CampaignConstructionProcessor.new())
	scheduler.register_processor(EconomicTurnProcessor.new())
	var days: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var technical_errors: Array[String] = []
	var itinerary_index := 0
	var level_up_index := 0
	var placement_cells := CampaignBuildingPlacement.city_cells(city.center)

	for day in range(1, DAYS + 1):
		city_manager.on_turn_ended(1)
		var level_up_actions: Array[Dictionary] = []
		var before_building := _run_level_up_actions(city, day, "before_construction",
			level_up_index, technical_errors)
		level_up_index = int(before_building.index)
		level_up_actions.append_array(before_building.actions)
		var construction_attempts: Array[Dictionary] = []
		while itinerary_index < CONSTRUCTION_ITINERARY.size() \
				and int(CONSTRUCTION_ITINERARY[itinerary_index].day) == day:
			var action: Dictionary = CONSTRUCTION_ITINERARY[itinerary_index]
			var anchor := placement_cells[6 + itinerary_index]
			var result := CampaignBuildingConstructionService.request(
				city, catalog, String(action.id), anchor)
			var attempt := {
				"day": day,
				"id": String(action.id),
				"ok": bool(result.get("ok", false)),
				"reason": String(result.get("reason", "")),
				"costs": result.get("instance", {}).get("paid_costs", {}),
				"uid": int(result.get("instance", {}).get("uid", -1)),
				"cell": [anchor.x, anchor.y],
			}
			construction_attempts.append(attempt)
			if not attempt.ok:
				if attempt.reason == "insufficient_stock":
					warnings.append(_warning("construction_unaffordable", {
						"expected": "affordable", "actual": false,
						"day": day, "building_id": String(action.id),
						"missing": result.get("missing", {}),
					}))
				else:
					technical_errors.append("Day %d %s construction failed: %s" % [day, action.id, str(result)])
			itinerary_index += 1

		var after_building := _run_level_up_actions(city, day, "after_construction",
			level_up_index, technical_errors)
		level_up_index = int(after_building.index)
		level_up_actions.append_array(after_building.actions)
		var ctx := TurnContext.new()
		ctx.is_campaign = true
		ctx.cities.append(city)
		ctx.heroes.append(hero)
		var turn_report := scheduler.execute_turn(ctx)
		var phases: Dictionary = turn_report.get("phases", {})
		var raid_phase: Dictionary = phases.get(&"balance_raid_input", {})
		var raid_events: Array = raid_phase.get("events", [])
		var economy: Dictionary = phases.get(&"economy", {})
		var city_economy: Dictionary = economy.get("cities", [{}])[0]
		var campaign_food: Dictionary = city_economy.get("campaign_food", {})
		var campaign_population: Dictionary = city_economy.get("campaign_population", {})
		var report := {
			"day": day,
			"construction": construction_attempts,
			"level_up_actions": level_up_actions,
			"city_level": city.level,
			"occupied_city_cells": CampaignCityProgression.occupied_cells(city).size(),
			"city_cell_limit": CampaignCityProgression.cell_limit(city.level),
			"raid": raid_events,
			"ledger": city.resource_ctx.get_ledger().duplicate(true),
			"stocks": _stocks(city),
			"staffing": _staffing(city),
			"buildings": _buildings(city),
			"group_coverage": campaign_population.get("groups", {}).duplicate(true),
			"service_capacity": campaign_population.get("service_capacity", {}).duplicate(true),
			"food": {
				"resident_demand": float(campaign_food.get("resident_demand", 0.0)),
				"resident_consumed": float(campaign_food.get("resident_consumed", 0.0)),
				"resident_shortage": float(campaign_food.get("resident_shortage", 0.0)),
				"party": economy.get("party", {}),
			},
		}
		for resource_id in MVP_RESOURCES:
			if city.resource_ctx.amount(resource_id) < -0.0001:
				technical_errors.append("Day %d %s stock is negative" % [day, resource_id])
		days.append(report)

	if itinerary_index != CONSTRUCTION_ITINERARY.size():
		technical_errors.append("Not all construction actions were replayed")
	if level_up_index != LEVEL_UP_ITINERARY.size():
		technical_errors.append("Not all city level-up actions were replayed")
	var construction_summary := _construction_summary(days, city.campaign_buildings, catalog)
	var first_farm_day := _first_day(construction_summary.construction_build_days.get("campaign_farm", []))
	var first_barracks_day := _first_day(construction_summary.construction_build_days.get("campaign_barracks", []))
	var first_raid: Dictionary = {}
	var first_raid_day := -1
	var food_after_first_raid := -1.0
	for day_report in days:
		var raids: Array = day_report.get("raid", [])
		if not raids.is_empty() and first_raid.is_empty():
			first_raid = raids[0]
			first_raid_day = int(first_raid.get("day", -1))
			food_after_first_raid = float(day_report.stocks.food)
	var day21: Dictionary = days[-1]
	var day21_food := float(day21.stocks.food)
	var forecast_daily_food := float(days[0].food.resident_demand) \
		+ float(days[0].food.party.get("members", 0))
	var day21_food_ceiling := float(targets.get("day21_food_max", forecast_daily_food * 2.0))
	var day21_defense := CampaignDefenseResolver.strength(city.campaign_buildings)
	var day21_group_coverage: Dictionary = day21.group_coverage
	var group_coverage_summary := {}
	var all_groups_covered := not day21_group_coverage.is_empty()
	for group_id in day21_group_coverage:
		var group_state: Dictionary = day21_group_coverage[group_id]
		group_coverage_summary[String(group_id)] = {
			"need": String(group_state.get("need", "")),
			"coverage_percent": int(group_state.get("coverage_percent", 0)),
		}
		if int(group_state.get("coverage_percent", 0)) < 100:
			all_groups_covered = false
	var footprint_used := _footprint_cell_count(city)
	var occupied_city_cells := CampaignCityProgression.occupied_cells(city).size()
	if occupied_city_cells > 52:
		technical_errors.append("Selected city occupies %d cells, maximum is 52" % occupied_city_cells)

	var milestones: Array[Dictionary] = []
	_record_milestone(warnings, milestones, "first_farm_day", {"day": 1}, first_farm_day, first_farm_day == 1)
	_record_milestone(warnings, milestones, "first_barracks_day", {"day": 1}, first_barracks_day, first_barracks_day == 1)
	_record_milestone(warnings, milestones, "first_raid_day", {"day": RAID_DAY}, first_raid_day,
		first_raid_day == RAID_DAY)
	_record_milestone(warnings, milestones, "food_after_first_raid", {"max": 15.0},
		food_after_first_raid, food_after_first_raid >= 0.0 and food_after_first_raid <= 15.0)
	_record_milestone(warnings, milestones, "day21_food", {
		"min": 0.0, "max": day21_food_ceiling,
		"forecast_daily_demand": forecast_daily_food,
	}, day21_food, day21_food >= 0.0 and day21_food <= day21_food_ceiling)
	_record_milestone(warnings, milestones, "day21_defense", {"min": 4}, day21_defense,
		day21_defense >= 4)
	_record_milestone(warnings, milestones, "seven_group_needs", {
		"groups": 7, "coverage_percent": 100,
	}, group_coverage_summary, all_groups_covered and group_coverage_summary.size() == 7)

	var day21_counts: Dictionary = construction_summary.building_counts
	var balance_status := "passes" if warnings.is_empty() else "has %d balance warning(s)" % warnings.size()
	var summary_format := "First farm d%d, barracks d%d; first raid d%d (food %.1f after raid). " \
		+ "Day 21 stocks: food %.1f, wood %.1f, iron %.1f; defense %d; footprint %d/52; " \
		+ "city level %d, occupied cells %d/%d; %s."
	var summary_text := summary_format % [
		first_farm_day, first_barracks_day, first_raid_day, food_after_first_raid,
		day21.stocks.food, day21.stocks.wood, day21.stocks.iron,
		day21_defense, footprint_used, city.level, occupied_city_cells,
		CampaignCityProgression.cell_limit(city.level), balance_status,
	]
	var output := {
		"scenario": "canonical_mvp_campaign_city_21_day",
		"days": DAYS,
		"mode": "campaign",
		"targets": {"day21_food_max": day21_food_ceiling},
		"assumptions": fixture.assumptions,
		"party_roster": fixture.party.duplicate(true),
		"raid_input": {
			"day": RAID_DAY,
			"strength": RAID_STRENGTH,
			"food_pillage_fraction": RAID_FOOD_FRACTION,
			"stochastic_raid_rolls": "omitted; one fixed unrepelled input is injected",
		},
		"catalog_cost_snapshot": _catalog_cost_snapshot(catalog),
		"construction_itinerary": CONSTRUCTION_ITINERARY.duplicate(true),
		"construction_summary": construction_summary,
		"level_up_itinerary": LEVEL_UP_ITINERARY.duplicate(true),
		"city_progression": {
			"level": city.level,
			"occupied_city_cells": occupied_city_cells,
			"cell_limit": CampaignCityProgression.cell_limit(city.level),
			"level_up_actions": LEVEL_UP_ITINERARY.size(),
		},
		"milestones": milestones,
		"summary": {
			"first_farm_day": first_farm_day,
			"first_barracks_day": first_barracks_day,
			"first_raid_day": first_raid_day,
			"food_after_first_raid": food_after_first_raid,
			"day21_stocks": day21.stocks.duplicate(true),
			"day21_defense": day21_defense,
			"day21_group_coverage": group_coverage_summary,
			"day21_service_capacity": day21.service_capacity.duplicate(true),
			"footprint_cells_used": footprint_used,
			"city_level": city.level,
			"occupied_city_cells": occupied_city_cells,
			"city_cell_limit": CampaignCityProgression.cell_limit(city.level),
			"building_counts": day21_counts.duplicate(true),
			"text": summary_text,
		},
		"days_report": days,
		"warnings": warnings,
		"technical_errors": technical_errors,
		"ok": technical_errors.is_empty(),
		"balance_pass": warnings.is_empty(),
	}
	CampaignCityBalanceFixture.dispose(fixture)
	return output

static func _run_level_up_actions(city: City, day: int, timing: String,
		start_index: int, technical_errors: Array[String]) -> Dictionary:
	var index := start_index
	var actions: Array[Dictionary] = []
	while index < LEVEL_UP_ITINERARY.size():
		var action: Dictionary = LEVEL_UP_ITINERARY[index]
		if int(action.day) != day or String(action.timing) != timing:
			break
		var expected_level := int(action.level)
		if city.level != expected_level:
			technical_errors.append("Day %d expected city level %d before level-up, got %d" % [
				day, expected_level, city.level])
		var result := CampaignCityProgression.try_level_up(city)
		if not bool(result.get("ok", false)):
			technical_errors.append("Day %d city level-up failed: %s" % [day, str(result)])
		else:
			actions.append({"day": day, "from_level": expected_level,
				"to_level": int(result.level), "occupied_city_cells": int(result.used),
				"new_cell_limit": int(result.limit)})
		index += 1
	return {"index": index, "actions": actions}

static func _catalog_cost_snapshot(catalog: Dictionary) -> Array[Dictionary]:
	var costs: Array[Dictionary] = []
	for building in catalog.get("buildings", []):
		costs.append({"id": String(building.get("id", "")), "costs": building.get("costs", {}).duplicate(true)})
	return costs

static func _construction_summary(days: Array[Dictionary], buildings: Array, catalog: Dictionary) -> Dictionary:
	var selected := {}
	var attempts := 0
	var affordable := 0
	var failures: Array[Dictionary] = []
	var total_costs := {"food": 0.0, "wood": 0.0, "iron": 0.0}
	for day_report in days:
		for attempt in day_report.get("construction", []):
			attempts += 1
			if not bool(attempt.get("ok", false)):
				failures.append({"day": int(attempt.day), "id": String(attempt.id),
					"reason": String(attempt.reason)})
				continue
			affordable += 1
			var building_id := String(attempt.id)
			var definition := _find_building(catalog, building_id)
			if not selected.has(building_id):
				selected[building_id] = {
					"id": building_id, "count": 0, "build_days": [],
					"unit_costs": attempt.costs.duplicate(true),
					"cumulative_costs": {"food": 0.0, "wood": 0.0, "iron": 0.0},
					"worker_slots_per_instance": int(definition.get("jobs", 0)),
					"roles": definition.get("roles", []).duplicate(),
					"services": definition.get("services", {}).duplicate(true),
					"recipes": definition.get("recipes", []).duplicate(true),
				}
			var plan_entry: Dictionary = selected[building_id]
			plan_entry.count = int(plan_entry.count) + 1
			plan_entry.build_days.append(int(attempt.day))
			for resource_id in attempt.costs:
				var resource := String(resource_id)
				var amount := float(attempt.costs[resource_id])
				plan_entry.cumulative_costs[resource] = float(plan_entry.cumulative_costs.get(resource, 0.0)) + amount
				total_costs[resource] = float(total_costs.get(resource, 0.0)) + amount
			selected[building_id] = plan_entry

	var building_counts := {}
	var footprint_used := 0
	for building in buildings:
		var building_id := String(building.get("id", ""))
		building_counts[building_id] = int(building_counts.get(building_id, 0)) + 1
		var anchor: Vector2i = building.get("cell", Vector2i.ZERO)
		var footprint := CampaignBuildingPlacement.footprint_cells(anchor, building.get("footprint", [[0, 0]]))
		footprint_used += footprint.size()
	var selected_plan: Array[Dictionary] = []
	for building_id in selected:
		selected_plan.append(selected[building_id])
	return {
		"building_counts": building_counts,
		"selected_plan": selected_plan,
		"footprint_cells_used": footprint_used,
		"construction_build_days": _build_days_by_id(selected_plan),
		"cumulative_costs": total_costs,
		"affordability": {"attempted": attempts, "affordable": affordable, "failed": failures},
	}

static func _build_days_by_id(plan: Array[Dictionary]) -> Dictionary:
	var build_days := {}
	for entry in plan:
		build_days[String(entry.id)] = entry.build_days.duplicate()
	return build_days

static func _find_building(catalog: Dictionary, building_id: String) -> Dictionary:
	for building in catalog.get("buildings", []):
		if String(building.get("id", "")) == building_id:
			return building
	return {}

static func _first_day(days: Array) -> int:
	return int(days[0]) if not days.is_empty() else -1

static func _record_milestone(
	warnings: Array[Dictionary], milestones: Array[Dictionary], code: String,
	expected: Dictionary, actual: Variant, achieved: bool
) -> void:
	milestones.append({"code": code, "expected": expected.duplicate(true),
		"actual": actual, "achieved": achieved})
	if not achieved:
		warnings.append(_warning(code, {"expected": expected.duplicate(true), "actual": actual}))

static func _warning(code: String, details: Dictionary) -> Dictionary:
	var warning := details.duplicate(true)
	warning["code"] = code
	return warning

static func _footprint_cell_count(city: City) -> int:
	var count := 0
	for building in city.campaign_buildings:
		var anchor: Vector2i = building.get("cell", Vector2i.ZERO)
		count += CampaignBuildingPlacement.footprint_cells(
			anchor, building.get("footprint", [[0, 0]])).size()
	return count

static func _stocks(city: City) -> Dictionary:
	var stocks := {}
	for resource_id in MVP_RESOURCES:
		stocks[String(resource_id)] = city.resource_ctx.amount(resource_id)
	return stocks

static func _staffing(city: City) -> Array[Dictionary]:
	var staffing: Array[Dictionary] = []
	for building in city.campaign_buildings:
		var workers: Array[int] = []
		var uid := int(building.get("uid", -1))
		for resident in city.pop:
			if resident.state == PopUnit.State.WORKER and resident.assigned_to == uid:
				workers.append(resident.uid)
		workers.sort()
		staffing.append({"building_uid": uid, "building_id": String(building.get("id", "")),
			"worker_ids": workers, "assigned_workers": int(building.get("assigned_workers", 0))})
	staffing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.building_uid) < int(b.building_uid))
	return staffing

static func _buildings(city: City) -> Array[Dictionary]:
	var buildings: Array[Dictionary] = []
	for building in city.campaign_buildings:
		var cell: Vector2i = building.get("cell", Vector2i.ZERO)
		buildings.append({
			"uid": int(building.get("uid", -1)),
			"id": String(building.get("id", "")),
			"state": String(building.get("state", "active")),
			"construction_turns_remaining": int(building.get("construction_turns_remaining", 0)),
			"cell": [cell.x, cell.y],
		})
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.uid) < int(b.uid))
	return buildings
