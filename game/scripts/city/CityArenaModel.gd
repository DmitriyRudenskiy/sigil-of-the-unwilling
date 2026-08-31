class_name CityArenaModel
extends RefCounted
## Модель строительной арены — отдельная hex-карта с кольцами.
##
## Арена: шестиугольное поле радиуса ARENA_RADIUS (91 клетка), центр
## города — (0, 0). Каждое кольцо имеет свой цвет, свой прирост
## ресурсов (ArenaBalance.RING_YIELD) и свои бонусы зданий
## (ArenaBalance.RING_BONUS). Численные константы подбираются
## итеративно tools/tune_city_arena.gd.
##
## Ход арены повторяет мир:
##   1. монолит City.process_turn(turn) — еда, рост, легаси-хранилище;
##   2. фаза города CityTurnProcessor — масштаб, зonation, репутация,
##      рабочие, процветание, уровень, рейды, события;
##   3. КОЛЬЦА — apply_ring_multipliers(): zone_multiplier зданий =
##      (1 + бонус кольца) × кластер × особенность клетки × шторм
##      (фаза города сбрасывает множитель, поэтому применяем после неё);
##   4. экономика EconomicTurnProcessor — читает zone_multiplier;
##   5. ШТОРМ (после экономики): потери еды на каждом N-м ходе.
##
## Механики арены (в духе TerraScape, все детерминированы):
##   * Кластер ×4: связная группа ≥4 зданий одного типа — ×CLUSTER_MULT
##     к производству каждого + CLUSTER_HOUSING слотов рабочих.
##   * Особенности клеток (хэш uid+клетка, кольца 2..4): карьер (рудник),
##     родник (ферма), река (всё), руины (+золото при постройке).
##   * Шторм: каждый STORM_PERIOD-й ход — ×производство, −еда;
##     стены ур. 2+ смягчают.
##
## Чистая статика: нет autoload'ов, headless-тестируема.

const ARENA_RADIUS := ArenaBalance.ARENA_RADIUS

## Порядок ресурсов прироста кольца (совпадает с RING_YIELD).
const YIELD_KEYS: Array = [&"food", &"industry", &"dust", &"science", &"influence"]

## Палитра колец: index = номер кольца (0 = центр).
const RING_COLORS: Array = [
	Color(0.95, 0.8, 0.3),     # 0 — центр (золото)
	Color(0.33, 0.58, 0.33),   # 1 — зелёное
	Color(0.78, 0.66, 0.32),   # 2 — жёлтое
	Color(0.72, 0.42, 0.36),   # 3 — красное
	Color(0.56, 0.42, 0.68),   # 4 — фиолетовое
	Color(0.36, 0.52, 0.78),   # 5 — синее
]

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


## Абсолютный центр арены. Строка чЁТНАЯ: в odd-r offset форма кольца
## зависит от parity строки, и только чётная строка совпадает с
## «стандартным» кольцом вокруг (0,0), на которое рассчитан демо-план.
## Сдвиг вправо, чтобы все клетки имели x >= 0 (City.gd пропускает
## работников с tile.x < 0: is_worker_tile_free / _ensure_exploited_cache).
const ARENA_CENTER := Vector2i(5, 4)


## Центр арены и города.
static func center() -> Vector2i:
	return ARENA_CENTER


## Номер кольца клетки (0 = центр).
static func ring_of(cell: Vector2i) -> int:
	return HexUtils.hex_distance(cell, center())


static func is_in_arena(cell: Vector2i) -> bool:
	return ring_of(cell) <= ARENA_RADIUS


## Все клетки арены: центр + кольца 1..R (91 клетка при R=5).
static func cells_in_arena() -> Array[Vector2i]:
	var out: Array[Vector2i] = [center()]
	for ring in range(1, ARENA_RADIUS + 1):
		out.append_array(cells_in_ring(ring))
	return out


