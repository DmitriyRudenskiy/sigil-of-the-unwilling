class_name ArenaTurnRunner
extends RefCounted
## Запуск хода и управление городом (M3): run_turn, seat_workers,
## place_building, hire_worker, demo_plan, run_demo_plan, score. Перенос из
## CityArenaModel. Делегирует геометрию/кольца/особенности к ArenaRingSystem,
## кластеры — ArenaClusterSystem, шторм — ArenaStorm.

const ArenaBalance := preload("res://scripts/city/ArenaBalance.gd")
const ArenaRingSystem := preload("res://scripts/city/ArenaRingSystem.gd")
const ArenaClusterSystem := preload("res://scripts/city/ArenaClusterSystem.gd")
const ArenaStorm := preload("res://scripts/city/ArenaStorm.gd")
const BuildingDefs := preload("res://scripts/data/BuildingDefs.gd")
const HexUtils := preload("res://scripts/core/HexUtils.gd")
const City := preload("res://scripts/world/City.gd")
const PopUnit := preload("res://scripts/world/PopUnit.gd")
const UniqueBuilding := preload("res://scripts/world/UniqueBuilding.gd")
const CityTurnProcessor := preload("res://scripts/city/CityTurnProcessor.gd")
const EconomicTurnProcessor := preload("res://scripts/economy/EconomicTurnProcessor.gd")
const TurnContext := preload("res://scripts/core/TurnContext.gd")
const ProductionChain := preload("res://scripts/economy/ProductionChain.gd")

static var _city_phase: CityTurnProcessor = null
static var _economy: EconomicTurnProcessor = null


static func _get_city_phase() -> CityTurnProcessor:
	if _city_phase == null:
		_city_phase = CityTurnProcessor.new()
	return _city_phase


static func _get_economy() -> EconomicTurnProcessor:
	if _economy == null:
		_economy = EconomicTurnProcessor.new()
	return _economy


# ==================== СТУДИЯ: СТАРТОВЫЙ ГОРОД ====================

## Новый город арены: центр (0,0), форт 2-го уровня, стартовое
## население (4 рабочих + 2 последователя), стартовые ресурсы.
static func make_city(overrides: Dictionary = {}) -> City:
	var c := City.new()
	c.uid = 1
	c.display_name = "Арена"
	c.center = ArenaRingSystem.center()
	c.stronghold_level = 2
	c.is_capital = true
	c.food_stockpile = 25.0
	c.storage = {&"industry": 80.0, &"gold": 40.0}
	c.tile_yield_fn = func(cell: Vector2i) -> Dictionary:
		return ArenaRingSystem.tile_yield(cell, overrides)
	for _i in 4:
		c.add_migrant(PopUnit.State.WORKER)
	# 4 последователя: по 2 — на апгрейды стен/рынка до 2-го уровня.
	for _i in 4:
		c.add_migrant(PopUnit.State.FOLLOWER)
	c.ensure_resource_ctx()
	return c


# ==================== ХОД ====================

## Запуск хода: сидение работников + монолит + фаза города + кольца +
## экономика + шторм.
static func run_turn(city: City, turn: int, overrides: Dictionary = {}) -> Dictionary:
	seat_workers(city)
	# 1. Монолит (еда, рост, старое хранилище).
	var mono: Dictionary = city.process_turn(turn)
	# 2. Контекст и фаза города.
	var ctx := TurnContext.new()
	var cs: Array[City] = [city]
	ctx.cities = cs
	ctx.turn_number = turn
	var city_report: Dictionary = _get_city_phase().process(ctx)
	# 3. Кольца + кластеры + особенности + шторм (после сброса
	# zone_multiplier фазы города).
	var applied: int = ArenaRingSystem.apply_ring_multipliers(city, overrides, turn)
	# 4. Экономика (читает zone_multiplier).
	var eco_report: Dictionary = _get_economy().process(ctx)
	# 5. Шторм: потери еды после экономики.
	var storm_food: float = ArenaStorm.storm_food_penalty(city, turn)
	if storm_food > 0.0:
		city.food_stockpile -= storm_food
		if city.food_stockpile < 0.0:
			city.starving = true
	return {
		"turn": turn,
		"mono": mono,
		"city": city_report,
		"economy": eco_report,
		"ring_mults_applied": applied,
		"storm": ArenaStorm.is_storm_turn(turn),
		"storm_food": storm_food,
		"clusters": (ArenaClusterSystem.clusters(city) as Array).size(),
		"starving": city.starving,
		"net_food": city.net_food(),
		"food": city.food_stockpile,
		"industry": float(city.storage.get(&"industry", 0.0)),
		"gold": float(city.storage.get(&"gold", 0.0)),
		"level": city.level,
		"prosperity": city.prosperity,
	}


