class_name TraderRole
extends ScenarioRole
## autopilot-scenario-matrix: Торговец — капитал через городской рынок.
## Политика: базовый цикл (сбор → выгрузка в город) + продажа со склада
## города через MarketSystem (дорогое первым). Цель — industry >= gold_goal.

var _deals := 0
var _transactions: Array[Dictionary] = []
var _last_market_attempt_turn := -1
var _market_build_attempts := 0
var _market_build_block_reason := ""

func _sell_order(city: City) -> Array[StringName]:
	var order: Array[StringName] = []
	for rid in MarketSystem.RATES.keys():
		order.append(StringName(rid))
	for rid in city.storage.keys():
		var id := StringName(rid)
		if id not in [&"industry", &"gold"] and not order.has(id):
			order.append(id)
	order.erase(&"food") # Keep the city's food reserve out of trade.
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		var rate_a: float = MarketSystem.rate_for(city, a)
		var rate_b: float = MarketSystem.rate_for(city, b)
		if is_equal_approx(rate_a, rate_b):
			return String(a) < String(b)
		return rate_a > rate_b
	)
	return order

func act(pilot: Node) -> bool:
	var city: City = pilot._player_city
	if city == null:
		return false
	var center: Vector2i = pilot._city_center()
	var distance: float = pilot._hero_cell().distance_to(center)
	if not MarketSystem.has_market(city) and _last_market_attempt_turn != pilot.turn:
		_last_market_attempt_turn = pilot.turn
		_market_build_attempts += 1
		if pilot._city_screen == null:
			_market_build_block_reason = "city_screen_unavailable"
		else:
			var build: CityCheck = pilot._city_screen.build_pressed(&"market")
			if build.ok:
				_market_build_block_reason = ""
				if pilot.first_building_turn < 0:
					pilot.first_building_turn = pilot.turn
				pilot._commit(true)
				return true
			_market_build_block_reason = build.reason
	if distance >= 2.0 and _has_tradeable_cargo(pilot):
		if pilot._walk_to(center):
			return true
		var probe: Vector2i = pilot._explore_target(center)
		if probe != Vector2i(-1, -1) and pilot._walk_to(probe):
			return true
		return false
	if distance >= 2.0:
		return false
	# Unload before BalanceProbe's low-needs early return; otherwise cargo stays on the hero.
	if pilot._unload_backpack() > 0:
		pilot._commit(true)
		return true
	if not MarketSystem.has_market(city):
		return false
	var sold_any := false
	for rid in _sell_order(city):
		var stock_before: float = MarketSystem.stock_of(city, rid)
		if stock_before < GameNumbers.MARKET_MIN_AMOUNT:
			continue
		var gold_before: float = float(city.storage.get(&"industry", 0.0))
		var result: CityCheck = MarketSystem.trade(city, rid, stock_before)
		var stock_after: float = MarketSystem.stock_of(city, rid)
		var gold_after: float = float(city.storage.get(&"industry", 0.0))
		if result.ok and stock_after < stock_before and gold_after > gold_before:
			_deals += 1
			_transactions.append({
				"turn": pilot.turn,
				"resource": String(rid),
				"amount": stock_before - stock_after,
				"gold": gold_after - gold_before,
				"stock_before": stock_before,
				"stock_after": stock_after,
				"industry_before": gold_before,
				"industry_after": gold_after,
			})
			sold_any = true
	if sold_any:
		pilot._commit(true)
		return true
	return false

func _has_tradeable_cargo(pilot: Node) -> bool:
	var hero: Node = pilot._hero
	if hero == null or hero.strategic_resources == null:
		return false
	var cargo: Dictionary = hero.strategic_resources.get_all()
	for rid in cargo:
		if StringName(rid) == &"gold":
			continue
		if int(cargo[rid]) >= GameNumbers.MARKET_MIN_AMOUNT:
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
		"transactions": _transactions.duplicate(true),
		"market_available": MarketSystem.has_market(city) if city != null else false,
		"market_build_attempts": _market_build_attempts,
		"market_build_block_reason": _market_build_block_reason,
		"turns": pilot.turn,
		"survived": survived(pilot),
	}