## Все клетки заданного кольца (6*ring клеток). Клетки в АБСОЛЮТНЫХ
## координатах арены. Offset-координаты не инвариантны к сдвигу (parity),
## поэтому кольцо генерируется прямым сканом окрестности центра с точной
## проверкой hex_distance — детерминированно (по строкам).
static func cells_in_ring(ring: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if ring < 1:
		return out
	var c: Vector2i = center()
	for y in range(-ring - 1, ring + 2):
		for x in range(-ring - 1, ring + 2):
			var cell := c + Vector2i(x, y)
			if HexUtils.hex_distance(cell, c) == ring:
				out.append(cell)
	return out


## Цвет кольца (для представления и легенды).
static func ring_color(ring: int) -> Color:
	var i := clampi(ring, 0, ARENA_RADIUS)
	return RING_COLORS[i]


## Прирост ресурсов на клетке (для City.tile_yield_fn).
static func tile_yield(cell: Vector2i, overrides: Dictionary = {}) -> Dictionary:
	var ring := ring_of(cell)
	if overrides.has(&"ring_yield"):
		return ArenaBalance.ring_yield(ring, overrides[&"ring_yield"])
	return ArenaBalance.ring_yield(ring)


## Бонус здания на кольце (с учётом опциональных переопределений —
## их использует тюнер).
static func ring_bonus(def_id: StringName, ring: int, overrides: Dictionary = {}) -> float:
	if overrides.has(&"ring_bonus"):
		return ArenaBalance.ring_bonus(def_id, ring, overrides[&"ring_bonus"])
	return ArenaBalance.ring_bonus(def_id, ring)


## Новый город арены: центр (0,0), форт 2-го уровня, стартовое
## население (4 рабочих + 2 последователя), стартовые ресурсы.
static func make_city(overrides: Dictionary = {}) -> City:
	var c := City.new()
	c.uid = 1
	c.display_name = "Арена"
	c.center = center()
	c.stronghold_level = 2
	c.is_capital = true
	c.food_stockpile = 25.0
	c.storage = {&"industry": 80.0, &"gold": 40.0}
	c.tile_yield_fn = func(cell: Vector2i) -> Dictionary:
		return tile_yield(cell, overrides)
	for _i in 4:
		c.add_migrant(PopUnit.State.WORKER)
	# 4 последователя: по 2 — на апгрейды стен/рынка до 2-го уровня.
	for _i in 4:
		c.add_migrant(PopUnit.State.FOLLOWER)
	c.ensure_resource_ctx()
	return c


## Полный множитель здания: кольцо × кластер × особенность × шторм.
## `turn` — для шторма (−1 или 0 = шторма нет).
static func building_mult(city: City, b: UniqueBuilding,
		overrides: Dictionary = {}, turn: int = -1) -> float:
	var clm: Dictionary = cluster_uids(city)
	var m: float = 1.0 + ring_bonus(b.def.id, ring_of(b.cell), overrides)
	m *= float(clm.get(b.uid, 1.0))
	m *= feature_mult(city, b.def.id, b.cell)
	m *= storm_production_mult(city, turn)
	return m


## Применить множители: zone_multiplier = кольцо × кластер × особенность
## × шторм. Вызывается ПОСЛЕ фазы города (она сбрасывает множитель) и
## ПЕРЕД экономикой (она его читает). Возвращает число затронутых зданий.
static func apply_ring_multipliers(city: City, overrides: Dictionary = {},
		turn: int = -1) -> int:
	var clm: Dictionary = cluster_uids(city)
	var storm: float = storm_production_mult(city, turn)
	var n := 0
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		var m: float = 1.0 + ring_bonus(b.def.id, ring_of(b.cell), overrides)
		m *= float(clm.get(b.uid, 1.0))
		m *= feature_mult(city, b.def.id, b.cell)
		if storm < 1.0:
			m *= storm
		b.zone_multiplier = m
		n += 1
	return n


## ==================== КЛАСТЕРЫ (авто-слияние ×4) ====================

## Связные группы ≥CLUSTER_MIN зданий одного типа (hex-соседство).
## Возвращает [ {"def_id", "cells": Array[Vector2i], "buildings"} ] в
## детерминированном порядке (по первой клетке кластера: y, затем x).
static func clusters(city: City) -> Array:
	var by_def: Dictionary = {}
	for b in city.buildings:
		if b == null or b.def == null:
			continue
		if not by_def.has(b.def.id):
			by_def[b.def.id] = []
		(by_def[b.def.id] as Array).append(b)
	var out: Array = []
	for def_id in by_def:
		var bldgs: Array = by_def[def_id]
		var by_cell: Dictionary = {}
		for b in bldgs:
			by_cell[(b as UniqueBuilding).cell] = b
		var seen: Dictionary = {}
		for b0 in bldgs:
			var start: UniqueBuilding = b0
			if seen.has(start.uid):
				continue
			var comp: Array = []
			var stack: Array = [start]
			seen[start.uid] = true
			while not stack.is_empty():
				var b: UniqueBuilding = stack.pop_back()
				comp.append(b)
				for nb in HexUtils.get_all_neighbors(b.cell):
					var nb_b: UniqueBuilding = by_cell.get(nb)
					if nb_b != null and not seen.has(nb_b.uid):
						seen[nb_b.uid] = true
						stack.append(nb_b)
			if comp.size() >= ArenaBalance.CLUSTER_MIN:
				var cells: Array[Vector2i] = []
				for b in comp:
					cells.append((b as UniqueBuilding).cell)
				out.append({"def_id": def_id, "cells": cells, "buildings": comp})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = (a["cells"] as Array)[0]
		var cb: Vector2i = (b["cells"] as Array)[0]
		return ca.y * 10000 + ca.x < cb.y * 10000 + cb.x)
	return out


