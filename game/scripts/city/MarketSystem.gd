class_name MarketSystem
extends RefCounted
## Спринт 10: Городской рынок. Торговля запасами города на золото.
##
## Требуется здание «Рынок» (BuildingDefs.market()). Курс: базовая цена
## ресурса × (1 + prosperity/200) — процветание 100 улучшает курс на 50%.
## Еда продаётся из food_stockpile, остальные ресурсы — из storage.
##
## Статический класс — headless-тестируемый, без autoload. Сигнал
## GameEventBus.trade_completed эмитит UI-слой/вызывающая сторона.

## Базовые цены (золото за единицу). &"gold" не продаётся (это и есть золото).
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
const DEFAULT_RATE := 2.0
const MIN_AMOUNT := 1.0


## Есть ли в городе рынок (хотя бы одно здание).
static func has_market(city: City) -> bool:
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"market":
			return true
	return false


## Курс ресурса при текущем процветании.
static func rate_for(city: City, resource_id: StringName) -> float:
	var base: float = float(RATES.get(resource_id, DEFAULT_RATE))
	# Спринт 11: специализация merchant — повышенный курс.
	return base * (1.0 + city.prosperity / 200.0) \
		* SpecializationSystem.trade_rate_multiplier(city)


## Запас ресурса: еда — из food_stockpile, остальное — из storage.
static func stock_of(city: City, resource_id: StringName) -> float:
	if resource_id == &"food":
		return city.food_stockpile
	return float(city.storage.get(resource_id, 0.0))


## Сделка: продать `amount` единиц ресурса за золото.
## Возвращает {ok, reason, amount, gold}.
static func trade(city: City, resource_id: StringName, amount: float) -> Dictionary:
	if amount < MIN_AMOUNT:
		return _fail("Минимум %f единиц" % MIN_AMOUNT)
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
	return {"ok": true, "reason": "", "amount": amount, "gold": gold}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "amount": 0.0, "gold": 0.0}
