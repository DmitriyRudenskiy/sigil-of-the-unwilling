class_name ArenaDemoScenario
extends RefCounted
## Аудит #20: сценарий-демо и score вынесены из ArenaTurnRunner.
## Сценарий (plan + score) — самостоятельная единица: его правят/сравнивают
## без риска тронуть игровой цикл (run_turn/make_city) в ArenaTurnRunner.


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
	var city := ArenaTurnRunner.make_city(overrides)
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
				# ponytail: чужой private статик — вызов напрямую, экспорт не нужен.
				ArenaTurnRunner._hire_workers(city)
			elif kind == &"borough":
				if not city.cell_is_built(cell):
					item.done = city.build_borough(cell)
			elif kind == &"build":
				var def: UniqueBuilding.Def = BuildingDefs.def_by_id(id)
				if def != null and city.get_building_at(cell) == null:
					var res: Dictionary = ArenaTurnRunner.place_building(city, def, cell, overrides)
					if res.ok:
						item.done = true
			elif kind == &"upgrade":
				var bld: UniqueBuilding = city.get_building_at(cell)
				if bld != null and bld.def != null and bld.def.id == id \
						and bld.level < bld.def.levels.size():
					if city.perform_upgrade(bld):
						item.done = true
		last = ArenaTurnRunner.run_turn(city, t, overrides)
		if city.starving:
			starve_days += 1
	return {
		"city": city,
		"turns": turns,
		"starve_days": starve_days,
		"last": last,
		"score": score(city, starve_days),
	}
