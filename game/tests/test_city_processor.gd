extends GdUnitTestSuite
const TestFactories := preload("res://tests/helpers/test_factories.gd")



func _cell_at_distance(city: City, d: int) -> Vector2i:
	if d <= 0:
		return city.center
	var frontier: Array = [city.center]
	var seen: Dictionary = {city.center: true}
	for _i in 200:
		var next: Array = []
		for c in frontier:
			for nb in HexUtils.get_all_neighbors(c):
				if seen.has(nb):
					continue
				seen[nb] = true
				if HexUtils.hex_distance(nb, city.center) == d:
					return nb
				next.append(nb)
		frontier = next
	return Vector2i(-1, -1)


func _cell_at_distance_from(from: Vector2i, d: int) -> Vector2i:
	var frontier: Array = [from]
	var seen: Dictionary = {from: true}
	for _i in 200:
		var next: Array = []
		for c in frontier:
			for nb in HexUtils.get_all_neighbors(c):
				if seen.has(nb):
					continue
				seen[nb] = true
				if HexUtils.hex_distance(nb, from) == d:
					return nb
				next.append(nb)
		frontier = next
	return Vector2i(-1, -1)


func _add_worker(city: City, tile: Vector2i) -> PopUnit:
	var u := PopUnit.new()
	u.uid = city.pop.size()
	u.state = PopUnit.State.WORKER
	u.tile = tile
	u.born_turn = 0
	city.pop.append(u)
	return u


func _neighbor_of(a: Vector2i, exclude: Vector2i) -> Vector2i:
	for nb in HexUtils.get_all_neighbors(a):
		if nb != exclude:
			return nb
	return Vector2i(-1, -1)


func _make_building(city: City, cell: Vector2i, zone: int) -> UniqueBuilding:
	var b := UniqueBuilding.new()
	b.uid = city.buildings.size() + 1
	b.cell = cell
	b.level = 1
	b.zone_type = zone
	b.def = BuildingDefs.farm()
	city.buildings.append(b)
	return b


func _run(p: CityTurnProcessor, city: City) -> Dictionary:
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	return p.process(ctx)



func test_phase_id_and_priority() -> void:
	var p := CityTurnProcessor.new()
	assert_that(p.get_phase_id()).is_equal(&"city")
	assert_that(p.get_priority()).is_equal(5)


func test_empty_ctx() -> void:
	var p := CityTurnProcessor.new()
	var report: Dictionary = p.process(null)
	assert_that(int(report.get("scale_changes", -1))).is_equal(0)
	assert_that(int(report.get("zone_violations", -1))).is_equal(0)


func test_no_scale_signal_on_same_tier() -> void:
	var city := TestFactories.make_city()
	city.add_followers(3)  
	var p := CityTurnProcessor.new()
	var shifts: Array = []
	p.city_scale_changed.connect(func(uid: int, tier: int): shifts.append([uid, tier]))
	_run(p, city)
	assert_that(city.scale_tier).is_equal(0)
	assert_that(shifts.size()).is_equal(0)
	_run(p, city)
	assert_that(shifts.size()).is_equal(0)


func test_scale_shift_signal() -> void:
	var city := TestFactories.make_city()
	var p := CityTurnProcessor.new()
	var shifts: Array = []
	p.city_scale_changed.connect(func(uid: int, tier: int): shifts.append([uid, tier]))
	_run(p, city)  
	city.add_followers(5)  
	_run(p, city)
	assert_that(city.scale_tier).is_equal(1)
	assert_that(shifts.size()).is_equal(1)
	assert_that(shifts[0][0]).is_equal(city.uid)
	assert_that(shifts[0][1]).is_equal(1)
	city.add_followers(10)  
	_run(p, city)
	assert_that(city.scale_tier).is_equal(2)
	assert_that(shifts.size()).is_equal(2)



func test_capacity_scale_and_restore() -> void:
	var city := TestFactories.make_city()
	var def := ResourceDef.new()
	def.id = &"ore"
	def.capacity = 10.0
	var res := city.ensure_resource_ctx([def])
	res.add(&"ore", 5.0)
	assert_that(res.get_capacity(&"ore")).is_equal(10.0)

	var p := CityTurnProcessor.new()
	_run(p, city)  
	assert_that(res.get_capacity(&"ore")).is_equal(10.0)

	city.add_followers(5)  
	_run(p, city)
	assert_that(res.get_capacity(&"ore")).is_equal(12.5)
	res.add(&"ore", 100.0)  
	assert_that(res.amount(&"ore")).is_equal(12.5)

	for i in 5:
		city.remove_pop(city.pop[0].uid)
	_run(p, city)
	assert_that(res.get_capacity(&"ore")).is_equal(10.0)
	assert_that(res.amount(&"ore")).is_equal(10.0)