# ==================== ПОСТРОЙКА ====================

## Поставить здание: проверка арены + City.can_build_building +
## начальный кольцевой множитель. {ok, reason?, building?, cost?, ring?}.
static func place_building(
	city: City, def: UniqueBuilding.Def, cell: Vector2i,
	overrides: Dictionary = {}) -> Dictionary:
	if def == null or def.levels.is_empty():
		return _fail("Нет определения здания")
	if not ArenaRingSystem.is_in_arena(cell):
		return _fail("Клетка вне арены")
	var check: Dictionary = city.can_build_building(def, cell)
	if not check.ok:
		return check
	var bld: UniqueBuilding = city.build_building(def, cell)
	if bld == null:
		return check
	# Начальный множитель: кольцо × кластер (новое здание может ЗАВЕРШИТЬ
	# кластер!) × особенность клетки.
	var clm: Dictionary = ArenaClusterSystem.cluster_uids(city)
	bld.zone_multiplier = (1.0 + ArenaRingSystem.ring_bonus(def.id, ArenaRingSystem.ring_of(cell), overrides)) \
		* float(clm.get(bld.uid, 1.0)) * ArenaRingSystem.feature_mult(city, def.id, cell)
	var res: Dictionary = {
		"ok": true,
		"building": bld,
		"cost": float(check.get("cost", 0.0)),
		"ring": ArenaRingSystem.ring_of(cell),
	}
	# Руины: разовый бонус золота за постройку на клетке.
	if ArenaRingSystem.cell_feature(city, cell) == &"ruins":
		var g: float = ArenaBalance.FEATURE_RUINS_GOLD
		city.storage[&"gold"] = float(city.storage.get(&"gold", 0.0)) + g
		res["ruins_gold"] = g
	# Кластерный кэш устарел (build_building меняет buildings).
	ArenaClusterSystem.invalidate(city.uid)
	return res


## «Свободная» клетка для рабочего в арене: как City.is_worker_tile_free,
## но БЕЗ guard `x < 0` (клетки арены имеют отрицательные X) и без
## `first_free_worker_tile`. Свободна = не застроена, соседствует с центром
## или районом, не занята другим рабочим.
static func arena_tile_free(city: City, tile: Vector2i, except_uid: int = -1) -> bool:
	if city.cell_is_built(tile):
		return false
	if HexUtils.hex_distance(tile, city.center) != 1:
		var adj := false
		for b in city.boroughs:
			if HexUtils.hex_distance(tile, b.cell) == 1:
				adj = true
				break
		if not adj:
			return false
	for u in city.pop:
		if u.uid != except_uid and u.state == PopUnit.State.WORKER and u.tile == tile:
			return false
	return true


## Садит работников на свободные клетки (в мире это делает герой;
## в песочнице — автоматически). Рабочий без клетки не даёт дохода.
## request_switch применяется в конце хода, поэтому занятость в этом
## цикле учитываем сами (used). Порядок клеток — по кольцам
## (cells_in_arena) — детерминированно. Возвращает число пересадженных.
static func seat_workers(city: City) -> int:
	var seated := 0
	# Занятые клетки: tile -> uid работника. Учитываем и pending-переходы
	# (apply_pending ещё не выполнен — до process_turn), иначе два рабочих
	# могут «забронировать» одну и ту же клетку.
	var occupied: Dictionary = {}
	for u in city.pop:
		if u.state != PopUnit.State.WORKER:
			continue
		if u.tile.x >= 0:
			occupied[u.tile] = u.uid
		if u.pending_state == PopUnit.State.WORKER and u.pending_tile.x >= 0:
			occupied[u.pending_tile] = u.uid
	# Свободные клетки (детерминированный порядок обхода арены).
	var free_tiles: Array[Vector2i] = []
	for cell in ArenaRingSystem.cells_in_arena():
		if city.cell_is_built(cell) or occupied.has(cell):
			continue
		var ok: bool = HexUtils.hex_distance(cell, city.center) == 1
		if not ok:
			for b in city.boroughs:
				if HexUtils.hex_distance(cell, b.cell) == 1:
					ok = true
					break
		if ok:
			free_tiles.append(cell)
	var fi := 0
	for u in city.pop:
		if u.state != PopUnit.State.WORKER:
			continue
		var cur := u.tile
		if cur.x >= 0 and not city.cell_is_built(cur) \
				and int(occupied.get(cur, -1)) == u.uid:
			continue  # уже сидит на валидной клетке
		if fi >= free_tiles.size():
			break
		var t: Vector2i = free_tiles[fi]
		fi += 1
		occupied[t] = u.uid
		city.request_switch(u.uid, PopUnit.State.WORKER, t)
		seated += 1
	return seated


