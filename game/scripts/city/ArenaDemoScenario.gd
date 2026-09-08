class_name ArenaDemoScenario
extends RefCounted



static func score(city: City, starve_days: int) -> float:
	var s := 0.0
	s += float(city.storage.get(&"gold", 0.0)) * 1.0
	s += float(city.storage.get(&"industry", 0.0)) * 0.5
	s += city.prosperity * 0.5
	s += city.level * 40.0
	s += city.pop_capped() * 2.0
	for rid in [&"grain", &"flour", &"bread", &"ore", &"tools"]:
		s += float(city.storage.get(rid, 0.0)) * 0.2
	s -= starve_days * 30.0
	s -= city.over_limit() * 10.0
	return s




static func demo_plan() -> Array:
	var p := []
	p.append([1, &"borough", &"", Vector2i(-1, -1)])      
	p.append([2, &"build", &"farm", Vector2i(-1, 0)])     
	p.append([2, &"hire", &"", Vector2i.ZERO])
	p.append([3, &"borough", &"", Vector2i(-1, -2)])      
	p.append([4, &"build", &"farm", Vector2i(0, 1)])      
	p.append([5, &"build", &"mill", Vector2i(-1, 1)])     
	p.append([5, &"hire", &"", Vector2i.ZERO])
	p.append([6, &"borough", &"", Vector2i(0, -2)])       
	p.append([6, &"build", &"farm", Vector2i(0, -3)])     
	p.append([7, &"build", &"bakery", Vector2i(2, 0)])    
	p.append([7, &"build", &"farm", Vector2i(-1, -3)])    
	p.append([8, &"build", &"farm", Vector2i(1, -3)])     
	p.append([9, &"build", &"farm", Vector2i(2, -2)])     
	p.append([7, &"hire", &"", Vector2i.ZERO])
	p.append([8, &"borough", &"", Vector2i(-2, -3)])      
	p.append([9, &"build", &"mine", Vector2i(1, -1)])     
	p.append([9, &"hire", &"", Vector2i.ZERO])
	p.append([10, &"build", &"smithy", Vector2i(1, 0)])   
	p.append([10, &"hire", &"", Vector2i.ZERO])
	p.append([11, &"build", &"shack", Vector2i(1, 1)])    
	p.append([12, &"build", &"tavern", Vector2i(-2, -1)]) 
	p.append([12, &"hire", &"", Vector2i.ZERO])
	p.append([14, &"build", &"market", Vector2i(0, 2)])   
	p.append([16, &"build", &"walls", Vector2i(-3, -1)])  
	p.append([18, &"build", &"trade_post", Vector2i(-1, 2)]) 
	p.append([18, &"hire", &"", Vector2i.ZERO])
	p.append([20, &"build", &"school", Vector2i(-2, 1)])  
	p.append([20, &"hire", &"", Vector2i.ZERO])
	p.append([24, &"hire", &"", Vector2i.ZERO])
	p.append([22, &"upgrade", &"market", Vector2i(0, 2)]) 
	p.append([26, &"upgrade", &"walls", Vector2i(-3, -1)])
	p.append([28, &"build", &"barracks", Vector2i(2, -1)]) 
	p.append([30, &"upgrade", &"market", Vector2i(0, 2)]) 
	p.append([32, &"upgrade", &"walls", Vector2i(-3, -1)])
	p.append([34, &"hire", &"", Vector2i.ZERO])
	p.append([36, &"build", &"tavern", Vector2i(-2, 0)])  
	p.append([36, &"hire", &"", Vector2i.ZERO])
	p.append([40, &"build", &"manor", Vector2i(1, 2)])    
	p.append([42, &"upgrade", &"barracks", Vector2i(2, -1)])
	p.append([44, &"hire", &"", Vector2i.ZERO])
	return p


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
		for item in pending:
			if item.done or t < int(item.deadline):
				continue
			var step: Array = item.step
			var kind: StringName = step[1]
			var id: StringName = step[2]
			var cell: Vector2i = city.center + step[3]
			if kind == &"hire":
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