func test_capacity_no_double_scaling() -> void:
	var city := TestFactories.make_city()
	var def := ResourceDef.new()
	def.id = &"ore"
	def.capacity = 10.0
	var res := city.ensure_resource_ctx([def])
	res.add(&"ore", 1.0)
	city.add_followers(5)  
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_that(res.get_capacity(&"ore")).is_equal(12.5)
	_run(p, city)  
	assert_that(res.get_capacity(&"ore")).is_equal(12.5)
	_run(p, city)
	assert_that(res.get_capacity(&"ore")).is_equal(12.5)


func test_capacity_inf_untouched() -> void:
	var city := TestFactories.make_city()
	var res := city.ensure_resource_ctx()  
	res.add(&"wood", 3.0)
	assert_bool(is_inf(res.get_capacity(&"wood"))).is_true()
	city.add_followers(5)
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_bool(is_inf(res.get_capacity(&"wood"))).is_true()



func test_auto_and_upkeep_mults_set() -> void:
	var city := TestFactories.make_city()
	city.add_followers(15)  
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_that(city.auto_resource_mult).is_equal(1.2)
	assert_that(city.upkeep_mult).is_equal(0.9)



func test_zone_multiplier_applied_to_buildings() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	var ba := _make_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)  
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_that(ba.zone_multiplier).is_equal(1.0 + GameNumbers.ZONE_AGGLOMERATION_BONUS)
	var plain: Vector2i = _cell_at_distance(city, 1)
	var bp := _make_building(city, plain, ZoningSystem.ZoneType.NONE)
	_run(p, city)
	assert_that(bp.zone_multiplier).is_equal(1.0)


func test_zone_violation_emitted() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)  
	_make_building(city, adj, ZoningSystem.ZoneType.INDUSTRIAL)
	var violations: Array = []
	var p := CityTurnProcessor.new()
	p.zone_violation.connect(func(uid: int, cell: Vector2i): violations.append([uid, cell]))
	var report: Dictionary = _run(p, city)
	assert_that(int(report.get("zone_violations", -1))).is_equal(1)
	assert_that(violations.size()).is_equal(1)
	assert_that(violations[0][1]).is_equal(adj)
	var report2: Dictionary = _run(p, city)
	assert_that(int(report2.get("zone_violations", -1))).is_equal(1)



func test_scheduler_city_before_economy() -> void:
	var city := TestFactories.make_city()
	city.add_followers(5)  
	var c1: Vector2i = _cell_at_distance(city, 1)
	var c2: Vector2i = _cell_at_distance_from(c1, 1)
	_add_worker(city, c1)
	_add_worker(city, c2)
	var b := _make_building(city, c1, ZoningSystem.ZoneType.NONE)
	var chain := ProductionChain.new()
	chain.id = &"mine"
	chain.inputs = {&"wood": 2.0}
	chain.outputs = {&"stone": 3.0}
	chain.required_workers = 2
	b.production_chain = chain

	var sched := TurnScheduler.new()
	sched.register_processor(EconomicTurnProcessor.new())
	sched.register_processor(CityTurnProcessor.new())  
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = sched.execute_turn(ctx)
	var phases: Dictionary = report.get("phases", {})
	assert_bool(phases.has(&"city")).is_true()
	assert_bool(phases.has(&"economy")).is_true()
	assert_bool(absf(city.resource_ctx.amount(&"wood") - 0.2) < 1e-9).is_true()
	assert_bool(absf(city.resource_ctx.amount(&"stone") - 5.2) < 1e-9).is_true()
	assert_that(city.scale_tier).is_equal(1)


func test_scheduler_logistics_and_zone_in_economy() -> void:
	var city := TestFactories.make_city()
	city.add_followers(5)
	var far: Vector2i = _cell_at_distance(city, 3)  
	var near: Vector2i = _cell_at_distance_from(far, 1)  
	var near2: Vector2i = _neighbor_of(far, near)  
	_add_worker(city, near)
	var b := _make_building(city, far, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, near, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, near2, ZoningSystem.ZoneType.INDUSTRIAL)  
	var chain := ProductionChain.new()
	chain.id = &"forge"
	chain.inputs = {&"wood": 1.0}
	chain.outputs = {&"iron": 2.0}
	chain.required_workers = 1
	b.production_chain = chain

	var p := CityTurnProcessor.new()
	var econ := EconomicTurnProcessor.new()
	_run(p, city)
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	econ.process(ctx)
	assert_bool(absf(city.resource_ctx.amount(&"iron") - 1.54) < 1e-9).is_true()
	assert_bool(absf(b.zone_multiplier - 1.1) < 1e-9).is_true()