# ==================== СЧЁТ ====================

## Оценка результата плана (цель тюнера).
static func score(city: City, starve_days: int) -> float:
	var s := 0.0
	s += float(city.storage.get(&"gold", 0.0)) * 1.0
	s += float(city.storage.get(&"industry", 0.0)) * 0.5
	s += city.prosperity * 0.5
	s += city.level * 40.0
	s += city.pop_capped() * 2.0
	# Ценность цепочечных ресурсов (по 0.2 за единицу).
	for rid in [&"grain", &"flour", &"bread", &"ore", &"tools"]:
		s += float(city.storage.get(rid, 0.0)) * 0.2
	s -= starve_days * 30.0
	s -= city.over_limit() * 10.0
	return s


# ==================== СТУДИЯ: ДЕМО-ПЛАН ====================

## ---- Демонстрационный план (детерминированный) ----------------------
## Фиксированный сценарий застройки на 48 ходов. Используется тюнером
## (цель = score) и тестами (стабильность). Шаги с дедлайном: шаг
## повторяется каждый ход до успеха или дедлайна (устойчив к нехватке
## ресурсов при разных кандидатах баланса).

## Шаги плана: [дедлайн, kind, def_id, cell].
## kind: "build" (здание) / "borough" (район) / "upgrade" / "hire".
##
## Раскладка найдена backtracking-решателем под правила HexUtils
## (pointy-top, odd-row shift): мельница у 2 ферм, кузницы у рудников,
## таверна у хижины (+2 репутации), цепочка районов от центра,
## второй рудник — у первого.
static func demo_plan() -> Array:
	# Клетки ОТНОСИТЕЛЬНЫ к центру города. Дедлайн = «не позже этого хода»:
	## исполняется, когда ресурсы позволяют, но не позже дедлайна.
	# Районы — первыми: каждый автоматически эксплуатирует 6 соседних клеток.
	var p := []
	p.append([1, &"borough", &"", Vector2i(-1, -1)])      # R1 район 1 (20)
	p.append([2, &"build", &"farm", Vector2i(-1, 0)])     # R1 ферма (12)
	p.append([2, &"hire", &"", Vector2i.ZERO])
	p.append([3, &"borough", &"", Vector2i(-1, -2)])      # R2 район 2 (30)
	p.append([4, &"build", &"farm", Vector2i(0, 1)])      # R1 ферма 2 (12)
	p.append([5, &"build", &"mill", Vector2i(-1, 1)])     # R1 мельница (18)
	p.append([5, &"hire", &"", Vector2i.ZERO])
	p.append([6, &"borough", &"", Vector2i(0, -2)])       # R2 район 3 (40)
	p.append([6, &"build", &"farm", Vector2i(0, -3)])     # R3 ферма 3 (12) — кластер
	p.append([7, &"build", &"bakery", Vector2i(2, 0)])    # R2 пекарня (18)
	p.append([7, &"build", &"farm", Vector2i(-1, -3)])    # R3 ферма 4 (12) — кластер
	p.append([8, &"build", &"farm", Vector2i(1, -3)])     # R3 ферма 5 (12) — кластер
	p.append([9, &"build", &"farm", Vector2i(2, -2)])     # R3 ферма 6 (12) — кластер ×4!
	p.append([7, &"hire", &"", Vector2i.ZERO])
	p.append([8, &"borough", &"", Vector2i(-2, -3)])      # R3 район 4 (50)
	p.append([9, &"build", &"mine", Vector2i(1, -1)])     # R2 рудник (20)
	p.append([9, &"hire", &"", Vector2i.ZERO])
	p.append([10, &"build", &"smithy", Vector2i(1, 0)])   # R1 кузница (25)
	p.append([10, &"hire", &"", Vector2i.ZERO])
	p.append([11, &"build", &"shack", Vector2i(1, 1)])    # R2 хижина (15)
	p.append([12, &"build", &"tavern", Vector2i(-2, -1)]) # R2 таверна (22)
	p.append([12, &"hire", &"", Vector2i.ZERO])
	p.append([14, &"build", &"market", Vector2i(0, 2)])   # R2 рынок (25+2 посл.+40 зл.)
	p.append([16, &"build", &"walls", Vector2i(-3, -1)])  # R3 стены (20+2 посл.+30 зл.)
	p.append([18, &"build", &"trade_post", Vector2i(-1, 2)]) # R2 торг. пост (28)
	p.append([18, &"hire", &"", Vector2i.ZERO])
	p.append([20, &"build", &"school", Vector2i(-2, 1)])  # R2 училище (30)
	p.append([20, &"hire", &"", Vector2i.ZERO])
	p.append([24, &"hire", &"", Vector2i.ZERO])
	p.append([22, &"upgrade", &"market", Vector2i(0, 2)]) # lvl2 (50+2 посл.+40 зл.)
	p.append([26, &"upgrade", &"walls", Vector2i(-3, -1)])
	p.append([28, &"build", &"barracks", Vector2i(2, -1)]) # R3 казармы (20)
	p.append([30, &"upgrade", &"market", Vector2i(0, 2)]) # lvl3 (100+3 посл.+80 зл.)
	p.append([32, &"upgrade", &"walls", Vector2i(-3, -1)])
	p.append([34, &"hire", &"", Vector2i.ZERO])
	p.append([36, &"build", &"tavern", Vector2i(-2, 0)])  # R2 таверна 2 (22)
	p.append([36, &"hire", &"", Vector2i.ZERO])
	p.append([40, &"build", &"manor", Vector2i(1, 2)])    # R2 особняк (40)
	p.append([42, &"upgrade", &"barracks", Vector2i(2, -1)])
	p.append([44, &"hire", &"", Vector2i.ZERO])
	return p


