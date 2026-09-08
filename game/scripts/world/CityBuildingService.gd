class_name CityBuildingService
extends RefCounted
# R3: операции строительства/апгрейда/переноса вынесены из City.gd (паттерн BoroughRules:
# статические правила, city — аргумент; сигналы эмитит City в тонких обёртках).

const RELOCATE_MAX_DISTANCE := 3


static func fail(reason: String) -> Dictionary:
	return {"ok": false, "cost": 0.0, "reason": reason}


static func check_req(city: City, req: UniqueBuilding.LevelReq) -> Dictionary:
	if float(city.storage.get(&"industry", 0.0)) < req.industry:
		return fail("Промышленность: %.0f/%.0f" % [float(city.storage.get(&"industry", 0.0)), req.industry])
	if req.special_amount > 0.0 \
			and float(city.storage.get(req.special_resource, 0.0)) < req.special_amount:
		return fail("%s: %.0f/%.0f" % [
			String(req.special_resource),
			float(city.storage.get(req.special_resource, 0.0)), req.special_amount,
		])
	if city.free_followers() < req.followers:
		return fail("Свободных последователей: %d/%d" % [city.free_followers(), req.followers])
	return {"ok": true, "cost": req.industry, "reason": ""}


static func spend_req(city: City, req: UniqueBuilding.LevelReq) -> void:
	city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) - req.industry
	if req.special_amount > 0.0:
		city.storage[req.special_resource] = float(city.storage.get(req.special_resource, 0.0)) - req.special_amount


static func assign_followers(city: City, bld: UniqueBuilding, n: int) -> void:
	var left := n
	for u in city.pop:
		if left <= 0:
			break
		if u.is_free_follower():
			u.assigned_to = bld.uid
			left -= 1
	bld.assigned_followers += n - left


static func within_build_distance(city: City, cell: Vector2i) -> bool:
	if HexUtils.hex_distance(cell, city.center) <= city.building_max_distance():
		return true
	for b in city.boroughs:
		if HexUtils.hex_distance(cell, b.cell) <= city.building_max_distance():
			return true
	return false


static func can_build_borough(city: City, cell: Vector2i) -> Dictionary:
	if cell == city.center:
		return fail("Клетка занята центром города")
	if city.cell_is_built(cell):
		return fail("Клетка уже застроена")
	if not city._is_adjacent_to_city_body(cell):
		return fail("Район должен примыкать к городу или району")
	if city.boroughs.size() >= BoroughRules.max_boroughs(city):
		return fail("Лимит районов: 1 район на %d населения" % int(BoroughRules.pop_ratio(city.faction)))
	var cost := BoroughRules.cost(city)
	if float(city.storage.get(&"industry", 0.0)) < cost:
		return fail("Промышленность: %.0f/%.0f" % [float(city.storage.get(&"industry", 0.0)), cost])
	return {"ok": true, "cost": cost, "reason": ""}


static func build_borough(city: City, cell: Vector2i) -> Dictionary:
	var check := can_build_borough(city, cell)
	if not check.ok:
		return {"ok": false, "reason": check.reason}
	city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) - float(check.cost)
	var b := Borough.new()
	b.cell = cell
	b.level = 1
	b.uid = city._uid_seq
	city._uid_seq += 1
	city.boroughs.append(b)
	BoroughRules.process_level_ups(city)
	return {"ok": true, "reason": ""}


static func can_build_building(city: City, def: UniqueBuilding.Def, cell: Vector2i) -> Dictionary:
	if def == null or def.levels.is_empty():
		return fail("Нет определения здания")
	if cell == city.center or city.cell_is_built(cell):
		return fail("Клетка занята")
	for u in city.pop:
		if u.state == PopUnit.State.WORKER and u.tile == cell:
			return fail("Клетка занята рабочим")
	if def.requires_site:
		if not city.special_sites.has(cell):
			return fail("Здание требует специальной площадки")
	else:
		if not within_build_distance(city, cell):
			return fail("Не дальше %d клеток от города или района" % city.building_max_distance())
	var req: UniqueBuilding.LevelReq = def.levels[0]
	return check_req(city, req)


static func build_building(city: City, def: UniqueBuilding.Def, cell: Vector2i) -> Dictionary:
	var check := can_build_building(city, def, cell)
	if not check.ok:
		return {"bld": null, "reason": check.reason}
	var req: UniqueBuilding.LevelReq = def.levels[0]
	spend_req(city, req)
	var bld := UniqueBuilding.new()
	bld.def = def
	bld.cell = cell
	bld.level = 1
	bld.uid = city._uid_seq
	city._uid_seq += 1
	assign_followers(city, bld, req.followers)
	if def.production_chain != null:
		bld.production_chain = ProductionChain.from_dict(def.production_chain.to_dict())
	for k in def.default_upkeep:
		bld.upkeep[StringName(k)] = float(def.default_upkeep[k])
	bld.zone_type = def.default_zone
	city.buildings.append(bld)
	return {"bld": bld, "reason": ""}


static func can_upgrade_building(city: City, bld: UniqueBuilding, hero_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if bld == null or not city.buildings.has(bld):
		return fail("Здание не найдено")
	if bld.level >= GameNumbers.BUILDING_MAX_LEVEL:
		return fail("Максимальный уровень")
	var req := bld.next_level_req()
	if req == null:
		return fail("Нет требований для следующего уровня")
	var check := check_req(city, req)
	if not check.ok:
		return check
	if hero_cell.x >= 0 and hero_cell != bld.cell:
		return fail("Герой должен находиться на клетке здания")
	return check


static func perform_upgrade(city: City, bld: UniqueBuilding) -> Dictionary:
	var check := can_upgrade_building(city, bld)
	if not check.ok:
		return {"ok": false, "reason": check.reason}
	var req := bld.next_level_req()
	spend_req(city, req)
	assign_followers(city, bld, req.followers)
	bld.level += 1
	return {"ok": true, "reason": ""}


static func relocate(
	city: City,
	new_center: Vector2i,
	map_size: Vector2i = Vector2i(-1, -1),
	occupied_cells: Dictionary = {}
) -> Dictionary:
	if new_center == city.center:
		return fail("Новый центр совпадает со старым")
	if HexUtils.hex_distance(city.center, new_center) > RELOCATE_MAX_DISTANCE:
		return fail("Слишком далеко: максимум %d клеток" % RELOCATE_MAX_DISTANCE)
	if map_size.x > 0 and map_size.y > 0:
		if new_center.x < 0 or new_center.y < 0 \
				or new_center.x >= map_size.x or new_center.y >= map_size.y:
			return fail("Новый центр вне карты")
	if occupied_cells.get(new_center, false):
		return fail("На новом центре стоит другой город")
	if city.cell_is_built(new_center):
		return fail("На новом центре уже застройка")
	var delta := new_center - city.center
	for b in city.boroughs:
		b.cell += delta
	for b in city.buildings:
		b.cell += delta
	var new_roads: Dictionary = {}
	for cell in city.roads:
		new_roads[(cell as Vector2i) + delta] = true
	city.roads = new_roads
	for u in city.pop:
		if u.tile.x >= 0:
			u.tile += delta
	city.center = new_center
	city._invalidate_exploited()
	return {"ok": true, "new_center": new_center}
