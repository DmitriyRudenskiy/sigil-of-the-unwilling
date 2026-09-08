class_name CityGrowthService
extends RefCounted
# R3: рост города (еда, порог, тактовый цикл) вынесен из City.gd (паттерн BoroughRules).


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

	var nf := net_food(city)
	city.food_stockpile = maxf(0.0, city.food_stockpile + nf)
	city.starving = nf < 0.0

	var births := 0
	while city.pop_capped() < city.pop_cap() and city.food_stockpile >= growth_threshold(city):
		city.food_stockpile -= growth_threshold(city)
		city._add_pop(PopUnit.State.FOLLOWER, turn)
		births += 1

	var level_ups := BoroughRules.process_level_ups(city)

	var y := city.get_yield()
	for k in [&"industry", &"dust", &"science", &"influence"]:
		city.storage[k] = float(city.storage.get(k, 0.0)) + float(y[k])

	return {
		"births": births, "level_ups": level_ups,
		"starving": city.starving, "net_food": nf, "switched": switched,
	}