## Выполнить демо-план на `turns` ходов и вернуть отчёт + score.
## score: золото + индустрия + процветание + уровень + население +
## цепочечные ресурсы − штрафы (голод, перенаселение).
static func run_demo_plan(turns: int = 48, overrides: Dictionary = {}) -> Dictionary:
	var city := make_city(overrides)
	var plan: Array = demo_plan()
	var pending: Array = []
	for step in plan:
		pending.append({"step": step, "done": false, "deadline": int(step[0])})
	var starve_days := 0
	var last: Dictionary = {}
	var t := 0
	while t < turns:
		t += 1
		# Шаги плана: шаг доступен С момента своего дедлайна и исполняется
		# на первом ходу, когда ресурсы позволяют (не сгорает).
		for item in pending:
			if item.done or t < int(item.deadline):
				continue
			var step: Array = item.step
			var kind: StringName = step[1]
			var id: StringName = step[2]
			# Клетки плана относительны к центру; город сидит в ARENA_CENTER.
			var cell: Vector2i = city.center + step[3]
			if kind == &"hire":
				_hire_workers(city)
			elif kind == &"borough":
				if not city.cell_is_built(cell):
					item.done = city.build_borough(cell)
			elif kind == &"build":
				var def: UniqueBuilding.Def = BuildingDefs.def_by_id(id)
				if def != null and city.get_building_at(cell) == null:
					var res: Dictionary = place_building(city, def, cell, overrides)
					if res.ok:
						item.done = true
			elif kind == &"upgrade":
				var bld: UniqueBuilding = city.get_building_at(cell)
				if bld != null and bld.def != null and bld.def.id == id \
						and bld.level < bld.def.levels.size():
					if city.perform_upgrade(bld):
						item.done = true
		last = run_turn(city, t, overrides)
		if city.starving:
			starve_days += 1
	return {
		"city": city,
		"turns": turns,
		"starve_days": starve_days,
		"last": last,
		"score": score(city, starve_days),
	}


# ==================== НАЙМ ====================

## Нанять одного рабочего (публичный API для UI арены). 0 = нельзя.
## Жильё — с учётом бонуса кластеров (cluster_worker_housing).
static func hire_worker(city: City) -> int:
	if ArenaClusterSystem.cluster_worker_housing(city) <= 0:
		return 0
	if not _has_free_worker_slot(city):
		return 0
	city.add_migrant(PopUnit.State.WORKER)
	return 1


## ponytail: вызов cluster_worker_housing внутри цикла — O(кластеров) за
## итерацию; для больших городов занести в локальную переменную один раз.
## Нанять рабочих, пока есть жильё (с бонусом кластеров) и свободные
## слоты цепочек.
static func _hire_workers(city: City) -> int:
	var hired := 0
	for _i in 8:
		if ArenaClusterSystem.cluster_worker_housing(city) <= 0:
			break
		if not _has_free_worker_slot(city):
			break
		city.add_migrant(PopUnit.State.WORKER)
		hired += 1
	return hired


static func _has_free_worker_slot(city: City) -> bool:
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		var chain: ProductionChain = b.get_production_chain()
		if chain == null:
			continue
		if b.assigned_workers < chain.required_workers:
			return true
	return false


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
