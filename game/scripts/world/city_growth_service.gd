class_name CityGrowthService
extends RefCounted

static func food_consumption(city: City) -> float:
	return city.count_state(PopUnit.State.WORKER) * GameNumbers.FOOD_PER_WORKER \
		+ city.count_state(PopUnit.State.MILITIA) * GameNumbers.FOOD_PER_MILITIA \
		+ city.count_state(PopUnit.State.FOLLOWER) * GameNumbers.FOOD_PER_FOLLOWER \
		+ city.count_state(PopUnit.State.SCHOLAR) * GameNumbers.FOOD_PER_SCHOLAR

static func net_food(city: City) -> float:
	return float(city.get_yield()[&"food"]) - food_consumption(city)

static func growth_threshold(city: City) -> float:
	return GameNumbers.GROWTH_THRESHOLD_BASE \
		* pow(float(maxi(1, city.pop_capped())), GameNumbers.GROWTH_THRESHOLD_EXP)

static func process_turn(city: City, turn: int) -> Dictionary:
	var switched := 0
	for u in city.pop:
		if u.apply_pending():
			switched += 1

	city._invalidate_exploited()

	var resources := city.ensure_resource_ctx()
	var food_id: StringName = &"food"
	var food_yield := maxf(float(city.get_yield().get(&"food", 0.0)), 0.0)
	var demand := food_consumption(city)
	resources.add(food_id, food_yield, "city:food_production")
	var available := resources.amount(food_id)
	city.food_supply_this_turn = available
	city.food_demand_this_turn = demand
	var consumed := minf(demand, available)
	if consumed > 0.0:
		resources.spend({food_id: consumed}, "city:population_food")
	var nf := food_yield - demand
	city.starving = nf < 0.0

	var births := 0
	while city.pop_capped() < city.pop_cap() and resources.amount(food_id) >= growth_threshold(city):
		var growth_cost := growth_threshold(city)
		if not resources.spend({food_id: growth_cost}, "city:population_growth"):
			break
		city._add_pop(PopUnit.State.FOLLOWER, turn)
		births += 1

	var level_ups := BoroughRules.process_level_ups(city)

	var y := city.get_yield()
	for k in [&"industry", &"dust", &"science", &"influence"]:
		city.storage[k] = float(city.storage.get(k, 0.0)) + float(y[k])

	return {
		"births": births, "level_ups": level_ups,
		"starving": city.starving, "net_food": nf, "switched": switched,
		"food_supply": available, "food_demand": demand,
		"food_consumed": consumed, "food_coverage_percent": ArchetypeResolver.need_coverage_percent(
			int(round(available * 1000.0)), int(round(demand * 1000.0))),
	}
