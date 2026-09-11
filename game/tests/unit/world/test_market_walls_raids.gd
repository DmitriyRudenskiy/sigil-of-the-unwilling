extends BaseTest









func _city(uid := 1) -> Variant:
	var c := City.new()
	c.uid = uid
	c.center = Vector2i(0, 0)
	c.stronghold_level = 2
	return c

func _add_building(c: Variant, def: Variant, level := 1, cell := Vector2i(1, 0)) -> Variant:
	var b := UniqueBuilding.new()
	b.def = def
	b.level = level
	b.cell = cell
	c.buildings.append(b)
	return b

func test_walls_def_registered() -> void:
	var d: Variant = BuildingDefs.walls()
	assert_that(d.id).is_equal(&"walls")
	assert_bool(BuildingDefs.def_by_id(&"walls") != null).is_true()

func test_defense_strength_militia_and_walls() -> void:
	var c: Variant = _city()
	for i in 3:
		c._add_pop(PopUnit.State.MILITIA, 0)
	assert_that(c.defense_strength()).is_equal(6)
	_add_building(c, BuildingDefs.walls(), 1)
	assert_that(c.defense_strength()).is_equal(11)
	for building in c.buildings:
		building.level = 3
	assert_that(c.defense_strength()).is_equal(21)

func test_market_trade_ok() -> void:
	var c: Variant = _city()
	_add_building(c, BuildingDefs.market())
	c.storage[&"grain"] = 10.0
	var gold_before: float = float(c.storage.get(&"industry", 0.0))
	var r: CityCheck = MarketSystem.trade(c, &"grain", 4.0)
	assert_bool(bool(r.ok)).is_true()
	assert_bool(absf(float(r.payload.get("gold", 0.0)) - 7.5) < 1e-9).is_true()
	assert_bool(absf(float(c.storage[&"grain"]) - 6.0) < 1e-9).is_true()
	assert_bool(absf(float(c.storage[&"industry"]) - (gold_before + 7.5)) < 1e-9).is_true()

func test_market_prosperity_rate() -> void:
	var c: Variant = _city()
	c.prosperity = 100.0
	_add_building(c, BuildingDefs.market())
	var rate: float = MarketSystem.rate_for(c, &"grain")
	assert_bool(absf(rate - 2.25) < 1e-9).is_true()
	c.prosperity = 0.0
	assert_bool(absf(MarketSystem.rate_for(c, &"grain") - 1.5) < 1e-9).is_true()

func test_market_trade_failures() -> void:
	var c: Variant = _city()
	var r: CityCheck = MarketSystem.trade(c, &"grain", 1.0)
	assert_bool(bool(r.ok)).is_false()
	assert_that(r.reason).is_equal("Нет рынка")
	_add_building(c, BuildingDefs.market())
	r = MarketSystem.trade(c, &"grain", 10.0)
	assert_bool(bool(r.ok)).is_false()
	r = MarketSystem.trade(c, &"grain", 0.5)
	assert_bool(bool(r.ok)).is_false()
	r = MarketSystem.trade(c, &"gold", 5.0)
	assert_bool(bool(r.ok)).is_false()
	assert_that(r.reason).is_equal("Золото не продают")

func test_market_food_trade() -> void:
	var c: Variant = _city()
	_add_building(c, BuildingDefs.market())
	c.prosperity = 0.0
	c.food_stockpile = 5.0
	var gold_before: float = float(c.storage.get(&"industry", 0.0))
	var r: CityCheck = MarketSystem.trade(c, &"food", 2.0)
	assert_bool(bool(r.ok)).is_true()
	assert_bool(absf(float(r.payload.get("gold", 0.0)) - 2.0) < 1e-9).is_true()
	assert_bool(absf(c.food_stockpile - 3.0) < 1e-9).is_true()
	assert_bool(absf(float(c.storage[&"industry"]) - (gold_before + 2.0)) < 1e-9).is_true()

