extends "res://tests/gut_base.gd"
const TestFactories := preload("res://tests/helpers/test_factories.gd")
## M3: Город — CityTurnProcessor (фаза &"city", приоритет 5).
## Масштаб, ёмкости, зоны, интеграция с TurnScheduler и экономикой.



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
	# Спринт 7: WorkerAssignment пропускает здания без def.
	b.def = BuildingDefs.farm()
	city.buildings.append(b)
	return b


func _run(p: CityTurnProcessor, city: City) -> Dictionary:
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	return p.process(ctx)


# ==================== БАЗА ====================

func test_phase_id_and_priority() -> void:
	var p := CityTurnProcessor.new()
	assert_eq(p.get_phase_id(), &"city", "phase id")
	assert_eq(p.get_priority(), 5, "priority 5 (раньше экономики)")


func test_empty_ctx() -> void:
	var p := CityTurnProcessor.new()
	var report: Dictionary = p.process(null)
	assert_eq(int(report.get("scale_changes", -1)), 0)
	assert_eq(int(report.get("zone_violations", -1)), 0)


func test_no_scale_signal_on_same_tier() -> void:
	var city := TestFactories.make_city()
	city.add_followers(3)  # tier 0
	var p := CityTurnProcessor.new()
	var shifts: Array = []
	p.city_scale_changed.connect(func(uid: int, tier: int): shifts.append([uid, tier]))
	_run(p, city)
	assert_eq(city.scale_tier, 0, "starts at tier 0")
	assert_eq(shifts.size(), 0, "no shift on first process at tier 0")
	_run(p, city)
	assert_eq(shifts.size(), 0, "no shift on repeat")


func test_scale_shift_signal() -> void:
	var city := TestFactories.make_city()
	var p := CityTurnProcessor.new()
	var shifts: Array = []
	p.city_scale_changed.connect(func(uid: int, tier: int): shifts.append([uid, tier]))
	_run(p, city)  # 0 жителей → tier 0
	city.add_followers(5)  # pop_capped 5 → tier 1
	_run(p, city)
	assert_eq(city.scale_tier, 1, "tier raised")
	assert_eq(shifts.size(), 1, "one shift signal")
	assert_eq(shifts[0][0], city.uid, "city uid in signal")
	assert_eq(shifts[0][1], 1, "new tier in signal")
	city.add_followers(10)  # 15 → tier 2
	_run(p, city)
	assert_eq(city.scale_tier, 2, "tier 2")
	assert_eq(shifts.size(), 2, "second shift")


# ==================== ЁМКОСТИ ====================

func test_capacity_scale_and_restore() -> void:
	var city := TestFactories.make_city()
	var def := ResourceDef.new()
	def.id = &"ore"
	def.capacity = 10.0
	var res := city.ensure_resource_ctx([def])
	res.add(&"ore", 5.0)
	assert_eq(res.get_capacity(&"ore"), 10.0, "base capacity")

	var p := CityTurnProcessor.new()
	_run(p, city)  # tier 0 — лимиты не трогаем
	assert_eq(res.get_capacity(&"ore"), 10.0, "tier 0: unchanged")

	city.add_followers(5)  # tier 1: ×1.25
	_run(p, city)
	assert_eq(res.get_capacity(&"ore"), 12.5, "tier 1: 10 * 1.25")
	res.add(&"ore", 100.0)  # упрёмся в новый лимит
	assert_eq(res.amount(&"ore"), 12.5, "clamped to scaled cap")

	# Возврат в tier 0: базовый лимит восстанавливается, запас обрезается.
	for i in 5:
		city.remove_pop(city.pop[0].uid)
	_run(p, city)
	assert_eq(res.get_capacity(&"ore"), 10.0, "restored base cap")
	assert_eq(res.amount(&"ore"), 10.0, "stock clamped to base cap")


func test_capacity_no_double_scaling() -> void:
	var city := TestFactories.make_city()
	var def := ResourceDef.new()
	def.id = &"ore"
	def.capacity = 10.0
	var res := city.ensure_resource_ctx([def])
	res.add(&"ore", 1.0)
	city.add_followers(5)  # сразу tier 1
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_eq(res.get_capacity(&"ore"), 12.5, "scaled once")
	_run(p, city)  # повтор — не 12.5 * 1.25
	assert_eq(res.get_capacity(&"ore"), 12.5, "no double scaling")
	_run(p, city)
	assert_eq(res.get_capacity(&"ore"), 12.5, "stable across turns")


func test_capacity_inf_untouched() -> void:
	var city := TestFactories.make_city()
	var res := city.ensure_resource_ctx()  # без defs — всё INF
	res.add(&"wood", 3.0)
	assert_true(is_inf(res.get_capacity(&"wood")), "inf before")
	city.add_followers(5)
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_true(is_inf(res.get_capacity(&"wood")), "inf after (not multiplied)")


