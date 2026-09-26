class_name ArenaTurnRunner
extends RefCounted

const ArenaRingSystem := preload("res://scripts/city/arena_ring_system.gd")
const ArenaClusterSystem := preload("res://scripts/city/arena_cluster_system.gd")
const ArenaStorm := preload("res://scripts/city/arena_storm.gd")
const BuildingDefs := preload("res://scripts/data/building_defs.gd")
const HexUtils := preload("res://scripts/core/hex_utils.gd")
const City := preload("res://scripts/world/city.gd")
const PopUnit := preload("res://scripts/world/pop_unit.gd")
const UniqueBuilding := preload("res://scripts/world/unique_building.gd")
const CityTurnProcessor := preload("res://scripts/city/city_turn_processor.gd")
const EconomicTurnProcessor := preload("res://scripts/economy/economic_turn_processor.gd")
const TurnContext := preload("res://scripts/core/turn_context.gd")
const ProductionChain := preload("res://scripts/economy/production_chain.gd")

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
	for _i in 4:
		c.add_migrant(PopUnit.State.FOLLOWER)
	c.ensure_resource_ctx()
	return c

static func run_turn(city: City, turn: int, overrides: Dictionary = {}) -> Dictionary:
	seat_workers(city)
	var mono: Dictionary = city.process_turn(turn)
	var ctx := TurnContext.new()
	var cs: Array[City] = [city]
	ctx.cities = cs
	ctx.turn_number = turn

	var city_phase := CityTurnProcessor.new()
	var city_report: Dictionary = city_phase.process(ctx)
	var applied: int = ArenaRingSystem.apply_ring_multipliers(city, overrides, turn)
	var economy := EconomicTurnProcessor.new()
	var eco_report: Dictionary = economy.process(ctx)
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

static func place_building(
	city: City,
	def: UniqueBuilding.Def,
	cell: Vector2i,
	overrides: Dictionary = {}
) -> CityCheck:
	if def == null or def.levels.is_empty():
		return _fail("Нет определения здания")
	if not ArenaRingSystem.is_in_arena(cell):
		return _fail("Клетка вне арены")
	var check: CityCheck = city.can_build_building(def, cell)
	if not check.ok:
		return check
	var bld: UniqueBuilding = city.build_building(def, cell)
	if bld == null:
		return check
	var clm: Dictionary = ArenaClusterSystem.cluster_uids(city)
	bld.zone_multiplier = (1.0 + ArenaRingSystem.ring_bonus(def.id, ArenaRingSystem.ring_of(cell), overrides)) \
		* float(clm.get(bld.uid, 1.0)) * ArenaRingSystem.feature_mult(city, def.id, cell)
	var p: Dictionary = {
		"building": bld,
		"cost": float(check.payload.get("cost", 0.0)),
		"ring": ArenaRingSystem.ring_of(cell),
	}
	if ArenaRingSystem.cell_feature(city, cell) == &"ruins":
		var g: float = GameNumbers.ARENA_FEATURE_RUINS_GOLD
		city.storage[&"gold"] = float(city.storage.get(&"gold", 0.0)) + g
		p["ruins_gold"] = g
	ArenaClusterSystem.invalidate(city.uid)
	return CityCheck.success(p)

static func arena_tile_free(city: City, tile: Vector2i, except_uid: int = -1) -> bool:
	if city.cell_is_built(tile):
		return false
	if HexUtils.hex_distance(tile, city.center) != 1:
		var adj := false
		for borough in city.boroughs:
			if HexUtils.hex_distance(tile, borough.cell) == 1:
				adj = true
				break
		if not adj:
			return false
	for u in city.pop:
		if u.uid != except_uid and u.state == PopUnit.State.WORKER and u.tile == tile:
			return false
	return true

static func seat_workers(city: City) -> int:
	var seated := 0
	var occupied: Dictionary = {}
	for u in city.pop:
		if u.state != PopUnit.State.WORKER:
			continue
		if u.tile.x >= 0:
			occupied[u.tile] = u.uid
		if u.pending_state == PopUnit.State.WORKER and u.pending_tile.x >= 0:
			occupied[u.pending_tile] = u.uid
	var free_tiles: Array[Vector2i] = []
	for cell in ArenaRingSystem.cells_in_arena():
		if city.cell_is_built(cell) or occupied.has(cell):
			continue
		var ok: bool = HexUtils.hex_distance(cell, city.center) == 1
		if not ok:
			for borough in city.boroughs:
				if HexUtils.hex_distance(cell, borough.cell) == 1:
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
			continue
		if fi >= free_tiles.size():
			break
		var t: Vector2i = free_tiles[fi]
		fi += 1
		occupied[t] = u.uid
		city.request_switch(u.uid, PopUnit.State.WORKER, t)
		seated += 1
	return seated

static func hire_worker(city: City) -> int:
	if ArenaClusterSystem.cluster_worker_housing(city) <= 0:
		return 0
	if not _has_free_worker_slot(city):
		return 0
	city.add_migrant(PopUnit.State.WORKER)
	return 1

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
	for building in city.buildings:
		if building == null or building.def == null:
			continue
		var chain: ProductionChain = building.get_production_chain()
		if chain == null:
			continue
		if building.assigned_workers < chain.required_workers:
			return true
	return false

static func _fail(reason: String) -> CityCheck:
	return CityCheck.fail(reason)