## uid здания -> множитель кластера (отсутствует = вне кластера).
static func cluster_uids(city: City) -> Dictionary:
	var m: Dictionary = {}
	for cl in clusters(city):
		for b in (cl as Dictionary)["buildings"]:
			m[(b as UniqueBuilding).uid] = ArenaBalance.CLUSTER_MULT
	return m


## Свободные слоты рабочих с учётом бонуса кластеров (+CLUSTER_HOUSING
## на каждый кластер).
static func cluster_worker_housing(city: City) -> int:
	return city.free_housing(PopUnit.State.WORKER) \
		+ ArenaBalance.CLUSTER_HOUSING * (clusters(city) as Array).size()


## ==================== ОСОБЕННОСТИ КЛЕТОК ====================

## Детерминированная особенность клетки (хэш uid города + координаты).
## Только кольца 2..4; &"" — обычная клетка. Виды: quarry (рудник ×),
## spring (ферма ×), river (всё ×), ruins (+золото при постройке).
static func cell_feature(city: City, cell: Vector2i) -> StringName:
	var ring := ring_of(cell)
	if ring < 2 or ring > 4:
		return &""
	var h: int = hash("%d:%d:%d" % [city.uid, cell.x, cell.y])
	var v: int = absi(h)
	if float(v % 1000) / 1000.0 >= ArenaBalance.FEATURE_CHANCE:
		return &""
	match v % 4:
		0:
			return &"quarry"
		1:
			return &"spring"
		2:
			return &"river"
		_:
			return &"ruins"
	return &""


## Множитель производства на особенности (1.0 = нет). Карьер и родник —
## только для своего здания, река — для любого.
static func feature_mult(city: City, def_id: StringName, cell: Vector2i) -> float:
	var f: StringName = cell_feature(city, cell)
	match f:
		&"quarry":
			return ArenaBalance.FEATURE_QUARRY_MULT if def_id == &"mine" else 1.0
		&"spring":
			return ArenaBalance.FEATURE_SPRING_MULT if def_id == &"farm" else 1.0
		&"river":
			return ArenaBalance.FEATURE_RIVER_MULT
		_:
			return 1.0
	return 1.0


static func feature_glyph(feature: StringName) -> String:
	match feature:
		&"quarry":
			return "⛏"
		&"spring":
			return "💧"
		&"river":
			return "🌊"
		&"ruins":
			return "🏛"
		_:
			return ""
	return ""


static func feature_name(feature: StringName) -> String:
	match feature:
		&"quarry":
			return "Карьер: рудник ×%.1f" % ArenaBalance.FEATURE_QUARRY_MULT
		&"spring":
			return "Родник: ферма ×%.1f" % ArenaBalance.FEATURE_SPRING_MULT
		&"river":
			return "Река: любое здание ×%.2f" % ArenaBalance.FEATURE_RIVER_MULT
		&"ruins":
			return "Руины: +%.0f золота при постройке" % ArenaBalance.FEATURE_RUINS_GOLD
		_:
			return ""
	return ""


## ==================== ШТОРМ ====================

## Шторм на каждом STORM_PERIOD-м ходе (turn % N == 0).
static func is_storm_turn(turn: int) -> bool:
	return turn > 0 and ArenaBalance.STORM_PERIOD > 0 \
		and turn % ArenaBalance.STORM_PERIOD == 0


