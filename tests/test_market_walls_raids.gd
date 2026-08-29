extends "res://tests/test_base.gd"
## Спринт 10: рынок, стены, рейды.

const _City := preload("res://world/City.gd")
const _UniqueBuilding := preload("res://world/UniqueBuilding.gd")
const _PopUnit := preload("res://world/PopUnit.gd")
const _BuildingDefs := preload("res://data/BuildingDefs.gd")
const _Market := preload("res://city/MarketSystem.gd")
const _Raid := preload("res://city/RaidSystem.gd")
const _Reputation := preload("res://city/ReputationSystem.gd")
const _CityProc := preload("res://city/CityTurnProcessor.gd")


func _city(uid := 1) -> Variant:
	var c := _City.new()
	c.uid = uid
	c.center = Vector2i(0, 0)
	c.stronghold_level = 2  # pop_cap 20
	return c


func _add_building(c: Variant, def: Variant, level := 1, cell := Vector2i(1, 0)) -> Variant:
	var b := _UniqueBuilding.new()
	b.def = def
	b.level = level
	b.cell = cell
	c.buildings.append(b)
	return b


# --- Стены и оборона ---

func test_walls_def_registered() -> void:
	var d: Variant = _BuildingDefs.walls()
	assert_eq(d.id, &"walls")
	assert_true(_BuildingDefs.def_by_id(&"walls") != null, "walls in registry")


func test_defense_strength_militia_and_walls() -> void:
	var c: Variant = _city()
	# 3 ополченца = 6.
	for i in 3:
		c._add_pop(_PopUnit.State.MILITIA, 0)
	assert_eq(c.defense_strength(), 6)
	# Стены L1 = +5 -> 11.
	_add_building(c, _BuildingDefs.walls(), 1)
	assert_eq(c.defense_strength(), 11)
	# Стены L3 = +15 -> 21.
	for b in c.buildings:
		b.level = 3
	assert_eq(c.defense_strength(), 21)


# --- Рынок ---

func test_market_trade_ok() -> void:
	var c: Variant = _city()
	_add_building(c, _BuildingDefs.market())
	c.storage[&"grain"] = 10.0
	var gold_before: float = float(c.storage.get(&"industry", 0.0))
	# Процветание 50: курс = 1.5 * 1.25 = 1.875. 4 зерна = 7.5.
	var r: Dictionary = _Market.trade(c, &"grain", 4.0)
	assert_true(bool(r.ok), "trade ok: %s" % r.reason)
	assert_true(absf(float(r.gold) - 7.5) < 1e-9, "gold 7.5, got %s" % r.gold)
	assert_true(absf(float(c.storage[&"grain"]) - 6.0) < 1e-9, "grain 6 left")
	assert_true(absf(float(c.storage[&"industry"]) - (gold_before + 7.5)) < 1e-9,
		"industry +7.5")


func test_market_prosperity_rate() -> void:
	var c: Variant = _city()
	c.prosperity = 100.0  # курс x1.5
	_add_building(c, _BuildingDefs.market())
	var rate: float = _Market.rate_for(c, &"grain")
	assert_true(absf(rate - 2.25) < 1e-9, "rate 2.25, got %s" % rate)
	c.prosperity = 0.0
	assert_true(absf(_Market.rate_for(c, &"grain") - 1.5) < 1e-9, "rate 1.5")


func test_market_trade_failures() -> void:
	var c: Variant = _city()
	# Нет рынка.
	var r: Dictionary = _Market.trade(c, &"grain", 1.0)
	assert_false(bool(r.ok), "no market fail")
	assert_eq(r.reason, "Нет рынка")
	_add_building(c, _BuildingDefs.market())
	# Мало ресурса.
	r = _Market.trade(c, &"grain", 10.0)
	assert_false(bool(r.ok), "insufficient fail")
	# Меньше минимума.
	r = _Market.trade(c, &"grain", 0.5)
	assert_false(bool(r.ok), "min amount fail")
	# Золото не продают.
	r = _Market.trade(c, &"gold", 5.0)
	assert_false(bool(r.ok), "gold fail")
	assert_eq(r.reason, "Золото не продают")


func test_market_food_trade() -> void:
	var c: Variant = _city()
	_add_building(c, _BuildingDefs.market())
	c.prosperity = 0.0  # курс без наценки = 1.0
	c.food_stockpile = 5.0
	var gold_before: float = float(c.storage.get(&"industry", 0.0))
	var r: Dictionary = _Market.trade(c, &"food", 2.0)
	assert_true(bool(r.ok), "food trade ok")
	assert_true(absf(float(r.gold) - 2.0) < 1e-9, "food rate 1.0")
	assert_true(absf(c.food_stockpile - 3.0) < 1e-9, "food 3 left")
	assert_true(absf(float(c.storage[&"industry"]) - (gold_before + 2.0)) < 1e-9,
		"industry +2")


