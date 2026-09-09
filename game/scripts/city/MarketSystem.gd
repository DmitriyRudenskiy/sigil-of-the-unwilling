class_name MarketSystem
extends RefCounted

const RATES: Dictionary = {
	&"food": 1.0,
	&"grain": 1.5,
	&"flour": 2.5,
	&"bread": 4.0,
	&"ore": 3.0,
	&"tools": 5.0,
	&"dust": 6.0,
	&"science": 8.0,
	&"scholar_points": 6.0,
	&"influence": 5.0,
}

static func has_market(city: City) -> bool:
	for building in city.buildings:
		if building != null and building.def != null and building.def.id == &"market":
			return true
	return false

static func rate_for(city: City, resource_id: StringName) -> float:
	var base: float = float(RATES.get(resource_id, GameNumbers.MARKET_DEFAULT_RATE))
	return base * (1.0 + city.prosperity / 200.0) \
		* SpecializationSystem.trade_rate_multiplier(city)

static func stock_of(city: City, resource_id: StringName) -> float:
	if resource_id == &"food":
		return city.food_stockpile
	return float(city.storage.get(resource_id, 0.0))

static func trade(city: City, resource_id: StringName, amount: float) -> CityCheck:
	if amount < GameNumbers.MARKET_MIN_AMOUNT:
		return _fail("Минимум %f единиц" % GameNumbers.MARKET_MIN_AMOUNT)
	if resource_id == &"gold":
		return _fail("Золото не продают")
	if not has_market(city):
		return _fail("Нет рынка")
	var stock := stock_of(city, resource_id)
	if amount > stock + 1e-9:
		return _fail("Не хватает ресурсов: %f/%f" % [stock, amount])
	var gold: float = amount * rate_for(city, resource_id)
	if resource_id == &"food":
		city.food_stockpile = maxf(0.0, city.food_stockpile - amount)
	else:
		city.storage[resource_id] = maxf(0.0, stock - amount)
	city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) + gold
	return CityCheck.success({"amount": amount, "gold": gold})

static func _fail(reason: String) -> CityCheck:
	return CityCheck.fail(reason, {"amount": 0.0, "gold": 0.0})