static func _has_walls_lvl2(city: City) -> bool:
	for b in city.buildings:
		if b != null and b.def != null and b.def.id == &"walls" and b.level >= 2:
			return true
	return false


## Множитель производства в шторм (1.0 = шторма нет).
static func storm_production_mult(city: City, turn: int) -> float:
	if not is_storm_turn(turn):
		return 1.0
	if _has_walls_lvl2(city):
		return ArenaBalance.STORM_MITIGATED_PRODUCTION_MULT
	return ArenaBalance.STORM_PRODUCTION_MULT


## Потери еды от шторма (вычитается после экономики).
static func storm_food_penalty(city: City, turn: int) -> float:
	if not is_storm_turn(turn):
		return 0.0
	if _has_walls_lvl2(city):
		return ArenaBalance.STORM_MITIGATED_FOOD
	return ArenaBalance.STORM_FOOD


## Поставить здание: проверка арены + City.can_build_building +
## начальный кольцевой множитель. {ok, reason?, building?, cost?, ring?}.
static func place_building(
	city: City, def: UniqueBuilding.Def, cell: Vector2i,
	overrides: Dictionary = {}) -> Dictionary:
	if def == null or def.levels.is_empty():
		return _fail("Нет определения здания")
	if not is_in_arena(cell):
		return _fail("Клетка вне арены")
	var check: Dictionary = city.can_build_building(def, cell)
	if not check.ok:
		return check
	var bld := city.build_building(def, cell)
	if bld == null:
		return check
	# Начальный множитель: кольцо × кластер (новое здание может ЗАВЕРШИТЬ
	# кластер!) × особенность клетки.
	var clm: Dictionary = cluster_uids(city)
	bld.zone_multiplier = (1.0 + ring_bonus(def.id, ring_of(cell), overrides)) \
		* float(clm.get(bld.uid, 1.0)) * feature_mult(city, def.id, cell)
	var res: Dictionary = {
		"ok": true,
		"building": bld,
		"cost": float(check.get("cost", 0.0)),
		"ring": ring_of(cell),
	}
	# Руины: разовый бонус золота за постройку на клетке.
	if cell_feature(city, cell) == &"ruins":
		var g: float = ArenaBalance.FEATURE_RUINS_GOLD
		city.storage[&"gold"] = float(city.storage.get(&"gold", 0.0)) + g
		res["ruins_gold"] = g
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
## Посадить рабочих на свободные клетки арены. Свободная клетка:
## не застроена, соседствует с центром или районом, не занята другим
## рабочим. Список свободных клеток считается ОДИН раз за ход
## (было: O(рабочие × клетки × население) на каждый ход — тормозило
## тюнер до 200 мс/ход).
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
	for cell in cells_in_arena():
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


## Полноценный ход арены: сидение работников + монолит + фаза города
## + кольца + экономика.
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
	# zone_multiplier фазой города).
	var applied: int = apply_ring_multipliers(city, overrides, turn)
	# 4. Экономика (читает zone_multiplier).
	var eco_report: Dictionary = _get_economy().process(ctx)
	# 5. Шторм: потери еды после экономики.
	var storm_food: float = storm_food_penalty(city, turn)
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
		"storm": is_storm_turn(turn),
		"storm_food": storm_food,
		"clusters": (clusters(city) as Array).size(),
		"starving": city.starving,
		"net_food": city.net_food(),
		"food": city.food_stockpile,
		"industry": float(city.storage.get(&"industry", 0.0)),
		"gold": float(city.storage.get(&"gold", 0.0)),
		"level": city.level,
		"prosperity": city.prosperity,
	}


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


## Нанять одного рабочего (публичный API для UI арены). 0 = нельзя.
## Жильё — с учётом бонуса кластеров (cluster_worker_housing).
static func hire_worker(city: City) -> int:
	if cluster_worker_housing(city) <= 0:
		return 0
	if not _has_free_worker_slot(city):
		return 0
	city.add_migrant(PopUnit.State.WORKER)
	return 1


## Нанять рабочих, пока есть жильё (с бонусом кластеров) и свободные
## слоты цепочек.
static func _hire_workers(city: City) -> int:
	var hired := 0
	for _i in 8:
		if cluster_worker_housing(city) <= 0:
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
