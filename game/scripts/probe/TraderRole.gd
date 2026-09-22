class_name TraderRole
extends ScenarioRole
## autopilot-scenario-matrix: Торговец — капитал через городской рынок.
## Политика: базовый цикл (сбор → выгрузка в город) + продажа со склада
## города через MarketSystem (дорогое первым). Цель — industry >= gold_goal.

var _deals := 0

func _sell_order() -> Array:
	var order: Array = []
	for rid in MarketSystem.RATES.keys():
		order.append(rid)
	order.sort_custom(func(a, b): return float(MarketSystem.RATES[a]) > float(MarketSystem.RATES[b]))
	return order

func act(pilot: Node) -> bool:
	var city = pilot._player_city
	if city == null or not MarketSystem.has_market(city):
		return false
	if pilot._hero_cell().distance_to(pilot._city_center()) >= 2.0:
		return false
	# Рядом с рынком — продать всё, что продаётся (дорогое первым).
	var sold_any := false
	for rid in _sell_order():
		var stock: float = MarketSystem.stock_of(city, rid)
		if stock < GameNumbers.MARKET_MIN_AMOUNT:
			continue
		var r: CityCheck = MarketSystem.trade(city, rid, stock)
		if r.ok:
			sold_any = true
	if sold_any:
		_deals += 1
		pilot._commit(true)
		return true
	return false

func goal_met(pilot: Node) -> bool:
	var city = pilot._player_city
	if city == null:
		return false
	return float(city.storage.get(&"industry", 0.0)) >= float(target.get("gold_goal", 0))

func metrics(pilot: Node) -> Dictionary:
	var city = pilot._player_city
	var gold: float = float(city.storage.get(&"industry", 0.0)) if city != null else 0.0
	return {
		"gold": int(gold),
		"gold_goal": int(target.get("gold_goal", 0)),
		"margin": int(gold) - int(target.get("gold_start", 0)),
		"deals": _deals,
		"turns": pilot.turn,
		"survived": survived(pilot),
	}