func test_raid_chance_bounds() -> void:
	var c: Variant = _city()
	c.reputation = 100
	assert_bool(absf(RaidSystem.chance(c) - GameNumbers.RAID_CHANCE_MIN) < 1e-9).is_true()
	c.reputation = -100
	assert_bool(absf(RaidSystem.chance(c) - GameNumbers.RAID_CHANCE_MAX) < 1e-9).is_true()
	c.reputation = 0
	assert_bool(absf(RaidSystem.chance(c) - 0.10) < 1e-9).is_true()

func test_raid_strength_range() -> void:
	var c: Variant = _city()
	for t in range(1, 31):
		var s: int = RaidSystem.raid_strength(c, t)
		assert_bool(s >= 5 and s <= 15).is_true()

func test_raid_occurs_deterministic() -> void:
	var c: Variant = _city(99)
	assert_bool(RaidSystem.occurs(c, 12)).is_true()
	var c2: Variant = _city(42)
	assert_bool(RaidSystem.occurs(c2, 7)).is_false()

func test_raid_repelled() -> void:
	var c: Variant = _city(99)
	for i in 10:
		c._add_pop(PopUnit.State.MILITIA, 0)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	var before_food: float = c.food_stockpile
	var before_gold: float = float(c.storage[&"industry"])
	var res: Dictionary = RaidSystem.resolve(c, 12)
	assert_bool(bool(res.occurred)).is_true()
	assert_bool(bool(res.repelled)).is_true()
	assert_bool(absf(c.food_stockpile - before_food) < 1e-9).is_true()
	assert_bool(absf(float(c.storage[&"industry"]) - before_gold) < 1e-9).is_true()
	assert_that(ReputationSystem.clamp_value(0 + GameNumbers.RAID_REP_RELIEF)).is_equal(5)
	assert_that(c.reputation).is_equal(5)

func test_raid_loses() -> void:
	var c: Variant = _city(99)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	c.ensure_resource_ctx().add(&"grain", 10.0)
	var res: Dictionary = RaidSystem.resolve(c, 12)
	assert_bool(bool(res.occurred)).is_true()
	assert_bool(bool(res.repelled)).is_false()
	assert_bool(absf(c.food_stockpile - 7.0) < 1e-6).is_true()
	assert_bool(absf(float(c.storage[&"industry"]) - 14.0) < 1e-6).is_true()
	assert_bool(absf(c.resource_ctx.amount(&"grain") - 7.0) < 1e-6).is_true()
	assert_that(c.reputation).is_equal(GameNumbers.RAID_REP_LOSS)

func test_raid_no_raid_no_mutation() -> void:
	var c: Variant = _city(42)
	c.food_stockpile = 10.0
	c.storage[&"industry"] = 20.0
	var res: Dictionary = RaidSystem.resolve(c, 7)
	assert_bool(bool(res.occurred)).is_false()
	assert_bool(absf(c.food_stockpile - 10.0) < 1e-9).is_true()
	assert_that(c.reputation).is_equal(0)

func test_processor_raid_signal() -> void:
	var c: Variant = _city(99)
	for i in 12:
		c._add_pop(PopUnit.State.WORKER, 0)
	var proc := CityTurnProcessor.new()
	var events: Array = []
	proc.raid_occurred.connect(func(uid: int, repelled: bool): events.append([uid, repelled]))
	var report: Dictionary = proc._process_city(c, 12)
	assert_that(int(report.get("raid_occurred", 0))).is_equal(1)
	assert_bool(bool(report.get("raid_repelled", false))).is_false()
	assert_that(events.size()).is_equal(1)
	assert_that(events[0][0]).is_equal(99)
	assert_that(events[0][1]).is_equal(false)
	var report2: Dictionary = proc._process_city(c, 7)
	assert_that(int(report2.get("raid_occurred", 0))).is_equal(0)
	assert_that(events.size()).is_equal(1)