# --- Рейды ---

func test_raid_chance_bounds() -> void:
	var c: Variant = _city()
	c.reputation = 100
	assert_true(absf(_Raid.chance(c) - _Raid.RAID_CHANCE_MIN) < 1e-9, "min clamp")
	c.reputation = -100
	assert_true(absf(_Raid.chance(c) - _Raid.RAID_CHANCE_MAX) < 1e-9, "max clamp")
	c.reputation = 0
	assert_true(absf(_Raid.chance(c) - 0.10) < 1e-9, "base 0.10")


func test_raid_strength_range() -> void:
	var c: Variant = _city()
	for t in range(1, 31):
		var s: int = _Raid.raid_strength(c, t)
		assert_true(s >= 5 and s <= 15, "strength %d in 5..15" % s)


func test_raid_occurs_deterministic() -> void:
	# (uid 99, turn 12): roll 0.0001 < min chance 0.02 -> всегда рейд.
	var c: Variant = _city(99)
	assert_true(_Raid.occurs(c, 12), "uid 99 turn 12 raid")
	# (uid 42, turn 7): roll 0.5317 > chance -> никогда.
	var c2: Variant = _city(42)
	assert_false(_Raid.occurs(c2, 7), "uid 42 turn 7 no raid")


func test_raid_repelled() -> void:
	var c: Variant = _city(99)
	# 10 ополченцев = 20 >= макс. силы 15 -> отбит всегда.
	for i in 10:
		c._add_pop(_PopUnit.State.MILITIA, 0)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	var before_food: float = c.food_stockpile
	var before_gold: float = float(c.storage[&"industry"])
	var res: Dictionary = _Raid.resolve(c, 12)
	assert_true(bool(res.occurred), "occurred")
	assert_true(bool(res.repelled), "repelled")
	assert_true(absf(c.food_stockpile - before_food) < 1e-9, "no food loss")
	assert_true(absf(float(c.storage[&"industry"]) - before_gold) < 1e-9,
		"no gold loss")
	# Репутация +5.
	assert_eq(_Reputation.clamp_value(0 + _Raid.REP_RELIEF), 5)
	assert_eq(c.reputation, 5)


func test_raid_loses() -> void:
	var c: Variant = _city(99)
	# Нет обороны -> рейд всегда пробивает (сила 5..15 > 0).
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	c.ensure_resource_ctx().add(&"grain", 10.0)
	var res: Dictionary = _Raid.resolve(c, 12)
	assert_true(bool(res.occurred), "occurred")
	assert_false(bool(res.repelled), "not repelled")
	# Грабёж 30%.
	assert_true(absf(c.food_stockpile - 7.0) < 1e-6, "food 7, got %s" % c.food_stockpile)
	assert_true(absf(float(c.storage[&"industry"]) - 14.0) < 1e-6, "gold 14")
	assert_true(absf(c.resource_ctx.amount(&"grain") - 7.0) < 1e-6, "grain 7")
	# Репутация -10.
	assert_eq(c.reputation, _Raid.REP_LOSS)


func test_raid_no_raid_no_mutation() -> void:
	var c: Variant = _city(42)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	var res: Dictionary = _Raid.resolve(c, 7)
	assert_false(bool(res.occurred), "no raid")
	assert_true(absf(c.food_stockpile - 10.0) < 1e-9, "food intact")
	assert_eq(c.reputation, 0)


func test_processor_raid_signal() -> void:
	var c: Variant = _city(99)
	# 12 рабочих -> pop 12; уровень не повышается (нет зданий).
	for i in 12:
		c._add_pop(_PopUnit.State.WORKER, 0)
	var proc := _CityProc.new()
	var events: Array = []
	proc.raid_occurred.connect(func(uid: int, repelled: bool): events.append([uid, repelled]))
	var report: Dictionary = proc._process_city(c, 12)
	assert_eq(int(report.get("raid_occurred", 0)), 1)
	assert_false(bool(report.get("raid_repelled", false)), "no defense -> loses")
	assert_eq(events.size(), 1, "one signal")
	assert_eq(events[0][0], 99)
	assert_eq(events[0][1], false)
	# Ход без рейда — сигнала нет.
	var report2: Dictionary = proc._process_city(c, 7)
	assert_eq(int(report2.get("raid_occurred", 0)), 0)
	assert_eq(events.size(), 1, "no second signal")