# ==================== МУЛЬТИПЛИКАТОРЫ ГОРОДА ====================

func test_auto_and_upkeep_mults_set() -> void:
	var city := TestFactories.make_city()
	city.add_followers(15)  # tier 2
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_eq(city.auto_resource_mult, 1.2, "auto mult tier 2")
	assert_eq(city.upkeep_mult, 0.9, "upkeep mult tier 2")


# ==================== ЗОНЫ ====================

func test_zone_multiplier_applied_to_buildings() -> void:
	var city := TestFactories.make_city()
	var a: Vector2i = _cell_at_distance(city, 2)
	var b1: Vector2i = _neighbor_of(a, city.center)
	var b2: Vector2i = _neighbor_of(a, b1)
	var ba := _make_building(city, a, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, b1, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, b2, ZoningSystem.ZoneType.INDUSTRIAL)  # 2 соседа той же зоны
	var p := CityTurnProcessor.new()
	_run(p, city)
	assert_eq(ba.zone_multiplier, 1.0 + ZoningSystem.AGGLOMERATION_BONUS, "agglomeration applied")
	# Здание без зоны — 1.0.
	var plain: Vector2i = _cell_at_distance(city, 1)
	var bp := _make_building(city, plain, ZoningSystem.ZoneType.NONE)
	_run(p, city)
	assert_eq(bp.zone_multiplier, 1.0, "none zone = 1.0")


func test_zone_violation_emitted() -> void:
	var city := TestFactories.make_city()
	var adj: Vector2i = _cell_at_distance(city, 1)  # d=1 < INDUSTRIAL_MIN_DISTANCE
	_make_building(city, adj, ZoningSystem.ZoneType.INDUSTRIAL)
	var violations: Array = []
	var p := CityTurnProcessor.new()
	p.zone_violation.connect(func(uid: int, cell: Vector2i): violations.append([uid, cell]))
	var report: Dictionary = _run(p, city)
	assert_eq(int(report.get("zone_violations", -1)), 1, "violation in report")
	assert_eq(violations.size(), 1, "signal emitted")
	assert_eq(violations[0][1], adj, "cell in signal")
	# Повторный ход — нарушение стабильно (не разовое).
	var report2: Dictionary = _run(p, city)
	assert_eq(int(report2.get("zone_violations", -1)), 1, "persistent violation")


# ==================== ИНТЕГРАЦИЯ ====================

func test_scheduler_city_before_economy() -> void:
	var city := TestFactories.make_city()
	city.add_followers(5)  # tier 1: авто ×1.1
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
	sched.register_processor(CityTurnProcessor.new())  # порядок не важен — по приоритету
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = sched.execute_turn(ctx)
	var phases: Dictionary = report.get("phases", {})
	assert_true(phases.has(&"city"), "city phase in report")
	assert_true(phases.has(&"economy"), "economy phase in report")
	# Авто-дрова с масштабным бонусом: 2 * 1.1 = 2.2; цепочка взяла 2 → 0.2.
	assert_true(absf(city.resource_ctx.amount(&"wood") - 0.2) < 1e-9, "wood: auto*1.1 - chain 2")
	# Камень: авто 2 * 1.1 = 2.2 + выход цепочки 3.0 = 5.2.
	assert_true(absf(city.resource_ctx.amount(&"stone") - 5.2) < 1e-9, "stone: auto*1.1 + output 3")
	assert_eq(city.scale_tier, 1, "scale processed")


func test_scheduler_logistics_and_zone_in_economy() -> void:
	var city := TestFactories.make_city()
	city.add_followers(5)
	var far: Vector2i = _cell_at_distance(city, 3)  # логистика 0.7
	var near: Vector2i = _cell_at_distance_from(far, 1)  # сосед, та же зона
	var near2: Vector2i = _neighbor_of(far, near)  # второй сосед той же зоны
	_add_worker(city, near)
	var b := _make_building(city, far, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, near, ZoningSystem.ZoneType.INDUSTRIAL)
	_make_building(city, near2, ZoningSystem.ZoneType.INDUSTRIAL)  # 2 соседа → агромерация
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
	# stone авто = 2.2 (tier 1) — входы 1 wood есть.
	# iron = 2.0 * 1.0(рабочий) * 1.0(eff) * (0.7 логистика * 1.1 зона) = 1.54
	assert_true(absf(city.resource_ctx.amount(&"iron") - 1.54) < 1e-9, "iron: 2 * 0.7 * 1.1")
	assert_true(absf(b.zone_multiplier - 1.1) < 1e-9, "zone multiplier stored on building")
